import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../../../app/app_settings.dart';
import '../../../core/database/settings_storage.dart';
import '../../../core/mapping/mapping_resolver.dart';
import '../../../core/network/bangumi_api.dart';
import '../../../core/network/notion_api.dart';
import '../../../models/bangumi_models.dart';
import '../../../models/mapping_config.dart';
import '../../../models/mapping_schema.dart';
import '../../../models/notion_models.dart';

class RecommendationNotionContent {
  final String? coverUrl;
  final String? longReview;

  const RecommendationNotionContent({
    required this.coverUrl,
    required this.longReview,
  });
}

class RecommendationScoreBin {
  final String label;
  final int count;

  const RecommendationScoreBin({
    required this.label,
    required this.count,
  });
}

class RecommendationViewModel extends ChangeNotifier {
  RecommendationViewModel({
    required NotionApi notionApi,
    required BangumiApi bangumiApi,
    SettingsStorage? settingsStorage,
  })  : _notionApi = notionApi,
        _bangumiApi = bangumiApi,
        _settingsStorage = settingsStorage ?? SettingsStorage();

  static const double minScore = 6.5;
  static const int heroSize = 3;
  static const int dailyCacheVersion = 5;
  static const int statsCacheVersion = 1;
  static const int recentCacheVersion = 1;
  static const int logTextLimit = 200;
  static const Duration rotationInterval = Duration(seconds: 20);
  static const List<String> scoreLabels = [
    '10',
    '9',
    '8',
    '7',
    '6',
    '5',
    '4',
    '3',
    '2',
    '1',
  ];

  final NotionApi _notionApi;
  final BangumiApi _bangumiApi;
  final SettingsStorage _settingsStorage;

  bool _loading = true;
  bool _statsLoading = false;
  List<DailyRecommendation> _dailyCandidates = [];
  List<int> _heroIndices = [];
  int _currentHeroIndex = 0;
  int? _pendingJumpIndex;

  String? _errorMessage;
  String? _emptyMessage;
  String? _configurationMessage;
  String? _configurationRoute;
  Object? _error;
  StackTrace? _stackTrace;

  bool _showLongReview = false;
  Timer? _rotationTimer;
  bool _disposed = false;

  final Map<int, BangumiSubjectDetail> _bangumiDetailCache = {};
  final Set<int> _bangumiDetailLoading = {};
  final Map<int, int> _recentLatestEpisodeCache = {};
  final Set<int> _recentLatestEpisodeLoading = {};
  final Map<String, RecommendationNotionContent> _notionContentCache = {};
  final Set<String> _notionContentLoading = {};

  List<NotionScoreEntry> _scoreEntries = [];
  List<RecommendationScoreBin> _scoreBins = [];
  int _scoreTotal = 0;
  bool _recentLoading = false;
  String? _recentMessage;
  List<NotionWatchEntry> _recentWatching = [];
  List<NotionWatchEntry> _recentWatched = [];

  String _notionToken = '';
  String _notionDatabaseId = '';
  String _bangumiToken = '';
  AppSettings? _settings;

  bool get isLoading => _loading;
  bool get isStatsLoading => _statsLoading;
  List<DailyRecommendation> get dailyCandidates => _dailyCandidates;
  List<int> get heroIndices => _heroIndices;
  int get currentHeroIndex => _currentHeroIndex;
  bool get showLongReview => _showLongReview;
  String? get errorMessage => _errorMessage;
  String? get emptyMessage => _emptyMessage;
  String? get configurationMessage => _configurationMessage;
  String? get configurationRoute => _configurationRoute;
  Object? get error => _error;
  StackTrace? get stackTrace => _stackTrace;
  Map<int, BangumiSubjectDetail> get bangumiDetailCache => _bangumiDetailCache;
  Map<String, RecommendationNotionContent> get notionContentCache =>
      _notionContentCache;
  int? latestEpisodeFor(int subjectId) => _recentLatestEpisodeCache[subjectId];
  List<RecommendationScoreBin> get scoreBins => _scoreBins;
  int get scoreTotal => _scoreTotal;
  bool get isRecentLoading => _recentLoading;
  String? get recentMessage => _recentMessage;
  List<NotionWatchEntry> get recentWatching => _recentWatching;
  List<NotionWatchEntry> get recentWatched => _recentWatched;

  bool get hasHero => _heroIndices.isNotEmpty;

