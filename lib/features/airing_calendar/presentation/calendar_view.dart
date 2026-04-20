import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/content_module_theme_extension.dart';
import '../../../core/widgets/episode_badge.dart';
import '../../../core/widgets/progress_segments_bar.dart';
import '../../../core/widgets/view_mode_toggle.dart';
import '../../../models/bangumi_models.dart';
import '../../../models/progress_segments.dart';

class CalendarViewState {
  const CalendarViewState({
    required this.notionConfigured,
    required this.showRatings,
    required this.calendarViewMode,
    required this.selectedWeekday,
    required this.selectedWeekdayInfo,
    required this.selectedItems,
    required this.boundItems,
    required this.boundIds,
    required this.weekdayBoundCounts,
    required this.watchedEpisodes,
    required this.yougnScores,
    required this.lastWatchedAt,
    required this.detailCache,
    required this.releaseSummaryCache,
    required this.airEndDateCache,
  });

  final bool notionConfigured;
  final bool showRatings;
  final String calendarViewMode;
  final int selectedWeekday;
  final BangumiCalendarWeekday selectedWeekdayInfo;
  final List<BangumiCalendarItem> selectedItems;
  final List<BangumiCalendarItem> boundItems;
  final Set<int> boundIds;
  final Map<int, int> weekdayBoundCounts;
  final Map<int, int> watchedEpisodes;
  final Map<int, double?> yougnScores;
  final Map<int, DateTime?> lastWatchedAt;
  final Map<int, BangumiSubjectDetail> detailCache;
  final Map<int, EpisodeReleaseSummary> releaseSummaryCache;
  final Map<int, String?> airEndDateCache;
}

class CalendarViewCallbacks {
  const CalendarViewCallbacks({
    required this.onWeekdaySelected,
    required this.onCalendarViewModeChanged,
    required this.onTapSubject,
    required this.onCopyBoundSubjectTitle,
    required this.onCopyDaySubjectTitle,
    required this.onIncrementBoundSubject,
  });

  final ValueChanged<int> onWeekdaySelected;
  final ValueChanged<String> onCalendarViewModeChanged;
  final ValueChanged<int> onTapSubject;
  final ValueChanged<String> onCopyBoundSubjectTitle;
  final ValueChanged<String> onCopyDaySubjectTitle;
  final ValueChanged<int> onIncrementBoundSubject;
}

class CalendarView extends StatelessWidget {
  const CalendarView({
    super.key,
    required this.state,
    required this.callbacks,
  });

