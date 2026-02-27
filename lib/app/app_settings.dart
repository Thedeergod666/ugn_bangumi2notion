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
  String _notionMovieDatabaseId = '';
  String _notionGameDatabaseId = '';
  String _bangumiAccessToken = '';
  String _bangumiRedirectPort = '';
  String _calendarViewMode = 'list';
  String _searchViewMode = 'list';
  String _recentViewMode = 'gallery';
  String _searchSort = 'match';

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
  String get notionMovieDatabaseId => _notionMovieDatabaseId;
  String get notionGameDatabaseId => _notionGameDatabaseId;
  String get bangumiAccessToken => _bangumiAccessToken;
  String get bangumiRedirectPort => _bangumiRedirectPort;
  String get calendarViewMode => _calendarViewMode;
  String get searchViewMode => _searchViewMode;
  String get recentViewMode => _recentViewMode;
  String get searchSort => _searchSort;

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

  Future<void> saveAdditionalNotionDatabases({
    String? movieDatabaseId,
    String? gameDatabaseId,
  }) async {
    if (movieDatabaseId != null) {
      _notionMovieDatabaseId = movieDatabaseId;
    }
    if (gameDatabaseId != null) {
      _notionGameDatabaseId = gameDatabaseId;
    }
    await _storage.saveAdditionalNotionDatabases(
      movieDatabaseId: movieDatabaseId,
      gameDatabaseId: gameDatabaseId,
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

  Future<void> setCalendarViewMode(String value) async {
    _calendarViewMode = value;
    await _storage.saveCalendarViewMode(value);
    notifyListeners();
  }

  Future<void> setSearchViewMode(String value) async {
    _searchViewMode = value;
    await _storage.saveSearchViewMode(value);
    notifyListeners();
  }

  Future<void> setRecentViewMode(String value) async {
    _recentViewMode = value;
    await _storage.saveRecentViewMode(value);
    notifyListeners();
  }

  Future<void> setSearchSort(String value) async {
    _searchSort = value;
    await _storage.saveSearchSort(value);
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
    _notionMovieDatabaseId = data[SettingsKeys.notionMovieDatabaseId] ?? '';
    _notionGameDatabaseId = data[SettingsKeys.notionGameDatabaseId] ?? '';
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
    _calendarViewMode =
        data[SettingsKeys.calendarViewMode] ?? _calendarViewMode;
    _searchViewMode =
        data[SettingsKeys.searchViewMode] ?? _searchViewMode;
    _recentViewMode =
        data[SettingsKeys.recentViewMode] ?? _recentViewMode;
    _searchSort = data[SettingsKeys.searchSort] ?? _searchSort;
    if (notify) {
      notifyListeners();
    }
  }
}
