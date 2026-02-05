import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_services.dart';
import '../app/app_settings.dart';
import '../models/bangumi_models.dart';
import '../models/mapping_config.dart';
import '../services/bangumi_api.dart';
import '../services/notion_api.dart';
import '../services/settings_storage.dart';
import '../widgets/navigation_shell.dart';
import 'detail_page.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late final BangumiApi _bangumiApi;
  late final NotionApi _notionApi;
  final SettingsStorage _settingsStorage = SettingsStorage();

  bool _loading = true;
  String? _errorMessage;
  List<BangumiCalendarDay> _days = [];
  Set<int> _boundIds = {};
  Map<int, int> _watchedEpisodes = {};
  Map<int, double?> _yougnScores = {};
  Map<int, BangumiSubjectDetail> _detailCache = {};
  final Set<int> _detailLoading = {};
  Map<int, int> _latestEpisodeCache = {};
  final Set<int> _latestEpisodeLoading = {};
  Map<int, List<BangumiCalendarItem>> _weekdayItems = {};
  Map<int, int> _weekdayBoundCounts = {};
  List<BangumiCalendarItem> _boundItems = [];
  bool _notionConfigured = false;
  int _selectedWeekday = DateTime.now().weekday;

  @override
  void initState() {
    super.initState();
    final services = context.read<AppServices>();
    _bangumiApi = services.bangumiApi;
    _notionApi = services.notionApi;
    _loadCalendar();
  }

  Future<void> _loadCalendar() async {
    if (!mounted) return;
    final appSettings = context.read<AppSettings>();
    setState(() {
      _loading = true;
      _errorMessage = null;
      _days = [];
      _boundIds = {};
      _boundItems = [];
      _watchedEpisodes = {};
      _yougnScores = {};
      _detailCache = {};
      _detailLoading.clear();
      _latestEpisodeCache = {};
      _latestEpisodeLoading.clear();
      _notionConfigured = false;
    });

    try {
      final calendar = await _bangumiApi.fetchCalendar();
      final filteredDays = _filterCalendarDays(calendar);

      final notionToken = appSettings.notionToken;
      final notionDbId = appSettings.notionDatabaseId;
      final mappingConfig = await _settingsStorage.getMappingConfig();
      final notionPropertyName = _resolveBangumiIdProperty(mappingConfig);

      final dailyBindings = await _settingsStorage.getDailyRecommendationBindings();
      final yougnScoreProperty = dailyBindings.yougnScore.isNotEmpty
          ? dailyBindings.yougnScore
          : mappingConfig.dailyRecommendationBindings.yougnScore;

      Set<int> boundIds = {};
      Map<int, int> watchedEpisodes = {};
      Map<int, double?> yougnScores = {};
      bool notionReady = false;
      if (notionToken.isNotEmpty &&
          notionDbId.isNotEmpty &&
          notionPropertyName.isNotEmpty) {
        notionReady = true;
        final progressMap = await _notionApi.getBangumiProgressInfo(
          token: notionToken,
          databaseId: notionDbId,
          idPropertyName: notionPropertyName,
          watchedEpisodesProperty: mappingConfig.watchedEpisodes,
          yougnScoreProperty: yougnScoreProperty,
          statusPropertyName: mappingConfig.watchingStatus,
          statusValue: mappingConfig.watchingStatusValue,
        );
        watchedEpisodes = {
          for (final entry in progressMap.entries)
            entry.key: entry.value.watchedEpisodes
        };
        yougnScores = {
          for (final entry in progressMap.entries)
            entry.key: entry.value.yougnScore
        };
        boundIds = progressMap.keys.toSet();
      }

      if (!mounted) return;
      setState(() {
        _days = filteredDays;
        _boundIds = boundIds;
        _watchedEpisodes = watchedEpisodes;
        _yougnScores = yougnScores;
        _weekdayItems = _buildWeekdayItems(filteredDays, boundIds);
        _weekdayBoundCounts = _buildWeekdayBoundCounts(filteredDays, boundIds);
        _boundItems = _buildBoundItems(filteredDays, boundIds);
        _notionConfigured = notionReady;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = '加载放送列表失败，请稍后重试';
      });
    }
  }

  String _resolveBangumiIdProperty(MappingConfig config) {
    if (config.bangumiId.trim().isNotEmpty) {
      return config.bangumiId.trim();
    }
    return config.idPropertyName.trim();
  }

  List<BangumiCalendarDay> _filterCalendarDays(List<BangumiCalendarDay> days) {
    final filtered = <BangumiCalendarDay>[];
    for (final day in days) {
      final items = day.items.where((item) => item.type == 2).toList();
      if (items.isEmpty) continue;
      filtered.add(BangumiCalendarDay(weekday: day.weekday, items: items));
    }
    return filtered;
  }

  int _normalizeWeekdayId(int id) {
    if (id == 0) return 7;
    return id;
  }

  Map<int, List<BangumiCalendarItem>> _buildWeekdayItems(
    List<BangumiCalendarDay> days,
    Set<int> boundIds,
  ) {
    final result = <int, List<BangumiCalendarItem>>{};
    for (final day in days) {
      final items = [...day.items];
      items.sort((a, b) {
        final aBound = boundIds.contains(a.id);
        final bBound = boundIds.contains(b.id);
        if (aBound == bBound) return 0;
        return aBound ? -1 : 1;
      });
      result[_normalizeWeekdayId(day.weekday.id)] = items;
    }
    return result;
  }

  Map<int, int> _buildWeekdayBoundCounts(
    List<BangumiCalendarDay> days,
    Set<int> boundIds,
  ) {
    final counts = <int, int>{};
    for (final day in days) {
      int count = 0;
      for (final item in day.items) {
        if (boundIds.contains(item.id)) count += 1;
      }
      counts[_normalizeWeekdayId(day.weekday.id)] = count;
    }
    return counts;
  }

  List<BangumiCalendarItem> _buildBoundItems(
    List<BangumiCalendarDay> days,
    Set<int> boundIds,
  ) {
    final result = <BangumiCalendarItem>[];
    final seen = <int>{};
    for (final day in days) {
      for (final item in day.items) {
        if (!boundIds.contains(item.id)) continue;
        if (seen.add(item.id)) {
          result.add(item);
        }
      }
    }
    return result;
  }

  DateTime _nextDateForWeekday(int weekday, DateTime now) {
    final base = DateTime(now.year, now.month, now.day);
    int diff = weekday - now.weekday;
    if (diff < 0) diff += 7;
    return base.add(Duration(days: diff));
  }

  void _scheduleDetailLoad(int subjectId) {
    if (_detailCache.containsKey(subjectId) ||
        _detailLoading.contains(subjectId)) {
      return;
    }
    _detailLoading.add(subjectId);
    _loadDetail(subjectId);
  }

  void _scheduleLatestEpisodeLoad(int subjectId, int currentLatest) {
    if (currentLatest > 0 ||
        _latestEpisodeCache.containsKey(subjectId) ||
        _latestEpisodeLoading.contains(subjectId)) {
      return;
    }
    _latestEpisodeLoading.add(subjectId);
    _loadLatestEpisode(subjectId);
  }

  Future<void> _loadLatestEpisode(int subjectId) async {
    try {
      final token = context.read<AppSettings>().bangumiAccessToken;
      final latest = await _bangumiApi.fetchLatestEpisodeNumber(
        subjectId: subjectId,
        accessToken: token.isEmpty ? null : token,
      );
      if (!mounted) return;
      if (latest > 0) {
        setState(() {
          _latestEpisodeCache[subjectId] = latest;
        });
      }
    } catch (_) {
      // Ignore latest episode fetch failures for list rendering.
    } finally {
      _latestEpisodeLoading.remove(subjectId);
    }
  }

  Future<void> _loadDetail(int subjectId) async {
    try {
      final token = context.read<AppSettings>().bangumiAccessToken;
      final detail = await _bangumiApi.fetchSubjectBase(
        subjectId: subjectId,
        accessToken: token.isEmpty ? null : token,
      );
      if (!mounted) return;
      setState(() {
        _detailCache[subjectId] = detail;
      });
    } catch (_) {
      // Ignore detail fetch failures for list rendering.
    } finally {
      _detailLoading.remove(subjectId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NavigationShell(
      title: '新番放送',
      selectedRoute: '/calendar',
      actions: [
        IconButton(
          tooltip: '刷新',
          onPressed: _loading ? null : _loadCalendar,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _buildCenteredMessage(
        context,
        icon: Icons.error_outline,
        title: _errorMessage!,
        actionLabel: '重试',
        onAction: _loadCalendar,
      );
    }

    if (_days.isEmpty) {
      return _buildCenteredMessage(
        context,
        icon: Icons.inbox_outlined,
        title: '暂时没有放送数据',
        actionLabel: '刷新',
        onAction: _loadCalendar,
      );
    }

    final selectedDay = _days.firstWhere(
      (day) => _normalizeWeekdayId(day.weekday.id) == _selectedWeekday,
      orElse: () => const BangumiCalendarDay(
        weekday: BangumiCalendarWeekday(id: 0, en: '', cn: '', ja: ''),
        items: [],
      ),
    );
    final selectedItems = _weekdayItems[_selectedWeekday] ?? selectedDay.items;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!_notionConfigured) _buildNoticeBanner(context),
        if (_notionConfigured) ...[
          _buildBoundSection(context),
          const SizedBox(height: 12),
        ],
        _buildWeekdaySelector(context),
        const SizedBox(height: 12),
        if (selectedItems.isEmpty)
          _buildEmptyDay(context)
        else ...[
          _buildDayHeader(context, selectedDay.weekday),
          const SizedBox(height: 8),
          for (final item in selectedItems)
            Builder(
              builder: (context) {
                _scheduleDetailLoad(item.id);
                _scheduleLatestEpisodeLoad(item.id, item.eps);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CalendarItemCard(
                    item: item,
                    detail: _detailCache[item.id],
                    isBound: _boundIds.contains(item.id),
                    watchedEpisodes: _watchedEpisodes[item.id] ?? 0,
                    latestEpisodes: _latestEpisodeCache[item.id] ?? 0,
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
          final isSelected = _selectedWeekday == entry.key;
          final boundCount = _weekdayBoundCounts[entry.key] ?? 0;
          final date = _nextDateForWeekday(entry.key, now);
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
              onSelected: (_) {
                setState(() {
                  _selectedWeekday = entry.key;
                });
              },
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

  Widget _buildBoundSection(BuildContext context) {
    final now = DateTime.now();
    final dateLabel = '${now.year}-${now.month}-${now.day}';
    final hasBound = _boundItems.isNotEmpty;
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
              itemCount: _boundItems.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = _boundItems[index];
                _scheduleDetailLoad(item.id);
                _scheduleLatestEpisodeLoad(item.id, item.eps);
                return _BoundBangumiCard(
                  item: item,
                  watchedEpisodes: _watchedEpisodes[item.id] ?? 0,
                  yougnScore: _yougnScores[item.id],
                  detail: _detailCache[item.id],
                  latestEpisodes: _latestEpisodeCache[item.id] ?? 0,
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
    required this.onTap,
  });

  final BangumiCalendarItem item;
  final int watchedEpisodes;
  final double? yougnScore;
  final BangumiSubjectDetail? detail;
  final int latestEpisodes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = item.nameCn.isNotEmpty ? item.nameCn : item.name;
    final latestValue = item.eps > 0 ? item.eps : latestEpisodes;
    final latestText = latestValue > 0 ? latestValue.toString() : '-';
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
                          if (yougnScore != null)
                            Text('悠GN ${yougnScore!.toStringAsFixed(1)}'),
                          if (yougnScore != null) const SizedBox(height: 4),
                          Text('已追 $watchedText'),
                          const SizedBox(height: 4),
                          Text('已更 $latestText'),
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
    required this.onTap,
  });

  final BangumiCalendarItem item;
  final BangumiSubjectDetail? detail;
  final bool isBound;
  final int watchedEpisodes;
  final int latestEpisodes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = item.nameCn.isNotEmpty ? item.nameCn : item.name;
    final airDate = item.airDate.isNotEmpty ? item.airDate : '待定';
    final latestValue = item.eps > 0 ? item.eps : latestEpisodes;
    final latestText = latestValue > 0 ? latestValue.toString() : '-';
    final totalValue = detail?.epsCount ?? item.epsCount;
    final totalText = totalValue > 0 ? totalValue.toString() : '-';
    final watchedText = watchedEpisodes > 0 ? watchedEpisodes.toString() : '-';
    final colorScheme = Theme.of(context).colorScheme;
    final score = detail?.score ?? 0;
    final rank = detail?.rank;
    final hasRating = score > 0 || (rank != null && rank > 0);
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
                          ? '\u5df2\u8ffd $watchedText / \u5df2\u66f4 $latestText / \u603b\u5171 $totalText'
                          : '\u5df2\u66f4 $latestText / \u603b\u5171 $totalText',
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
