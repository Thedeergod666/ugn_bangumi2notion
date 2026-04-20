import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_services.dart';
import '../../../app/app_settings.dart';
import '../../../core/utils/copy_text_feedback.dart';
import '../../../core/widgets/error_detail_dialog.dart';
import '../../../core/widgets/navigation_shell.dart';
import '../../../models/notion_models.dart';
import '../../../models/progress_segments.dart';
import '../providers/recommendation_view_model.dart';
import 'notion_detail_page.dart';
import 'recommendation_view.dart';

class RecommendationPage extends StatefulWidget {
  const RecommendationPage({super.key});

  @override
  State<RecommendationPage> createState() => _RecommendationPageState();
}

class _RecommendationPageState extends State<RecommendationPage> {
  late final RecommendationViewModel _viewModel;
  late final TextEditingController _notionSearchController;

  @override
  void initState() {
    super.initState();
    final services = context.read<AppServices>();
    _viewModel = RecommendationViewModel(
      notionApi: services.notionApi,
      bangumiApi: services.bangumiApi,
    );
    _notionSearchController = TextEditingController();
    _viewModel.load(context.read<AppSettings>());
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _notionSearchController.dispose();
    super.dispose();
  }

  void _openNotionDetail(
    BuildContext context, {
    required DailyRecommendation recommendation,
    required String coverUrl,
    required String longReview,
    required List<String> tags,
    required double? bangumiScore,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotionDetailPage(
          recommendation: recommendation,
          coverUrl: coverUrl,
          longReview: longReview,
          tags: tags,
          bangumiScore: bangumiScore,
        ),
      ),
    );
  }

  DailyRecommendation _buildRecommendationFromWatchEntry(
    NotionWatchEntry entry,
  ) {
    final bangumiId = entry.bangumiId?.trim();
    return DailyRecommendation(
      title: entry.title,
      yougnScore: null,
      bangumiScore: null,
      airDate: null,
      airEndDate: null,
      followDate: null,
      tags: const [],
      type: null,
      shortReview: null,
      longReview: null,
      cover: entry.coverUrl,
      contentCoverUrl: null,
      contentLongReview: null,
      bangumiId: bangumiId,
      subjectId: bangumiId,
      pageId: entry.id,
      pageUrl: entry.pageUrl,
      animationProduction: null,
      director: null,
      script: null,
      storyboard: null,
    );
  }

  void _openNotionDetailFromWatchEntry(
    BuildContext context,
    NotionWatchEntry entry,
  ) {
    final recommendation = _buildRecommendationFromWatchEntry(entry);
    _openNotionDetail(
      context,
      recommendation: recommendation,
      coverUrl: entry.coverUrl ?? '',
      longReview: '',
      tags: const [],
      bangumiScore: null,
    );
  }

  void _triggerNotionSearch(String keyword) {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入关键词')),
      );
      return;
    }
    Navigator.of(context).pushNamed(
      '/search',
      arguments: {
        'source': 'notion',
        'keyword': trimmed,
      },
    );
  }

  Future<void> _handleRecentIncrement(
    BuildContext context,
    RecommendationViewModel model,
    NotionWatchEntry entry,
  ) async {
    try {
      final result = await model.incrementRecentWatch(entry);
      if (result == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未配置 Notion 追番字段')),
        );
        return;
      }
      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Row(
            children: [
              const Expanded(child: Text('已追集数 +1')),
              TextButton(
                onPressed: () {
                  model.revertRecentWatch(result);
                  messenger.hideCurrentSnackBar();
                },
                child: const Text('撤销'),
              ),
            ],
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('更新失败，请稍后重试')),
      );
    }
  }

  Future<void> _handleCopyTitle(BuildContext context, String title) {
    return copyTextWithFeedback(context, title);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<RecommendationViewModel>(
        builder: (context, model, _) {
          return NavigationShell(
            title: '今日安利',
            selectedRoute: '/recommendation',
            child: _buildBody(context, model),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, RecommendationViewModel model) {
    if (model.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (model.configurationMessage != null) {
      final route = model.configurationRoute;
      return _buildCenteredMessage(
        context,
        icon: Icons.settings_suggest,
        title: model.configurationMessage!,
        actionLabel: route == '/mapping' ? '去映射配置' : '去设置',
        onAction: route == null
            ? null
            : () => Navigator.pushReplacementNamed(context, route),
      );
    }

    if (model.errorMessage != null) {
      return _buildCenteredMessage(
        context,
        icon: Icons.error_outline,
        title: model.errorMessage!,
        actionLabel: '重试',
        onAction: model.isLoading
            ? null
            : () => model.load(
                  context.read<AppSettings>(),
                  forceRefresh: true,
                ),
        secondaryLabel: '查看详情',
        onSecondaryAction: (model.error != null && model.stackTrace != null)
            ? () => showDialog(
                  context: context,
                  builder: (context) => ErrorDetailDialog(
                    error: model.error!,
                    stackTrace: model.stackTrace!,
                  ),
                )
            : null,
      );
    }

    if (model.emptyMessage != null) {
      return _buildCenteredMessage(
        context,
        icon: Icons.inbox_outlined,
        title: model.emptyMessage!,
        actionLabel: '刷新',
        onAction: model.isLoading
            ? null
            : () => model.load(
                  context.read<AppSettings>(),
                  forceRefresh: true,
                ),
      );
    }

    if (model.dailyCandidates.isEmpty || model.heroIndices.isEmpty) {
      return _buildCenteredMessage(
        context,
        icon: Icons.inbox_outlined,
        title: '暂无推荐内容',
        actionLabel: '刷新',
        onAction: model.isLoading
            ? null
            : () => model.load(
                  context.read<AppSettings>(),
                  forceRefresh: true,
                ),
      );
    }

    final settings = context.watch<AppSettings>();
    final showRatings = settings.showRatings;
    final recommendation =
        model.recommendationForHero(0) ?? model.dailyCandidates.first;

    final subjectId = model.resolveSubjectId(recommendation);
    if (subjectId != null) {
      model.scheduleBangumiDetailLoad(subjectId);
    }
    if ((recommendation.longReview?.trim().isEmpty ?? true) ||
        (recommendation.cover?.trim().isEmpty ?? true)) {
      model.scheduleNotionContentLoad(recommendation.pageId);
    }

    final detail = model.detailFor(recommendation);
    final notionContent = model.notionContentFor(recommendation);
    final coverUrl =
        model.resolveCoverUrl(recommendation, detail, notionContent);
    final tags = model.resolveTags(recommendation, detail);
    final longReview = model.resolveLongReview(recommendation, notionContent);

    final bangumiScore = detail != null && detail.score > 0
        ? detail.score
        : recommendation.bangumiScore;
    final yougnRank = model.computeYougnRank(
      recommendation.yougnScore,
      bangumiScore,
    );
    final bangumiRank = detail?.rank;

    final currentBinLabel = recommendation.yougnScore == null
        ? null
        : model.scoreToBinLabel(recommendation.yougnScore!);

    // Prefetch recent caches used by the View.
    final recentReleaseSummaries = <int, EpisodeReleaseSummary>{};
    for (final entry in [...model.recentWatching, ...model.recentWatched]) {
      if ((entry.coverUrl?.trim().isEmpty ?? true)) {
        model.scheduleNotionContentLoad(entry.id);
      }
      final id = int.tryParse(entry.bangumiId ?? '');
      if (id == null) continue;
      model.scheduleBangumiDetailLoad(id);
      model.scheduleRecentLatestEpisodeLoad(id);
      recentReleaseSummaries[id] =
          model.releaseSummaryFor(id) ?? EpisodeReleaseSummary.empty;
    }

    final viewState = RecommendationViewState(
      showRatings: showRatings,
      recommendation: recommendation,
      coverUrl: coverUrl,
      longReview: longReview,
      tags: tags,
      bangumiScore: bangumiScore,
      yougnRank: yougnRank,
      bangumiRank: bangumiRank,
      showLongReview: model.showLongReview,
      isStatsLoading: model.isStatsLoading,
      scoreBins: model.scoreBins,
      scoreTotal: model.scoreTotal,
      currentScoreBinLabel: currentBinLabel,
      recentViewMode: settings.recentViewMode,
      isRecentLoading: model.isRecentLoading,
      recentMessage: model.recentMessage,
      recentWatching: model.recentWatching,
      recentWatched: model.recentWatched,
      bangumiDetailCache: model.bangumiDetailCache,
      notionContentCache: model.notionContentCache,
      recentReleaseSummaryCache: recentReleaseSummaries,
      notionSearchController: _notionSearchController,
    );

    final callbacks = RecommendationViewCallbacks(
      onOpenNotionDetail: () => _openNotionDetail(
        context,
        recommendation: recommendation,
        coverUrl: coverUrl,
        longReview: longReview,
        tags: recommendation.tags,
        bangumiScore: bangumiScore,
      ),
      onCopyRecommendationTitle: (title) =>
          unawaited(_handleCopyTitle(context, title)),
      onToggleLongReview: model.toggleLongReview,
      onNotionSearch: _triggerNotionSearch,
      onRecentViewModeChanged: settings.setRecentViewMode,
      onOpenRecentEntry: (entry) =>
          _openNotionDetailFromWatchEntry(context, entry),
      onCopyRecentTitle: (title) =>
          unawaited(_handleCopyTitle(context, title)),
      onIncrementRecentWatch: (entry) =>
          unawaited(_handleRecentIncrement(context, model, entry)),
    );

    return RecommendationView(state: viewState, callbacks: callbacks);
  }

  Widget _buildCenteredMessage(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? actionLabel,
    VoidCallback? onAction,
    String? secondaryLabel,
    VoidCallback? onSecondaryAction,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 48, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  if (actionLabel != null)
                    FilledButton.icon(
                      onPressed: onAction,
                      icon: const Icon(Icons.refresh),
                      label: Text(actionLabel),
                    ),
                  if (secondaryLabel != null)
                    OutlinedButton(
                      onPressed: onSecondaryAction,
                      child: Text(secondaryLabel),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
