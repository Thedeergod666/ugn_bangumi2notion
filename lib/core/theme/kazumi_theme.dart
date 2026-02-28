import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemeSeed {
  const ThemeSeed({
    required this.id,
    required this.label,
    required this.color,
  });

  final String id;
  final String label;
  final Color color;
}

class KazumiTheme {
  static const double _radius = 18;
  static const double _cardRadius = 20;

  static const List<ThemeSeed> seeds = [
    ThemeSeed(id: 'default', label: '默认', color: Color(0xFF5ABF9B)),
    ThemeSeed(id: 'teal', label: '青色', color: Color(0xFF4DB6AC)),
    ThemeSeed(id: 'blue', label: '蓝色', color: Color(0xFF4A90E2)),
    ThemeSeed(id: 'indigo', label: '靛蓝色', color: Color(0xFF5C6BC0)),
    ThemeSeed(id: 'purple', label: '紫罗兰色', color: Color(0xFF8E7CCF)),
    ThemeSeed(id: 'pink', label: '粉红色', color: Color(0xFFE573B9)),
    ThemeSeed(id: 'yellow', label: '黄色', color: Color(0xFFF6C453)),
    ThemeSeed(id: 'orange', label: '橙色', color: Color(0xFFF39C5E)),
    ThemeSeed(id: 'deepOrange', label: '深橙色', color: Color(0xFFE66A2E)),
  ];

  static ThemeSeed seedForId(String id) {
    return seeds.firstWhere(
      (seed) => seed.id == id,
      orElse: () => seeds.first,
    );
  }

  static ThemeData light({
    required ColorScheme scheme,
    bool useSystemFont = false,
  }) {
    final textTheme =
        _buildTextTheme(scheme, Brightness.light, useSystemFont);
    return _buildTheme(scheme, textTheme);
  }

  static ThemeData dark({
    required ColorScheme scheme,
    bool useSystemFont = false,
  }) {
    final textTheme =
        _buildTextTheme(scheme, Brightness.dark, useSystemFont);
    return _buildTheme(scheme, textTheme);
  }

  static ColorScheme buildScheme({
    required Brightness brightness,
    required Color seedColor,
    bool oledOptimization = false,
    ColorScheme? dynamicScheme,
  }) {
    final baseScheme = dynamicScheme ??
        ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: brightness,
        );
    if (brightness == Brightness.dark && oledOptimization) {
      return _applyOled(baseScheme);
    }
    return baseScheme;
  }

  static TextTheme _buildTextTheme(
    ColorScheme scheme,
    Brightness brightness,
    bool useSystemFont,
  ) {
    final baseTextTheme = useSystemFont
        ? (brightness == Brightness.dark
            ? ThemeData.dark().textTheme
            : ThemeData.light().textTheme)
        : GoogleFonts.notoSansScTextTheme(
            brightness == Brightness.dark
                ? ThemeData.dark().textTheme
                : ThemeData.light().textTheme,
          );
    final textTheme = baseTextTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    return _tweakTextTheme(textTheme);
  }

  static ThemeData _buildTheme(ColorScheme scheme, TextTheme textTheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLowest,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cardRadius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: scheme.error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: scheme.primaryContainer,
        labelStyle: textTheme.labelLarge,
        secondaryLabelStyle:
            textTheme.labelLarge?.copyWith(color: scheme.onPrimaryContainer),
        shape: StadiumBorder(
          side: BorderSide(color: scheme.outlineVariant),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          side: BorderSide(color: scheme.outlineVariant),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const StadiumBorder(),
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.primary),
        selectedLabelTextStyle:
            textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        unselectedLabelTextStyle:
            textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        contentTextStyle:
            textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
    );
  }

  static TextTheme _tweakTextTheme(TextTheme textTheme) {
    return textTheme.copyWith(
      titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  static ColorScheme _applyOled(ColorScheme scheme) {
    return scheme.copyWith(
      surface: Colors.black,
      surfaceContainerLowest: Colors.black,
      surfaceContainerLow: const Color(0xFF0A0A0A),
      surfaceContainer: const Color(0xFF121212),
      surfaceContainerHigh: const Color(0xFF161616),
      surfaceContainerHighest: const Color(0xFF1A1A1A),
      onSurface: Colors.white,
      onSurfaceVariant: const Color(0xFFC9C9C9),
      outline: const Color(0xFF2A2A2A),
      outlineVariant: const Color(0xFF242424),
    );
  }
}
