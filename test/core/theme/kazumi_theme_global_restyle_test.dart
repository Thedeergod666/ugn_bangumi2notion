import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_utools/core/theme/kazumi_theme.dart';
import 'package:flutter_utools/core/theme/content_module_theme_extension.dart';
import 'package:flutter_utools/core/theme/mapping_theme_extension.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('KazumiTheme injects mapping extension and global container restyle',
      () {
    final darkScheme = KazumiTheme.buildScheme(
      brightness: Brightness.dark,
      seedColor: const Color(0xFF4A90E2),
    );
    final darkTheme = KazumiTheme.dark(
      scheme: darkScheme,
      useSystemFont: true,
    );

    final ext = darkTheme.extension<MappingThemeExtension>();
    expect(ext, isNotNull);
    expect(ext!.tableHeaderOpacity, greaterThan(0));
    expect(darkTheme.cardTheme.shape, isNotNull);
    expect(darkTheme.inputDecorationTheme.filled, isTrue);
  });

  test('Mapping theme extension keeps distinct status colors', () {
    final lightScheme = KazumiTheme.buildScheme(
      brightness: Brightness.light,
      seedColor: const Color(0xFF5ABF9B),
    );
    final theme = KazumiTheme.light(
      scheme: lightScheme,
      useSystemFont: true,
    );

    final ext = theme.extension<MappingThemeExtension>();
    expect(ext, isNotNull);
    expect(ext!.configuredColor, isNot(equals(ext.errorColor)));
    expect(ext.warningColor, isNot(equals(ext.errorColor)));
  });

  test('Content module theme extension is injected with distinct accent roles',
      () {
    final darkScheme = KazumiTheme.buildScheme(
      brightness: Brightness.dark,
      seedColor: const Color(0xFF5ABF9B),
    );
    final theme = KazumiTheme.dark(
      scheme: darkScheme,
      useSystemFont: true,
    );

    final ext = theme.extension<ContentModuleThemeExtension>();
    expect(ext, isNotNull);
    expect(ext!.progressWatchedColor, isNot(equals(ext.progressUpdatedColor)));
    expect(ext.badgeColor, isNot(equals(ext.containerColor)));
    expect(ext.hoverBorderColor, isNot(equals(ext.borderColor)));
  });
}