  final CalendarViewState state;
  final CalendarViewCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final selectedItems = state.selectedItems;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!state.notionConfigured) _buildNoticeBanner(context),
        if (state.notionConfigured) ...[
          _buildBoundSection(context),
          const SizedBox(height: 12),
        ],
        _buildWeekdaySelector(context),
        const SizedBox(height: 8),
        if (selectedItems.isEmpty)
          _buildEmptyDay(context)
        else ...[
          _buildDayHeader(context),
          const SizedBox(height: 8),
          _buildDayItems(context, selectedItems),
        ],
      ],
    );
  }

  Widget _buildEmptyDay(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: const Text('今天没有放送条目'),
    );
  }

  Widget _buildWeekdaySelector(BuildContext context) {
    const labels = <int, String>{
      1: '周一',
      2: '周二',
      3: '周三',
      4: '周四',
      5: '周五',
      6: '周六',
      7: '周日',
    };
    final now = DateTime.now();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: labels.entries.map((entry) {
          final weekday = entry.key;
          final isSelected = state.selectedWeekday == weekday;
          final boundCount = state.weekdayBoundCounts[weekday] ?? 0;
          final date = _nextDateForWeekday(weekday, now);
          final dateLabel = '${date.month}月${date.day}日';
          final label = weekday == now.weekday ? '今天' : entry.value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: _WeekdayChipLabel(
                label: label,
                count: boundCount,
                dateLabel: dateLabel,
              ),
              selected: isSelected,
              onSelected: (_) => callbacks.onWeekdaySelected(weekday),
            ),
          );
        }).toList(),
      ),
    );
  }

  DateTime _nextDateForWeekday(int weekday, DateTime now) {
    final base = DateTime(now.year, now.month, now.day);
    var diff = weekday - now.weekday;
    if (diff < 0) diff += 7;
    return base.add(Duration(days: diff));
  }

  Widget _buildNoticeBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '未检测到 Notion 绑定信息，仅展示 Bangumi 放送列表。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoundSection(BuildContext context) {
    final now = DateTime.now();
    final dateLabel = '${now.year}-${now.month}-${now.day}';
    final hasBound = state.boundItems.isNotEmpty;
    final headerText = hasBound ? '$dateLabel · 追番' : dateLabel;
    final layout =
        _CalendarModuleLayout.fromWidth(MediaQuery.sizeOf(context).width);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              headerText,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Divider(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ],
        ),
        if (hasBound) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: layout.boundCardHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: state.boundItems.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = state.boundItems[index];
                final title = item.nameCn.isNotEmpty ? item.nameCn : item.name;
                return SizedBox(
                  width: layout.boundCardWidth,
                  child: _BoundBangumiCard(
                    item: item,
                    watchedEpisodes: state.watchedEpisodes[item.id] ?? 0,
                    yougnScore: state.yougnScores[item.id],
                    detail: state.detailCache[item.id],
                    releaseSummary: state.releaseSummaryCache[item.id],
                    lastWatchedAt: state.lastWatchedAt[item.id],
                    showRatings: state.showRatings,
                    layout: layout,
                    onTap: () => callbacks.onTapSubject(item.id),
                    onLongPress: () =>
                        callbacks.onCopyBoundSubjectTitle(title),
                    onIncrement: () =>
                        callbacks.onIncrementBoundSubject(item.id),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDayHeader(BuildContext context) {
    final weekday = state.selectedWeekdayInfo;
    final label = weekday.cn.isNotEmpty
        ? weekday.cn
        : (weekday.en.isNotEmpty ? weekday.en : '周${weekday.id}');
    return Row(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Divider(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        const SizedBox(width: 8),
        ViewModeToggle(
          mode: state.calendarViewMode,
          compact: true,
          onChanged: callbacks.onCalendarViewModeChanged,
        ),
      ],
    );
  }

  Widget _buildDayItems(
    BuildContext context,
    List<BangumiCalendarItem> items,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final layout = _CalendarModuleLayout.fromWidth(width);
        final isGallery = state.calendarViewMode == 'gallery';
        final crossAxisCount =
            isGallery ? (layout.isWide ? (width >= 1200 ? 3 : 2) : 1) : 1;
        final childAspectRatio = layout.isNarrow
            ? 1.38
            : (isGallery && crossAxisCount > 1 ? 1.9 : 3.0);

        if (crossAxisCount == 1) {
          return Column(
            children: [
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CalendarItemCard(
                    item: item,
                    detail: state.detailCache[item.id],
                    isBound: state.boundIds.contains(item.id),
                    isGallery: isGallery,
                    watchedEpisodes: state.watchedEpisodes[item.id] ?? 0,
                    releaseSummary: state.releaseSummaryCache[item.id],
                    airEndDate: state.airEndDateCache[item.id],
                    lastWatchedAt: state.lastWatchedAt[item.id],
                    showRatings: state.showRatings,
                    layout: layout,
                    onTap: () => callbacks.onTapSubject(item.id),
                    onLongPress: () => callbacks.onCopyDaySubjectTitle(
                      item.nameCn.isNotEmpty ? item.nameCn : item.name,
                    ),
                  ),
                ),
            ],
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _CalendarItemCard(
              item: item,
              detail: state.detailCache[item.id],
              isBound: state.boundIds.contains(item.id),
              isGallery: isGallery,
              watchedEpisodes: state.watchedEpisodes[item.id] ?? 0,
              releaseSummary: state.releaseSummaryCache[item.id],
              airEndDate: state.airEndDateCache[item.id],
              lastWatchedAt: state.lastWatchedAt[item.id],
              showRatings: state.showRatings,
              layout: layout,
              onTap: () => callbacks.onTapSubject(item.id),
              onLongPress: () => callbacks.onCopyDaySubjectTitle(
                item.nameCn.isNotEmpty ? item.nameCn : item.name,
              ),
            );
          },
        );
      },
    );
  }
}

