import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mapping_config.dart';
import '../models/notion_models.dart';

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
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<void> saveBangumiCredentials({
    required String appId,
    required String appSecret,
  }) async {
    final prefs = await _prefs;
    await prefs.setString(SettingsKeys.bangumiAppId, appId);
    if (appSecret.isEmpty) {
      await _secureStorage.delete(key: SettingsKeys.bangumiAppSecret);
    } else {
      await _secureStorage.write(
        key: SettingsKeys.bangumiAppSecret,
        value: appSecret,
      );
    }
  }

  Future<void> saveBangumiRedirectPort(String port) async {
    final prefs = await _prefs;
    await prefs.setString(SettingsKeys.bangumiRedirectPort, port);
  }

  Future<void> saveBangumiAccessToken(String token) async {
    await _secureStorage.write(
      key: SettingsKeys.bangumiAccessToken,
      value: token,
    );
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
          await _secureStorage.read(key: SettingsKeys.bangumiAppSecret) ?? '',
      SettingsKeys.bangumiAccessToken:
          await _secureStorage.read(key: SettingsKeys.bangumiAccessToken) ?? '',
      SettingsKeys.bangumiRedirectPort:
          prefs.getString(SettingsKeys.bangumiRedirectPort) ?? '',
      SettingsKeys.notionToken:
          await _secureStorage.read(key: SettingsKeys.notionToken) ?? '',
      SettingsKeys.notionDatabaseId:
          prefs.getString(SettingsKeys.notionDatabaseId) ?? '',
      SettingsKeys.themeMode: prefs.getString(SettingsKeys.themeMode) ?? 'system',
    };
  }
}
