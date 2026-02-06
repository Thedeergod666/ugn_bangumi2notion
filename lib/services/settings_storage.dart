import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mapping_config.dart';
import '../models/notion_models.dart';

class SettingsKeys {
  static const bangumiAccessToken = 'bangumiAccessToken';
  static const bangumiRedirectPort = 'bangumiRedirectPort';
  static const notionToken = 'notionToken';
  static const notionDatabaseId = 'notionDatabaseId';
  static const themeMode = 'themeMode';
  static const useDynamicColor = 'useDynamicColor';
  static const colorSchemeId = 'colorSchemeId';
  static const useSystemFont = 'useSystemFont';
  static const showRatings = 'showRatings';
  static const oledOptimization = 'oledOptimization';
  static const useSystemTitleBar = 'useSystemTitleBar';
  static const mappingConfig = 'mappingConfig';
  static const dailyRecommendationBindings = 'dailyRecommendationBindings';
  static const notionProperties = 'notionProperties';
  static const dailyRecommendationDate = 'dailyRecommendationDate';
  static const dailyRecommendationPayload = 'dailyRecommendationPayload';
}

class SettingsStorage {
  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  Map<String, String>? _cache;

  Future<void> saveBangumiRedirectPort(String port) async {
    final prefs = await _prefs;
    await prefs.setString(SettingsKeys.bangumiRedirectPort, port);
    _cache ??= {};
    _cache![SettingsKeys.bangumiRedirectPort] = port;
  }

  Future<void> saveBangumiAccessToken(String token) async {
    await _secureStorage.write(
      key: SettingsKeys.bangumiAccessToken,
      value: token,
    );
    _cache ??= {};
    _cache![SettingsKeys.bangumiAccessToken] = token;
  }

  Future<void> clearBangumiAccessToken() async {
    await _secureStorage.delete(key: SettingsKeys.bangumiAccessToken);
    _cache ??= {};
    _cache![SettingsKeys.bangumiAccessToken] = '';
  }

  Future<void> saveNotionSettings({
    required String notionToken,
    required String notionDatabaseId,
  }) async {
    final prefs = await _prefs;
    await _secureStorage.write(
      key: SettingsKeys.notionToken,
      value: notionToken,
    );
    await prefs.setString(SettingsKeys.notionDatabaseId, notionDatabaseId);
    _cache ??= {};
    _cache![SettingsKeys.notionToken] = notionToken;
    _cache![SettingsKeys.notionDatabaseId] = notionDatabaseId;
  }

  Future<void> saveNotionProperties(List<NotionProperty> properties) async {
    final prefs = await _prefs;
    final jsonList = properties.map((p) => jsonEncode(p.toJson())).toList();
    await prefs.setStringList(SettingsKeys.notionProperties, jsonList);
  }

  Future<List<NotionProperty>> getNotionProperties() async {
    final prefs = await _prefs;
    final jsonList = prefs.getStringList(SettingsKeys.notionProperties) ?? [];
    return jsonList.map((j) => NotionProperty.fromJson(jsonDecode(j))).toList();
  }

  Future<void> saveThemeMode(String mode) async {
    final prefs = await _prefs;
    await prefs.setString(SettingsKeys.themeMode, mode);
    _cache ??= {};
    _cache![SettingsKeys.themeMode] = mode;
  }

  Future<void> saveUseDynamicColor(bool value) async {
    await _saveBoolSetting(SettingsKeys.useDynamicColor, value);
  }

  Future<void> saveColorSchemeId(String value) async {
    final prefs = await _prefs;
    await prefs.setString(SettingsKeys.colorSchemeId, value);
    _cache ??= {};
    _cache![SettingsKeys.colorSchemeId] = value;
  }

  Future<void> saveUseSystemFont(bool value) async {
    await _saveBoolSetting(SettingsKeys.useSystemFont, value);
  }

  Future<void> saveShowRatings(bool value) async {
    await _saveBoolSetting(SettingsKeys.showRatings, value);
  }

  Future<void> saveOledOptimization(bool value) async {
    await _saveBoolSetting(SettingsKeys.oledOptimization, value);
  }

  Future<void> saveUseSystemTitleBar(bool value) async {
    await _saveBoolSetting(SettingsKeys.useSystemTitleBar, value);
  }

  Future<String> getThemeMode() async {
    final prefs = await _prefs;
    return prefs.getString(SettingsKeys.themeMode) ?? 'system';
  }

  Future<void> _saveBoolSetting(String key, bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(key, value);
    _cache ??= {};
    _cache![key] = value.toString();
  }