  Future<void> load(
    AppSettings settings, {
    bool showLoading = true,
    bool forceRefresh = false,
  }) async {
    _settings = settings;
    _notionToken = settings.notionToken;
    _notionDatabaseId = settings.notionDatabaseId;
    _bangumiToken = settings.bangumiAccessToken;
    final cacheScope = _cacheScope();

    var hasDailyCache = false;
    var hasStatsCache = false;
    var hasRecentCache = false;

    if (!forceRefresh) {
      final cachedDaily = await _loadDailyCache();
      final cachedStats = await _loadStatsCache(cacheScope);
      final cachedRecent = await _loadRecentCache(cacheScope);

      if (cachedDaily != null) {
        hasDailyCache = true;
        if (kDebugMode) {
          debugPrint('[DailyReco] cache hit');
        }
        final indices = _normalizeHeroIndices(
          cachedDaily.indices,
          cachedDaily.candidates.length,
        );
        final currentIndex = (cachedDaily.currentIndex >= 0 &&
                cachedDaily.currentIndex < indices.length)
            ? cachedDaily.currentIndex
            : 0;
        _dailyCandidates = cachedDaily.candidates;
        _heroIndices = indices;
        _currentHeroIndex = currentIndex;
        _pendingJumpIndex = currentIndex;
        _loading = false;
        _emptyMessage = _dailyCandidates.isEmpty
            ? 'No items above ${minScore.toStringAsFixed(1)}'
            : null;
      } else if (kDebugMode) {
        debugPrint('[DailyReco] cache miss');
      }

      if (cachedStats != null) {
        hasStatsCache = true;
        _scoreEntries = cachedStats;
        _scoreBins = _buildScoreBins(cachedStats);
        _scoreTotal = cachedStats.length;
      }

      if (cachedRecent != null) {
        hasRecentCache = true;
        _recentWatching = cachedRecent.watching;
        _recentWatched = cachedRecent.watched;
        _recentMessage = cachedRecent.message;
      }

      if (hasDailyCache || hasStatsCache || hasRecentCache) {
        _errorMessage = null;
        _configurationMessage = null;
        _configurationRoute = null;
        _error = null;
        _stackTrace = null;
        notifyListeners();
      }
    }

    if (showLoading && !hasDailyCache) {
      _loading = true;
      _dailyCandidates = [];
      _heroIndices = [];
      _currentHeroIndex = 0;
      _pendingJumpIndex = null;
      _errorMessage = null;
      _emptyMessage = null;
      _configurationMessage = null;
      _configurationRoute = null;
      _error = null;
      _stackTrace = null;
      _recentMessage = null;
      _recentWatching = [];
      _recentWatched = [];
      _recentLatestEpisodeCache.clear();
      _recentLatestEpisodeLoading.clear();
      notifyListeners();
    }

    _stopRotationTimer();

    if (_notionToken.isEmpty || _notionDatabaseId.isEmpty) {
      if (!hasDailyCache) {
        _setConfiguration(
          'Please configure Notion Token and Database ID in Settings.',
          '/settings',
        );
      }
      return;
    }

    final bindings = await _loadBindings();
    if (bindings == null ||
        bindings.yougnScore.isEmpty ||
        bindings.title.isEmpty) {
      if (!hasDailyCache) {
        _setConfiguration(
          'Please configure recommendation field mappings in Mapping page.',
          '/mapping',
        );
      }
      return;
    }

    try {
      final candidates = await _notionApi.getDailyRecommendationCandidates(
        token: _notionToken,
        databaseId: _notionDatabaseId,
        bindings: bindings,
        minScore: minScore,
      );

      final indices = _pickHeroIndices(candidates.length);
      await _saveDailyCache(
        candidates: candidates,
        indices: indices,
        currentIndex: 0,
      );

      _dailyCandidates = candidates;
      _heroIndices = indices;
      _currentHeroIndex = 0;
      _pendingJumpIndex = 0;
      _loading = false;
      if (candidates.isEmpty) {
        _emptyMessage = 'No items above ${minScore.toStringAsFixed(1)}';
      }
      _errorMessage = null;
      _configurationMessage = null;
      _configurationRoute = null;
      _error = null;
      _stackTrace = null;
      notifyListeners();

      await _loadLibraryStats(
        token: _notionToken,
        databaseId: _notionDatabaseId,
        bindings: bindings,
        preserveOnError: hasStatsCache,
        cacheScope: cacheScope,
      );
      await _loadRecentWatchEntries(
        preserveOnError: hasRecentCache,
        cacheScope: cacheScope,
      );
    } catch (error, stackTrace) {
      if (!hasDailyCache) {
        final isTimeout = error is TimeoutException;
        _loading = false;
        _errorMessage = isTimeout
            ? 'Network is slow, try refresh again.'
            : 'Load failed, please try again later.';
        _error = error;
        _stackTrace = stackTrace;
        notifyListeners();
        _stopRotationTimer();
      }
    }
  }

  int? takePendingJumpIndex() {
    final index = _pendingJumpIndex;
    _pendingJumpIndex = null;
    return index;
  }

  DailyRecommendation? recommendationForHero(int index) {
    if (index < 0 || index >= _heroIndices.length) return null;
    final candidateIndex = _heroIndices[index];
    if (candidateIndex < 0 || candidateIndex >= _dailyCandidates.length) {
      return null;
    }
    return _dailyCandidates[candidateIndex];
  }

