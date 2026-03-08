import 'package:flutter/material.dart';

import '../../../../../models/bangumi_models.dart';
import '../../../providers/batch_binding_ui_models.dart';

class BatchImportRightPane extends StatelessWidget {
  const BatchImportRightPane({
    super.key,
    required this.activeItem,
    required this.manualInputController,
    required this.isManualVerifying,
    required this.manualVerifiedId,
    required this.manualVerifiedDetail,
    required this.isBusy,
    required this.onOpenNotionDetail,
    required this.onBindSingle,
    required this.onSelectCandidate,
    required this.onOpenBangumiDetail,
    required this.onOpenBangumiExternal,
    required this.onManualInputChanged,
    required this.onVerifyManual,
    required this.onBindManual,
    required this.onToggleConflict,
  });

  final BatchUiItem? activeItem;
  final TextEditingController manualInputController;
  final bool isManualVerifying;
  final int? manualVerifiedId;
  final BangumiSubjectDetail? manualVerifiedDetail;
  final bool isBusy;
  final ValueChanged<BatchUiItem> onOpenNotionDetail;
  final void Function(BatchUiItem item, int bangumiId) onBindSingle;
  final void Function(BatchUiItem item, int bangumiId) onSelectCandidate;
  final ValueChanged<int> onOpenBangumiDetail;
  final ValueChanged<int> onOpenBangumiExternal;
  final ValueChanged<String> onManualInputChanged;
  final VoidCallback onVerifyManual;
  final VoidCallback onBindManual;
  final ValueChanged<String> onToggleConflict;

