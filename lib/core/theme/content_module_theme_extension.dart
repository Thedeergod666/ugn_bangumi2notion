import 'package:flutter/material.dart';

@immutable
class ContentModuleThemeExtension
    extends ThemeExtension<ContentModuleThemeExtension> {
  const ContentModuleThemeExtension({
    required this.containerColor,
    required this.borderColor,
    required this.hoverBorderColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.badgeColor,
    required this.badgeTextColor,
    required this.progressWatchedColor,
    required this.progressUpdatedColor,
    required this.progressRemainingColor,
  });

  final Color containerColor;
  final Color borderColor;
  final Color hoverBorderColor;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final Color badgeColor;
  final Color badgeTextColor;
  final Color progressWatchedColor;
  final Color progressUpdatedColor;
  final Color progressRemainingColor;

  factory ContentModuleThemeExtension.fromScheme(ColorScheme scheme) {
    final container =
        Color.lerp(scheme.surfaceContainerLow, scheme.primary, 0.08) ??
            scheme.surfaceContainerLow;
    final border = Color.lerp(scheme.outlineVariant, scheme.primary, 0.18) ??
        scheme.outlineVariant;
    final hoverBorder =
        Color.lerp(scheme.outlineVariant, scheme.primary, 0.55) ??
            scheme.primary;
    final secondary =
        Color.lerp(scheme.onSurfaceVariant, scheme.outline, 0.2) ??
            scheme.onSurfaceVariant;
    final badge =
        Color.lerp(scheme.error, scheme.tertiary, 0.18) ?? scheme.error;
    final badgeText = scheme.brightness == Brightness.dark
        ? const Color(0xFF2A1413)
        : scheme.onError;
    final watched =
        Color.lerp(scheme.primary, scheme.tertiary, 0.12) ?? scheme.primary;
    final updated = Color.lerp(scheme.primary, scheme.surface, 0.32) ??
        scheme.primaryContainer;
    final remaining = Color.lerp(scheme.primary, scheme.surface, 0.74) ??
        scheme.surfaceContainerHighest;

    return ContentModuleThemeExtension(
      containerColor: container,
      borderColor: border,
      hoverBorderColor: hoverBorder,
      primaryTextColor: scheme.onSurface,
      secondaryTextColor: secondary,
      badgeColor: badge,
      badgeTextColor: badgeText,
      progressWatchedColor: watched,
      progressUpdatedColor: updated,
      progressRemainingColor: remaining,
    );
  }

  @override
  ContentModuleThemeExtension copyWith({
    Color? containerColor,
    Color? borderColor,
    Color? hoverBorderColor,
    Color? primaryTextColor,
    Color? secondaryTextColor,
    Color? badgeColor,
    Color? badgeTextColor,
    Color? progressWatchedColor,
    Color? progressUpdatedColor,
    Color? progressRemainingColor,
  }) {
    return ContentModuleThemeExtension(
      containerColor: containerColor ?? this.containerColor,
      borderColor: borderColor ?? this.borderColor,
      hoverBorderColor: hoverBorderColor ?? this.hoverBorderColor,
      primaryTextColor: primaryTextColor ?? this.primaryTextColor,
      secondaryTextColor: secondaryTextColor ?? this.secondaryTextColor,
      badgeColor: badgeColor ?? this.badgeColor,
      badgeTextColor: badgeTextColor ?? this.badgeTextColor,
      progressWatchedColor: progressWatchedColor ?? this.progressWatchedColor,
      progressUpdatedColor: progressUpdatedColor ?? this.progressUpdatedColor,
      progressRemainingColor:
          progressRemainingColor ?? this.progressRemainingColor,
    );
  }

  @override
  ContentModuleThemeExtension lerp(
    covariant ThemeExtension<ContentModuleThemeExtension>? other,
    double t,
  ) {
    if (other is! ContentModuleThemeExtension) return this;
    return ContentModuleThemeExtension(
      containerColor:
          Color.lerp(containerColor, other.containerColor, t) ?? containerColor,
      borderColor: Color.lerp(borderColor, other.borderColor, t) ?? borderColor,
      hoverBorderColor:
          Color.lerp(hoverBorderColor, other.hoverBorderColor, t) ??
              hoverBorderColor,
      primaryTextColor:
          Color.lerp(primaryTextColor, other.primaryTextColor, t) ??
              primaryTextColor,
      secondaryTextColor:
          Color.lerp(secondaryTextColor, other.secondaryTextColor, t) ??
              secondaryTextColor,
      badgeColor: Color.lerp(badgeColor, other.badgeColor, t) ?? badgeColor,
      badgeTextColor:
          Color.lerp(badgeTextColor, other.badgeTextColor, t) ?? badgeTextColor,
      progressWatchedColor:
          Color.lerp(progressWatchedColor, other.progressWatchedColor, t) ??
              progressWatchedColor,
      progressUpdatedColor:
          Color.lerp(progressUpdatedColor, other.progressUpdatedColor, t) ??
              progressUpdatedColor,
      progressRemainingColor:
          Color.lerp(progressRemainingColor, other.progressRemainingColor, t) ??
              progressRemainingColor,
    );
  }
}
