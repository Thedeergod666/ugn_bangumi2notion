import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/widgets/progress_segments_bar.dart';
import '../../../core/widgets/view_mode_toggle.dart';
import '../../../models/bangumi_models.dart';
import '../../../models/notion_models.dart';
import '../providers/recommendation_view_model.dart';

class RecommendationViewState {
  const RecommendationViewState({
    required this.showRatings,
    required this.recommendation,
    required this.coverUrl,
    required this.longReview,
    required this.tags,
    required this.bangumiScore,
    required this.yougnRank,
    required this.bangumiRank,
    required this.showLongReview,
    required this.isStatsLoading,
    required this.scoreBins,
    required this.scoreTotal,
    required this.currentScoreBinLabel,
    required this.recentViewMode,
    required this.isRecentLoading,
    required this.recentMessage,
    required this.recentWatching,
    required this.recentWatched,
    required this.bangumiDetailCache,
    required this.notionContentCache,
    required this.recentLatestEpisodeCache,
    required this.notionSearchController,
  });

  final bool showRatings;
  final DailyRecommendation recommendation;
  final String coverUrl;
  final String longReview;
  final List<String> tags;
  final double? bangumiScore;
  final int? yougnRank;
  final int? bangumiRank;

  final bool showLongReview;
  final bool isStatsLoading;
  final List<RecommendationScoreBin> scoreBins;
  final int scoreTotal;
  final String? currentScoreBinLabel;

  final String recentViewMode;
  final bool isRecentLoading;
  final String? recentMessage;
  final List<NotionWatchEntry> recentWatching;
  final List<NotionWatchEntry> recentWatched;
  final Map<int, BangumiSubjectDetail> bangumiDetailCache;
  final Map<String, RecommendationNotionContent> notionContentCache;
  final Map<int, int> recentLatestEpisodeCache;

  final TextEditingController notionSearchController;
}

class RecommendationViewCallbacks {
  const RecommendationViewCallbacks({
    required this.onOpenNotionDetail,
    required this.onToggleLongReview,
    required this.onNotionSearch,
    required this.onRecentViewModeChanged,
    required this.onOpenRecentEntry,
    required this.onIncrementRecentWatch,
  });

  final VoidCallback onOpenNotionDetail;
  final VoidCallback onToggleLongReview;
  final ValueChanged<String> onNotionSearch;
  final ValueChanged<String> onRecentViewModeChanged;
  final ValueChanged<NotionWatchEntry> onOpenRecentEntry;
  final ValueChanged<NotionWatchEntry> onIncrementRecentWatch;
}

class RecommendationView extends StatelessWidget {
  const RecommendationView({
    super.key,
    required this.state,
    required this.callbacks,
  });

  final RecommendationViewState state;
  final RecommendationViewCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isUltraWide = constraints.maxWidth >= 1200;
        final isMedium = constraints.maxWidth >= 900;