class _WeekdayChipLabel extends StatelessWidget {
  const _WeekdayChipLabel({
    required this.label,
    required this.count,
    required this.dateLabel,
  });

  final String label;
  final int count;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showBadge = count > 0;
    final badgeColor = theme.colorScheme.primary;
    final dateStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.1,
    );
    final weekdayStyle = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w600,
      height: 1.1,
    );
    final countStyle = theme.textTheme.labelSmall?.copyWith(
      color: badgeColor,
      fontWeight: FontWeight.w700,
      height: 1.0,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dateLabel,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.fade,
          style: dateStyle,
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: weekdayStyle,
              ),
              if (showBadge) ...[
                const SizedBox(width: 1),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 1),
                Text('$count', style: countStyle),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BoundBangumiCard extends StatelessWidget {
  const _BoundBangumiCard({
    required this.item,
    required this.watchedEpisodes,
    required this.yougnScore,
    required this.detail,
    required this.releaseSummary,
    required this.lastWatchedAt,
    required this.showRatings,
    required this.layout,
    required this.onTap,
    required this.onLongPress,
    required this.onIncrement,
  });

  final BangumiCalendarItem item;
  final int watchedEpisodes;
  final double? yougnScore;
  final BangumiSubjectDetail? detail;
  final EpisodeReleaseSummary? releaseSummary;
  final DateTime? lastWatchedAt;
  final bool showRatings;
  final _CalendarModuleLayout layout;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final moduleTheme = theme.extension<ContentModuleThemeExtension>() ??
        ContentModuleThemeExtension.fromScheme(theme.colorScheme);
    final title = item.nameCn.isNotEmpty ? item.nameCn : item.name;
    final summary = releaseSummary ?? EpisodeReleaseSummary.empty;
    final updated = summary.updatedEpisodes;
    final bangumiScore = detail?.score;
    final hasBangumiScore =
        showRatings && bangumiScore != null && bangumiScore > 0;
    final total = _resolveTotalEpisodes(
      detail?.epsCount ?? item.epsCount,
      watchedEpisodes,
      updated,
    );
    final missingCount = max(0, updated - watchedEpisodes);
    final progressLabel =
        '已追 $watchedEpisodes / 已更 $updated / 共 ${total > 0 ? total : '-'}';
    final cadenceLabel =
        _formatWeeklyUpdateLabel(summary.nextAiredAt, item.airWeekday);
    final watchStatusLabel = cadenceLabel.isEmpty ? '看到' : '$cadenceLabel ·';
    final watchStatusValue = watchedEpisodes > 0
        ? (cadenceLabel.isEmpty
            ? 'EP$watchedEpisodes'
            : '看到 EP$watchedEpisodes')
        : (cadenceLabel.isEmpty ? '-' : '看到 -');

    return Material(
      color: moduleTheme.containerColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: moduleTheme.borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CoverImage(
                          url: item.imageUrl,
                          width: layout.boundCoverWidth,
                          height: layout.boundCoverHeight,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(
                                  right: missingCount > 0 ? 28 : 0,
                                ),
                                child: Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: moduleTheme.primaryTextColor,
                                    fontWeight: FontWeight.w700,
                                    height: 1.25,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  if (showRatings && yougnScore != null) ...[
                                    _InfoChip(
                                      label:
                                          '悠gn ${yougnScore!.toStringAsFixed(1)}',
                                      backgroundColor:
                                          moduleTheme.progressRemainingColor,
                                      textColor: moduleTheme.primaryTextColor,
                                      compact: true,
                                    ),
                                  ],
                                  if (hasBangumiScore)
                                    _InfoChip(
                                      label:
                                          'BGM ${bangumiScore.toStringAsFixed(1)}',
                                      backgroundColor:
                                          moduleTheme.progressUpdatedColor,
                                      textColor: moduleTheme.primaryTextColor,
                                      compact: true,
                                    ),
                                  _BoundQuickActionButton(
                                    onPressed: onIncrement,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _LabeledValueRow(
                                label: watchStatusLabel,
                                value: watchStatusValue,
                                highlightLabel: cadenceLabel.isNotEmpty,
                              ),
                              const SizedBox(height: 4),
                              _LabeledValueRow(
                                label: '最近更新',
                                value: _formatLatestEpisodeUpdate(summary),
                                highlightLabel: true,
                              ),
                              const SizedBox(height: 4),
                              _LabeledValueRow(
                                label: '下次更新',
                                value: _formatNextEpisodeUpdate(summary),
                              ),
                              const SizedBox(height: 4),
                              _LabeledValueRow(
                                label: '最近观看',
                                value: _formatWatchMoment(lastWatchedAt),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  ProgressSegmentsBar(
                    watched: watchedEpisodes,
                    updated: updated,
                    total: total,
                    watchedColor: moduleTheme.progressWatchedColor,
                    updatedColor: moduleTheme.progressUpdatedColor,
                    remainingColor: moduleTheme.progressRemainingColor,
                    height: 10,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    progressLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: moduleTheme.secondaryTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (missingCount > 0)
              Positioned(
                top: 10,
                right: 10,
                child: _CompactUnreadBadge(
                  count: missingCount,
                  backgroundColor: moduleTheme.badgeColor,
                  textColor: moduleTheme.badgeTextColor,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CalendarItemCard extends StatelessWidget {
  const _CalendarItemCard({
    required this.item,
    required this.detail,
    required this.isBound,
    required this.isGallery,
    required this.watchedEpisodes,
    required this.releaseSummary,
    required this.airEndDate,
    required this.lastWatchedAt,
    required this.showRatings,
    required this.layout,
    required this.onTap,
    required this.onLongPress,
  });

  final BangumiCalendarItem item;
  final BangumiSubjectDetail? detail;
  final bool isBound;
  final bool isGallery;
  final int watchedEpisodes;
  final EpisodeReleaseSummary? releaseSummary;
  final String? airEndDate;
  final DateTime? lastWatchedAt;
  final bool showRatings;
  final _CalendarModuleLayout layout;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final moduleTheme = theme.extension<ContentModuleThemeExtension>() ??
        ContentModuleThemeExtension.fromScheme(theme.colorScheme);
    final title = item.nameCn.isNotEmpty ? item.nameCn : item.name;
    final airDate = item.airDate.isNotEmpty ? item.airDate : '待定';
    final endDate = (airEndDate ?? '').trim();
    final airRangeText =
        endDate.isEmpty || endDate == airDate ? airDate : '$airDate ~ $endDate';
    final summary = releaseSummary ?? EpisodeReleaseSummary.empty;
    final updated = summary.updatedEpisodes;
    final total = _resolveTotalEpisodes(
      detail?.epsCount ?? item.epsCount,
      watchedEpisodes,
      updated,
    );
    final missingCount = max(0, updated - watchedEpisodes);
    final score = detail?.score ?? 0;
    final rank = detail?.rank;
    final hasRating = showRatings && (score > 0 || (rank != null && rank > 0));
    final sortedTags = [...(detail?.tagDetails ?? const <BangumiTag>[])]
      ..sort((a, b) => b.count.compareTo(a.count));
    final tagPool = sortedTags
        .map((tag) => tag.name)
        .where((name) => name.isNotEmpty)
        .take(isGallery ? 3 : 5)
        .toList();
    final compact = isGallery || layout.isNarrow;

    return Material(
      color: isBound
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.22)
          : moduleTheme.containerColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color:
              isBound ? moduleTheme.hoverBorderColor : moduleTheme.borderColor,
          width: isBound ? 1.1 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 14),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CoverImage(
                        url: item.imageUrl,
                        width: layout.dayCoverWidth,
                        height: layout.dayCoverHeight,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    maxLines: compact ? 1 : 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: moduleTheme.primaryTextColor,
                                    ),
                                  ),
                                ),
                                if (isBound) ...[
                                  const SizedBox(width: 8),
                                  _InfoChip(
                                    label: '已绑定',
                                    backgroundColor:
                                        moduleTheme.progressUpdatedColor,
                                    textColor: moduleTheme.primaryTextColor,
                                  ),
                                ],
                              ],
                            ),
                            if (hasRating) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  if (score > 0)
                                    _InfoChip(
                                      label:
                                          'Bangumi ${score.toStringAsFixed(1)}',
                                      backgroundColor:
                                          moduleTheme.progressRemainingColor,
                                      textColor: moduleTheme.primaryTextColor,
                                    ),
                                  if (rank != null && rank > 0)
                                    _InfoChip(
                                      label: 'Rank #$rank',
                                      backgroundColor:
                                          moduleTheme.progressRemainingColor,
                                      textColor: moduleTheme.secondaryTextColor,
                                    ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 8),
                            _LabeledValueRow(label: '放送', value: airRangeText),
                            const SizedBox(height: 4),
                            _LabeledValueRow(
                              label: '最近更新',
                              value: _formatLatestEpisodeUpdate(summary),
                              highlightLabel: true,
                            ),
                            const SizedBox(height: 4),
                            _LabeledValueRow(
                              label: isBound ? '最近观看' : '下次更新',
                              value: isBound
                                  ? _formatWatchMoment(lastWatchedAt)
                                  : _formatNextEpisodeUpdate(summary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ProgressSegmentsBar(
                    watched: watchedEpisodes,
                    updated: updated,
                    total: total,
                    showWatched: isBound,
                    watchedColor: moduleTheme.progressWatchedColor,
                    updatedColor: moduleTheme.progressUpdatedColor,
                    remainingColor: moduleTheme.progressRemainingColor,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isBound
                        ? '已追 $watchedEpisodes / 已更 $updated / 共 ${total > 0 ? total : '-'}'
                        : '已更 $updated / 共 ${total > 0 ? total : '-'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: moduleTheme.secondaryTextColor,
                    ),
                  ),
                  if (tagPool.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: tagPool
                          .map(
                            (tag) => _InfoChip(
                              label: tag,
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                              textColor: moduleTheme.secondaryTextColor,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  if (!compact && item.summary.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      item.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: moduleTheme.secondaryTextColor,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
              if (isBound && missingCount > 0)
                Positioned(
                  top: 0,
                  right: 0,
                  child: EpisodeBadge(count: missingCount),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({
    required this.url,
    this.width = 72,
    this.height = 96,
  });

  final String url;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget buildFallback(IconData icon) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: min(width, height) * 0.34),
      );
    }

    if (url.isEmpty) {
      return buildFallback(Icons.image);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: BoxFit.cover,
        placeholder: (_, __) => buildFallback(Icons.image),
        errorWidget: (_, __, ___) => buildFallback(Icons.broken_image),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.compact = false,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _BoundQuickActionButton extends StatelessWidget {
  const _BoundQuickActionButton({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final moduleTheme = theme.extension<ContentModuleThemeExtension>() ??
        ContentModuleThemeExtension.fromScheme(theme.colorScheme);
    final radius = BorderRadius.circular(999);

    return Tooltip(
      message: '+1',
      child: Material(
        color: moduleTheme.progressRemainingColor,
        borderRadius: radius,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              border: Border.all(color: moduleTheme.borderColor),
              borderRadius: radius,
            ),
            child: Text(
              '+1',
              style: theme.textTheme.labelMedium?.copyWith(
                color: moduleTheme.progressWatchedColor,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactUnreadBadge extends StatelessWidget {
  const _CompactUnreadBadge({
    required this.count,
    required this.backgroundColor,
    required this.textColor,
  });

  final int count;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    final circular = label.length == 1;

    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: EdgeInsets.symmetric(horizontal: circular ? 0 : 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circular ? null : BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
      ),
    );
  }
}

class _LabeledValueRow extends StatelessWidget {
  const _LabeledValueRow({
    required this.label,
    required this.value,
    this.highlightLabel = false,
  });

  final String label;
  final String value;
  final bool highlightLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final moduleTheme = theme.extension<ContentModuleThemeExtension>() ??
        ContentModuleThemeExtension.fromScheme(theme.colorScheme);
    return Text.rich(
      TextSpan(
        style: theme.textTheme.bodySmall?.copyWith(
          color: moduleTheme.secondaryTextColor,
          height: 1.3,
        ),
        children: [
          TextSpan(
            text: '$label ',
            style: TextStyle(
              color: highlightLabel
                  ? moduleTheme.progressWatchedColor
                  : moduleTheme.secondaryTextColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              color: moduleTheme.primaryTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _CalendarModuleLayout {
  const _CalendarModuleLayout({
    required this.isWide,
    required this.isMedium,
    required this.isNarrow,
    required this.boundCardWidth,
    required this.boundCardHeight,
    required this.boundCoverWidth,
    required this.boundCoverHeight,
    required this.dayCoverWidth,
    required this.dayCoverHeight,
  });

  final bool isWide;
  final bool isMedium;
  final bool isNarrow;
  final double boundCardWidth;
  final double boundCardHeight;
  final double boundCoverWidth;
  final double boundCoverHeight;
  final double dayCoverWidth;
  final double dayCoverHeight;

  factory _CalendarModuleLayout.fromWidth(double width) {
    if (width >= 840) {
      return const _CalendarModuleLayout(
        isWide: true,
        isMedium: false,
        isNarrow: false,
        boundCardWidth: 352,
        boundCardHeight: 236,
        boundCoverWidth: 84,
        boundCoverHeight: 112,
        dayCoverWidth: 80,
        dayCoverHeight: 108,
      );
    }
    if (width >= 600) {
      return const _CalendarModuleLayout(
        isWide: false,
        isMedium: true,
        isNarrow: false,
        boundCardWidth: 320,
        boundCardHeight: 236,
        boundCoverWidth: 78,
        boundCoverHeight: 108,
        dayCoverWidth: 74,
        dayCoverHeight: 100,
      );
    }
    return const _CalendarModuleLayout(
      isWide: false,
      isMedium: false,
      isNarrow: true,
      boundCardWidth: 292,
      boundCardHeight: 236,
      boundCoverWidth: 72,
      boundCoverHeight: 98,
      dayCoverWidth: 68,
      dayCoverHeight: 92,
    );
  }
}

int _resolveTotalEpisodes(int baseTotal, int watched, int updated) {
  if (baseTotal > 0) return baseTotal;
  return max(1, max(watched, updated));
}

String _formatLatestEpisodeUpdate(EpisodeReleaseSummary summary) {
  final episode = summary.latestAiredEpisode;
  if (episode == null || episode <= 0) {
    return summary.nextEpisode == null ? '未放送' : '待更新';
  }
  final moment = _formatReleaseMoment(summary.latestAiredAt);
  return moment.isEmpty ? 'EP$episode' : 'EP$episode · $moment';
}

String _formatNextEpisodeUpdate(EpisodeReleaseSummary summary) {
  final nextEpisode = summary.nextEpisode;
  if (nextEpisode != null && nextEpisode > 0) {
    final moment = _formatReleaseMoment(summary.nextAiredAt);
    return moment.isEmpty ? 'EP$nextEpisode' : 'EP$nextEpisode · $moment';
  }
  final latest = summary.latestAiredEpisode;
  if (latest != null && latest > 0) {
    return '已更新至 EP$latest';
  }
  return '待定';
}

String _formatWeeklyUpdateLabel(DateTime? nextAiredAt, int fallbackWeekday) {
  final weekday = nextAiredAt?.weekday ?? fallbackWeekday;
  const weekdayLabels = <int, String>{
    DateTime.monday: '周一',
    DateTime.tuesday: '周二',
    DateTime.wednesday: '周三',
    DateTime.thursday: '周四',
    DateTime.friday: '周五',
    DateTime.saturday: '周六',
    DateTime.sunday: '周日',
  };
  final label = weekdayLabels[weekday];
  return label == null ? '' : '$label更新';
}

String _formatWatchMoment(DateTime? value) {
  if (value == null) return '-';
  final date =
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  if (_hasTimePrecision(value)) {
    return '$date ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }
  return date;
}

String _formatReleaseMoment(DateTime? value) {
  if (value == null) return '';
  final date =
      '${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  if (_hasTimePrecision(value)) {
    return '$date ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }
  return date;
}

bool _hasTimePrecision(DateTime value) {
  return value.hour != 0 ||
      value.minute != 0 ||
      value.second != 0 ||
      value.millisecond != 0 ||
      value.microsecond != 0;
}
