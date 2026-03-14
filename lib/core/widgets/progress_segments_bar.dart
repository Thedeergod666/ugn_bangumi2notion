import 'dart:math';

import 'package:flutter/material.dart';

class ProgressSegmentsBar extends StatelessWidget {
  const ProgressSegmentsBar({
    super.key,
    required this.watched,
    required this.updated,
    required this.total,
    this.showWatched = true,
    this.height = 6,
    this.watchedColor,
    this.updatedColor,
    this.remainingColor,
  });

  final int watched;
  final int updated;
  final int total;
  final bool showWatched;
  final double height;
  final Color? watchedColor;
  final Color? updatedColor;
  final Color? remainingColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final totalSafe = total > 0 ? total : max(1, max(watched, updated));
    final watchedSafe = watched.clamp(0, totalSafe);
    final updatedSafe = updated.clamp(0, totalSafe);
    final watchedSegment = showWatched ? watchedSafe : 0;
    final updatedSegment =
        showWatched ? max(0, updatedSafe - watchedSafe) : updatedSafe;
    final remainingSegment = max(
      0,
      totalSafe - (showWatched ? updatedSafe : updatedSafe),
    );

    final resolvedWatchedColor = watchedColor ?? colorScheme.primary;
    final resolvedUpdatedColor = updatedColor ??
        Color.lerp(colorScheme.primary, colorScheme.surface, 0.4) ??
        colorScheme.primaryContainer;
    final resolvedRemainingColor = remainingColor ??
        Color.lerp(colorScheme.primary, colorScheme.surface, 0.7) ??
        colorScheme.surfaceContainerHighest;

    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            if (watchedSegment > 0)
              Expanded(
                flex: watchedSegment,
                child: Container(color: resolvedWatchedColor),
              ),
            if (updatedSegment > 0)
              Expanded(
                flex: updatedSegment,
                child: Container(color: resolvedUpdatedColor),
              ),
            if (remainingSegment > 0)
              Expanded(
                flex: remainingSegment,
                child: Container(color: resolvedRemainingColor),
              ),
          ],
        ),
      ),
    );
  }
}
