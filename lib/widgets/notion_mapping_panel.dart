import 'package:flutter/material.dart';
import '../models/mapping_config.dart';
import '../models/notion_models.dart';

class NotionMappingPanel extends StatelessWidget {
  final bool isLoading;
  final bool isConfigured;
  final List<NotionProperty> properties;
  final NotionDailyRecommendationBindings bindings;
  final ValueChanged<NotionDailyRecommendationBindings> onBindingsChanged;

  const NotionMappingPanel({
    super.key,
    required this.isLoading,
    required this.isConfigured,
    required this.properties,
    required this.bindings,
    required this.onBindingsChanged,
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
        const SizedBox(height: 8),
        _buildBindingRow(
          context,
          label: '标题 (title)',
          value: bindings.title,
          onChanged: (value) => onBindingsChanged(
            bindings.copyWith(title: value),
          ),
        ),
        _buildBindingRow(
          context,
          label: '评分 (yougnScore)',
          value: bindings.yougnScore,
          onChanged: (value) => onBindingsChanged(
            bindings.copyWith(yougnScore: value),
          ),
        ),
        _buildBindingRow(
          context,
          label: '放送日期 (airDate)',
          value: bindings.airDate,
          onChanged: (value) => onBindingsChanged(
            bindings.copyWith(airDate: value),
          ),
        ),
        _buildBindingRow(
          context,
          label: '标签 (tags)',
          value: bindings.tags,
          onChanged: (value) => onBindingsChanged(
            bindings.copyWith(tags: value),
          ),
        ),
        _buildBindingRow(
          context,
          label: '类型 (type)',
          value: bindings.type,
          onChanged: (value) => onBindingsChanged(
            bindings.copyWith(type: value),
          ),
        ),
        _buildBindingRow(
          context,
          label: '短评 (shortReview)',
          value: bindings.shortReview,
          onChanged: (value) => onBindingsChanged(
            bindings.copyWith(shortReview: value),
          ),
        ),
        _buildAutoExtractedNote(context),
        _buildBindingRow(
          context,
          label: 'Bangumi ID (bangumiId)',
          value: bindings.bangumiId ?? '',
          onChanged: (value) => onBindingsChanged(
            bindings.copyWith(bangumiId: value.isEmpty ? null : value),
          ),
        ),
        _buildBindingRow(
          context,
          label: 'Subject ID (subjectId)',
          value: bindings.subjectId ?? '',
          onChanged: (value) => onBindingsChanged(
            bindings.copyWith(subjectId: value.isEmpty ? null : value),
          ),
        ),
      ],
    );
  }

  Widget _buildAutoExtractedNote(BuildContext context) {
    return const SizedBox.shrink();
  }

  Widget _buildBindingRow(
    BuildContext context, {
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    final items = _buildPropertyItems(value);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useVertical = constraints.maxWidth < 520;
          final dropdown = DropdownButtonFormField<String>(
            initialValue: value,
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
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                dropdown,
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
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