  Future<void> updateHeroIndex(int index) async {
    if (index < 0 || index >= _heroIndices.length) return;
    _currentHeroIndex = index;
    _showLongReview = false;
    notifyListeners();
    await _saveDailyCache(
      candidates: _dailyCandidates,
      indices: _heroIndices,
      currentIndex: _currentHeroIndex,
    );
  }

  Future<void> reshuffle() async {
    if (_dailyCandidates.isEmpty) {
      if (_settings != null) {
        await load(_settings!);
      }
      return;
    }
    final indices = _pickHeroIndices(_dailyCandidates.length);
    if (indices.isEmpty) return;
    _heroIndices = indices;
    _currentHeroIndex = 0;
    _pendingJumpIndex = 0;
    _showLongReview = false;
    notifyListeners();
    await _saveDailyCache(
      candidates: _dailyCandidates,
      indices: _heroIndices,
      currentIndex: _currentHeroIndex,
    );
    // rotation disabled
  }

  void toggleLongReview() {
    _showLongReview = !_showLongReview;
    notifyListeners();
  }

  void scheduleBangumiDetailLoad(int subjectId) {
    if (_bangumiDetailCache.containsKey(subjectId) ||
        _bangumiDetailLoading.contains(subjectId)) {
      return;
    }
    _bangumiDetailLoading.add(subjectId);
    _loadBangumiDetail(subjectId);
  }

  void scheduleRecentLatestEpisodeLoad(int subjectId) {
    if (_recentLatestEpisodeCache.containsKey(subjectId) ||
        _recentLatestEpisodeLoading.contains(subjectId)) {
      return;
    }
    _recentLatestEpisodeLoading.add(subjectId);
    _loadLatestEpisode(subjectId);
  }

  void scheduleNotionContentLoad(String? pageId) {
    if (pageId == null || pageId.trim().isEmpty) return;
    if (_notionContentCache.containsKey(pageId) ||
        _notionContentLoading.contains(pageId)) {
      return;
    }
    _notionContentLoading.add(pageId);
    _notifyListenersSafe();
    _loadNotionContent(pageId);
  }

  bool isNotionContentLoading(String pageId) {
    return _notionContentLoading.contains(pageId);
  }

  RecommendationNotionContent? notionContentFor(
      DailyRecommendation recommendation) {
    final pageId = recommendation.pageId?.trim() ?? '';
    if (pageId.isEmpty) return null;
    return _notionContentCache[pageId];
  }

  BangumiSubjectDetail? detailFor(DailyRecommendation recommendation) {
    final subjectId = resolveSubjectId(recommendation);
    if (subjectId == null) return null;
    return _bangumiDetailCache[subjectId];
  }

  int? resolveSubjectId(DailyRecommendation recommendation) {
    final raw = (recommendation.subjectId?.trim().isNotEmpty == true)
        ? recommendation.subjectId
        : recommendation.bangumiId;
    if (raw == null || raw.trim().isEmpty) return null;
    return int.tryParse(raw.trim());
  }

  String resolveCoverUrl(
    DailyRecommendation recommendation,
    BangumiSubjectDetail? detail,
    RecommendationNotionContent? content,
  ) {
    final detailCover = detail?.imageUrl ?? '';
    if (detailCover.isNotEmpty) return detailCover;
    final cover = recommendation.cover?.trim() ?? '';
    if (cover.isNotEmpty) return cover;
    final cachedCover = recommendation.contentCoverUrl?.trim() ?? '';
    if (cachedCover.isNotEmpty) return cachedCover;
    final contentCover = content?.coverUrl?.trim() ?? '';
    if (contentCover.isNotEmpty) return contentCover;
    return '';
  }

  String resolveLongReview(
    DailyRecommendation recommendation,
    RecommendationNotionContent? content,
  ) {
    final direct = recommendation.longReview?.trim() ?? '';
    if (direct.isNotEmpty) return direct;
    final cached = recommendation.contentLongReview?.trim() ?? '';
    if (cached.isNotEmpty) return cached;
    final contentText = content?.longReview?.trim() ?? '';
    return contentText;
  }

  List<String> resolveTags(
    DailyRecommendation recommendation,
    BangumiSubjectDetail? detail,
  ) {
    if (detail != null && detail.tagDetails.isNotEmpty) {
      final sorted = [...detail.tagDetails]
        ..sort((a, b) => b.count.compareTo(a.count));
      return sorted.take(8).map((tag) => tag.name).toList();
    }
    return recommendation.tags.take(8).toList();
  }

  String pickNotionOrBangumi(String? notionValue, String? bangumiValue) {
    final notion = notionValue?.trim() ?? '';
    if (notion.isNotEmpty) return notion;
    return bangumiValue?.trim() ?? '';
  }

