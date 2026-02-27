import 'package:flutter/material.dart';

class ViewModeToggle extends StatelessWidget {
  const ViewModeToggle({
    super.key,
    required this.mode,
    required this.onChanged,
    this.listLabel = '列表',
    this.galleryLabel = '画廊',
    this.compact = false,
  });

  final String mode;
  final ValueChanged<String> onChanged;
  final String listLabel;
  final String galleryLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final selected = mode == 'gallery' ? 'gallery' : 'list';
    return SegmentedButton<String>(
      segments: [
        ButtonSegment(
          value: 'list',
          label: compact ? const SizedBox.shrink() : Text(listLabel),
          icon: const Icon(Icons.view_list_rounded),
        ),
        ButtonSegment(
          value: 'gallery',
          label: compact ? const SizedBox.shrink() : Text(galleryLabel),
          icon: const Icon(Icons.grid_view_rounded),
        ),
      ],
      selected: {selected},
      showSelectedIcon: false,
      onSelectionChanged: (values) {
        if (values.isEmpty) return;
        onChanged(values.first);
      },
    );
  }
}

