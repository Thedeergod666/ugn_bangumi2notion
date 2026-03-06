import 'package:flutter/material.dart';

import '../../../../../core/theme/mapping_theme_extension.dart';
import '../../../providers/mapping_view_model.dart';

class MappingStatusFooter extends StatelessWidget {
  const MappingStatusFooter({
    super.key,
    required this.summary,
    required this.hasUnsavedChanges,
    required this.onReset,
    required this.onSave,
  });

  final MappingStatusSummaryVm summary;
  final bool hasUnsavedChanges;
  final VoidCallback onReset;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mappingExt = Theme.of(context).extension<MappingThemeExtension>();
    final panelColor =
        mappingExt?.panelColor ?? colorScheme.surfaceContainerLow;

    TextStyle styleFor(Color color) {
      return Theme.of(context).textTheme.bodySmall!.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: panelColor,
        border: Border(
          top: BorderSide(
            color: mappingExt?.panelBorderColor ?? colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '映射状态:',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                Text(' ${summary.configured} 已配置',
                    style:
                        styleFor(mappingExt?.configuredColor ?? Colors.green)),
                Text(' ${summary.unconfigured} 未配置',
                    style: styleFor(mappingExt?.warningColor ?? Colors.orange)),
                Text(' ${summary.error} 错误',
                    style: styleFor(mappingExt?.errorColor ?? Colors.red)),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: hasUnsavedChanges ? onReset : null,
            child: const Text('重置'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onSave,
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