  int? computeYougnRank(double? yougnScore, double? bangumiScore) {
    if (yougnScore == null || _scoreEntries.isEmpty) return null;
    final compareBangumiScore = bangumiScore ?? 0;
    var rank = 1;
    for (final entry in _scoreEntries) {
      if (entry.yougnScore > yougnScore) {
        rank += 1;
        continue;
      }
      if (entry.yougnScore == yougnScore &&
          entry.bangumiScore > compareBangumiScore) {
        rank += 1;
      }
    }
    return rank;
  }

  String scoreToBinLabel(double score) {
    return scoreLabels[_scoreToBinIndex(score)];
  }

  void _setConfiguration(String message, String route) {
    _loading = false;
    _configurationMessage = message;
    _configurationRoute = route;
    notifyListeners();
    _stopRotationTimer();
  }

  Future<void> _loadBangumiDetail(int subjectId) async {
    try {
      final detail = await _bangumiApi.fetchDetail(
        subjectId: subjectId,
        accessToken: _bangumiToken.isEmpty ? null : _bangumiToken,
      );
      _bangumiDetailCache[subjectId] = detail;
      notifyListeners();
    } catch (_) {
      // ignore
    } finally {
      _bangumiDetailLoading.remove(subjectId);
    }
  }

  Future<void> _loadLatestEpisode(int subjectId) async {
    try {
      final latest = await _bangumiApi.fetchLatestEpisodeNumber(
        subjectId: subjectId,
        accessToken: _bangumiToken.isEmpty ? null : _bangumiToken,
        type: 0,
      );
      _recentLatestEpisodeCache[subjectId] = latest;
      notifyListeners();
    } catch (_) {
      _recentLatestEpisodeCache[subjectId] = 0;
    } finally {
      _recentLatestEpisodeLoading.remove(subjectId);
    }
  }

  Future<void> _loadNotionContent(String pageId) async {
    try {
      if (_notionToken.isEmpty) return;
      final content = await _notionApi.getPageContent(
        token: _notionToken,
        pageId: pageId,
      );
      _notionContentCache[pageId] = RecommendationNotionContent(
        coverUrl: content.coverUrl,
        longReview: content.longReview,
      );
      notifyListeners();
    } catch (_) {
      // ignore
    } finally {
      _notionContentLoading.remove(pageId);
      notifyListeners();
    }
  }

  Future<NotionDailyRecommendationBindings?> _loadBindings() async {
    final mappingConfig = await _settingsStorage.getMappingConfig();
    final bindings = mappingConfig.toDailyRecommendationBindings();
    return bindings.isEmpty ? null : bindings;
  }