        final leftPanel = _buildLeftPanel(context, horizontal: isMedium);
        final rankCard =
            _buildRankCard(context, hint: isUltraWide ? null : '点击切换');
        final reviewCard =
            _buildLongReviewCard(context, hint: isUltraWide ? null : '点击切换');
        final rightPanel = isUltraWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: rankCard),
                  const SizedBox(width: 16),
                  Expanded(child: reviewCard),
                ],
              )
            : GestureDetector(
                onTap: callbacks.onToggleLongReview,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: state.showLongReview
                      ? KeyedSubtree(
                          key: const ValueKey('review'),
                          child: reviewCard,
                        )
                      : KeyedSubtree(
                          key: const ValueKey('rank'),
                          child: rankCard,
                        ),
                ),
              );

        Widget heroContent;
        if (isMedium) {
          heroContent = IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 6, child: leftPanel),
                const SizedBox(width: 16),
                Expanded(flex: 4, child: rightPanel),
              ],
            ),
          );
        } else {
          heroContent = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              leftPanel,
              const SizedBox(height: 16),
              rightPanel,
            ],
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '今日安利',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              _buildNotionSearchBar(context),
              const SizedBox(height: 16),
              heroContent,
              const SizedBox(height: 20),
              _buildRecentSection(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotionSearchBar(BuildContext context) {
    return _buildPanel(
      context,
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: state.notionSearchController,
              decoration: const InputDecoration(
                hintText: 'Notion 搜索',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: callbacks.onNotionSearch,
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: () => callbacks.onNotionSearch(
              state.notionSearchController.text,
            ),
            child: const Text('搜索'),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildLeftPanel(BuildContext context, {required bool horizontal}) {
    final colorScheme = Theme.of(context).colorScheme;
    final coverUrl = state.coverUrl;

    final cover =
        _buildCoverImage(context, coverUrl: coverUrl, stretch: horizontal);
    final info = _buildInfoContent(context);

    final content = horizontal
        ? IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(flex: 4, child: cover),
                const SizedBox(width: 16),
                Expanded(
                  flex: 6,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: info,
                  ),
                ),
              ],
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              cover,
              Padding(
                padding: const EdgeInsets.all(16),
                child: info,
              ),
            ],
          );

    return Material(
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: callbacks.onOpenNotionDetail,
        child: content,
      ),
    );
  }

  Widget _buildCoverImage(
    BuildContext context, {
    required String coverUrl,
    required bool stretch,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final image = coverUrl.isEmpty
        ? Container(
            color: colorScheme.surfaceContainerHighest,
            child: const Center(child: Icon(Icons.image_outlined, size: 48)),
          )
        : Image.network(
            coverUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: colorScheme.surfaceContainerHighest,
              child: const Center(
                  child: Icon(Icons.broken_image_outlined, size: 48)),
            ),
          );

    final child = stretch
        ? SizedBox.expand(child: image)
        : AspectRatio(aspectRatio: 3 / 4, child: image);
    return child;
  }

  Widget _buildInfoContent(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final rec = state.recommendation;
    final title = rec.title;
    final shortReview = rec.shortReview?.trim() ?? '';
    final tags = state.tags;

    final yougnScore = rec.yougnScore;
    final bangumiScore = state.bangumiScore;
    final yougnRank = state.yougnRank;

    String rankText() {
      if (yougnRank == null) return '-';
      return '#$yougnRank';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        if (state.showRatings)
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _pill(context, 'Yougn', yougnScore?.toStringAsFixed(1) ?? '-'),
              _pill(
                  context, 'Bangumi', bangumiScore?.toStringAsFixed(1) ?? '-'),
              _pill(context, 'Rank', rankText()),
            ],
          ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags.take(12).map((t) => _tag(context, t)).toList(),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          shortReview.isEmpty ? '暂无短评' : shortReview,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: shortReview.isEmpty
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.onSurface,
                height: 1.6,
              ),
        ),
      ],
    );
  }

  Widget _pill(BuildContext context, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Text(
        '$label $value',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _tag(BuildContext context, String tag) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(tag, style: Theme.of(context).textTheme.labelSmall),
    );
  }

  Widget _buildRankCard(BuildContext context, {String? hint}) {
    final colorScheme = Theme.of(context).colorScheme;
    final total = state.scoreTotal;
    final bins = state.scoreBins;
    final maxCount = bins.fold<int>(0, (cur, bin) => max(cur, bin.count));

    Widget body;
    if (state.isStatsLoading) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (bins.isEmpty || total == 0) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          '暂无评分分布数据',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
      );
    } else {
      body = Column(
        children: bins.map((bin) {
          final isActive = state.currentScoreBinLabel != null &&
              bin.label == state.currentScoreBinLabel;
          return _buildScoreRow(
            context,
            bin: bin,
            total: total,
            maxCount: maxCount,
            highlight: isActive,
          );
        }).toList(),
      );
    }

    return _buildPanel(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPanelHeader(context, title: '排名分布', hint: hint),
          const SizedBox(height: 12),
          body,
        ],
      ),
    );
  }

  Widget _buildScoreRow(
    BuildContext context, {
    required RecommendationScoreBin bin,
    required int total,
    required int maxCount,
    required bool highlight,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final ratio = maxCount == 0 ? 0.0 : bin.count / maxCount;
    final percent = total == 0 ? 0.0 : (bin.count / total) * 100;
    final barColor = highlight ? colorScheme.primary : colorScheme.tertiary;
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: highlight ? colorScheme.primary : colorScheme.onSurfaceVariant,
          fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 60, child: Text(bin.label, style: labelStyle)),
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: ratio == 0 ? 0 : ratio.clamp(0.05, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 84,
            child: Text(
              total == 0
                  ? '-'
                  : '${percent.toStringAsFixed(1)}% / ${bin.count}',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: highlight
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLongReviewCard(BuildContext context, {String? hint}) {
    final colorScheme = Theme.of(context).colorScheme;
    final trimmed = state.longReview.trim();
    final displayText =
        trimmed.isNotEmpty ? trimmed : (state.showLongReview ? '暂无长评' : '暂无长评');
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: trimmed.isNotEmpty
              ? colorScheme.onSurface
              : colorScheme.onSurfaceVariant,
          height: 1.6,
        );

    return _buildPanel(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPanelHeader(context, title: '长评', hint: hint),
          const SizedBox(height: 12),
          Text(displayText, style: textStyle),
        ],
      ),
    );
  }

  Widget _buildPanelHeader(
    BuildContext context, {
    required String title,
    String? hint,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const Spacer(),
        if (hint != null)
          Text(
            hint,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                ),
          ),
      ],
    );
  }

  Widget _buildPanel(
    BuildContext context,
    Widget child, {
    EdgeInsets? padding,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: child,
    );
  }

  Widget _buildRecentSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final viewMode = state.recentViewMode;

    return _buildPanel(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '最近观看',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              ViewModeToggle(
                mode: viewMode,
                compact: true,
                onChanged: callbacks.onRecentViewModeChanged,
              ),
              const SizedBox(width: 8),
              if (state.isRecentLoading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.primary,
                  ),
                ),
            ],
          ),
          if (state.recentMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              state.recentMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
          const SizedBox(height: 12),
          _buildRecentRow(
            context,
            label: '在看',
            items: state.recentWatching,
            showProgress: true,
            viewMode: viewMode,
          ),
          const SizedBox(height: 16),
          _buildRecentRow(
            context,
            label: '已看',
            items: state.recentWatched,
            showProgress: false,
            viewMode: viewMode,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentRow(
    BuildContext context, {
    required String label,
    required List<NotionWatchEntry> items,
    required bool showProgress,
    required String viewMode,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    if (items.isEmpty) {
      return Text(
        '$label：暂无数据',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        if (viewMode == 'list')
          Column(
            children: [
              for (final entry in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildRecentCard(
                    context,
                    entry: entry,
                    showProgress: showProgress,
                    isList: true,
                  ),
                ),
            ],
          )
        else
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final entry = items[index];
                return _buildRecentCard(
                  context,
                  entry: entry,
                  showProgress: showProgress,
                  isList: false,
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildRecentCard(
    BuildContext context, {
    required NotionWatchEntry entry,
    required bool showProgress,
    required bool isList,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final watched = entry.watchedEpisodes ?? 0;
    final subjectId = int.tryParse(entry.bangumiId ?? '');
    final detail =
        subjectId != null ? state.bangumiDetailCache[subjectId] : null;
    final latest =
        subjectId != null ? state.recentLatestEpisodeCache[subjectId] : null;
    final total = detail?.epsCount ?? entry.totalEpisodes ?? 0;
    final updated = latest ?? 0;
    final progressText = total > 0 ? '已追 $watched / $total' : '已追 $watched';
    final serialStatus = showProgress
        ? (total > 0 && updated >= total
            ? '已完结'
            : (updated > 0 ? '连载中' : '未放送'))
        : '已看完';

    final Widget infoBlock = showProgress
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                progressText,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 6),
              if (updated > 0 || total > 0)
                ProgressSegmentsBar(
                  watched: watched,
                  updated: updated,
                  total: total > 0 ? total : (updated > 0 ? updated : watched),
                )
              else
                LinearProgressIndicator(
                  value: total > 0 ? watched / total : null,
                  minHeight: 5,
                  color: colorScheme.primary,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                ),
              const SizedBox(height: 6),
              Text(
                serialStatus,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  serialStatus,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                progressText,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          );

    final card = Card(
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => callbacks.onOpenRecentEntry(entry),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRecentCover(context, entry),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    infoBlock,
                  ],
                ),
              ),
              if (showProgress)
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: '+1',
                  onPressed: () => callbacks.onIncrementRecentWatch(entry),
                ),
            ],
          ),
        ),
      ),
    );

    if (isList) return card;
    return SizedBox(width: showProgress ? 260 : 240, child: card);
  }

  String _resolveRecentCoverUrl(NotionWatchEntry entry) {
    final direct = entry.coverUrl?.trim() ?? '';
    if (direct.isNotEmpty) return direct;

    final pageId = entry.id.trim();
    if (pageId.isNotEmpty) {
      final cached = state.notionContentCache[pageId]?.coverUrl?.trim() ?? '';
      if (cached.isNotEmpty) return cached;
    }

    final subjectId = int.tryParse(entry.bangumiId ?? '');
    if (subjectId != null) {
      final detailCover =
          state.bangumiDetailCache[subjectId]?.imageUrl.trim() ?? '';
      if (detailCover.isNotEmpty) return detailCover;
    }

    return '';
  }

  Widget _buildRecentCover(BuildContext context, NotionWatchEntry entry) {
    final url = _resolveRecentCoverUrl(entry);
    final colorScheme = Theme.of(context).colorScheme;
    if (url.isEmpty) {
      return Container(
        width: 62,
        height: 86,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.image_outlined, size: 28),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        url,
        width: 62,
        height: 86,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 62,
          height: 86,
          color: colorScheme.surfaceContainerLow,
          child: const Icon(Icons.broken_image_outlined, size: 28),
        ),
      ),
    );
  }
}