  Future<void> saveMappingConfig(MappingConfig config) async {
    final prefs = await _prefs;
    await prefs.setString(
        SettingsKeys.mappingConfig, jsonEncode(config.toJson()));
  }

  Future<void> saveDailyRecommendationCache({
    required String date,
    required String payload,
  }) async {
    final prefs = await _prefs;
    await prefs.setString(SettingsKeys.dailyRecommendationDate, date);
    await prefs.setString(SettingsKeys.dailyRecommendationPayload, payload);
  }

  Future<String?> getDailyRecommendationCacheDate() async {
    final prefs = await _prefs;
    return prefs.getString(SettingsKeys.dailyRecommendationDate);
  }

  Future<String?> getDailyRecommendationCachePayload() async {
    final prefs = await _prefs;
    return prefs.getString(SettingsKeys.dailyRecommendationPayload);
  }

  Future<void> clearDailyRecommendationCache() async {
    final prefs = await _prefs;
    await prefs.remove(SettingsKeys.dailyRecommendationDate);
    await prefs.remove(SettingsKeys.dailyRecommendationPayload);
  }

  Future<void> saveDailyRecommendationBindings(
    NotionDailyRecommendationBindings bindings,
  ) async {
    final prefs = await _prefs;
    await prefs.setString(
      SettingsKeys.dailyRecommendationBindings,
      jsonEncode(bindings.toJson()),
    );
  }

  Future<MappingConfig> getMappingConfig() async {
    final prefs = await _prefs;
    final jsonStr = prefs.getString(SettingsKeys.mappingConfig);
    if (jsonStr == null || jsonStr.isEmpty) {
      final legacyBindings = await getDailyRecommendationBindings();
      return MappingConfig(dailyRecommendationBindings: legacyBindings);
    }
    try {
      final config = MappingConfig.fromJson(jsonDecode(jsonStr));
      final legacyBindings = await getDailyRecommendationBindings();
      if (config.dailyRecommendationBindings.isEmpty) {
        return config.copyWith(dailyRecommendationBindings: legacyBindings);
      }
      return config;
    } catch (_) {
      final legacyBindings = await getDailyRecommendationBindings();
      return MappingConfig(dailyRecommendationBindings: legacyBindings);
    }
  }

  Future<NotionDailyRecommendationBindings>
      getDailyRecommendationBindings() async {
    final prefs = await _prefs;
    final jsonStr =
        prefs.getString(SettingsKeys.dailyRecommendationBindings) ?? '';
    if (jsonStr.isEmpty) {
      return const NotionDailyRecommendationBindings();
    }
    try {
      return NotionDailyRecommendationBindings.fromJson(jsonDecode(jsonStr));
    } catch (_) {
      return const NotionDailyRecommendationBindings();
    }
  }

  Future<Map<String, String>> loadAll({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null) {
      return Map<String, String>.from(_cache!);
    }
    final prefs = await _prefs;
    final useDynamicColor =
        prefs.getBool(SettingsKeys.useDynamicColor) ?? false;
    final useSystemFont = prefs.getBool(SettingsKeys.useSystemFont) ?? false;
    final showRatings = prefs.getBool(SettingsKeys.showRatings) ?? true;
    final oledOptimization =
        prefs.getBool(SettingsKeys.oledOptimization) ?? false;
    final useSystemTitleBar =
        prefs.getBool(SettingsKeys.useSystemTitleBar) ?? false;
    final data = {
      SettingsKeys.bangumiAccessToken:
          await _secureStorage.read(key: SettingsKeys.bangumiAccessToken) ?? '',
      SettingsKeys.bangumiRedirectPort:
          prefs.getString(SettingsKeys.bangumiRedirectPort) ?? '',
      SettingsKeys.notionToken:
          await _secureStorage.read(key: SettingsKeys.notionToken) ?? '',
      SettingsKeys.notionDatabaseId:
          prefs.getString(SettingsKeys.notionDatabaseId) ?? '',
      SettingsKeys.themeMode:
          prefs.getString(SettingsKeys.themeMode) ?? 'system',
      SettingsKeys.useDynamicColor: useDynamicColor.toString(),
      SettingsKeys.colorSchemeId:
          prefs.getString(SettingsKeys.colorSchemeId) ?? 'default',
      SettingsKeys.useSystemFont: useSystemFont.toString(),
      SettingsKeys.showRatings: showRatings.toString(),
      SettingsKeys.oledOptimization: oledOptimization.toString(),
      SettingsKeys.useSystemTitleBar: useSystemTitleBar.toString(),
    };
    _cache = Map<String, String>.from(data);
    return data;
  }
}
