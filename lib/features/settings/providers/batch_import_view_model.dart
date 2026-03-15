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
  static const int _candidatesCacheVersion = 1;
  static final Map<String, List<BatchImportCandidate>> _candidateCache = {};
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
  bool _disposed = false;
  String? _errorMessage;
  List<BatchImportCandidate> _candidates = [];

  bool get isLoading => _loading;
  bool get isDisposed => _disposed;
  String? get errorMessage => _errorMessage;
  List<BatchImportCandidate> get candidates => _candidates;

  void _notifySafely() {
    if (_disposed) return;
    notifyListeners();
  }

  void _syncCacheFromState([String? scope]) {
    _candidateCache[scope ?? _cacheScope()] =
        List<BatchImportCandidate>.from(_candidates);
  }

  bool _isMangaType(String? notionType) {
    final value = (notionType ?? '').trim().toLowerCase();
    if (value.isEmpty) return false;
    const mangaKeywords = ['manga', 'comic', 'manhua'];
    return mangaKeywords.any(value.contains);
  }

  Future<void> load({bool forceRefresh = false}) async {
    if (_disposed) return;
    if (_loading) return;
    final cacheScope = _cacheScope();
    var restoredFromCache = false;
    final hadVisibleCandidates = _candidates.isNotEmpty;

    if (!forceRefresh) {
      restoredFromCache = await _restoreFromCache(cacheScope);
      if (restoredFromCache) {
        _errorMessage = null;
        _loading = false;
        _notifySafely();
      }
    }

    if (!restoredFromCache) {
      _loading = _candidates.isEmpty;
      _errorMessage = null;
      if (_candidates.isEmpty) {
        _candidates = [];
      }
      _notifySafely();
    }

    try {
      final token = _settings.notionToken;
      final databaseId = _settings.notionDatabaseId;
      if (token.isEmpty || databaseId.isEmpty) {
        throw Exception('Please configure Notion Token and Database ID first.');
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
        throw Exception(
          'Please configure Bangumi ID and title mapping in Mapping page.',
        );
      }

      final pages = await _notionApi.getPagesWithoutBangumiId(
        token: token,
        databaseId: databaseId,
        idPropertyName: idProperty,
        titlePropertyName: titleProperty,
        notionIdPropertyName: notionIdProperty,
        typePropertyName: typeProperty.isEmpty ? 'type' : typeProperty,
        limit: 30,
      );

      final results = <BatchImportCandidate>[];
      for (final item in pages) {
        if (_disposed) return;
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
        if (_disposed) return;
        await Future.delayed(const Duration(milliseconds: 400));
      }

      if (_disposed) return;
      _candidates = results;
      _syncCacheFromState(cacheScope);
      await _saveToCache(cacheScope);
    } catch (e) {
      if (_disposed) return;
      if (!restoredFromCache && !hadVisibleCandidates) {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      }
    } finally {
      _loading = false;
      _notifySafely();
    }
  }

  String _cacheScope() => _settings.notionDatabaseId.trim();

  Future<bool> _restoreFromCache(String scope) async {
    final memoryCache = _candidateCache[scope];
    if (memoryCache != null && memoryCache.isNotEmpty) {
      _candidates = List<BatchImportCandidate>.from(memoryCache);
      return true;
    }
    final payload = await _settingsStorage.getBatchImportCandidatesCache(
      scope: scope,
      minVersion: _candidatesCacheVersion,
    );
    if (payload == null) {
      return false;
    }
    final raw = payload['candidates'];
    if (raw is! List) {
      return false;
    }
    final restored = <BatchImportCandidate>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map =
          item is Map<String, dynamic> ? item : item.cast<String, dynamic>();
      final candidate = _candidateFromJson(map);
      if (candidate == null) continue;
      restored.add(candidate);
    }
    _candidates = restored;
    _syncCacheFromState(scope);
    return true;
  }

  Future<void> _saveToCache(String scope) async {
    _syncCacheFromState(scope);
    await _settingsStorage.saveBatchImportCandidatesCache(
      scope: scope,
      version: _candidatesCacheVersion,
      data: {
        'candidates': _candidates.map(_candidateToJson).toList(growable: false),
      },
    );
  }

  Map<String, dynamic> _candidateToJson(BatchImportCandidate candidate) {
    return {
      'notionItem': {
        'id': candidate.notionItem.id,
        'title': candidate.notionItem.title,
        'url': candidate.notionItem.url,
        'notionId': candidate.notionItem.notionId,
        'notionType': candidate.notionItem.notionType,
      },
      'matches': candidate.matches
          .map(
            (item) => {
              'id': item.id,
              'name': item.name,
              'name_cn': item.nameCn,
              'summary': item.summary,
              'airDate': item.airDate,
              'imageUrl': item.imageUrl,
              'score': item.score,
              'rank': item.rank,
            },
          )
          .toList(growable: false),
      'bound': candidate.bound,
    };
  }

  BatchImportCandidate? _candidateFromJson(Map<String, dynamic> json) {
    final notionRaw = json['notionItem'];
    if (notionRaw is! Map) return null;
    final notionMap = notionRaw is Map<String, dynamic>
        ? notionRaw
        : notionRaw.cast<String, dynamic>();
    final id = notionMap['id']?.toString() ?? '';
    if (id.trim().isEmpty) return null;
    final matchesRaw = json['matches'];
    final matchList = <BangumiSearchItem>[];
    if (matchesRaw is List) {
      for (final item in matchesRaw) {
        if (item is! Map) continue;
        final map =
            item is Map<String, dynamic> ? item : item.cast<String, dynamic>();
        matchList.add(
          BangumiSearchItem(
            id: int.tryParse(map['id']?.toString() ?? '') ?? 0,
            name: map['name']?.toString() ?? '',
            nameCn: map['name_cn']?.toString() ?? '',
            summary: map['summary']?.toString() ?? '',
            imageUrl: map['imageUrl']?.toString() ?? '',
            airDate: map['airDate']?.toString() ?? '',
            score: double.tryParse(map['score']?.toString() ?? '') ?? 0,
            rank: int.tryParse(map['rank']?.toString() ?? '') ?? 0,
          ),
        );
      }
    }
    return BatchImportCandidate(
      notionItem: NotionSearchItem(
        id: id,
        title: notionMap['title']?.toString() ?? '',
        url: notionMap['url']?.toString() ?? '',
        notionId: notionMap['notionId']?.toString(),
        notionType: notionMap['notionType']?.toString(),
      ),
      matches: matchList,
      bound: json['bound'] == true,
    );
  }

  Future<void> bindCandidate({
    required BatchImportCandidate candidate,
    required int bangumiId,
  }) async {
    final token = _settings.notionToken;
    final databaseId = _settings.notionDatabaseId;
    if (token.isEmpty || databaseId.isEmpty) {
      throw Exception('Please configure Notion Token and Database ID first.');
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
      throw Exception('Missing Bangumi ID mapping.');
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
    if (_disposed) return;
    if (pageId.trim().isEmpty) return;
    _candidates = _candidates
        .map((item) =>
            item.notionItem.id == pageId ? item.copyWith(bound: true) : item)
        .toList();
    _syncCacheFromState(_cacheScope());
    unawaited(_saveToCache(_cacheScope()));
    _notifySafely();
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

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
