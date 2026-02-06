import 'package:flutter/material.dart';

import '../services/settings_storage.dart';

class AppSettings extends ChangeNotifier {
  AppSettings({SettingsStorage? storage})
      : _storage = storage ?? SettingsStorage();

  final SettingsStorage _storage;

  bool _loaded = false;
  ThemeMode _themeMode = ThemeMode.system;
  bool _useDynamicColor = false;
  String _colorSchemeId = 'default';
  bool _useSystemFont = false;
  bool _showRatings = true;
  bool _oledOptimization = false;
  bool _useSystemTitleBar = false;
  String _notionToken = '';
  String _notionDatabaseId = '';
  String _bangumiAccessToken = '';
  String _bangumiRedirectPort = '';

  bool get loaded => _loaded;
  ThemeMode get themeMode => _themeMode;
  bool get useDynamicColor => _useDynamicColor;
  String get colorSchemeId => _colorSchemeId;
  bool get useSystemFont => _useSystemFont;
  bool get showRatings => _showRatings;
  bool get oledOptimization => _oledOptimization;
  bool get useSystemTitleBar => _useSystemTitleBar;
  String get notionToken => _notionToken;
  String get notionDatabaseId => _notionDatabaseId;
  String get bangumiAccessToken => _bangumiAccessToken;
  String get bangumiRedirectPort => _bangumiRedirectPort;

  Future<void> load() async {
    await refresh();
    _loaded = true;
    notifyListeners();
  }

  Future<void> refresh() async {
    final data = await _storage.loadAll();
    _apply(data, notify: false);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _storage.saveThemeMode(mode.name);
    notifyListeners();
  }

  Future<void> setUseDynamicColor(bool value) async {
    _useDynamicColor = value;
    await _storage.saveUseDynamicColor(value);
    notifyListeners();
  }

  Future<void> setColorSchemeId(String value) async {
    _colorSchemeId = value;
    await _storage.saveColorSchemeId(value);
    notifyListeners();
  }

  Future<void> setUseSystemFont(bool value) async {
    _useSystemFont = value;
    await _storage.saveUseSystemFont(value);
    notifyListeners();
  }

  Future<void> setShowRatings(bool value) async {
    _showRatings = value;
    await _storage.saveShowRatings(value);
    notifyListeners();
  }

  Future<void> setOledOptimization(bool value) async {
    _oledOptimization = value;
    await _storage.saveOledOptimization(value);
    notifyListeners();
  }

  Future<void> setUseSystemTitleBar(bool value) async {
    _useSystemTitleBar = value;
    await _storage.saveUseSystemTitleBar(value);
    notifyListeners();
  }

  Future<void> saveNotionSettings({
    required String token,
    required String databaseId,
  }) async {
    _notionToken = token;
    _notionDatabaseId = databaseId;
    await _storage.saveNotionSettings(
      notionToken: token,
      notionDatabaseId: databaseId,
    );
    notifyListeners();
  }

  Future<void> saveBangumiAccessToken(String token) async {
    _bangumiAccessToken = token;
    await _storage.saveBangumiAccessToken(token);
    notifyListeners();
  }

  Future<void> clearBangumiAccessToken() async {
    _bangumiAccessToken = '';
    await _storage.clearBangumiAccessToken();
    notifyListeners();
  }

  Future<void> saveBangumiRedirectPort(String port) async {
    _bangumiRedirectPort = port;
    await _storage.saveBangumiRedirectPort(port);
    notifyListeners();
  }

  void _apply(Map<String, String> data, {bool notify = true}) {
    bool parseBool(String key, bool fallback) {
      final raw = data[key];
      if (raw == null) {
        return fallback;
      }
      return raw.toLowerCase() == 'true';
    }

    _bangumiAccessToken = data[SettingsKeys.bangumiAccessToken] ?? '';
    _bangumiRedirectPort = data[SettingsKeys.bangumiRedirectPort] ?? '';
    _notionToken = data[SettingsKeys.notionToken] ?? '';
    _notionDatabaseId = data[SettingsKeys.notionDatabaseId] ?? '';
    final savedTheme = data[SettingsKeys.themeMode] ?? 'system';
    _themeMode = ThemeMode.values.firstWhere(
      (e) => e.name == savedTheme,
      orElse: () => ThemeMode.system,
    );
    _useDynamicColor =
        parseBool(SettingsKeys.useDynamicColor, _useDynamicColor);
    _colorSchemeId =
        data[SettingsKeys.colorSchemeId] ?? _colorSchemeId;
    _useSystemFont = parseBool(SettingsKeys.useSystemFont, _useSystemFont);
    _showRatings = parseBool(SettingsKeys.showRatings, _showRatings);
    _oledOptimization =
        parseBool(SettingsKeys.oledOptimization, _oledOptimization);
    _useSystemTitleBar =
        parseBool(SettingsKeys.useSystemTitleBar, _useSystemTitleBar);
    if (notify) {
      notifyListeners();
    }
  }
}
