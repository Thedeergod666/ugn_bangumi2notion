import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_services.dart';
import '../../../app/app_settings.dart';
import '../../../core/widgets/navigation_shell.dart';
import '../../detail/presentation/detail_page.dart';
import '../providers/search_view_model.dart';
import 'search_view.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final TextEditingController _controller;
  late final SearchViewModel _viewModel;
  late final FocusNode _searchFocusNode;
  bool _initializedFromArgs = false;
  bool _showHints = false;
  Timer? _hideHintsTimer;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _searchFocusNode = FocusNode();
    _searchFocusNode.addListener(() {
      if (!mounted) return;
      _hideHintsTimer?.cancel();
      if (_searchFocusNode.hasFocus) {
        if (!_showHints) {
          setState(() => _showHints = true);
        }
        return;
      }
      _hideHintsTimer = Timer(const Duration(milliseconds: 120), () {
        if (!mounted || _searchFocusNode.hasFocus) return;
        setState(() => _showHints = false);
      });
    });
    _viewModel = SearchViewModel(
      bangumiApi: context.read<AppServices>().bangumiApi,
      notionApi: context.read<AppServices>().notionApi,
      settings: context.read<AppSettings>(),
    );
    _viewModel.initialize();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initializedFromArgs) return;
    _initializedFromArgs = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final source = args['source']?.toString();
      if (source == 'notion') {
        _viewModel.setSource(SearchSource.notion);
      } else if (source == 'bangumi') {
        _viewModel.setSource(SearchSource.bangumi);
      }
      final keyword = args['keyword']?.toString().trim() ?? '';
      if (keyword.isNotEmpty) {
        _controller.text = keyword;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _viewModel.search(_controller.text);
        });
      }
    }
  }

  @override
  void dispose() {
    _hideHintsTimer?.cancel();
    _controller.dispose();
    _searchFocusNode.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _submitSearch(String keyword) {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入关键词')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _showHints = false);
    _viewModel.search(trimmed);
  }

  void _submitSearchFromTag(String keyword) {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return;
    _controller
      ..text = trimmed
      ..selection = TextSelection.collapsed(offset: trimmed.length);
    _submitSearch(trimmed);
  }

  Future<void> _openNotionPage(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _confirmRemoveHistory(
    SearchViewModel model,
    String keyword,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除搜索记录'),
        content: Text('是否删除“$keyword”？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (result == true) {
      await model.removeHistory(keyword);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<SearchViewModel>(
        builder: (context, model, _) {
          final settings = context.watch<AppSettings>();
          final input = _controller.text.trim();
          final suggestions =
              input.isEmpty ? const <String>[] : model.suggestionsFor(input);

          return NavigationShell(
            title: '搜索',
            selectedRoute: '/search',
            child: SearchView(
              state: SearchViewState(
                source: model.source,
                sort: model.sort,
                searchViewMode: settings.searchViewMode,
                isLoading: model.isLoading,
                errorMessage: model.errorMessage,
                showHints: _showHints,
                suggestions: suggestions,
                history: model.history,
                items: model.items,
                notionItems: model.notionItems,
                controller: _controller,
                searchFocusNode: _searchFocusNode,
              ),
              callbacks: SearchViewCallbacks(
                onSourceChanged: model.setSource,
                onSortChanged: model.setSort,
                onSearchViewModeChanged: settings.setSearchViewMode,
                onQueryChanged: () => setState(() {}),
                onSubmit: _submitSearch,
                onClearHistory: () => unawaited(model.clearHistory()),
                onRemoveHistory: (keyword) =>
                    unawaited(_confirmRemoveHistory(model, keyword)),
                onPickSuggestion: _submitSearchFromTag,
                onPickHistory: _submitSearchFromTag,
                onTapBangumiItem: (subjectId) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DetailPage(subjectId: subjectId),
                    ),
                  );
                },
                onOpenNotionPage: (url) => unawaited(_openNotionPage(url)),
              ),
            ),
          );
        },
      ),
    );
  }
}
