import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/app_services.dart';
import '../../../../app/app_settings.dart';
import '../../../../core/widgets/navigation_shell.dart';
import '../../../../models/bangumi_models.dart';
import '../../../../models/notion_models.dart';
import '../../../dashboard/presentation/notion_detail_page.dart';
import '../../../detail/presentation/detail_page.dart';
import '../../../detail/providers/detail_view_model.dart';
import '../../../detail/presentation/notion_import_dialog.dart';
import '../../providers/batch_binding_similarity.dart';
import '../../providers/batch_binding_ui_controller.dart';
import '../../providers/batch_binding_ui_models.dart';
import '../../providers/batch_import_view_model.dart';
import 'batch_import_view.dart';

class BatchImportPage extends StatefulWidget {
  const BatchImportPage({super.key});

  @override
  State<BatchImportPage> createState() => _BatchImportPageState();
}

class _BatchImportPageState extends State<BatchImportPage> {
  late final AppServices _services;
  late final AppSettings _settings;
  late final BatchImportViewModel _model;
  late final BatchBindingUiController _uiController;
  late final TextEditingController _searchController;
  late final TextEditingController _manualInputController;

  bool _isBulkBinding = false;
  bool _isManualVerifying = false;
  int? _manualVerifiedId;
  String? _manualVerifiedForPageId;
  String? _lastActivePageId;
  BangumiSubjectDetail? _manualVerifiedDetail;

  @override
  void initState() {
    super.initState();
    _services = context.read<AppServices>();
    _settings = context.read<AppSettings>();

    _model = BatchImportViewModel(
      settings: _settings,
      notionApi: _services.notionApi,
      bangumiApi: _services.bangumiApi,
    );
    _uiController = BatchBindingUiController(autoBindThreshold: 85);
    _searchController = TextEditingController();
    _manualInputController = TextEditingController();

    _model.addListener(_handleModelUpdated);
    _uiController.addListener(_handleUiUpdated);

    unawaited(_model.load());
  }

  @override
  void dispose() {
    _model.removeListener(_handleModelUpdated);
    _uiController.removeListener(_handleUiUpdated);
    _searchController.dispose();
    _manualInputController.dispose();
    _uiController.dispose();
    _model.dispose();
    super.dispose();
  }

  void _handleModelUpdated() {
    if (_model.errorMessage == null && !_model.isLoading) {
      _uiController.applyCandidates(_model.candidates);
    }
  }

  void _handleUiUpdated() {
    final activeId = _uiController.activeItem?.pageId;
    if (_lastActivePageId == activeId) {
      return;
    }
    _lastActivePageId = activeId;
    _manualInputController.clear();
    if (mounted) {
      setState(() {
        _manualVerifiedId = null;
        _manualVerifiedForPageId = null;
        _manualVerifiedDetail = null;
      });
    }
  }

  Future<void> _refresh() async {
    await _model.load(forceRefresh: true);
  }

