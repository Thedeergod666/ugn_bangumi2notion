import 'package:flutter/material.dart';

class EpisodeBadge extends StatelessWidget {
  const EpisodeBadge({
    super.key,
    required this.count,
  });

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    final text = count > 99 ? '99+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.error,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onError,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

