import 'package:flutter/material.dart';

import '../services/settings_storage.dart';

class AppSettings extends ChangeNotifier {
  AppSettings({SettingsStorage? storage})
      : _storage = storage ?? SettingsStorage();

  final SettingsStorage _storage;

  bool _loaded = false;
  ThemeMode _themeMode = ThemeMode.system;
  String _notionToken = '';
  String _notionDatabaseId = '';
  String _bangumiAccessToken = '';
  String _bangumiRedirectPort = '';

  bool get loaded => _loaded;
  ThemeMode get themeMode => _themeMode;
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
    _bangumiAccessToken = data[SettingsKeys.bangumiAccessToken] ?? '';
    _bangumiRedirectPort = data[SettingsKeys.bangumiRedirectPort] ?? '';
    _notionToken = data[SettingsKeys.notionToken] ?? '';
    _notionDatabaseId = data[SettingsKeys.notionDatabaseId] ?? '';
    final savedTheme = data[SettingsKeys.themeMode] ?? 'system';
    _themeMode = ThemeMode.values.firstWhere(
      (e) => e.name == savedTheme,
      orElse: () => ThemeMode.system,
    );
    if (notify) {
      notifyListeners();
    }
  }
}