  Future<bool> _bindCandidateWithDialog(BatchUiItem item, int bangumiId) async {
    DetailViewModel? importModel;
    try {
      final detail = await _model.getSubjectDetail(bangumiId);
      if (!mounted) return false;

      importModel = DetailViewModel(
        subjectId: bangumiId,
        bangumiApi: _services.bangumiApi,
        notionApi: _services.notionApi,
        settings: _settings,
        initialDetail: detail,
      );

      final imported = await showNotionImportDialog(
        context: context,
        model: importModel,
        initialBindMode: true,
        initialNotionId: item.notionId,
      );

      if (!mounted) return false;
      if (imported) {
        _model.markCandidateBound(item.pageId);
        _uiController.markBound(item.pageId);
      }
      return imported;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载导入数据失败: $error')),
      );
      return false;
    } finally {
      importModel?.dispose();
    }
  }

  Future<void> _bindTasksSequential(List<_BindTask> tasks) async {
    if (tasks.isEmpty || _isBulkBinding) {
      return;
    }

    setState(() => _isBulkBinding = true);
    try {
      for (final task in tasks) {
        if (!mounted) break;
        await _bindCandidateWithDialog(task.item, task.bangumiId);
      }
    } finally {
      if (mounted) {
        setState(() => _isBulkBinding = false);
      }
    }
  }

  Future<void> _bindOneClickVisible() async {
    final tasks = _uiController
        .autoBindableVisibleItems()
        .map((item) {
          final match = item.bestSimilarityMatch;
          if (match == null) return null;
          return _BindTask(item: item, bangumiId: match.item.id);
        })
        .whereType<_BindTask>()
        .toList();

    if (tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前没有可自动绑定的条目')),
      );
      return;
    }
    await _bindTasksSequential(tasks);
  }

  Future<void> _bindSelectedItems() async {
    final tasks = _uiController
        .selectedVisibleItemsForBinding()
        .map((item) {
          final match = item.bestSimilarityMatch;
          if (match == null) return null;
          return _BindTask(item: item, bangumiId: match.item.id);
        })
        .whereType<_BindTask>()
        .toList();

    if (tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择可绑定条目')),
      );
      return;
    }

    await _bindTasksSequential(tasks);
    _uiController.clearSelection();
  }

  void _skipSelectedItems() {
    final removed = _uiController.removeSelectedVisibleItems();
    if (removed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择需要跳过的条目')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已跳过 ${removed.length} 条')),
    );
  }

  void _onManualInputChanged(String value) {
    final parsed = parseBangumiIdInput(value);
    if (parsed == _manualVerifiedId) {
      return;
    }
    if (_manualVerifiedId == null && _manualVerifiedDetail == null) {
      return;
    }
    setState(() {
      _manualVerifiedId = null;
      _manualVerifiedForPageId = null;
      _manualVerifiedDetail = null;
    });
  }

  Future<void> _verifyManualInput() async {
    final active = _uiController.activeItem;
    if (active == null) {
      return;
    }

    final input = _manualInputController.text;
    final bangumiId = parseBangumiIdInput(input);
    if (bangumiId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的 Bangumi ID 或链接')),
      );
      return;
    }

    setState(() => _isManualVerifying = true);
    try {
      final detail = await _model.getSubjectDetail(bangumiId);
      if (!mounted) return;
      setState(() {
        _manualVerifiedId = bangumiId;
        _manualVerifiedForPageId = active.pageId;
        _manualVerifiedDetail = detail;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('校验失败: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isManualVerifying = false);
      }
    }
  }

  Future<void> _bindManualVerified() async {
    final active = _uiController.activeItem;
    final verifiedId = _manualVerifiedId;
    if (active == null || verifiedId == null) {
      return;
    }

    final imported = await _bindCandidateWithDialog(active, verifiedId);
    if (!mounted) return;

    if (imported) {
      setState(() {
        _manualVerifiedId = null;
        _manualVerifiedForPageId = null;
        _manualVerifiedDetail = null;
      });
      _manualInputController.clear();
    }
  }

  void _openBangumiDetail(int subjectId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetailPage(subjectId: subjectId),
      ),
    );
  }

  Future<void> _openBangumiExternal(int subjectId) async {
    final uri = Uri.parse('https://bgm.tv/subject/$subjectId');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  DailyRecommendation _buildNotionDetailRecommendation(BatchUiItem item) {
    final best = item.bestSimilarityMatch;
    final bangumiId = best?.item.id.toString();
    final cover = best?.item.imageUrl;
    return DailyRecommendation(
      title: item.title,
      yougnScore: null,
      bangumiScore: best?.item.score,
      airDate: null,
      airEndDate: null,
      followDate: null,
      tags: const [],
      type: null,
      shortReview: null,
      longReview: null,
      cover: cover,
      contentCoverUrl: null,
      contentLongReview: null,
      bangumiId: bangumiId,
      subjectId: bangumiId,
      pageId: item.pageId,
      pageUrl: item.notionUrl,
      animationProduction: null,
      director: null,
      script: null,
      storyboard: null,
    );
  }

  void _openNotionDetail(BatchUiItem item) {
    final recommendation = _buildNotionDetailRecommendation(item);
    final best = item.bestSimilarityMatch;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotionDetailPage(
          recommendation: recommendation,
          coverUrl: recommendation.cover ?? '',
          longReview: '',
          tags: const [],
          bangumiScore: best?.item.score,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<BatchImportViewModel>.value(value: _model),
        ChangeNotifierProvider<BatchBindingUiController>.value(
          value: _uiController,
        ),
      ],
      child: Consumer2<BatchImportViewModel, BatchBindingUiController>(
        builder: (context, model, ui, _) {
          final activeItem = ui.activeItem;
          final showManualPreview =
              _manualVerifiedForPageId == activeItem?.pageId;

          return NavigationShell(
            title: '批量绑定',
            selectedRoute: '/settings',
            onBack: () => Navigator.of(context).pop(),
            actions: [
              IconButton(
                tooltip: '刷新',
                onPressed: model.isLoading || _isBulkBinding
                    ? null
                    : () => unawaited(_refresh()),
                icon: const Icon(Icons.refresh),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: BatchImportView(
                state: BatchImportViewState(
                  isLoading: model.isLoading,
                  errorMessage: model.errorMessage,
                  searchController: _searchController,
                  manualInputController: _manualInputController,
                  onlyUnbound: ui.onlyUnbound,
                  sortMode: ui.sortMode,
                  visibleItems: ui.visibleItems,
                  activeItem: activeItem,
                  pendingCount: ui.pendingVisibleCount,
                  completedCount: ui.completedVisibleCount,
                  selectedCount: ui.selectedVisibleCount,
                  isBulkBinding: _isBulkBinding,
                  isManualVerifying: _isManualVerifying,
                  manualVerifiedId:
                      showManualPreview ? _manualVerifiedId : null,
                  manualVerifiedDetail:
                      showManualPreview ? _manualVerifiedDetail : null,
                ),
                callbacks: BatchImportViewCallbacks(
                  onSearchChanged: ui.setQuery,
                  onOnlyUnboundChanged: ui.setOnlyUnbound,
                  onSortChanged: ui.setSortMode,
                  onOneClickBind: () => unawaited(_bindOneClickVisible()),
                  onSelectItem: ui.selectItem,
                  onToggleItemSelected: ui.toggleItemSelected,
                  onSkipSelected: _skipSelectedItems,
                  onBindSelected: () => unawaited(_bindSelectedItems()),
                  onBindSingle: (item, bangumiId) =>
                      unawaited(_bindCandidateWithDialog(item, bangumiId)),
                  onOpenNotionDetail: _openNotionDetail,
                  onOpenBangumiDetail: _openBangumiDetail,
                  onOpenBangumiExternal: (id) =>
                      unawaited(_openBangumiExternal(id)),
                  onManualInputChanged: _onManualInputChanged,
                  onVerifyManual: () => unawaited(_verifyManualInput()),
                  onBindManual: () => unawaited(_bindManualVerified()),
                  onToggleConflict: ui.toggleConflict,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BindTask {
  const _BindTask({
    required this.item,
    required this.bangumiId,
  });

  final BatchUiItem item;
  final int bangumiId;
}
