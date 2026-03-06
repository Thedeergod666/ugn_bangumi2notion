import 'package:flutter/material.dart';
import 'dart:ui' show lerpDouble;

@immutable
class MappingThemeExtension extends ThemeExtension<MappingThemeExtension> {
  const MappingThemeExtension({
    required this.pageBgTop,
    required this.pageBgBottom,
    required this.panelColor,
    required this.panelBorderColor,
    required this.tableHeaderColor,
    required this.tableRowEvenColor,
    required this.tableRowOddColor,
    required this.tableHeaderOpacity,
    required this.configuredColor,
    required this.warningColor,
    required this.errorColor,
    required this.statusChipBgAlpha,
    required this.panelRadius,
    required this.rowRadius,
    required this.elevationShadowOpacity,
  });

  final Color pageBgTop;
  final Color pageBgBottom;
  final Color panelColor;
  final Color panelBorderColor;
  final Color tableHeaderColor;
  final Color tableRowEvenColor;
  final Color tableRowOddColor;
  final double tableHeaderOpacity;
  final Color configuredColor;
  final Color warningColor;
  final Color errorColor;
  final double statusChipBgAlpha;
  final double panelRadius;
  final double rowRadius;
  final double elevationShadowOpacity;

  factory MappingThemeExtension.fromScheme(ColorScheme scheme) {
    return MappingThemeExtension(
      pageBgTop:
          Color.lerp(scheme.surface, scheme.primary, 0.12) ?? scheme.surface,
      pageBgBottom:
          Color.lerp(scheme.surface, scheme.surfaceContainerLowest, 0.85) ??
              scheme.surface,
      panelColor: scheme.surfaceContainerLow,
      panelBorderColor: scheme.outlineVariant.withValues(alpha: 0.75),
      tableHeaderColor:
          Color.lerp(scheme.surfaceContainer, scheme.primary, 0.14) ??
              scheme.surfaceContainer,
      tableRowEvenColor:
          Color.lerp(scheme.surfaceContainerLowest, scheme.primary, 0.06) ??
              scheme.surfaceContainerLowest,
      tableRowOddColor:
          Color.lerp(scheme.surfaceContainerLow, scheme.primary, 0.08) ??
              scheme.surfaceContainerLow,
      tableHeaderOpacity: 0.96,
      configuredColor: const Color(0xFF00B879),
      warningColor: const Color(0xFFE2A700),
      errorColor: const Color(0xFFE05353),
      statusChipBgAlpha: 0.16,
      panelRadius: 14,
      rowRadius: 10,
      elevationShadowOpacity: 0.18,
    );
  }

  @override
  MappingThemeExtension copyWith({
    Color? pageBgTop,
    Color? pageBgBottom,
    Color? panelColor,
    Color? panelBorderColor,
    Color? tableHeaderColor,
    Color? tableRowEvenColor,
    Color? tableRowOddColor,
    double? tableHeaderOpacity,
    Color? configuredColor,
    Color? warningColor,
    Color? errorColor,
    double? statusChipBgAlpha,
    double? panelRadius,
    double? rowRadius,
    double? elevationShadowOpacity,
  }) {
    return MappingThemeExtension(
      pageBgTop: pageBgTop ?? this.pageBgTop,
      pageBgBottom: pageBgBottom ?? this.pageBgBottom,
      panelColor: panelColor ?? this.panelColor,
      panelBorderColor: panelBorderColor ?? this.panelBorderColor,
      tableHeaderColor: tableHeaderColor ?? this.tableHeaderColor,
      tableRowEvenColor: tableRowEvenColor ?? this.tableRowEvenColor,
      tableRowOddColor: tableRowOddColor ?? this.tableRowOddColor,
      tableHeaderOpacity: tableHeaderOpacity ?? this.tableHeaderOpacity,
      configuredColor: configuredColor ?? this.configuredColor,
      warningColor: warningColor ?? this.warningColor,
      errorColor: errorColor ?? this.errorColor,
      statusChipBgAlpha: statusChipBgAlpha ?? this.statusChipBgAlpha,
      panelRadius: panelRadius ?? this.panelRadius,
      rowRadius: rowRadius ?? this.rowRadius,
      elevationShadowOpacity:
          elevationShadowOpacity ?? this.elevationShadowOpacity,
    );
  }

  @override
  MappingThemeExtension lerp(
    covariant ThemeExtension<MappingThemeExtension>? other,
    double t,
  ) {
    if (other is! MappingThemeExtension) return this;
    return MappingThemeExtension(
      pageBgTop: Color.lerp(pageBgTop, other.pageBgTop, t) ?? pageBgTop,
      pageBgBottom:
          Color.lerp(pageBgBottom, other.pageBgBottom, t) ?? pageBgBottom,
      panelColor: Color.lerp(panelColor, other.panelColor, t) ?? panelColor,
      panelBorderColor:
          Color.lerp(panelBorderColor, other.panelBorderColor, t) ??
              panelBorderColor,
      tableHeaderColor:
          Color.lerp(tableHeaderColor, other.tableHeaderColor, t) ??
              tableHeaderColor,
      tableRowEvenColor:
          Color.lerp(tableRowEvenColor, other.tableRowEvenColor, t) ??
              tableRowEvenColor,
      tableRowOddColor:
          Color.lerp(tableRowOddColor, other.tableRowOddColor, t) ??
              tableRowOddColor,
      tableHeaderOpacity:
          lerpDouble(tableHeaderOpacity, other.tableHeaderOpacity, t) ??
              tableHeaderOpacity,
      configuredColor: Color.lerp(configuredColor, other.configuredColor, t) ??
          configuredColor,
      warningColor:
          Color.lerp(warningColor, other.warningColor, t) ?? warningColor,
      errorColor: Color.lerp(errorColor, other.errorColor, t) ?? errorColor,
      statusChipBgAlpha:
          lerpDouble(statusChipBgAlpha, other.statusChipBgAlpha, t) ??
              statusChipBgAlpha,
      panelRadius: lerpDouble(panelRadius, other.panelRadius, t) ?? panelRadius,
      rowRadius: lerpDouble(rowRadius, other.rowRadius, t) ?? rowRadius,
      elevationShadowOpacity:
          lerpDouble(elevationShadowOpacity, other.elevationShadowOpacity, t) ??
              elevationShadowOpacity,
    );
  }
}
