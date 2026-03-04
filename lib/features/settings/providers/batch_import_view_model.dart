import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../app/app_settings.dart';
import '../../../core/database/settings_storage.dart';
import '../../../core/mapping/mapping_resolver.dart';
import '../../../core/network/bangumi_api.dart';
import '../../../core/network/notion_api.dart';
import '../../../models/bangumi_models.dart';
import '../../../models/mapping_schema.dart';
import '../../../models/notion_models.dart';

class BatchImportCandidate {
  final NotionSearchItem notionItem;
  final List<BangumiSearchItem> matches;
  final bool bound;

  const BatchImportCandidate({
    required this.notionItem,
    required this.matches,
    this.bound = false,
  });

  BatchImportCandidate copyWith({
    List<BangumiSearchItem>? matches,
    bool? bound,
  }) {
    return BatchImportCandidate(
      notionItem: notionItem,
      matches: matches ?? this.matches,
      bound: bound ?? this.bound,
    );
  }
}

class BatchImportViewModel extends ChangeNotifier {
  static const Duration _candidateCacheTtl = Duration(minutes: 20);
  static DateTime? _candidateCacheAt;
  static List<BatchImportCandidate> _candidateCache = [];
  static final Map<int, BangumiSubjectDetail> _subjectDetailCache = {};

  BatchImportViewModel({
    required AppSettings settings,
    required NotionApi notionApi,
    required BangumiApi bangumiApi,
    SettingsStorage? settingsStorage,
  })  : _settings = settings,
        _notionApi = notionApi,
        _bangumiApi = bangumiApi,
        _settingsStorage = settingsStorage ?? SettingsStorage();

  final AppSettings _settings;
  final NotionApi _notionApi;
  final BangumiApi _bangumiApi;
  final SettingsStorage _settingsStorage;

  bool _loading = false;
  String? _errorMessage;
  List<BatchImportCandidate> _candidates = [];

  bool get isLoading => _loading;
  String? get errorMessage => _errorMessage;
  List<BatchImportCandidate> get candidates => _candidates;

  bool get _hasValidCache {
    final at = _candidateCacheAt;
    if (at == null) return false;
    return DateTime.now().difference(at) < _candidateCacheTtl &&
        _candidateCache.isNotEmpty;
  }

  void _syncCacheFromState() {
    _candidateCache = List<BatchImportCandidate>.from(_candidates);
    _candidateCacheAt = DateTime.now();
  }

  bool _isMangaType(String? notionType) {
    final value = (notionType ?? '').trim().toLowerCase();
    if (value.isEmpty) return false;
    const mangaKeywords = ['漫画', 'manga', '漫改', 'comic'];
    return mangaKeywords.any(value.contains);
  }

  Future<void> load({bool forceRefresh = false}) async {
    if (_loading) return;
    if (!forceRefresh && _hasValidCache) {
      _errorMessage = null;
      _candidates = List<BatchImportCandidate>.from(_candidateCache);
      notifyListeners();
      return;
    }

    _loading = true;
    _errorMessage = null;
    _candidates = [];
    notifyListeners();

    try {
      final token = _settings.notionToken;
      final databaseId = _settings.notionDatabaseId;
      if (token.isEmpty || databaseId.isEmpty) {
        throw Exception('请先配置 Notion Token 与 Database ID');
      }

      final mappingConfig = await _settingsStorage.getMappingConfig();
      final resolver = DefaultMappingResolver(mappingConfig);
      final idProperty = resolver
          .resolve(
            MappingSlotKey.bangumiId,
            MappingModuleId.batchImport,
            forWrite: false,
          )
          .trim();
      final titleProperty = resolver
          .resolve(
            MappingSlotKey.title,
            MappingModuleId.batchImport,
            forWrite: false,
          )
          .trim();
      final notionIdProperty = resolver
          .resolve(
            MappingSlotKey.notionId,
            MappingModuleId.identityBinding,
            forWrite: false,
          )
          .trim();
      final typeProperty = resolver
          .resolve(
            MappingSlotKey.type,
            MappingModuleId.batchImport,
            forWrite: false,
          )
          .trim();

      if (idProperty.isEmpty || titleProperty.isEmpty) {
        throw Exception('请在映射配置中设置 Bangumi ID 与标题字段');
      }

      final pages = await _notionApi.getPagesWithoutBangumiId(
        token: token,
        databaseId: databaseId,
        idPropertyName: idProperty,
        titlePropertyName: titleProperty,
        notionIdPropertyName: notionIdProperty,
        typePropertyName: typeProperty.isEmpty ? '番剧类型' : typeProperty,
        limit: 30,
      );

      final results = <BatchImportCandidate>[];
      for (final item in pages) {
        if (_isMangaType(item.notionType)) continue;
        final keyword = item.title.trim();
        if (keyword.isEmpty) continue;
        final matches = await _bangumiApi.search(
          keyword: keyword,
          accessToken: _settings.bangumiAccessToken.isEmpty
              ? null
              : _settings.bangumiAccessToken,
          sort: 'match',
        );
        results.add(
          BatchImportCandidate(
            notionItem: item,
            matches: matches.take(3).toList(),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 400));
      }

      _candidates = results;
      _syncCacheFromState();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> bindCandidate({
    required BatchImportCandidate candidate,
    required int bangumiId,
  }) async {
    final token = _settings.notionToken;
    final databaseId = _settings.notionDatabaseId;
    if (token.isEmpty || databaseId.isEmpty) {
      throw Exception('请先配置 Notion Token 与 Database ID');
    }

    final mappingConfig = await _settingsStorage.getMappingConfig();
    final resolver = DefaultMappingResolver(mappingConfig);
    final idProperty = resolver
        .resolve(
          MappingSlotKey.bangumiId,
          MappingModuleId.batchImport,
          forWrite: true,
        )
        .trim();
    if (idProperty.isEmpty) {
      throw Exception('缺少 Bangumi ID 字段映射');
    }

    await _notionApi.updatePageNumberProperty(
      token: token,
      pageId: candidate.notionItem.id,
      propertyName: idProperty,
      value: bangumiId,
    );

    markCandidateBound(candidate.notionItem.id);
  }

  void markCandidateBound(String pageId) {
    if (pageId.trim().isEmpty) return;
    _candidates = _candidates
        .map((item) =>
            item.notionItem.id == pageId ? item.copyWith(bound: true) : item)
        .toList();
    _syncCacheFromState();
    notifyListeners();
  }

  Future<BangumiSubjectDetail> getSubjectDetail(int subjectId) async {
    final cached = _subjectDetailCache[subjectId];
    if (cached != null) return cached;
    final detail = await _bangumiApi.fetchDetail(
      subjectId: subjectId,
      accessToken: _settings.bangumiAccessToken.isEmpty
          ? null
          : _settings.bangumiAccessToken,
    );
    _subjectDetailCache[subjectId] = detail;
    return detail;
  }
}
