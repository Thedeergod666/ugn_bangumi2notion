import 'package:flutter/material.dart';

import '../../../../../core/theme/mapping_theme_extension.dart';
import '../../../../../models/mapping_schema.dart';
import '../../../../../models/notion_models.dart';
import '../../../providers/mapping_view_model.dart';
import 'mapping_row_editor.dart';

class MappingTableDesktop extends StatelessWidget {
  const MappingTableDesktop({
    super.key,
    required this.model,
    required this.rows,
    required this.onPropertyChanged,
    required this.onParamChanged,
  });

  final MappingViewModel model;
  final List<MappingRowVm> rows;
  final void Function(MappingSlotKey slot, String value) onPropertyChanged;
  final void Function(MappingSlotKey slot, String value) onParamChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mappingExt = Theme.of(context).extension<MappingThemeExtension>();
    final panelRadius = mappingExt?.panelRadius ?? 12;
    final borderColor =
        mappingExt?.panelBorderColor ?? colorScheme.outlineVariant;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(panelRadius),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: (mappingExt?.tableHeaderColor ??
                      colorScheme.surfaceContainerHighest)
                  .withValues(alpha: mappingExt?.tableHeaderOpacity ?? 1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(panelRadius),
                topRight: Radius.circular(panelRadius),
              ),
            ),
            child: const Row(
              children: [
                Expanded(flex: 20, child: Text('Bangumi 属性')),
                Expanded(flex: 12, child: Text('属性类型')),
                Expanded(flex: 4, child: Center(child: Text('→'))),
                Expanded(flex: 30, child: Text('Notion 属性名称')),
                Expanded(flex: 16, child: Text('Notion 属性类型')),
                Expanded(flex: 22, child: Text('使用位置')),
                Expanded(
                    flex: 10,
                    child: Align(
                        alignment: Alignment.centerRight, child: Text('状态'))),
              ],
            ),
          ),
          for (final entry in rows.asMap().entries)
            _DesktopRow(
              row: entry.value,
              index: entry.key,
              options: model.optionsForSlot(entry.value.slot),
              onPropertyChanged: (value) =>
                  onPropertyChanged(entry.value.slot, value),
              onParamChanged: (value) =>
                  onParamChanged(entry.value.slot, value),
            ),
        ],
      ),
    );
  }
}

class _DesktopRow extends StatelessWidget {
  const _DesktopRow({
    required this.row,
    required this.index,
    required this.options,
    required this.onPropertyChanged,
    required this.onParamChanged,
  });

  final MappingRowVm row;
  final int index;
  final List<NotionProperty> options;
  final ValueChanged<String> onPropertyChanged;
  final ValueChanged<String> onParamChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mappingExt = Theme.of(context).extension<MappingThemeExtension>();
    final rowColor = index.isEven
        ? mappingExt?.tableRowEvenColor ?? colorScheme.surfaceContainerLowest
        : mappingExt?.tableRowOddColor ?? colorScheme.surfaceContainerLow;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: rowColor,
        border: Border(
          top: BorderSide(
            color: mappingExt?.panelBorderColor ?? colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 20,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    row.label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (row.isRequired) ...[
                  const SizedBox(width: 8),
                  _requiredBadge(context),
                ],
              ],
            ),
          ),
          Expanded(
            flex: 12,
            child: _typeBadge(context, row.sourceTypeTag),
          ),
          const Expanded(
            flex: 4,
            child: Center(
              child: Icon(Icons.arrow_forward, size: 16),
            ),
          ),
          Expanded(
            flex: 30,
            child: MappingRowEditor(
              row: row,
              options: options,
              onPropertyChanged: onPropertyChanged,
              onParamChanged: onParamChanged,
              dense: true,
            ),
          ),
          Expanded(
            flex: 16,
            child: _typeBadge(
              context,
              row.notionPropertyType.isEmpty ? '—' : row.notionPropertyType,
            ),
          ),
          Expanded(
            flex: 22,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    row.usageText.isEmpty ? '—' : row.usageText,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Tooltip(
                  message: row.helpText,
                  child: Icon(
                    Icons.help_outline,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 10,
            child: Align(
              alignment: Alignment.centerRight,
              child: _statusBadge(context, row.status),
            ),
          ),
        ],
      ),
    );
  }

  Widget _requiredBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
    );
  }

  Widget _typeBadge(BuildContext context, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall,
        overflow: TextOverflow.ellipsis,
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
      MappingRowStatus.configured => '✓ 已配',
      MappingRowStatus.unconfigured => '未配置',
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
