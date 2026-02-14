import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_services.dart';
import '../app/app_settings.dart';
import '../models/bangumi_models.dart';
import '../view_models/calendar_view_model.dart';
import '../widgets/navigation_shell.dart';
import 'detail_page.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => CalendarViewModel(
        bangumiApi: context.read<AppServices>().bangumiApi,
        notionApi: context.read<AppServices>().notionApi,
      )..load(context.read<AppSettings>()),
      child: const _CalendarView(),
    );
  }
}

class _CalendarView extends StatelessWidget {
  const _CalendarView();

  @override
  Widget build(BuildContext context) {
    final model = context.watch<CalendarViewModel>();
    return NavigationShell(
      title: '新番放送',
      selectedRoute: '/calendar',
      actions: [
        IconButton(
          tooltip: '刷新',
          onPressed: model.isLoading
              ? null
              : () => model.load(context.read<AppSettings>()),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: _buildBody(context, model),
    );
  }

  Widget _buildBody(BuildContext context, CalendarViewModel model) {
    final showRatings = context.watch<AppSettings>().showRatings;
    if (model.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (model.errorMessage != null) {
      return _buildCenteredMessage(
        context,
        icon: Icons.error_outline,
        title: model.errorMessage!,
        actionLabel: '重试',
        onAction: () => model.load(context.read<AppSettings>()),
      );
    }

    if (model.days.isEmpty) {
      return _buildCenteredMessage(
        context,
        icon: Icons.inbox_outlined,
        title: '暂无放送数据',
        actionLabel: '刷新',
        onAction: () => model.load(context.read<AppSettings>()),
      );
    }

    final selectedDay = model.days.firstWhere(
      (day) => model.normalizeWeekdayId(day.weekday.id) == model.selectedWeekday,
      orElse: () => const BangumiCalendarDay(
        weekday: BangumiCalendarWeekday(id: 0, en: '', cn: '', ja: ''),
        items: [],
      ),
    );
    final selectedItems =
        model.weekdayItems[model.selectedWeekday] ?? selectedDay.items;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!model.notionConfigured) _buildNoticeBanner(context),
        if (model.notionConfigured) ...[
          _buildBoundSection(context, model, showRatings: showRatings),
          const SizedBox(height: 12),
        ],
        _buildWeekdaySelector(context, model),
        const SizedBox(height: 12),
        if (selectedItems.isEmpty)
          _buildEmptyDay(context)
        else ...[
          _buildDayHeader(context, selectedDay.weekday),
          const SizedBox(height: 8),
          _buildDayItems(context, model, selectedItems, showRatings),
        ],
      ],
    );
  }

