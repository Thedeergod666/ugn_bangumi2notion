import 'package:flutter/material.dart';

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
  final BangumiApi _bangumiApi = BangumiApi();
  final NotionApi _notionApi = NotionApi();
  final SettingsStorage _settingsStorage = SettingsStorage();

  bool _loading = true;
  String? _errorMessage;
  List<BangumiCalendarDay> _days = [];
  Set<int> _boundIds = {};
  bool _notionConfigured = false;

  @override
  void initState() {
    super.initState();
    _loadCalendar();
  }

  Future<void> _loadCalendar() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
      _days = [];
      _boundIds = {};
      _notionConfigured = false;
    });

    try {
      final calendar = await _bangumiApi.fetchCalendar();
      final filteredDays = _filterCalendarDays(calendar);

      final settings = await _settingsStorage.loadAll();
      final notionToken = settings[SettingsKeys.notionToken] ?? '';
      final notionDbId = settings[SettingsKeys.notionDatabaseId] ?? '';
      final mappingConfig = await _settingsStorage.getMappingConfig();
      final notionPropertyName = _resolveBangumiIdProperty(mappingConfig);

      Set<int> boundIds = {};
      bool notionReady = false;
      if (notionToken.isNotEmpty &&
          notionDbId.isNotEmpty &&
          notionPropertyName.isNotEmpty) {
        notionReady = true;
        boundIds = await _notionApi.getBangumiIdSet(
          token: notionToken,
          databaseId: notionDbId,
          propertyName: notionPropertyName,
        );
      }

      if (!mounted) return;
      setState(() {
        _days = filteredDays;
        _boundIds = boundIds;
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!_notionConfigured)
          _buildNoticeBanner(context),
        for (final day in _days) ...[
          _buildDayHeader(context, day.weekday),
          const SizedBox(height: 8),
          for (final item in day.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CalendarItemCard(
                item: item,
                isBound: _boundIds.contains(item.id),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DetailPage(subjectId: item.id),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildNoticeBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
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
              Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
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

class _CalendarItemCard extends StatelessWidget {
  const _CalendarItemCard({
    required this.item,
    required this.isBound,
    required this.onTap,
  });

  final BangumiCalendarItem item;
  final bool isBound;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = item.nameCn.isNotEmpty ? item.nameCn : item.name;
    final airDate = item.airDate.isNotEmpty ? item.airDate : '待定';
    final epsText = item.epsCount > 0
        ? '全 $item.epsCount 集'
        : (item.eps > 0 ? '预计 $item.eps 集' : '集数未知');
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: isBound
          ? colorScheme.primaryContainer.withOpacity(0.3)
          : colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isBound ? colorScheme.primary : colorScheme.outlineVariant,
          width: isBound ? 1.2 : 0.8,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
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
                            child: const Text(
                              '已绑定',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('放送开始：$airDate'),
                    const SizedBox(height: 4),
                    Text(epsText, style: Theme.of(context).textTheme.bodySmall),
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
    if (url.isEmpty) {
      return Container(
        width: 72,
        height: 96,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.image, size: 32),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: 72,
        height: 96,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 72,
            height: 96,
            color: colorScheme.surfaceContainerHighest,
            child: const Icon(Icons.broken_image, size: 32),
          );
        },
      ),
    );
  }
}
