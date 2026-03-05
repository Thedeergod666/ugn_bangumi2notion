import 'package:flutter/material.dart';

import '../../../providers/batch_binding_ui_models.dart';

class BatchImportLeftPane extends StatelessWidget {
  const BatchImportLeftPane({
    super.key,
    required this.items,
    required this.activePageId,
    required this.sortMode,
    required this.selectedCount,
    required this.isBusy,
    required this.onSortChanged,
    required this.onSelectItem,
    required this.onToggleItemSelected,
    required this.onSkipSelected,
    required this.onBindSelected,
  });

  final List<BatchUiItem> items;
  final String? activePageId;
  final BatchSortMode sortMode;
  final int selectedCount;
  final bool isBusy;
  final ValueChanged<BatchSortMode> onSortChanged;
  final ValueChanged<String> onSelectItem;
  final ValueChanged<String> onToggleItemSelected;
  final VoidCallback onSkipSelected;
  final VoidCallback onBindSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Text(
                  'Notion 条目',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<BatchSortMode>(
                      value: sortMode,
                      isDense: true,
                      onChanged: (value) {
                        if (value == null) return;
                        onSortChanged(value);
                      },
                      items: const [
                        DropdownMenuItem(
                          value: BatchSortMode.similarity,
                          child: Text('相似度'),
                        ),
                        DropdownMenuItem(
                          value: BatchSortMode.score,
                          child: Text('评分'),
                        ),
                        DropdownMenuItem(
                          value: BatchSortMode.year,
                          child: Text('年份'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      '当前筛选条件下暂无条目',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(10),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final isActive = item.pageId == activePageId;
                      return _LeftItemCard(
                        item: item,
                        active: isActive,
                        onTap: () => onSelectItem(item.pageId),
                        onToggleSelection: () =>
                            onToggleItemSelected(item.pageId),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(
              children: [
                Text(
                  '已选择 $selectedCount 条',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed:
                      selectedCount == 0 || isBusy ? null : onSkipSelected,
                  child: const Text('跳过'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed:
                      selectedCount == 0 || isBusy ? null : onBindSelected,
                  child: const Text('绑定'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeftItemCard extends StatelessWidget {
  const _LeftItemCard({
    required this.item,
    required this.active,
    required this.onTap,
    required this.onToggleSelection,
  });

  final BatchUiItem item;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onToggleSelection;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final level = resolveMatchLevel(item.bestSimilarity);

    final statusText = switch (item.status) {
      BatchItemStatus.pending => '未绑定',
      BatchItemStatus.bound => '已绑定',
      BatchItemStatus.conflict => '冲突',
    };

    final statusColor = switch (item.status) {
      BatchItemStatus.pending => colorScheme.error,
      BatchItemStatus.bound => Colors.green,
      BatchItemStatus.conflict => Colors.orange,
    };

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: active
              ? colorScheme.primaryContainer.withValues(alpha: 0.35)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? colorScheme.primary : colorScheme.outlineVariant,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Checkbox(
                value: item.selected,
                onChanged: (_) => onToggleSelection(),
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Notion ID · ${item.notionId ?? item.pageId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _SmallChip(
                    text: '${item.bestSimilarity}%',
                    textColor: colorScheme.onPrimaryContainer,
                    backgroundColor: colorScheme.primaryContainer,
                  ),
                  const SizedBox(height: 6),
                  _SmallChip(
                    text: statusText,
                    textColor: statusColor,
                    backgroundColor: statusColor.withValues(alpha: 0.12),
                    borderColor: statusColor.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 6),
                  _SmallChip(
                    text: matchLevelText(level),
                    textColor: colorScheme.onSurfaceVariant,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({
    required this.text,
    required this.textColor,
    required this.backgroundColor,
    this.borderColor,
  });

  final String text;
  final Color textColor;
  final Color backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
