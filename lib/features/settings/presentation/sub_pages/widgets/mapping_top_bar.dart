import 'package:flutter/material.dart';

import '../../../../../core/theme/mapping_theme_extension.dart';
import '../../../providers/mapping_view_model.dart';

class MappingTopBar extends StatelessWidget {
  const MappingTopBar({
    super.key,
    required this.model,
    required this.onBack,
    required this.onApplyMagicMap,
  });

  final MappingViewModel model;
  final VoidCallback onBack;
  final VoidCallback onApplyMagicMap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mappingExt = Theme.of(context).extension<MappingThemeExtension>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: mappingExt?.tableRowOddColor ??
                      colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: mappingExt?.panelBorderColor ??
                        colorScheme.outlineVariant,
                  ),
                ),
                child: const Icon(Icons.arrow_back, size: 18),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '设置',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(width: 6),
            Text(
              '/',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(width: 6),
            Text(
              '数据映射',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: model.isConfigured ? onApplyMagicMap : null,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('推荐配置'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: (mappingExt?.tableHeaderColor ?? colorScheme.primary)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: mappingExt?.panelBorderColor ?? colorScheme.outlineVariant,
            ),
          ),
          child: Text(
            model.statusSummary.error > 0
                ? '当前存在 ${model.statusSummary.error} 个错误映射，请修复后保存。'
                : '映射校验通过，可直接保存。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: model.statusSummary.error > 0
                      ? mappingExt?.errorColor
                      : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }
}
