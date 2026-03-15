import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/mapping_config.dart';
import '../../models/notion_models.dart';

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
  static const dailyRecommendationScopedCachePayload =
      'dailyRecommendationScopedCachePayload';
  static const calendarViewMode = 'calendarViewMode';
  static const searchViewMode = 'searchViewMode';
  static const recentViewMode = 'recentViewMode';
  static const searchSort = 'searchSort';
  static const searchHistory = 'searchHistory';
  static const notionMovieDatabaseId = 'notionMovieDatabaseId';
  static const notionGameDatabaseId = 'notionGameDatabaseId';
  static const calendarPageCachePayload = 'calendarPageCachePayload';
  static const recommendationStatsCachePayload =
      'recommendationStatsCachePayload';
  static const recommendationRecentCachePayload =
      'recommendationRecentCachePayload';
  static const batchImportCandidatesCachePayload =
      'batchImportCandidatesCachePayload';
  static const batchImportUiStateCachePayload =
      'batchImportUiStateCachePayload';
  static const errorLogCachePayload = 'errorLogCachePayload';
}

class SettingsStorage {
  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  Map<String, String>? _cache;
  List<String>? _lastMappingMigrationNotes;

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

  Future<void> saveAdditionalNotionDatabases({
    String? movieDatabaseId,
    String? gameDatabaseId,
  }) async {
    final prefs = await _prefs;
    if (movieDatabaseId != null) {
      await prefs.setString(
          SettingsKeys.notionMovieDatabaseId, movieDatabaseId);
      _cache ??= {};
      _cache![SettingsKeys.notionMovieDatabaseId] = movieDatabaseId;
    }
    if (gameDatabaseId != null) {
      await prefs.setString(SettingsKeys.notionGameDatabaseId, gameDatabaseId);
      _cache ??= {};
      _cache![SettingsKeys.notionGameDatabaseId] = gameDatabaseId;
    }
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

  Future<void> saveCalendarViewMode(String value) async {
    final prefs = await _prefs;
    await prefs.setString(SettingsKeys.calendarViewMode, value);
    _cache ??= {};
    _cache![SettingsKeys.calendarViewMode] = value;
  }

  Future<void> saveSearchViewMode(String value) async {
    final prefs = await _prefs;
    await prefs.setString(SettingsKeys.searchViewMode, value);
    _cache ??= {};
    _cache![SettingsKeys.searchViewMode] = value;
  }

  Future<void> saveRecentViewMode(String value) async {
    final prefs = await _prefs;
    await prefs.setString(SettingsKeys.recentViewMode, value);
    _cache ??= {};
    _cache![SettingsKeys.recentViewMode] = value;
  }

  Future<void> saveSearchSort(String value) async {
    final prefs = await _prefs;
    await prefs.setString(SettingsKeys.searchSort, value);
    _cache ??= {};
    _cache![SettingsKeys.searchSort] = value;
  }

  Future<List<String>> getSearchHistory() async {
    final prefs = await _prefs;
    return prefs.getStringList(SettingsKeys.searchHistory) ?? <String>[];
  }

  Future<void> saveSearchHistory(List<String> history) async {
    final prefs = await _prefs;
    await prefs.setStringList(SettingsKeys.searchHistory, history);
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

  Future<void> saveDailyRecommendationScopedCache({
    required String scope,
    required int version,
    required String date,
    required String payload,
  }) {
    return _saveScopedPayload(
      key: SettingsKeys.dailyRecommendationScopedCachePayload,
      scope: scope,
      version: version,
      data: {
        'date': date,
        'payload': payload,
      },
    );
  }

  Future<Map<String, String>?> getDailyRecommendationScopedCache({
    required String scope,
    int minVersion = 1,
  }) async {
    final data = await _getScopedPayload(
      key: SettingsKeys.dailyRecommendationScopedCachePayload,
      scope: scope,
      minVersion: minVersion,
    );
    if (data == null) {
      return null;
    }

    final date = data['date']?.toString() ?? '';
    final payload = data['payload']?.toString() ?? '';
    if (date.isEmpty || payload.isEmpty) {
      return null;
    }

    return {
      'date': date,
      'payload': payload,
    };
  }

  Future<void> clearDailyRecommendationScopedCache() async {
    final prefs = await _prefs;
    await prefs.remove(SettingsKeys.dailyRecommendationScopedCachePayload);
  }

  Future<void> saveCalendarPageCache({
    required String scope,
    required int version,
    required Map<String, dynamic> data,
  }) {
    return _saveScopedPayload(
      key: SettingsKeys.calendarPageCachePayload,
      scope: scope,
      version: version,
      data: data,
    );
  }

  Future<Map<String, dynamic>?> getCalendarPageCache({
    required String scope,
    int minVersion = 1,
  }) {
    return _getScopedPayload(
      key: SettingsKeys.calendarPageCachePayload,
      scope: scope,
      minVersion: minVersion,
    );
  }

  Future<void> clearCalendarPageCache() async {
    final prefs = await _prefs;
    await prefs.remove(SettingsKeys.calendarPageCachePayload);
  }

  Future<void> saveRecommendationStatsCache({
    required String scope,
    required int version,
    required Map<String, dynamic> data,
  }) {
    return _saveScopedPayload(
      key: SettingsKeys.recommendationStatsCachePayload,
      scope: scope,
      version: version,
      data: data,
    );
  }

  Future<Map<String, dynamic>?> getRecommendationStatsCache({
    required String scope,
    int minVersion = 1,
  }) {
    return _getScopedPayload(
      key: SettingsKeys.recommendationStatsCachePayload,
      scope: scope,
      minVersion: minVersion,
    );
  }

  Future<void> clearRecommendationStatsCache() async {
    final prefs = await _prefs;
    await prefs.remove(SettingsKeys.recommendationStatsCachePayload);
  }

  Future<void> saveRecommendationRecentCache({
    required String scope,
    required int version,
    required Map<String, dynamic> data,
  }) {
    return _saveScopedPayload(
      key: SettingsKeys.recommendationRecentCachePayload,
      scope: scope,
      version: version,
      data: data,
    );
  }

  Future<Map<String, dynamic>?> getRecommendationRecentCache({
    required String scope,
    int minVersion = 1,
  }) {
    return _getScopedPayload(
      key: SettingsKeys.recommendationRecentCachePayload,
      scope: scope,
      minVersion: minVersion,
    );
  }

  Future<void> clearRecommendationRecentCache() async {
    final prefs = await _prefs;
    await prefs.remove(SettingsKeys.recommendationRecentCachePayload);
  }

  Future<void> saveBatchImportCandidatesCache({
    required String scope,
    required int version,
    required Map<String, dynamic> data,
  }) {
    return _saveScopedPayload(
      key: SettingsKeys.batchImportCandidatesCachePayload,
      scope: scope,
      version: version,
      data: data,
    );
  }

  Future<Map<String, dynamic>?> getBatchImportCandidatesCache({
    required String scope,
    int minVersion = 1,
  }) {
    return _getScopedPayload(
      key: SettingsKeys.batchImportCandidatesCachePayload,
      scope: scope,
      minVersion: minVersion,
    );
  }

  Future<void> clearBatchImportCandidatesCache() async {
    final prefs = await _prefs;
    await prefs.remove(SettingsKeys.batchImportCandidatesCachePayload);
  }

  Future<void> saveBatchImportUiStateCache({
    required String scope,
    required int version,
    required Map<String, dynamic> data,
  }) {
    return _saveScopedPayload(
      key: SettingsKeys.batchImportUiStateCachePayload,
      scope: scope,
      version: version,
      data: data,
    );
  }

  Future<Map<String, dynamic>?> getBatchImportUiStateCache({
    required String scope,
    int minVersion = 1,
  }) {
    return _getScopedPayload(
      key: SettingsKeys.batchImportUiStateCachePayload,
      scope: scope,
      minVersion: minVersion,
    );
  }

  Future<void> clearBatchImportUiStateCache() async {
    final prefs = await _prefs;
    await prefs.remove(SettingsKeys.batchImportUiStateCachePayload);
  }

  Future<void> saveErrorLogCache({
    required int version,
    required Map<String, dynamic> data,
  }) {
    return _saveScopedPayload(
      key: SettingsKeys.errorLogCachePayload,
      scope: '',
      version: version,
      data: data,
    );
  }

  Future<Map<String, dynamic>?> getErrorLogCache({
    int minVersion = 1,
  }) {
    return _getScopedPayload(
      key: SettingsKeys.errorLogCachePayload,
      scope: '',
      minVersion: minVersion,
    );
  }

  Future<void> clearErrorLogCache() async {
    final prefs = await _prefs;
    await prefs.remove(SettingsKeys.errorLogCachePayload);
  }

  Future<void> _saveScopedPayload({
    required String key,
    required String scope,
    required int version,
    required Map<String, dynamic> data,
  }) async {
    final prefs = await _prefs;
    final payload = <String, dynamic>{
      'version': version,
      'updatedAt': DateTime.now().toIso8601String(),
      'scope': scope,
      'data': data,
    };
    await prefs.setString(key, jsonEncode(payload));
  }

  Future<Map<String, dynamic>?> _getScopedPayload({
    required String key,
    required String scope,
    required int minVersion,
  }) async {
    final prefs = await _prefs;
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final payload = decoded is Map<String, dynamic>
          ? decoded
          : decoded.cast<String, dynamic>();

      final version = int.tryParse(payload['version']?.toString() ?? '') ?? 0;
      if (version < minVersion) {
        return null;
      }

      final storedScope = payload['scope']?.toString() ?? '';
      if (storedScope != scope) {
        return null;
      }

      final data = payload['data'];
      if (data is Map<String, dynamic>) {
        return data;
      }
      if (data is Map) {
        return data.cast<String, dynamic>();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveDailyRecommendationBindings(
    NotionDailyRecommendationBindings bindings,
  ) async {
    final prefs = await _prefs;
    await prefs.setString(
      SettingsKeys.dailyRecommendationBindings,
      jsonEncode(bindings.toJson()),
    );
    final config = await getMappingConfig();
    await saveMappingConfig(
      config.copyWith(dailyRecommendationBindings: bindings),
    );
  }

  Future<MappingConfig> getMappingConfig() async {
    final prefs = await _prefs;
    final jsonStr = prefs.getString(SettingsKeys.mappingConfig);
    final legacyRaw =
        prefs.getString(SettingsKeys.dailyRecommendationBindings) ?? '';
    Map<String, dynamic> legacyDailyMap = const <String, dynamic>{};
    if (legacyRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(legacyRaw);
        if (decoded is Map<String, dynamic>) {
          legacyDailyMap = decoded;
        } else if (decoded is Map) {
          legacyDailyMap = decoded.cast<String, dynamic>();
        }
      } catch (_) {
        legacyDailyMap = const <String, dynamic>{};
      }
    }

    if (jsonStr == null || jsonStr.isEmpty) {
      final migration = MappingConfig.migrateFromLegacy(
        v1Config: const <String, dynamic>{},
        legacyDailyBindings: legacyDailyMap,
      );
      await saveMappingConfig(migration.config);
      _lastMappingMigrationNotes = migration.notes;
      return migration.config;
    }

    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map) {
        throw Exception('Invalid mapping config json');
      }
      final rawMap = decoded is Map<String, dynamic>
          ? decoded
          : decoded.cast<String, dynamic>();
      final schemaVersion = rawMap['schemaVersion'];
      if (schemaVersion == mappingSchemaVersion) {
        _lastMappingMigrationNotes = null;
        return MappingConfig.fromJson(rawMap);
      }

      final migration = MappingConfig.migrateFromLegacy(
        v1Config: rawMap,
        legacyDailyBindings: legacyDailyMap,
      );
      await saveMappingConfig(migration.config);
      _lastMappingMigrationNotes = migration.notes;
      return migration.config;
    } catch (_) {
      final migration = MappingConfig.migrateFromLegacy(
        v1Config: const <String, dynamic>{},
        legacyDailyBindings: legacyDailyMap,
      );
      await saveMappingConfig(migration.config);
      _lastMappingMigrationNotes = migration.notes;
      return migration.config;
    }
  }

  Future<NotionDailyRecommendationBindings>
      getDailyRecommendationBindings() async {
    final config = await getMappingConfig();
    return config.toDailyRecommendationBindings();
  }

  List<String>? takeLastMappingMigrationNotes() {
    final notes = _lastMappingMigrationNotes;
    _lastMappingMigrationNotes = null;
    return notes;
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
    final calendarViewMode =
        prefs.getString(SettingsKeys.calendarViewMode) ?? 'list';
    final searchViewMode =
        prefs.getString(SettingsKeys.searchViewMode) ?? 'list';
    final recentViewMode =
        prefs.getString(SettingsKeys.recentViewMode) ?? 'auto';
    final searchSort = prefs.getString(SettingsKeys.searchSort) ?? 'match';
    final notionMovieDatabaseId =
        prefs.getString(SettingsKeys.notionMovieDatabaseId) ?? '';
    final notionGameDatabaseId =
        prefs.getString(SettingsKeys.notionGameDatabaseId) ?? '';
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
      SettingsKeys.calendarViewMode: calendarViewMode,
      SettingsKeys.searchViewMode: searchViewMode,
      SettingsKeys.recentViewMode: recentViewMode,
      SettingsKeys.searchSort: searchSort,
      SettingsKeys.notionMovieDatabaseId: notionMovieDatabaseId,
      SettingsKeys.notionGameDatabaseId: notionGameDatabaseId,
    };
    _cache = Map<String, String>.from(data);
    return data;
  }
}
