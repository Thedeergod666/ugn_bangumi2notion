import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/logging.dart';
import '../widgets/navigation_shell.dart';

class ErrorLogPage extends StatelessWidget {
  const ErrorLogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logger = context.watch<Logger>();
    final entries =
        logger.entriesForLevel(LogLevel.error).toList().reversed.toList();
    final canCopy = entries.isNotEmpty;

    return NavigationShell(
      title: '错误日志',
      selectedRoute: '/settings',
      onBack: () => Navigator.of(context).pop(),
      actions: [
        IconButton(
          tooltip: '一键复制',
          onPressed: canCopy
              ? () {
                  final payload = logger.exportText(level: LogLevel.error);
                  Clipboard.setData(ClipboardData(text: payload));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('错误日志已复制')),
                  );
                }
              : null,
          icon: const Icon(Icons.copy_all),
        ),
        IconButton(
          tooltip: '清空',
          onPressed: entries.isNotEmpty
              ? () {
                  logger.clear();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已清空错误日志')),
                  );
                }
              : null,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
      child: SelectionArea(
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
              ...entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildLogCard(context, entry),
                  )),
          ],
        ),
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
