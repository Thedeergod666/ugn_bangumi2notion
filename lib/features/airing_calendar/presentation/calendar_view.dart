import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/episode_badge.dart';
import '../../../core/widgets/progress_segments_bar.dart';
import '../../../core/widgets/view_mode_toggle.dart';
import '../../../models/bangumi_models.dart';

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
    required this.latestEpisodeCache,
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
  final Map<int, int> latestEpisodeCache;
  final Map<int, String?> airEndDateCache;
}

class CalendarViewCallbacks {
  const CalendarViewCallbacks({
    required this.onWeekdaySelected,
    required this.onCalendarViewModeChanged,
    required this.onTapSubject,
    required this.onLongPressBoundSubject,
  });

  final ValueChanged<int> onWeekdaySelected;
  final ValueChanged<String> onCalendarViewModeChanged;
  final ValueChanged<int> onTapSubject;
  final ValueChanged<int> onLongPressBoundSubject;
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
    int diff = weekday - now.weekday;
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
    final headerText = hasBound ? '$dateLabel · 已追' : dateLabel;
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
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: state.boundItems.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = state.boundItems[index];
                return _BoundBangumiCard(
                  item: item,
                  watchedEpisodes: state.watchedEpisodes[item.id] ?? 0,
                  yougnScore: state.yougnScores[item.id],
                  detail: state.detailCache[item.id],
                  latestEpisodes: state.latestEpisodeCache[item.id],
                  lastWatchedAt: state.lastWatchedAt[item.id],
                  showRatings: state.showRatings,
                  onTap: () => callbacks.onTapSubject(item.id),
                  onLongPress: () => callbacks.onLongPressBoundSubject(item.id),
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
        final isGallery = state.calendarViewMode == 'gallery';
        final crossAxisCount =
            isGallery ? (width >= 1200 ? 3 : (width >= 900 ? 2 : 1)) : 1;
        final childAspectRatio = isGallery && crossAxisCount > 1 ? 2.2 : 3.2;

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
                    latestEpisodes: state.latestEpisodeCache[item.id],
                    airEndDate: state.airEndDateCache[item.id],
                    lastWatchedAt: state.lastWatchedAt[item.id],
                    showRatings: state.showRatings,
                    onTap: () => callbacks.onTapSubject(item.id),
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
              latestEpisodes: state.latestEpisodeCache[item.id],
              airEndDate: state.airEndDateCache[item.id],
              lastWatchedAt: state.lastWatchedAt[item.id],
              showRatings: state.showRatings,
              onTap: () => callbacks.onTapSubject(item.id),
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
    required this.latestEpisodes,
    required this.lastWatchedAt,
    required this.showRatings,
    required this.onTap,
    required this.onLongPress,
  });

  final BangumiCalendarItem item;
  final int watchedEpisodes;
  final double? yougnScore;
  final BangumiSubjectDetail? detail;
  final int? latestEpisodes;
  final DateTime? lastWatchedAt;
  final bool showRatings;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final title = item.nameCn.isNotEmpty ? item.nameCn : item.name;
    final latestSegment = latestEpisodes == null
        ? '已更 -'
        : (latestEpisodes! > 0 ? '已更 ${latestEpisodes!}' : '未放送');
    final totalValue = detail?.epsCount ?? item.epsCount;
    final totalText = totalValue > 0 ? totalValue.toString() : '-';
    final watchedText = watchedEpisodes > 0 ? watchedEpisodes.toString() : '-';
    final updatedValue = latestEpisodes ?? 0;
    final missingCount =
        updatedValue > watchedEpisodes ? updatedValue - watchedEpisodes : 0;
    final lastWatchedText = lastWatchedAt == null
        ? '-'
        : '${lastWatchedAt!.year}-${lastWatchedAt!.month.toString().padLeft(2, '0')}-${lastWatchedAt!.day.toString().padLeft(2, '0')}';

    return IntrinsicWidth(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 180, maxWidth: 280),
        child: Card(
          clipBehavior: Clip.antiAlias,
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 0.8,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CoverImage(url: item.imageUrl),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showRatings && yougnScore != null)
                                Text('评分 ${yougnScore!.toStringAsFixed(1)}'),
                              if (showRatings && yougnScore != null)
                                const SizedBox(height: 4),
                              Text('最近观看 $lastWatchedText'),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ProgressSegmentsBar(
                              watched: watchedEpisodes,
                              updated: updatedValue,
                              total: totalValue > 0
                                  ? totalValue
                                  : max(watchedEpisodes, updatedValue),
                              showWatched: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '已追 $watchedText / $latestSegment / 共 $totalText',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (missingCount > 0)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: EpisodeBadge(count: missingCount),
                    ),
                ],
              ),
            ),
          ),
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
    required this.latestEpisodes,
    required this.airEndDate,
    required this.lastWatchedAt,
    required this.showRatings,
    required this.onTap,
  });

  final BangumiCalendarItem item;
  final BangumiSubjectDetail? detail;
  final bool isBound;
  final bool isGallery;
  final int watchedEpisodes;
  final int? latestEpisodes;
  final String? airEndDate;
  final DateTime? lastWatchedAt;
  final bool showRatings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = item.nameCn.isNotEmpty ? item.nameCn : item.name;
    final airDate = item.airDate.isNotEmpty ? item.airDate : '待定';
    final endDate = (airEndDate != null && airEndDate!.trim().isNotEmpty)
        ? airEndDate!.trim()
        : '';
    final airRangeText =
        endDate.isEmpty || endDate == airDate ? airDate : '$airDate ~ $endDate';
    final latestSegment = latestEpisodes == null
        ? '已更 -'
        : (latestEpisodes! > 0 ? '已更 ${latestEpisodes!}' : '未放送');
    final totalValue = detail?.epsCount ?? item.epsCount;
    final totalText = totalValue > 0 ? totalValue.toString() : '-';
    final watchedText = watchedEpisodes > 0 ? watchedEpisodes.toString() : '-';
    final updatedValue = latestEpisodes ?? 0;
    final missingCount =
        updatedValue > watchedEpisodes ? updatedValue - watchedEpisodes : 0;
    final colorScheme = Theme.of(context).colorScheme;
    final score = detail?.score ?? 0;
    final rank = detail?.rank;
    final hasRating = showRatings && (score > 0 || (rank != null && rank > 0));
    final sortedTags = [...(detail?.tagDetails ?? const <BangumiTag>[])]
      ..sort((a, b) => b.count.compareTo(a.count));
    final tagPool = sortedTags
        .map((tag) => tag.name)
        .where((name) => name.isNotEmpty)
        .take(20)
        .toList();
    final compactLayout = isGallery;

    return Card(
      clipBehavior: Clip.antiAlias,
      color: isBound
          ? colorScheme.primaryContainer.withValues(alpha: 0.35)
          : colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isBound ? colorScheme.primary : colorScheme.outlineVariant,
          width: isBound ? 1.1 : 0.8,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CoverImage(url: item.imageUrl),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (isBound)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '已绑定',
                                  style: TextStyle(
                                    color: colorScheme.onPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: compactLayout ? 4 : 6),
                        if (hasRating) ...[
                          Row(
                            children: [
                              if (score > 0)
                                Text(
                                  'Bangumi ${score.toStringAsFixed(1)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: colorScheme.tertiary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              if (score > 0 && rank != null && rank > 0)
                                const SizedBox(width: 8),
                              if (rank != null && rank > 0)
                                Text(
                                  'Rank #$rank',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),
                            ],
                          ),
                          SizedBox(height: compactLayout ? 2 : 4),
                        ],
                        Text('放送：$airRangeText'),
                        SizedBox(height: compactLayout ? 4 : 6),
                        Row(
                          children: [
                            Expanded(
                              child: ProgressSegmentsBar(
                                watched: watchedEpisodes,
                                updated: updatedValue,
                                total: totalValue > 0
                                    ? totalValue
                                    : max(watchedEpisodes, updatedValue),
                                showWatched: isBound,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                isBound
                                    ? '已追 $watchedText / $latestSegment / 共 $totalText'
                                    : '$latestSegment / 共 $totalText',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                        if (tagPool.isNotEmpty) ...[
                          SizedBox(height: compactLayout ? 6 : 8),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final maxPerLine =
                                  max(1, (constraints.maxWidth / 88).floor());
                              const maxLines = 1;
                              final maxTags = max(1, maxPerLine * maxLines);
                              final tags = tagPool.take(maxTags).toList();
                              return Wrap(
                                spacing: 6,
                                runSpacing: compactLayout ? 4 : 6,
                                children: tags.map((tag) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      tag,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall,
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        ],
                        if (item.summary.isNotEmpty) ...[
                          SizedBox(height: compactLayout ? 6 : 8),
                          Text(
                            item.summary,
                            maxLines: compactLayout ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (isBound && missingCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: EpisodeBadge(count: missingCount),
              ),
          ],
        ),
      ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget buildFallback(IconData icon) {
      return Container(
        width: 72,
        height: 96,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 32),
      );
    }

    if (url.isEmpty) {
      return buildFallback(Icons.image);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: url,
        width: 72,
        height: 96,
        fit: BoxFit.cover,
        placeholder: (_, __) => buildFallback(Icons.image),
        errorWidget: (_, __, ___) => buildFallback(Icons.broken_image),
      ),
    );
  }
}
