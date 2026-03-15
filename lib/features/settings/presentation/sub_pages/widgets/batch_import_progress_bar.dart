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
    final textTheme = Theme.of(context).textTheme;
    final total = pendingCount + completedCount;
    final progress = total == 0 ? 0.0 : completedCount / total;

    Widget buildCounterRow() {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('待处理', style: textTheme.bodySmall),
          const SizedBox(width: 6),
          Text(
            '$pendingCount',
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          Text('/ 已完成', style: textTheme.bodySmall),
          const SizedBox(width: 6),
          Text(
            '$completedCount',
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            ),
          ),
        ],
      );
    }

    Widget buildProgressBar() {
      return ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 8,
          backgroundColor: colorScheme.surfaceContainerHighest,
        ),
      );
    }

    final helperText = Text(
      '当前仅扫描最近 30 条未绑定条目：左侧选条目 -> 右侧点候选绑定',
      style: textTheme.bodySmall?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 680;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildCounterRow(),
                    const SizedBox(height: 10),
                    buildProgressBar(),
                    const SizedBox(height: 10),
                    helperText,
                  ],
                )
              : Row(
                  children: [
                    buildCounterRow(),
                    const SizedBox(width: 18),
                    Expanded(child: buildProgressBar()),
                    const SizedBox(width: 16),
                    Flexible(child: helperText),
                  ],
                ),
        );
      },
    );
  }
}
