import 'package:flutter/material.dart';

import '../../../../../models/notion_models.dart';
import '../../../providers/mapping_view_model.dart';

class MappingRowEditor extends StatelessWidget {
  const MappingRowEditor({
    super.key,
    required this.row,
    required this.options,
    required this.onPropertyChanged,
    required this.onParamChanged,
    this.dense = false,
  });

  final MappingRowVm row;
  final List<NotionProperty> options;
  final ValueChanged<String> onPropertyChanged;
  final ValueChanged<String> onParamChanged;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    if (row.isParamSlot) {
      return TextFormField(
        key: ValueKey('param-${row.slot.name}-${row.notionPropertyName}'),
        initialValue: row.notionPropertyName,
        decoration: InputDecoration(
          isDense: dense,
          hintText: '输入参数值',
        ),
        onChanged: onParamChanged,
      );
    }

    final current = row.notionPropertyName.trim();
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: current.isEmpty ? null : current,
      decoration: InputDecoration(
        isDense: dense,
        hintText: '选择 Notion 属性...',
      ),
      items: options.map((item) {
        final name = item.name.trim().isEmpty ? '未选择' : item.name;
        final type = item.type.trim();
        return DropdownMenuItem<String>(
          value: item.name,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (type.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  type,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ],
          ),
        );
      }).toList(),
      onChanged: (value) => onPropertyChanged(value ?? ''),
    );
  }
}
