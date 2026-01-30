import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mapping_config.dart';

class SettingsKeys {
  static const bangumiAppId = 'bangumiAppId';
  static const bangumiAppSecret = 'bangumiAppSecret';
  static const bangumiAccessToken = 'bangumiAccessToken';
  static const bangumiRedirectPort = 'bangumiRedirectPort';
  static const notionToken = 'notionToken';
  static const notionDatabaseId = 'notionDatabaseId';
  static const themeMode = 'themeMode';
  static const mappingConfig = 'mappingConfig';
  static const notionProperties = 'notionProperties';
}

class SettingsStorage {
  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<void> saveBangumiCredentials({
    required String appId,
    required String appSecret,
  }) async {
    final prefs = await _prefs;
    await prefs.setString(SettingsKeys.bangumiAppId, appId);
    await prefs.setString(SettingsKeys.bangumiAppSecret, appSecret);
  }

  Future<void> saveBangumiRedirectPort(String port) async {
    final prefs = await _prefs;
    await prefs.setString(SettingsKeys.bangumiRedirectPort, port);
  }

  Future<void> saveBangumiAccessToken(String token) async {
    final prefs = await _prefs;
    await prefs.setString(SettingsKeys.bangumiAccessToken, token);
  }

  Future<void> saveNotionSettings({
    required String notionToken,
    required String notionDatabaseId,
  }) async {
    final prefs = await _prefs;
    await prefs.setString(SettingsKeys.notionToken, notionToken);
    await prefs.setString(SettingsKeys.notionDatabaseId, notionDatabaseId);
  }

  Future<void> saveNotionProperties(List<String> properties) async {
    final prefs = await _prefs;
    await prefs.setStringList(SettingsKeys.notionProperties, properties);
  }

  Future<List<String>> getNotionProperties() async {
    final prefs = await _prefs;
    return prefs.getStringList(SettingsKeys.notionProperties) ?? [];
  }

  Future<void> saveThemeMode(String mode) async {
    final prefs = await _prefs;
    await prefs.setString(SettingsKeys.themeMode, mode);
  }

  Future<String> getThemeMode() async {
    final prefs = await _prefs;
    return prefs.getString(SettingsKeys.themeMode) ?? 'system';
  }

  Future<void> saveMappingConfig(MappingConfig config) async {
    final prefs = await _prefs;
    await prefs.setString(SettingsKeys.mappingConfig, jsonEncode(config.toJson()));
  }

  Future<MappingConfig> getMappingConfig() async {
    final prefs = await _prefs;
    final jsonStr = prefs.getString(SettingsKeys.mappingConfig);
    if (jsonStr == null || jsonStr.isEmpty) {
      return MappingConfig();
    }
    try {
      return MappingConfig.fromJson(jsonDecode(jsonStr));
    } catch (_) {
      return MappingConfig();
    }
  }

  Future<Map<String, String>> loadAll() async {
    final prefs = await _prefs;
    return {
      SettingsKeys.bangumiAppId: prefs.getString(SettingsKeys.bangumiAppId) ?? '',
      SettingsKeys.bangumiAppSecret:
          prefs.getString(SettingsKeys.bangumiAppSecret) ?? '',
      SettingsKeys.bangumiAccessToken:
          prefs.getString(SettingsKeys.bangumiAccessToken) ?? '',
      SettingsKeys.bangumiRedirectPort:
          prefs.getString(SettingsKeys.bangumiRedirectPort) ?? '',
      SettingsKeys.notionToken: prefs.getString(SettingsKeys.notionToken) ?? '',
      SettingsKeys.notionDatabaseId:
          prefs.getString(SettingsKeys.notionDatabaseId) ?? '',
      SettingsKeys.themeMode: prefs.getString(SettingsKeys.themeMode) ?? 'system',
    };
  }
}
