import 'package:flutter/material.dart';

import '../app/app_settings.dart';

class AppearanceSettingsViewModel extends ChangeNotifier {
  AppearanceSettingsViewModel({required AppSettings settings})
      : _settings = settings {
    _settings.addListener(_handleSettingsChanged);
  }

  final AppSettings _settings;

  ThemeMode get themeMode => _settings.themeMode;
  bool get useDynamicColor => _settings.useDynamicColor;
  String get colorSchemeId => _settings.colorSchemeId;
  bool get useSystemFont => _settings.useSystemFont;
  bool get showRatings => _settings.showRatings;
  bool get oledOptimization => _settings.oledOptimization;
  bool get useSystemTitleBar => _settings.useSystemTitleBar;

  Future<void> setThemeMode(ThemeMode mode) async {
    await _settings.setThemeMode(mode);
  }

  Future<void> setUseDynamicColor(bool value) async {
    await _settings.setUseDynamicColor(value);
  }

  Future<void> setColorSchemeId(String value) async {
    await _settings.setColorSchemeId(value);
  }

  Future<void> setUseSystemFont(bool value) async {
    await _settings.setUseSystemFont(value);
  }

  Future<void> setShowRatings(bool value) async {
    await _settings.setShowRatings(value);
  }

  Future<void> setOledOptimization(bool value) async {
    await _settings.setOledOptimization(value);
  }

  Future<void> setUseSystemTitleBar(bool value) async {
    await _settings.setUseSystemTitleBar(value);
  }

  void _handleSettingsChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _settings.removeListener(_handleSettingsChanged);
    super.dispose();
  }
}
