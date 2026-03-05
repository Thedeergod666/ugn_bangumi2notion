import 'package:flutter/material.dart';

class BatchImportTopActions extends StatelessWidget {
  const BatchImportTopActions({
    super.key,
    required this.searchController,
    required this.onlyUnbound,
    required this.onSearchChanged,
    required this.onOnlyUnboundChanged,
    required this.onOneClickBind,
    required this.isBinding,
  });

  final TextEditingController searchController;
  final bool onlyUnbound;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<bool> onOnlyUnboundChanged;
  final VoidCallback onOneClickBind;
  final bool isBinding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              hintText: '搜索 Notion 标题 / Bangumi ID',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 12),
        FilterChip(
          selected: onlyUnbound,
          onSelected: onOnlyUnboundChanged,
          label: const Text('仅未绑定'),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: isBinding ? null : onOneClickBind,
          icon: isBinding
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.flash_on_outlined),
          label: const Text('批量一键绑定'),
          style: FilledButton.styleFrom(
            foregroundColor: colorScheme.onPrimary,
            backgroundColor: colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