  Future<void> _loadLibraryStats({
    required String token,
    required String databaseId,
    required NotionDailyRecommendationBindings bindings,
    bool preserveOnError = false,
    String? cacheScope,
  }) async {
    if (token.isEmpty || databaseId.isEmpty || bindings.yougnScore.isEmpty) {
      return;
    }
    if (_statsLoading) return;
    _statsLoading = true;
    notifyListeners();
    try {
      final entries = await _notionApi.getYougnScoreEntries(
        token: token,
        databaseId: databaseId,
        yougnScoreProperty: bindings.yougnScore,
        bangumiScoreProperty:
            bindings.bangumiScore.isEmpty ? null : bindings.bangumiScore,
      );
      _scoreEntries = entries;
      _scoreBins = _buildScoreBins(entries);
      _scoreTotal = entries.length;
      if (cacheScope != null) {
        await _saveStatsCache(cacheScope, entries);
      }
    } catch (_) {
      if (!preserveOnError) {
        _scoreEntries = [];
        _scoreBins = [];
        _scoreTotal = 0;
      }
    } finally {
      _statsLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadRecentWatchEntries({
    bool preserveOnError = false,
    String? cacheScope,
  }) async {
    if (_recentLoading) return;
    if (_notionToken.isEmpty || _notionDatabaseId.isEmpty) {
      if (!preserveOnError) {
        _recentMessage = 'Notion Token or Database ID is not configured.';
        notifyListeners();
      }
      return;
    }

    _recentLoading = true;
    _recentMessage = null;
    notifyListeners();

    try {
      final mappingConfig = await _settingsStorage.getMappingConfig();
      final resolver = DefaultMappingResolver(mappingConfig);

      final titleProperty = resolver
          .resolve(
            MappingSlotKey.title,
            MappingModuleId.watchRead,
            forWrite: false,
          )
          .trim();
      final coverProperty = resolver
          .resolve(
            MappingSlotKey.cover,
            MappingModuleId.watchRead,
            forWrite: false,
          )
          .trim();

      final idProperty = resolver
          .resolve(
            MappingSlotKey.bangumiId,
            MappingModuleId.watchRead,
            forWrite: false,
          )
          .trim();
      final statusProperty = resolver
          .resolve(
            MappingSlotKey.watchingStatus,
            MappingModuleId.watchRead,
            forWrite: false,
          )
          .trim();
      final watchingValue = resolver
          .resolve(
            MappingSlotKey.watchingStatusValue,
            MappingModuleId.watchRead,
            forWrite: false,
          )
          .trim();
      final watchedValue = resolver
          .resolve(
            MappingSlotKey.watchingStatusValueWatched,
            MappingModuleId.watchRead,
            forWrite: false,
          )
          .trim();
      final watchedEpisodesProperty = resolver
          .resolve(
            MappingSlotKey.watchedEpisodes,
            MappingModuleId.watchRead,
            forWrite: false,
          )
          .trim();
      final totalEpisodesProperty = resolver
          .resolve(
            MappingSlotKey.totalEpisodes,
            MappingModuleId.watchRead,
            forWrite: false,
          )
          .trim();
      final lastWatchedAtProperty = resolver
          .resolve(
            MappingSlotKey.lastWatchedAt,
            MappingModuleId.watchRead,
            forWrite: false,
          )
          .trim();
      final followDateProperty = resolver
          .resolve(
            MappingSlotKey.followDate,
            MappingModuleId.watchRead,
            forWrite: false,
          )
          .trim();
      final tagsProperty = resolver
          .resolve(
            MappingSlotKey.tags,
            MappingModuleId.watchRead,
            forWrite: false,
          )
          .trim();
      final yougnScoreProperty = resolver
          .resolve(
            MappingSlotKey.yougnScore,
            MappingModuleId.watchRead,
            forWrite: false,
          )
          .trim();
      if (idProperty.isEmpty ||
          statusProperty.isEmpty ||
          watchingValue.isEmpty) {
        if (!preserveOnError) {
          _recentMessage = 'Please configure watch status mapping in Mapping.';
          _recentWatching = [];
          _recentWatched = [];
        }
        return;
      }

      final watching = await _notionApi.getRecentWatchEntries(
        token: _notionToken,
        databaseId: _notionDatabaseId,
        idPropertyName: idProperty,
        titlePropertyName: titleProperty,
        coverPropertyName: coverProperty,
        watchedEpisodesProperty: watchedEpisodesProperty,
        totalEpisodesProperty: totalEpisodesProperty,
        lastWatchedAtProperty:
            lastWatchedAtProperty.isEmpty ? null : lastWatchedAtProperty,
        followDateProperty: followDateProperty,
        tagsProperty: tagsProperty,
        yougnScoreProperty:
            yougnScoreProperty.isEmpty ? null : yougnScoreProperty,
        statusPropertyName: statusProperty,
        statusValue: watchingValue,
        limit: 10,
      );
      final watched = await _notionApi.getRecentWatchEntries(
        token: _notionToken,
        databaseId: _notionDatabaseId,
        idPropertyName: idProperty,
        titlePropertyName: titleProperty,
        coverPropertyName: coverProperty,
        watchedEpisodesProperty: watchedEpisodesProperty,
        totalEpisodesProperty: totalEpisodesProperty,
        lastWatchedAtProperty:
            lastWatchedAtProperty.isEmpty ? null : lastWatchedAtProperty,
        followDateProperty: followDateProperty,
        tagsProperty: tagsProperty,
        yougnScoreProperty:
            yougnScoreProperty.isEmpty ? null : yougnScoreProperty,
        statusPropertyName: statusProperty,
        statusValue: watchedValue.isEmpty ? 'watched' : watchedValue,
        limit: 10,
      );

      final sortedWatched = [...watched]..sort((a, b) {
          final ad = a.lastWatchedAt ?? a.lastEditedAt;
          final bd = b.lastWatchedAt ?? b.lastEditedAt;
          if (ad == null && bd == null) return 0;
          if (ad == null) return 1;
          if (bd == null) return -1;
          return bd.compareTo(ad);
        });

      _recentWatching = watching;
      _recentWatched = sortedWatched;
      if (watching.isEmpty && watched.isEmpty) {
        _recentMessage = 'No recent watch entries.';
      }
      if (cacheScope != null) {
        await _saveRecentCache(
          cacheScope,
          watching: _recentWatching,
          watched: _recentWatched,
          message: _recentMessage,
        );
      }
    } catch (_) {
      if (!preserveOnError) {
        _recentMessage = 'Failed to load recent watch entries.';
      }
    } finally {
      _recentLoading = false;
      notifyListeners();
    }
  }

  Future<RecentWatchUpdateResult?> incrementRecentWatch(
    NotionWatchEntry entry,
  ) async {
    if (_notionToken.isEmpty || _notionDatabaseId.isEmpty) return null;
    if (entry.id.isEmpty) return null;

    final mappingConfig = await _settingsStorage.getMappingConfig();
    final resolver = DefaultMappingResolver(mappingConfig);
    final watchedProperty = resolver
        .resolve(
          MappingSlotKey.watchedEpisodes,
          MappingModuleId.watchWrite,
          forWrite: true,
        )
        .trim();
    final lastWatchedProperty = resolver
        .resolve(
          MappingSlotKey.lastWatchedAt,
          MappingModuleId.watchWrite,
          forWrite: true,
        )
        .trim();
    if (watchedProperty.trim().isEmpty) return null;

    final currentWatched = entry.watchedEpisodes ?? 0;
    final nextWatched = currentWatched + 1;
    final previousWatchedAt = entry.lastWatchedAt;
    final now = DateTime.now();

    await _notionApi.updateWatchProgress(
      token: _notionToken,
      pageId: entry.id,
      watchedEpisodesProperty: watchedProperty,
      watchedEpisodes: nextWatched,
      lastWatchedAtProperty:
          lastWatchedProperty.trim().isEmpty ? null : lastWatchedProperty,
      lastWatchedAt: lastWatchedProperty.trim().isEmpty ? null : now,
    );

    _recentWatching = _recentWatching
        .map((item) => item.id == entry.id
            ? _copyWatchEntry(
                item,
                watchedEpisodes: nextWatched,
                lastWatchedAt: lastWatchedProperty.trim().isEmpty
                    ? item.lastWatchedAt
                    : now,
              )
            : item)
        .toList();
    notifyListeners();
    await _saveRecentCache(
      _cacheScope(),
      watching: _recentWatching,
      watched: _recentWatched,
      message: _recentMessage,
    );

    if (_bangumiToken.isNotEmpty && entry.bangumiId != null) {
      final subjectId = int.tryParse(entry.bangumiId ?? '');
      if (subjectId != null && subjectId > 0) {
        try {
          await _bangumiApi.updateEpisodeProgress(
            subjectId: subjectId,
            watchedEpisodes: nextWatched,
            accessToken: _bangumiToken,
          );
        } catch (_) {
          // ignore sync failures
        }
      }
    }

    return RecentWatchUpdateResult(
      pageId: entry.id,
      oldWatched: currentWatched,
      newWatched: nextWatched,
      oldLastWatchedAt: previousWatchedAt,
      newLastWatchedAt: now,
    );
  }

  Future<void> revertRecentWatch(RecentWatchUpdateResult result) async {
    if (_notionToken.isEmpty) return;
    final mappingConfig = await _settingsStorage.getMappingConfig();
    final resolver = DefaultMappingResolver(mappingConfig);
    final watchedProperty = resolver
        .resolve(
          MappingSlotKey.watchedEpisodes,
          MappingModuleId.watchWrite,
          forWrite: true,
        )
        .trim();
    final lastWatchedProperty = resolver
        .resolve(
          MappingSlotKey.lastWatchedAt,
          MappingModuleId.watchWrite,
          forWrite: true,
        )
        .trim();
    if (watchedProperty.trim().isEmpty) return;

    await _notionApi.updateWatchProgress(
      token: _notionToken,
      pageId: result.pageId,
      watchedEpisodesProperty: watchedProperty,
      watchedEpisodes: result.oldWatched,
      lastWatchedAtProperty:
          lastWatchedProperty.trim().isEmpty ? null : lastWatchedProperty,
      lastWatchedAt: result.oldLastWatchedAt,
    );

    _recentWatching = _recentWatching
        .map((item) => item.id == result.pageId
            ? _copyWatchEntry(
                item,
                watchedEpisodes: result.oldWatched,
                lastWatchedAt: result.oldLastWatchedAt,
              )
            : item)
        .toList();
    notifyListeners();
    await _saveRecentCache(
      _cacheScope(),
      watching: _recentWatching,
      watched: _recentWatched,
      message: _recentMessage,
    );
  }

  NotionWatchEntry _copyWatchEntry(
    NotionWatchEntry entry, {
    int? watchedEpisodes,
    DateTime? lastWatchedAt,
  }) {
    return NotionWatchEntry(
      id: entry.id,
      title: entry.title,
      coverUrl: entry.coverUrl,
      watchedEpisodes: watchedEpisodes ?? entry.watchedEpisodes,
      totalEpisodes: entry.totalEpisodes,
      updatedEpisodes: entry.updatedEpisodes,
      bangumiId: entry.bangumiId,
      pageUrl: entry.pageUrl,
      lastEditedAt: entry.lastEditedAt,
      lastWatchedAt: lastWatchedAt ?? entry.lastWatchedAt,
      followDate: entry.followDate,
      status: entry.status,
      tags: entry.tags,
      yougnScore: entry.yougnScore,
    );
  }

  String _buildTodayKey() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _cacheScope() => _notionDatabaseId.trim();

  String _clipLog(String? value) {
    if (value == null) return '';
    final trimmed = value.trim();
    if (trimmed.length <= logTextLimit) return trimmed;
    return '${trimmed.substring(0, logTextLimit)}...';
  }

  Future<_RecommendationCacheData?> _loadDailyCache() async {
    final cachedDate = await _settingsStorage.getDailyRecommendationCacheDate();
    final payload = await _settingsStorage.getDailyRecommendationCachePayload();
    if (payload == null || payload.isEmpty) {
      return null;
    }
    final today = _buildTodayKey();
    if (kDebugMode && cachedDate != null && cachedDate != today) {
      debugPrint(
          '[DailyReco] stale cache fallback date=$cachedDate today=$today');
    }

    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return null;
      final version = int.tryParse(decoded['version']?.toString() ?? '') ?? 0;
      if (version < dailyCacheVersion) {
        return null;
      }
      if (decoded['candidates'] is List) {
        final rawList = decoded['candidates'] as List;
        final candidates = rawList
            .whereType<Map<String, dynamic>>()
            .map(DailyRecommendation.fromJson)
            .toList();
        final indices = _parseIndices(decoded['indices'], candidates.length);
        var currentIndex =
            int.tryParse(decoded['currentIndex']?.toString() ?? '') ??
                int.tryParse(decoded['index']?.toString() ?? '') ??
                0;
        if (currentIndex < 0) currentIndex = 0;
        if (currentIndex >= indices.length && indices.isNotEmpty) {
          currentIndex = 0;
        }
        if (kDebugMode) {
          final currentTitle = candidates.isNotEmpty
              ? candidates[indices.isNotEmpty ? indices.first : 0].title
              : '';
          final currentScore = candidates.isNotEmpty
              ? candidates[indices.isNotEmpty ? indices.first : 0]
                      .yougnScore
                      ?.toStringAsFixed(1) ??
                  '-'
              : '-';
          debugPrint(
            '[DailyReco] cache payload candidates=${candidates.length} '
            'indices=${indices.length} title="${_clipLog(currentTitle)}" '
            'score=$currentScore',
          );
        }
        return _RecommendationCacheData(
          candidates: candidates,
          indices: indices,
          currentIndex: currentIndex,
        );
      }
      final recommendation = DailyRecommendation.fromJson(decoded);
      if (kDebugMode) {
        debugPrint(
          '[DailyReco] cache payload title="${_clipLog(recommendation.title)}" '
          'score=${recommendation.yougnScore?.toStringAsFixed(1) ?? "-"}',
        );
      }
      return _RecommendationCacheData(
        candidates: [recommendation],
        indices: const [0],
        currentIndex: 0,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveDailyCache({
    required List<DailyRecommendation> candidates,
    required List<int> indices,
    required int currentIndex,
  }) async {
    final payload = jsonEncode({
      'version': dailyCacheVersion,
      'currentIndex': currentIndex,
      'indices': indices,
      'candidates': candidates.map((item) => item.toJson()).toList(),
    });
    await _settingsStorage.saveDailyRecommendationCache(
      date: _buildTodayKey(),
      payload: payload,
    );
  }

  Future<List<NotionScoreEntry>?> _loadStatsCache(String scope) async {
    final payload = await _settingsStorage.getRecommendationStatsCache(
      scope: scope,
      minVersion: statsCacheVersion,
    );
    if (payload == null) return null;
    final rawEntries = payload['entries'];
    if (rawEntries is! List) return null;
    final result = <NotionScoreEntry>[];
    for (final item in rawEntries) {
      if (item is! Map) continue;
      final map =
          item is Map<String, dynamic> ? item : item.cast<String, dynamic>();
      final yougnScore =
          double.tryParse(map['yougnScore']?.toString() ?? '') ?? 0;
      final bangumiScore =
          double.tryParse(map['bangumiScore']?.toString() ?? '') ?? 0;
      result.add(
        NotionScoreEntry(
          yougnScore: yougnScore,
          bangumiScore: bangumiScore,
        ),
      );
    }
    return result;
  }

  Future<void> _saveStatsCache(
    String scope,
    List<NotionScoreEntry> entries,
  ) async {
    await _settingsStorage.saveRecommendationStatsCache(
      scope: scope,
      version: statsCacheVersion,
      data: {
        'entries': entries
            .map(
              (item) => {
                'yougnScore': item.yougnScore,
                'bangumiScore': item.bangumiScore,
              },
            )
            .toList(growable: false),
      },
    );
  }

  Future<_RecentWatchCacheData?> _loadRecentCache(String scope) async {
    final payload = await _settingsStorage.getRecommendationRecentCache(
      scope: scope,
      minVersion: recentCacheVersion,
    );
    if (payload == null) return null;
    final watchingRaw = payload['watching'];
    final watchedRaw = payload['watched'];
    if (watchingRaw is! List || watchedRaw is! List) return null;
    final watching = watchingRaw
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .map(_watchEntryFromJson)
        .toList();
    final watched = watchedRaw
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .map(_watchEntryFromJson)
        .toList();
    return _RecentWatchCacheData(
      watching: watching,
      watched: watched,
      message: payload['message']?.toString(),
    );
  }

  Future<void> _saveRecentCache(
    String scope, {
    required List<NotionWatchEntry> watching,
    required List<NotionWatchEntry> watched,
    String? message,
  }) async {
    await _settingsStorage.saveRecommendationRecentCache(
      scope: scope,
      version: recentCacheVersion,
      data: {
        'watching': watching.map(_watchEntryToJson).toList(growable: false),
        'watched': watched.map(_watchEntryToJson).toList(growable: false),
        'message': message,
      },
    );
  }

  Map<String, dynamic> _watchEntryToJson(NotionWatchEntry entry) {
    return {
      'id': entry.id,
      'title': entry.title,
      'coverUrl': entry.coverUrl,
      'watchedEpisodes': entry.watchedEpisodes,
      'totalEpisodes': entry.totalEpisodes,
      'updatedEpisodes': entry.updatedEpisodes,
      'bangumiId': entry.bangumiId,
      'pageUrl': entry.pageUrl,
      'lastEditedAt': entry.lastEditedAt?.toIso8601String(),
      'lastWatchedAt': entry.lastWatchedAt?.toIso8601String(),
      'followDate': entry.followDate?.toIso8601String(),
      'status': entry.status,
      'tags': entry.tags,
      'yougnScore': entry.yougnScore,
    };
  }

  NotionWatchEntry _watchEntryFromJson(Map<String, dynamic> json) {
    List<String> parseTags(dynamic raw) {
      if (raw is! List) return const [];
      return raw.map((item) => item.toString()).toList(growable: false);
    }

    DateTime? parseDate(dynamic raw) {
      final text = raw?.toString() ?? '';
      if (text.isEmpty) return null;
      return DateTime.tryParse(text);
    }

    return NotionWatchEntry(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      coverUrl: json['coverUrl']?.toString(),
      watchedEpisodes: int.tryParse(json['watchedEpisodes']?.toString() ?? ''),
      totalEpisodes: int.tryParse(json['totalEpisodes']?.toString() ?? ''),
      updatedEpisodes: int.tryParse(json['updatedEpisodes']?.toString() ?? ''),
      bangumiId: json['bangumiId']?.toString(),
      pageUrl: json['pageUrl']?.toString(),
      lastEditedAt: parseDate(json['lastEditedAt']),
      lastWatchedAt: parseDate(json['lastWatchedAt']),
      followDate: parseDate(json['followDate']),
      status: json['status']?.toString(),
      tags: parseTags(json['tags']),
      yougnScore: double.tryParse(json['yougnScore']?.toString() ?? ''),
    );
  }

  List<int> _parseIndices(dynamic raw, int max) {
    if (raw is! List) return [];
    final indices = <int>[];
    for (final value in raw) {
      final parsed = int.tryParse(value.toString());
      if (parsed == null) continue;
      if (parsed < 0 || parsed >= max) continue;
      if (!indices.contains(parsed)) indices.add(parsed);
    }
    return indices;
  }

  List<int> _pickHeroIndices(int count) {
    if (count <= 0) return [];
    final rand = Random();
    return [rand.nextInt(count)];
  }

  List<int> _normalizeHeroIndices(List<int> indices, int count) {
    if (count <= 0) return [];
    final valid = indices.where((i) => i >= 0 && i < count).toList();
    if (valid.isEmpty) return _pickHeroIndices(count);
    return valid;
  }

  void _stopRotationTimer() {
    _rotationTimer?.cancel();
    _rotationTimer = null;
  }

  void _notifyListenersSafe() {
    if (_disposed || !hasListeners) return;
    if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_disposed || !hasListeners) return;
        notifyListeners();
      });
      return;
    }
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  List<RecommendationScoreBin> _buildScoreBins(List<NotionScoreEntry> entries) {
    final counts = List<int>.filled(scoreLabels.length, 0);
    for (final entry in entries) {
      final index = _scoreToBinIndex(entry.yougnScore);
      counts[index] += 1;
    }
    return List.generate(
      scoreLabels.length,
      (index) => RecommendationScoreBin(
          label: scoreLabels[index], count: counts[index]),
    );
  }

  int _scoreToBinIndex(double score) {
    if (score >= 10) return 0;
    final clamped = score.clamp(1, 9.999);
    final bucket = clamped.floor();
    return 10 - bucket;
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _rotationTimer = null;
    _disposed = true;
    super.dispose();
  }
}

class _RecommendationCacheData {
  final List<DailyRecommendation> candidates;
  final List<int> indices;
  final int currentIndex;

  const _RecommendationCacheData({
    required this.candidates,
    required this.indices,
    required this.currentIndex,
  });
}

class _RecentWatchCacheData {
  final List<NotionWatchEntry> watching;
  final List<NotionWatchEntry> watched;
  final String? message;

  const _RecentWatchCacheData({
    required this.watching,
    required this.watched,
    required this.message,
  });
}

class RecentWatchUpdateResult {
  final String pageId;
  final int oldWatched;
  final int newWatched;
  final DateTime? oldLastWatchedAt;
  final DateTime? newLastWatchedAt;

  const RecentWatchUpdateResult({
    required this.pageId,
    required this.oldWatched,
    required this.newWatched,
    required this.oldLastWatchedAt,
    required this.newLastWatchedAt,
  });
}
