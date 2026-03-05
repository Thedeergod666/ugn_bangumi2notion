import 'package:flutter/material.dart';

class BatchImportProgressBar extends StatelessWidget {
  const BatchImportProgressBar({
    super.key,
    required this.pendingCount,
    required this.completedCount,
  });

  final int pendingCount;
  final int completedCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final total = pendingCount + completedCount;
    final progress = total == 0 ? 0.0 : completedCount / total;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Text('待处理', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 6),
          Text(
            '$pendingCount',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(width: 12),
          Text('/ 已完成', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 6),
          Text(
            '$completedCount',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '建议流程：左侧选条目 → 右侧点候选绑定',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