  Widget _buildDayItems(
    BuildContext context,
    CalendarViewModel model,
    List<BangumiCalendarItem> items,
    bool showRatings,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1100 ? 2 : 1;
        if (crossAxisCount == 1) {
          return Column(
            children: [
              for (final item in items)
                Builder(
                  builder: (context) {
                    model.scheduleDetailLoad(item.id);
                    model.scheduleLatestEpisodeLoad(item.id);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CalendarItemCard(
                        item: item,
                        detail: model.detailCache[item.id],
                        isBound: model.boundIds.contains(item.id),
                        watchedEpisodes: model.watchedEpisodes[item.id] ?? 0,
                        latestEpisodes: model.latestEpisodeCache[item.id],
                        showRatings: showRatings,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => DetailPage(subjectId: item.id),
                            ),
                          );
                        },
                      ),
                    );
                  },
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
            childAspectRatio: 3.2,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            model.scheduleDetailLoad(item.id);
            model.scheduleLatestEpisodeLoad(item.id);
            return _CalendarItemCard(
              item: item,
              detail: model.detailCache[item.id],
              isBound: model.boundIds.contains(item.id),
              watchedEpisodes: model.watchedEpisodes[item.id] ?? 0,
              latestEpisodes: model.latestEpisodeCache[item.id],
              showRatings: showRatings,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DetailPage(subjectId: item.id),
                  ),
                );
              },
            );
          },
        );
      },
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

  Widget _buildWeekdaySelector(BuildContext context, CalendarViewModel model) {
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
          final isSelected = model.selectedWeekday == entry.key;
          final boundCount = model.weekdayBoundCounts[entry.key] ?? 0;
          final date = model.nextDateForWeekday(entry.key, now);
          final dateLabel = '${date.month}月${date.day}日';
          final label = entry.key == now.weekday ? '今天' : entry.value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: _WeekdayChipLabel(
                label: label,
                count: boundCount,
                dateLabel: dateLabel,
              ),
              selected: isSelected,
              onSelected: (_) => model.selectWeekday(entry.key),
            ),
          );
        }).toList(),
      ),
    );
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
              '未检测到 Notion 绑定信息，仅展示 Bangumi 放送列表',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoundSection(
    BuildContext context,
    CalendarViewModel model, {
    required bool showRatings,
  }) {
    final now = DateTime.now();
    final dateLabel = '${now.year}-${now.month}-${now.day}';
    final hasBound = model.boundItems.isNotEmpty;
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
            height: 144,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: model.boundItems.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = model.boundItems[index];
                model.scheduleDetailLoad(item.id);
                model.scheduleLatestEpisodeLoad(item.id);
                return _BoundBangumiCard(
                  item: item,
                  watchedEpisodes: model.watchedEpisodes[item.id] ?? 0,
                  yougnScore: model.yougnScores[item.id],
                  detail: model.detailCache[item.id],
                  latestEpisodes: model.latestEpisodeCache[item.id],
                  showRatings: showRatings,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DetailPage(subjectId: item.id),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDayHeader(
    BuildContext context,
    BangumiCalendarWeekday weekday,
  ) {
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
          child: Divider(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildCenteredMessage(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? actionLabel,
    VoidCallback? onAction,
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
              if (actionLabel != null) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh),
                  label: Text(actionLabel),
                ),
              ],
            ],
          ),
        ),
      ),
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
    final showBadge = count > 0;
    final badgeColor = Theme.of(context).colorScheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dateLabel,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            if (showBadge) ...[
              const SizedBox(width: 6),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '$count',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: badgeColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ],
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
    required this.showRatings,
    required this.onTap,
  });

  final BangumiCalendarItem item;
  final int watchedEpisodes;
  final double? yougnScore;
  final BangumiSubjectDetail? detail;
  final int? latestEpisodes;
  final bool showRatings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = item.nameCn.isNotEmpty ? item.nameCn : item.name;
    final latestSegment = latestEpisodes == null
        ? '已更 -'
        : (latestEpisodes! > 0 ? '已更 ${latestEpisodes!}' : '未放送');
    final totalValue = detail?.epsCount ?? item.epsCount;
    final totalText = totalValue > 0 ? totalValue.toString() : '-';
    final watchedText = watchedEpisodes > 0 ? watchedEpisodes.toString() : '-';
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
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
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
                            Text('悠gn ${yougnScore!.toStringAsFixed(1)}'),
                          if (showRatings && yougnScore != null)
                            const SizedBox(height: 4),
                          Text('已追 $watchedText'),
                          const SizedBox(height: 4),
                          Text(latestSegment),
                          const SizedBox(height: 4),
                          Text('总共 $totalText'),
                        ],
                      ),
                    ],
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
    required this.watchedEpisodes,
    required this.latestEpisodes,
    required this.showRatings,
    required this.onTap,
  });

  final BangumiCalendarItem item;
  final BangumiSubjectDetail? detail;
  final bool isBound;
  final int watchedEpisodes;
  final int? latestEpisodes;
  final bool showRatings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = item.nameCn.isNotEmpty ? item.nameCn : item.name;
    final airDate = item.airDate.isNotEmpty ? item.airDate : '待定';
    final latestSegment = latestEpisodes == null
        ? '已更 -'
        : (latestEpisodes! > 0 ? '已更 ${latestEpisodes!}' : '未放送');
    final totalValue = detail?.epsCount ?? item.epsCount;
    final totalText = totalValue > 0 ? totalValue.toString() : '-';
    final watchedText = watchedEpisodes > 0 ? watchedEpisodes.toString() : '-';
    final colorScheme = Theme.of(context).colorScheme;
    final score = detail?.score ?? 0;
    final rank = detail?.rank;
    final hasRating =
        showRatings && (score > 0 || (rank != null && rank > 0));
    final tags = detail?.tags.take(10).toList() ?? <String>[];
    final ratingStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colorScheme.tertiary,
          fontWeight: FontWeight.w600,
        );
    final rankStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        );

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
        child: Padding(
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
                    const SizedBox(height: 6),
                    if (hasRating) ...[
                      Row(
                        children: [
                          if (score > 0)
                            Text(
                              'Bangumi ${score.toStringAsFixed(1)}',
                              style: ratingStyle,
                            ),
                          if (score > 0 && rank != null && rank > 0)
                            const SizedBox(width: 8),
                          if (rank != null && rank > 0)
                            Text(
                              'Rank #$rank',
                              style: rankStyle,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text('放送开始：$airDate'),
                    const SizedBox(height: 4),
                    Text(
                      isBound
                          ? '已追 $watchedText / $latestSegment / 总共 $totalText'
                          : '$latestSegment / 总共 $totalText',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: tags.map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              tag,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    if (item.summary.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        item.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
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
