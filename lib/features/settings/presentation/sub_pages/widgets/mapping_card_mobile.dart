import 'package:flutter/material.dart';

import '../../../../../core/theme/mapping_theme_extension.dart';
import '../../../../../models/notion_models.dart';
import '../../../providers/mapping_view_model.dart';
import 'mapping_row_editor.dart';

class MappingCardMobile extends StatelessWidget {
  const MappingCardMobile({
    super.key,
    required this.row,
    required this.options,
    required this.onPropertyChanged,
    required this.onParamChanged,
  });

  final MappingRowVm row;
  final List<NotionProperty> options;
  final ValueChanged<String> onPropertyChanged;
  final ValueChanged<String> onParamChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mappingExt = Theme.of(context).extension<MappingThemeExtension>();
    final panelColor =
        mappingExt?.tableRowEvenColor ?? colorScheme.surfaceContainerLow;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(mappingExt?.rowRadius ?? 10),
        border: Border.all(
          color: mappingExt?.panelBorderColor ?? colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        row.label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (row.isRequired) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '必填',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _statusBadge(context, row.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Bangumi 类型: ${row.sourceTypeTag}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Notion 属性名称',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          MappingRowEditor(
            row: row,
            options: options,
            onPropertyChanged: onPropertyChanged,
            onParamChanged: onParamChanged,
            dense: true,
          ),
          const SizedBox(height: 8),
          Text(
            'Notion 属性类型: ${row.notionPropertyType.isEmpty ? '—' : row.notionPropertyType}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            '使用位置: ${row.usageText.isEmpty ? '—' : row.usageText}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(BuildContext context, MappingRowStatus status) {
    final mappingExt = Theme.of(context).extension<MappingThemeExtension>();
    final color = switch (status) {
      MappingRowStatus.configured =>
        mappingExt?.configuredColor ?? Colors.green,
      MappingRowStatus.unconfigured =>
        mappingExt?.warningColor ?? Colors.orange,
      MappingRowStatus.error => mappingExt?.errorColor ?? Colors.red,
    };
    final text = switch (status) {
      MappingRowStatus.configured => '已配',
      MappingRowStatus.unconfigured => '未配',
      MappingRowStatus.error => '错误',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: mappingExt?.statusChipBgAlpha ?? 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
