import 'package:flutter/material.dart';

import '../app/app_settings.dart';
import '../models/mapping_config.dart';
import '../models/notion_models.dart';
import '../services/notion_api.dart';
import '../services/settings_storage.dart';

enum MappingFieldType {
  title,
  number,
  date,
  dateRange,
  tags,
  url,
  richText,
  cover,
  status,
  statusValue,
}

class MappingViewModel extends ChangeNotifier {
  MappingViewModel({
    required NotionApi notionApi,
    SettingsStorage? settingsStorage,
  })  : _notionApi = notionApi,
        _settingsStorage = settingsStorage ?? SettingsStorage();

  final NotionApi _notionApi;
  final SettingsStorage _settingsStorage;

  bool _loading = true;
  Object? _error;

  MappingConfig _config = MappingConfig();
  NotionDailyRecommendationBindings _bindings =
      const NotionDailyRecommendationBindings();
  List<NotionProperty> _notionProperties = [];
  final Map<MappingFieldType, List<NotionProperty>> _optionsCache = {};
  String _notionToken = '';
  String _notionDatabaseId = '';

  bool get isLoading => _loading;
  Object? get error => _error;
  MappingConfig get config => _config;
  NotionDailyRecommendationBindings get bindings => _bindings;
  List<NotionProperty> get notionProperties => _notionProperties;
  bool get isConfigured =>
      _notionToken.isNotEmpty && _notionDatabaseId.isNotEmpty;