  @override
  Widget build(BuildContext context) {
    final item = activeItem;
    final colorScheme = Theme.of(context).colorScheme;
    if (item == null) {
      return Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Center(
          child: Text(
            '请选择左侧条目查看候选匹配',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Text(
                  '候选匹配',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => onOpenNotionDetail(item),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('打开 Notion 详情页'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: _CurrentNotionCard(item: item),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              children: [
                for (final match in item.scoredMatches)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CandidateCard(
                      item: item,
                      match: match,
                      selected: item.selectedMatchId == match.item.id,
                      recommended:
                          match.item.id == item.bestSimilarityMatch?.item.id,
                      busy: isBusy,
                      onBind: () => onBindSingle(item, match.item.id),
                      onSelect: () => onSelectCandidate(item, match.item.id),
                      onOpenDetail: () => onOpenBangumiDetail(match.item.id),
                      onOpenExternal: () =>
                          onOpenBangumiExternal(match.item.id),
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  '手动绑定',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: manualInputController,
                  onChanged: onManualInputChanged,
                  decoration: const InputDecoration(
                    hintText: '例如：15574 或 https://bgm.tv/subject/315574',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: isManualVerifying ? null : onVerifyManual,
                      child: isManualVerifying
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('校验'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: manualVerifiedId == null || isBusy
                          ? null
                          : onBindManual,
                      child: const Text('绑定该 ID'),
                    ),
                  ],
                ),
                if (manualVerifiedDetail != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _ManualPreviewCard(
                      detail: manualVerifiedDetail!,
                      verifiedId: manualVerifiedId!,
                    ),
                  ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: colorScheme.error,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '若候选不正确，建议先查看 Bangumi 条目再手动绑定。',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => onToggleConflict(item.pageId),
                        child: Text(
                          item.status == BatchItemStatus.conflict
                              ? '取消冲突'
                              : '标记冲突',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentNotionCard extends StatelessWidget {
  const _CurrentNotionCard({required this.item});

  final BatchUiItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusText = switch (item.status) {
      BatchItemStatus.pending => '当前未绑定',
      BatchItemStatus.bound => '已绑定',
      BatchItemStatus.conflict => '冲突',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(Icons.description_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Notion ID · ${item.notionId ?? item.pageId} · $statusText',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${item.bestSimilarity}%',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onPrimaryContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.item,
    required this.match,
    required this.selected,
    required this.recommended,
    required this.busy,
    required this.onBind,
    required this.onSelect,
    required this.onOpenDetail,
    required this.onOpenExternal,
  });

  final BatchUiItem item;
  final BatchScoredMatch match;
  final bool selected;
  final bool recommended;
  final bool busy;
  final VoidCallback onBind;
  final VoidCallback onSelect;
  final VoidCallback onOpenDetail;
  final VoidCallback onOpenExternal;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = selected
        ? colorScheme.primaryContainer.withValues(alpha: 0.42)
        : colorScheme.surface;
    final borderColor = selected
        ? colorScheme.primary
        : (recommended
            ? colorScheme.tertiary.withValues(alpha: 0.55)
            : colorScheme.outlineVariant);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: item.isBound || busy ? null : onSelect,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                image: match.item.imageUrl.trim().isEmpty
                    ? null
                    : DecorationImage(
                        image: NetworkImage(match.item.imageUrl),
                        fit: BoxFit.cover,
                      ),
              ),
              alignment: Alignment.center,
              child: match.item.imageUrl.trim().isEmpty
                  ? const Icon(Icons.image_outlined)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          match.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                      if (recommended && !selected) ...[
                        const SizedBox(width: 6),
                        _TinyChip(
                          text: '推荐项',
                          backgroundColor: colorScheme.tertiaryContainer
                              .withValues(alpha: 0.7),
                          textColor: colorScheme.onTertiaryContainer,
                        ),
                      ],
                      if (selected)
                        Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Bangumi ID · ${match.item.id} · ${match.year == 0 ? '-' : match.year}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _TinyChip(
                        text: match.item.score > 0
                            ? 'bgm ${match.item.score.toStringAsFixed(1)}'
                            : 'bgm -',
                        backgroundColor: Colors.amber.withValues(alpha: 0.2),
                        textColor: Colors.amber.shade800,
                      ),
                      _TinyChip(
                        text: matchLevelText(match.level),
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        textColor: colorScheme.onSurfaceVariant,
                      ),
                      _TinyChip(
                        text: '${match.similarity}%',
                        backgroundColor: colorScheme.primaryContainer,
                        textColor: colorScheme.onPrimaryContainer,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                FilledButton(
                  onPressed: item.isBound || busy
                      ? null
                      : (selected ? onBind : onSelect),
                  child: Text(selected ? '绑定已选' : '选中此项'),
                ),
                const SizedBox(height: 6),
                OutlinedButton(
                  onPressed: onOpenDetail,
                  child: const Text('查看 Bangumi'),
                ),
                IconButton(
                  onPressed: onOpenExternal,
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  tooltip: '浏览器打开',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualPreviewCard extends StatelessWidget {
  const _ManualPreviewCard({
    required this.detail,
    required this.verifiedId,
  });

  final BangumiSubjectDetail detail;
  final int verifiedId;

  @override
  Widget build(BuildContext context) {
    final title = detail.nameCn.trim().isNotEmpty ? detail.nameCn : detail.name;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: colorScheme.surfaceContainerHighest,
              image: detail.imageUrl.trim().isEmpty
                  ? null
                  : DecorationImage(
                      image: NetworkImage(detail.imageUrl),
                      fit: BoxFit.cover,
                    ),
            ),
            alignment: Alignment.center,
            child: detail.imageUrl.trim().isEmpty
                ? const Icon(Icons.image_not_supported_outlined)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bangumi ID · $verifiedId · ${detail.airDate.isEmpty ? '-' : detail.airDate}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 2),
                Text(
                  detail.score > 0
                      ? '评分 ${detail.score.toStringAsFixed(1)}'
                      : '评分 -',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TinyChip extends StatelessWidget {
  const _TinyChip({
    required this.text,
    required this.backgroundColor,
    required this.textColor,
  });

  final String text;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
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
