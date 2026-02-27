import 'package:flutter/material.dart';
import '../models/mapping_config.dart';
import '../models/notion_models.dart';

class NotionMappingPanel extends StatelessWidget {
  final bool isLoading;
  final bool isConfigured;
  final List<NotionProperty> properties;
  final NotionDailyRecommendationBindings bindings;
  final ValueChanged<NotionDailyRecommendationBindings> onBindingsChanged;
  final NotionWatchBindings watchBindings;
  final ValueChanged<NotionWatchBindings> onWatchBindingsChanged;
  final bool embedInScroll;

  const NotionMappingPanel({
    super.key,
    required this.isLoading,
    required this.isConfigured,
    required this.properties,
    required this.bindings,
    required this.onBindingsChanged,
    required this.watchBindings,
    required this.onWatchBindingsChanged,
    this.embedInScroll = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!isConfigured) {
      return const Center(child: Text('请先在设置页面配置 Notion Token 和 Database ID'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool useColumnLayout = constraints.maxWidth < 900;
        final leftPanel = _buildPropertiesPanel(context);
        final rightPanel = _buildBindingsPanel(context);

        final content = useColumnLayout
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  leftPanel,
                  const SizedBox(height: 16),
                  rightPanel,
                  const SizedBox(height: 24),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: leftPanel),
                  const SizedBox(width: 24),
                  Expanded(child: rightPanel),
                ],
              );

        if (embedInScroll) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: content,
          );
        }

        return Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            primary: true,
            padding: const EdgeInsets.all(16),
            child: content,
          ),
        );
      },
    );
  }

  Widget _buildPropertiesPanel(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notion 属性列表',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        if (properties.isEmpty)
          const Text('暂无属性，请刷新或检查数据库配置。')
        else
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: properties.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final prop = properties[index];
                return ListTile(
                  dense: true,
                  title: Text(prop.name),
                  trailing: SizedBox(
                    width: 120,
                    child: Text(
                      prop.type,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).disabledColor,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildBindingsPanel(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '每日推荐字段绑定',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        _buildSectionTitle('核心字段'),
        _buildBindingRow(
          context,
          label: '标题 (title)',
          value: bindings.title,
          helpText: '用于推荐卡片标题',
          onChanged: (value) => onBindingsChanged(
            bindings.copyWith(title: value),
          ),
        ),
        _buildBindingRow(
          context,
          label: '悠gn评分 (yougnScore)',
          value: bindings.yougnScore,
          helpText: '用于悠gn评分与排名',
          onChanged: (value) => onBindingsChanged(
            bindings.copyWith(yougnScore: value),
          ),
        ),
        _buildBindingRow(
          context,
          label: 'Bangumi评分 (bangumiScore)',
          value: bindings.bangumiScore,
          helpText: '用于展示 Bangumi 评分',
          onChanged: (value) => onBindingsChanged(
            bindings.copyWith(bangumiScore: value),
          ),
        ),
        _buildBindingRow(
          context,
          label: 'Bangumi排名 (bangumiRank)',
          value: bindings.bangumiRank,
          helpText: '用于展示 Bangumi 排名',
          onChanged: (value) => onBindingsChanged(
            bindings.copyWith(bangumiRank: value),
          ),
        ),
        const SizedBox(height: 12),
        _buildSectionTitle('日期信息'),
        _buildBindingRow(
          context,
          label: '追番日期 (followDate)',
          value: bindings.followDate,
          helpText: '用于显示追番日期',
          onChanged: (value) => onBindingsChanged(
            bindings.copyWith(followDate: value),
          ),
        ),
        _buildBindingRow(
          context,
          label: '放送日期 (airDate)',
          value: bindings.airDate,
          helpText: '用于显示放送日期',
          onChanged: (value) => onBindingsChanged(
            bindings.copyWith(airDate: value),
          ),
        ),
        _buildBindingRow(
          context,
          label: '放送日期范围 (airDateRange)',
          value: bindings.airDateRange,
          helpText: '用于显示放送区间',
          onChanged: (value) => onBindingsChanged(
            bindings.copyWith(airDateRange: value),
          ),
        ),
        _buildBindingRow(
          context,
          label: '标签 (tags)',
          value: bindings.tags,
          helpText: '用于推荐卡片标签',
          onChanged: (value) => onBindingsChanged(
            bindings.copyWith(tags: value),
          ),
        ),
        _buildBindingRow(
          context,
          label: '类型 (type)',
          value: bindings.type,
          helpText: '用于推荐筛选/类型',
          onChanged: (value) => onBindingsChanged(
            bindings.copyWith(type: value),
          ),
        ),
        const SizedBox(height: 12),
        _buildSectionTitle('制作信息'),
        _buildBindingRow(
          context,
          label: '动画制作 (animationProduction)',
          value: bindings.animationProduction,
          helpText: '用于制作信息展示',
          onChanged: (value) => onBindingsChanged(
            bindings.copyWith(animationProduction: value),
          ),
        ),
        _buildBindingRow(
          context,
          label: '导演 (director)',
          value: bindings.director,
          helpText: '用于制作信息展示',
          onChanged: (value) => onBindingsChanged(
            bindings.copyWith(director: value),
          ),
        ),
        _buildBindingRow(
          context,
          label: '脚本 (script)',
          value: bindings.script,
          helpText: '用于制作信息展示',
          onChanged: (value) => onBindingsChanged(
            bindings.copyWith(script: value),
          ),
        ),
        _buildBindingRow(
          context,
          label: '分镜 (storyboard)',
          value: bindings.storyboard,
          helpText: '用于制作信息展示',
          onChanged: (value) => onBindingsChanged(
            bindings.copyWith(storyboard: value),
          ),
        ),
        const SizedBox(height: 12),
        _buildSectionTitle('内容信息'),
        _buildBindingRow(
          context,
          label: '短评 (shortReview)',
          value: bindings.shortReview,
          helpText: '用于推荐卡片悠简评',
          onChanged: (value) => onBindingsChanged(
            bindings.copyWith(shortReview: value),
          ),
        ),
        _buildAutoExtractedNote(context),
        _buildBindingRow(
          context,
          label: 'Bangumi ID (bangumiId)',
          value: bindings.bangumiId ?? '',
          helpText: '用于关联 Bangumi 条目',
          onChanged: (value) => onBindingsChanged(
            bindings.copyWith(bangumiId: value.isEmpty ? null : value),
          ),
        ),
        _buildBindingRow(
          context,
          label: 'Subject ID (subjectId)',
          value: bindings.subjectId ?? '',
          helpText: '用于关联 Bangumi 条目',
          onChanged: (value) => onBindingsChanged(
            bindings.copyWith(subjectId: value.isEmpty ? null : value),
          ),
        ),
        _buildBindingRow(
          context,
          label: '封面 (cover)',
          value: bindings.cover,
          helpText: '用于推荐卡片封面',
          onChanged: (value) => onBindingsChanged(
            bindings.copyWith(cover: value),
          ),
        ),
        _buildBindingRow(
          context,
          label: '长评 (longReview)',
          value: bindings.longReview,
          helpText: '用于长评展示',
          onChanged: (value) => onBindingsChanged(
            bindings.copyWith(longReview: value),
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionTitle('追番 / 最近观看'),
        _buildBindingRow(
          context,
          label: '标题 (title)',
          value: watchBindings.title,
          helpText: '用于追番/最近观看标题',
          onChanged: (value) => onWatchBindingsChanged(
            watchBindings.copyWith(title: value),
          ),
        ),
        _buildBindingRow(
          context,
          label: '封面 (cover)',
          value: watchBindings.cover,
          helpText: '用于追番/最近观看封面',
          onChanged: (value) => onWatchBindingsChanged(
            watchBindings.copyWith(cover: value),
          ),
        ),
        _buildBindingRow(
          context,
          label: 'Bangumi ID (bangumiId)',
          value: watchBindings.bangumiId,
          helpText: '用于关联 Bangumi 条目',
          onChanged: (value) => onWatchBindingsChanged(
            watchBindings.copyWith(bangumiId: value),
          ),
        ),
        _buildBindingRow(
          context,
          label: '已追集数 (watchedEpisodes)',
          value: watchBindings.watchedEpisodes,
          helpText: '用于进度条与 +1 更新',
          onChanged: (value) => onWatchBindingsChanged(
            watchBindings.copyWith(watchedEpisodes: value),
          ),
        ),
        _buildBindingRow(
          context,
          label: '总集数 (totalEpisodes)',
          value: watchBindings.totalEpisodes,
          helpText: '用于进度条展示总集数',
          onChanged: (value) => onWatchBindingsChanged(
            watchBindings.copyWith(totalEpisodes: value),
          ),
        ),
        _buildBindingRow(
          context,
          label: '追番状态 (watchingStatus)',
          value: watchBindings.watchingStatus,
          helpText: '用于区分在看/已看',
          onChanged: (value) => onWatchBindingsChanged(
            watchBindings.copyWith(watchingStatus: value),
          ),
        ),
        _buildBindingRow(
          context,
          label: '追番日期 (followDate)',
          value: watchBindings.followDate,
          helpText: '用于显示追番日期',
          onChanged: (value) => onWatchBindingsChanged(
            watchBindings.copyWith(followDate: value),
          ),
        ),
        _buildBindingRow(
          context,
          label: '最近观看时间 (lastWatchedAt)',
          value: watchBindings.lastWatchedAt,
          helpText: '用于最近观看排序与展示',
          onChanged: (value) => onWatchBindingsChanged(
            watchBindings.copyWith(lastWatchedAt: value),
          ),
        ),
        _buildBindingRow(
          context,
          label: '标签 (tags)',
          value: watchBindings.tags,
          helpText: '用于追番标签',
          onChanged: (value) => onWatchBindingsChanged(
            watchBindings.copyWith(tags: value),
          ),
        ),
        _buildBindingRow(
          context,
          label: '悠gn评分 (yougnScore)',
          value: watchBindings.yougnScore,
          helpText: '用于悠gn评分显示',
          onChanged: (value) => onWatchBindingsChanged(
            watchBindings.copyWith(yougnScore: value),
          ),
        ),
      ],
    );
  }

  Widget _buildAutoExtractedNote(BuildContext context) {
    return const SizedBox.shrink();
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildBindingRow(
    BuildContext context, {
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
    String? helpText,
  }) {
    final items = _buildPropertyItems(value);
    final labelWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        if (helpText != null) ...[
          const SizedBox(width: 6),
          Tooltip(
            message: helpText,
            child: Icon(
              Icons.help_outline,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useVertical = constraints.maxWidth < 520;
          final dropdown = DropdownButtonFormField<String>(
            initialValue: value,
            isExpanded: true,
            items: items.map((prop) {
              return DropdownMenuItem(
                value: prop.name,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        prop.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (prop.type.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        '(${prop.type})',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).disabledColor,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
            onChanged: (selected) => onChanged(selected ?? ''),
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
            ),
          );

          if (useVertical) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                labelWidget,
                const SizedBox(height: 8),
                dropdown,
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                flex: 3,
                child: labelWidget,
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 4,
                child: dropdown,
              ),
            ],
          );
        },
      ),
    );
  }

  List<NotionProperty> _buildPropertyItems(String currentValue) {
    final List<NotionProperty> items = [
      NotionProperty(name: '', type: ''),
      ...properties,
    ];

    final bool exists = items.any((p) => p.name == currentValue);
    if (currentValue.isNotEmpty && !exists) {
      items.add(NotionProperty(name: currentValue, type: 'unknown'));
    }

    return items;
  }
}