  Future<void> load(
    AppSettings settings, {
    bool forceRefresh = false,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _notionToken = settings.notionToken;
      _notionDatabaseId = settings.notionDatabaseId;
      _config = await _settingsStorage.getMappingConfig();
      _bindings = _config.dailyRecommendationBindings.isEmpty
          ? await _settingsStorage.getDailyRecommendationBindings()
          : _config.dailyRecommendationBindings;

      if (isConfigured) {
        if (!forceRefresh) {
          _notionProperties = await _settingsStorage.getNotionProperties();
        }
        if (forceRefresh || _notionProperties.isEmpty) {
          _notionProperties = await _notionApi.getDatabaseProperties(
            token: _notionToken,
            databaseId: _notionDatabaseId,
          );
          await _settingsStorage.saveNotionProperties(_notionProperties);
        }
      } else {
        _notionProperties = [];
      }
      _optionsCache.clear();
    } catch (err) {
      _error = err;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> saveConfig() async {
    await _settingsStorage.saveMappingConfig(_config);
  }

  Future<void> saveBindings() async {
    await _settingsStorage.saveDailyRecommendationBindings(_bindings);
    _config = _config.copyWith(dailyRecommendationBindings: _bindings);
    await _settingsStorage.saveMappingConfig(_config);
  }

  void updateConfig(MappingConfig config) {
    _config = config;
    notifyListeners();
  }

  void updateBindings(NotionDailyRecommendationBindings bindings) {
    _bindings = bindings;
    notifyListeners();
  }

  List<NotionProperty> optionsFor(
    MappingFieldType fieldType,
    String currentValue,
  ) {
    final base = _optionsCache.putIfAbsent(fieldType, () {
      final allowedTypes = _allowedNotionTypes(fieldType);
      return [
        NotionProperty(name: '', type: ''),
        NotionProperty(name: '正文', type: 'page_content'),
        ..._notionProperties.where(
          (prop) => allowedTypes.isEmpty || allowedTypes.contains(prop.type),
        ),
      ];
    });
    final items = List<NotionProperty>.from(base);

    final exists = items.any((prop) => prop.name == currentValue);
    if (currentValue.isNotEmpty && !exists) {
      items.add(NotionProperty(name: currentValue, type: 'unknown'));
    }
    return items;
  }

  void applyMagicMap() {
    if (_notionProperties.isEmpty) return;
    MappingConfig updated = _config;

    updated = updated.copyWith(
      title: _pickPropertyName(
            candidates: const ['标题', '名称', '名字', 'title', 'name'],
            requireType: 'title',
          ) ??
          updated.title,
    );
    updated = updated.copyWith(
      score: _pickPropertyName(
            candidates: const ['评分', 'score', 'bgm评分', 'bangumi评分'],
            allowedTypes: _allowedNotionTypes(MappingFieldType.number),
          ) ??
          updated.score,
      bangumiId: _pickPropertyName(
            candidates: const ['bangumi id', 'bgm id', '番剧id', 'id'],
            allowedTypes: _allowedNotionTypes(MappingFieldType.number),
          ) ??
          updated.bangumiId,
      airDate: _pickPropertyName(
            candidates: const ['放送开始', '放送日期', '首播', 'air date', 'start'],
            allowedTypes: _allowedNotionTypes(MappingFieldType.date),
          ) ??
          updated.airDate,
      airDateRange: _pickPropertyName(
            candidates: const ['放送范围', '放送区间', 'air range', 'airdate'],
            allowedTypes: _allowedNotionTypes(MappingFieldType.dateRange),
          ) ??
          updated.airDateRange,
      tags: _pickPropertyName(
            candidates: const ['标签', 'tag', 'tags'],
            allowedTypes: _allowedNotionTypes(MappingFieldType.tags),
          ) ??
          updated.tags,
      imageUrl: _pickPropertyName(
            candidates: const ['封面', '图片', 'cover', 'image'],
            allowedTypes: _allowedNotionTypes(MappingFieldType.cover),
          ) ??
          updated.imageUrl,
      link: _pickPropertyName(
            candidates: const ['链接', '网址', 'url', 'link'],
            allowedTypes: _allowedNotionTypes(MappingFieldType.url),
          ) ??
          updated.link,
      totalEpisodes: _pickPropertyName(
            candidates: const ['总集数', '集数', 'eps', 'episode'],
            allowedTypes: _allowedNotionTypes(MappingFieldType.number),
          ) ??
          updated.totalEpisodes,
      animationProduction: _pickPropertyName(
            candidates: const ['动画制作', '制作', 'studio', 'production'],
            allowedTypes: _allowedNotionTypes(MappingFieldType.richText),
          ) ??
          updated.animationProduction,
      director: _pickPropertyName(
            candidates: const ['导演', 'director'],
            allowedTypes: _allowedNotionTypes(MappingFieldType.richText),
          ) ??
          updated.director,
      script: _pickPropertyName(
            candidates: const ['脚本', 'script'],
            allowedTypes: _allowedNotionTypes(MappingFieldType.richText),
          ) ??
          updated.script,
      storyboard: _pickPropertyName(
            candidates: const ['分镜', 'storyboard'],
            allowedTypes: _allowedNotionTypes(MappingFieldType.richText),
          ) ??
          updated.storyboard,
      description: _pickPropertyName(
            candidates: const ['简介', 'summary', '描述', '长评', '正文'],
            allowedTypes: _allowedNotionTypes(MappingFieldType.richText),
          ) ??
          updated.description,
      watchedEpisodes: _pickPropertyName(
            candidates: const ['已追', '已看', '进度', 'watched'],
            allowedTypes: _allowedNotionTypes(MappingFieldType.number),
          ) ??
          updated.watchedEpisodes,
      watchingStatus: _pickPropertyName(
            candidates: const ['追番状态', '在看', '状态', 'status'],
            allowedTypes: _allowedNotionTypes(MappingFieldType.status),
          ) ??
          updated.watchingStatus,
    );

    updateConfig(updated);
  }

  List<String> _allowedNotionTypes(MappingFieldType type) {
    switch (type) {
      case MappingFieldType.title:
        return ['title', 'rich_text'];
      case MappingFieldType.number:
        return ['number', 'formula', 'rollup'];
      case MappingFieldType.date:
      case MappingFieldType.dateRange:
        return ['date', 'formula', 'rollup'];
      case MappingFieldType.tags:
        return ['multi_select', 'select', 'relation', 'formula'];
      case MappingFieldType.url:
        return ['url', 'rich_text'];
      case MappingFieldType.cover:
        return ['files', 'url', 'rich_text'];
      case MappingFieldType.status:
        return ['status', 'select', 'multi_select'];
      case MappingFieldType.statusValue:
        return ['rich_text', 'select'];
      case MappingFieldType.richText:
        return ['rich_text', 'select', 'multi_select'];
    }
  }

  String? _pickPropertyName({
    required List<String> candidates,
    String? requireType,
    List<String>? allowedTypes,
  }) {
    String normalize(String value) {
      return value
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fa5]'), '');
    }

    final normalizedCandidates = candidates.map(normalize).toList();
    NotionProperty? pick;

    for (final prop in _notionProperties) {
      if (requireType != null && prop.type != requireType) {
        continue;
      }
      if (allowedTypes != null &&
          allowedTypes.isNotEmpty &&
          !allowedTypes.contains(prop.type)) {
        continue;
      }
      final normalizedName = normalize(prop.name);
      if (normalizedCandidates.contains(normalizedName)) {
        pick = prop;
        break;
      }
    }

    pick ??= _notionProperties.firstWhere(
      (prop) {
        if (requireType != null && prop.type != requireType) {
          return false;
        }
        if (allowedTypes != null &&
            allowedTypes.isNotEmpty &&
            !allowedTypes.contains(prop.type)) {
          return false;
        }
        final normalizedName = normalize(prop.name);
        return normalizedCandidates
            .any((candidate) => normalizedName.contains(candidate));
      },
      orElse: () => NotionProperty(name: '', type: ''),
    );

    if (pick.name.trim().isEmpty) return null;
    return pick.name;
  }
}
