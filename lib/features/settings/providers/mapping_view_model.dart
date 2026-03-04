import 'package:flutter/material.dart';

import '../../../app/app_settings.dart';
import '../../../core/database/settings_storage.dart';
import '../../../core/mapping/mapping_resolver.dart';
import '../../../core/network/notion_api.dart';
import '../../../models/mapping_config.dart';
import '../../../models/mapping_schema.dart';
import '../../../models/notion_models.dart';

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
  List<NotionProperty> _notionProperties = [];
  String _notionToken = '';
  String _notionDatabaseId = '';
  List<ModuleValidationIssue> _moduleValidationIssues = [];
  Map<String, List<MappingSlotUsage>> _propertyUsageIndex = {};
  List<String>? _migrationNotes;
  final Map<MappingSlotKey, List<NotionProperty>> _optionsCache = {};

  bool get isLoading => _loading;
  Object? get error => _error;
  MappingConfig get config => _config;
  List<NotionProperty> get notionProperties => _notionProperties;
  List<ModuleValidationIssue> get moduleValidationIssues =>
      _moduleValidationIssues;
  Map<String, List<MappingSlotUsage>> get propertyUsageIndex =>
      _propertyUsageIndex;
  List<String>? get migrationNotes => _migrationNotes;
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
      _migrationNotes = _settingsStorage.takeLastMappingMigrationNotes();

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
      _rebuildDerivedState();
    } catch (err) {
      _error = err;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> saveConfig() async {
    await _settingsStorage.saveMappingConfig(_config);
    _migrationNotes = null;
  }

  List<NotionProperty> optionsForSlot(MappingSlotKey slot) {
    final currentValue = _config.bindingFor(slot).propertyName;
    final base = _optionsCache.putIfAbsent(slot, () {
      final allowed = mappingSlotMetaByKey[slot]?.allowedNotionTypes ?? const [];
      return [
        NotionProperty(name: '', type: ''),
        NotionProperty(name: '正文', type: 'page_content'),
        ..._notionProperties.where(
          (prop) => allowed.isEmpty || allowed.contains(prop.type),
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

  void updateSlotProperty(MappingSlotKey slot, String propertyName) {
    _config = _config.updateBinding(
      slot,
      _config.bindingFor(slot).copyWith(propertyName: propertyName),
    );
    _rebuildDerivedState();
    notifyListeners();
  }

  void updateSlotWriteEnabled(MappingSlotKey slot, bool enabled) {
    _config = _config.updateBinding(
      slot,
      _config.bindingFor(slot).copyWith(writeEnabledDefault: enabled),
    );
    _rebuildDerivedState();
    notifyListeners();
  }

  void updateModuleParam(String key, String value) {
    _config = _config.updateModuleParam(key, value);
    _rebuildDerivedState();
    notifyListeners();
  }

  String resolveForModule(
    MappingSlotKey slot,
    MappingModuleId module, {
    required bool forWrite,
  }) {
    return _resolver.resolve(slot, module, forWrite: forWrite);
  }

  List<MappingModuleId> usageOfSlot(MappingSlotKey slot) {
    return _resolver.usageOfSlot(slot);
  }

  void applyMagicMap() {
    if (_notionProperties.isEmpty) return;
    var updated = _config;

    String? pick({
      required List<String> candidates,
      required List<String> allowedTypes,
      String? requireType,
    }) {
      String normalize(String value) {
        return value
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fa5]'), '');
      }

      final normalizedCandidates = candidates.map(normalize).toList();
      NotionProperty? selected;

      for (final prop in _notionProperties) {
        if (requireType != null && prop.type != requireType) continue;
        if (allowedTypes.isNotEmpty && !allowedTypes.contains(prop.type)) {
          continue;
        }
        final normalizedName = normalize(prop.name);
        if (normalizedCandidates.contains(normalizedName)) {
          selected = prop;
          break;
        }
      }

      selected ??= _notionProperties.firstWhere(
        (prop) {
          if (requireType != null && prop.type != requireType) return false;
          if (allowedTypes.isNotEmpty && !allowedTypes.contains(prop.type)) {
            return false;
          }
          final normalizedName = normalize(prop.name);
          return normalizedCandidates.any(
            (candidate) => normalizedName.contains(candidate),
          );
        },
        orElse: () => NotionProperty(name: '', type: ''),
      );

      if (selected.name.trim().isEmpty) return null;
      return selected.name;
    }

    void setSlot(
      MappingSlotKey slot,
      List<String> candidates, {
      String? requireType,
    }) {
      final meta = mappingSlotMetaByKey[slot];
      if (meta == null) return;
      final selected = pick(
        candidates: candidates,
        allowedTypes: meta.allowedNotionTypes,
        requireType: requireType,
      );
      if (selected == null) return;
      updated = updated.updateBinding(
        slot,
        updated.bindingFor(slot).copyWith(propertyName: selected),
      );
    }

    setSlot(
      MappingSlotKey.title,
      const ['标题', '名称', '名字', 'title', 'name'],
      requireType: 'title',
    );
    setSlot(
      MappingSlotKey.yougnScore,
      const ['yougn评分', 'yougn score', '自评', 'yougn'],
    );
    setSlot(
      MappingSlotKey.bangumiScore,
      const ['bangumi评分', 'bgm评分', 'bangumi score'],
    );
    setSlot(
      MappingSlotKey.score,
      const ['评分', 'score', '分数'],
    );
    setSlot(
      MappingSlotKey.bangumiId,
      const ['bangumi id', 'bgm id', '番剧id', 'id'],
    );
    setSlot(
      MappingSlotKey.cover,
      const ['封面', 'cover', '图片', 'image'],
    );
    setSlot(
      MappingSlotKey.tags,
      const ['标签', 'tag', 'tags'],
    );
    setSlot(
      MappingSlotKey.type,
      const ['类型', 'type'],
    );
    setSlot(
      MappingSlotKey.airDate,
      const ['放送开始', '放送日期', '首播', 'air date', 'start'],
    );
    setSlot(
      MappingSlotKey.airDateRange,
      const ['放送范围', '放送区间', 'air range', 'range'],
    );
    setSlot(
      MappingSlotKey.totalEpisodes,
      const ['总集数', '集数', 'eps', 'episode'],
    );
    setSlot(
      MappingSlotKey.watchedEpisodes,
      const ['已追', '已看', '进度', 'watched'],
    );
    setSlot(
      MappingSlotKey.followDate,
      const ['追番日期', '追番时间', 'follow', 'start watch'],
    );
    setSlot(
      MappingSlotKey.lastWatchedAt,
      const ['最近观看', '最后观看', 'last watch', 'last viewed'],
    );
    setSlot(
      MappingSlotKey.watchingStatus,
      const ['追番状态', '在看', '状态', 'status'],
    );
    setSlot(
      MappingSlotKey.link,
      const ['链接', '网址', 'url', 'link'],
    );
    setSlot(
      MappingSlotKey.animationProduction,
      const ['动画制作', '制作', 'studio', 'production'],
    );
    setSlot(
      MappingSlotKey.director,
      const ['导演', 'director'],
    );
    setSlot(
      MappingSlotKey.script,
      const ['脚本', 'script'],
    );
    setSlot(
      MappingSlotKey.storyboard,
      const ['分镜', 'storyboard'],
    );
    setSlot(
      MappingSlotKey.shortReview,
      const ['短评', 'short review'],
    );
    setSlot(
      MappingSlotKey.longReview,
      const ['长评', 'long review'],
    );
    setSlot(
      MappingSlotKey.description,
      const ['简介', 'summary', '描述', '正文'],
    );
    setSlot(
      MappingSlotKey.bangumiUpdatedAt,
      const ['bangumi更新日期', '更新日期', '更新时间'],
    );
    setSlot(
      MappingSlotKey.notionId,
      const ['notion id', 'notionid'],
    );
    setSlot(
      MappingSlotKey.idProperty,
      const ['bangumi id', 'bgm id', 'id'],
    );
    setSlot(
      MappingSlotKey.globalIdProperty,
      const ['global id', '唯一id', 'unique id'],
    );
    setSlot(
      MappingSlotKey.subjectId,
      const ['subject id', 'subjectid'],
    );

    _config = updated;
    _rebuildDerivedState();
    notifyListeners();
  }

  late MappingResolver _resolver = DefaultMappingResolver(_config);

  void _rebuildDerivedState() {
    _resolver = DefaultMappingResolver(_config);
    _moduleValidationIssues = _resolver.validateByModule();
    _propertyUsageIndex = _resolver.buildPropertyUsageIndex();
  }
}
