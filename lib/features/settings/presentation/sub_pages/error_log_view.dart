import 'package:flutter/material.dart';

import '../../../../core/utils/logging.dart';

class ErrorLogViewState {
  const ErrorLogViewState({required this.entries});

  final List<LogEntry> entries;
}

class ErrorLogView extends StatelessWidget {
  const ErrorLogView({
    super.key,
    required this.state,
  });

  final ErrorLogViewState state;

  @override
  Widget build(BuildContext context) {
    final entries = state.entries;
    return SelectionArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '共 ${entries.length} 条记录',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            _buildEmptyState(context)
          else
            ...entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildLogCard(context, entry),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: const Text('暂无错误日志'),
    );
  }

  Widget _buildLogCard(BuildContext context, LogEntry entry) {
    final colorScheme = Theme.of(context).colorScheme;
    final levelColor =
        entry.level == LogLevel.error ? colorScheme.error : colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: levelColor),
              const SizedBox(width: 8),
              Text(
                entry.level.name.toUpperCase(),
                style: TextStyle(
                  color: levelColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                entry.formattedTime,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            entry.message,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (entry.error != null) ...[
            const SizedBox(height: 6),
            SelectableText(
              'Error: ${entry.error}',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
          if (entry.stackTrace != null) ...[
            const SizedBox(height: 6),
            SelectableText(
              entry.stackTrace.toString(),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

