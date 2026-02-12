import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../app/app_settings.dart';
import '../models/bangumi_models.dart';
import '../models/mapping_config.dart';
import '../models/notion_models.dart';
import '../services/bangumi_api.dart';
import '../services/notion_api.dart';
import '../services/settings_storage.dart';

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
  final Map<String, RecommendationNotionContent> _notionContentCache = {};
  final Set<String> _notionContentLoading = {};

  List<NotionScoreEntry> _scoreEntries = [];
  List<RecommendationScoreBin> _scoreBins = [];
  int _scoreTotal = 0;

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
  List<RecommendationScoreBin> get scoreBins => _scoreBins;
  int get scoreTotal => _scoreTotal;

  bool get hasHero => _heroIndices.isNotEmpty;

  Future<void> load(
    AppSettings settings, {
    bool showLoading = true,
  }) async {
    _settings = settings;
    _notionToken = settings.notionToken;
    _notionDatabaseId = settings.notionDatabaseId;
    _bangumiToken = settings.bangumiAccessToken;

    if (showLoading) {
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
      notifyListeners();
    }

    _stopRotationTimer();

    try {
      final cached = await _loadDailyCache();
      if (cached != null) {
        if (kDebugMode) {
          debugPrint('[DailyReco] cache hit');
        }
        final indices = _normalizeHeroIndices(
          cached.indices,
          cached.candidates.length,
        );
        final currentIndex =
            (cached.currentIndex >= 0 && cached.currentIndex < indices.length)
                ? cached.currentIndex
                : 0;
        _dailyCandidates = cached.candidates;
        _heroIndices = indices;
        _currentHeroIndex = currentIndex;
        _pendingJumpIndex = currentIndex;
        _loading = false;
        _emptyMessage =
            _dailyCandidates.isEmpty ? '暂无 ${minScore.toStringAsFixed(1)}+ 条目' : null;
        notifyListeners();
        _startRotationTimer();
        final bindings = await _loadBindings();
        if (bindings != null) {
          await _loadLibraryStats(
            token: _notionToken,
            databaseId: _notionDatabaseId,
            bindings: bindings,
          );
        }
        return;
      }

      if (kDebugMode) {
        debugPrint('[DailyReco] cache miss');
      }

      if (_notionToken.isEmpty || _notionDatabaseId.isEmpty) {
        _setConfiguration(
          '请先在设置页面配置 Notion Token 和 Database ID',
          '/settings',
        );
        return;
      }

      final bindings = await _loadBindings();
      if (bindings == null ||
          bindings.yougnScore.isEmpty ||
          bindings.title.isEmpty) {
        _setConfiguration(
          '请先在映射配置页面绑定每日推荐字段',
          '/mapping',
        );
        return;
      }

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
        _emptyMessage = '暂无 ${minScore.toStringAsFixed(1)}+ 条目';
      }
      notifyListeners();

      _startRotationTimer();
      await _loadLibraryStats(
        token: _notionToken,
        databaseId: _notionDatabaseId,
        bindings: bindings,
      );
    } catch (error, stackTrace) {
      final isTimeout = error is TimeoutException;
      _loading = false;
      _errorMessage = isTimeout ? '网络较慢，点击换一部重试' : '加载失败，请稍后重试';
      _error = error;
      _stackTrace = stackTrace;
      notifyListeners();
      _stopRotationTimer();
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
    _resetRotationTimer();
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
    _startRotationTimer();
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

  RecommendationNotionContent? notionContentFor(DailyRecommendation recommendation) {
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
    final legacyBindings =
        await _settingsStorage.getDailyRecommendationBindings();
    final bindings = _resolveBindings(mappingConfig, legacyBindings);
    return bindings.isEmpty ? null : bindings;
  }

  Future<void> _loadLibraryStats({
    required String token,
    required String databaseId,
    required NotionDailyRecommendationBindings bindings,
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
    } catch (_) {
      _scoreEntries = [];
      _scoreBins = [];
      _scoreTotal = 0;
    } finally {
      _statsLoading = false;
      notifyListeners();
    }
  }

  String _buildTodayKey() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _clipLog(String? value) {
    if (value == null) return '';
    final trimmed = value.trim();
    if (trimmed.length <= logTextLimit) return trimmed;
    return '${trimmed.substring(0, logTextLimit)}...';
  }

  Future<_RecommendationCacheData?> _loadDailyCache() async {
    final today = _buildTodayKey();
    final cachedDate = await _settingsStorage.getDailyRecommendationCacheDate();
    final payload = await _settingsStorage.getDailyRecommendationCachePayload();
    if (cachedDate == null || payload == null || payload.isEmpty) {
      return null;
    }
    if (cachedDate != today) {
      return null;
    }

    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return null;
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
      'version': 3,
      'currentIndex': currentIndex,
      'indices': indices,
      'candidates': candidates.map((item) => item.toJson()).toList(),
    });
    await _settingsStorage.saveDailyRecommendationCache(
      date: _buildTodayKey(),
      payload: payload,
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
    final size = min(count, heroSize);
    final rand = Random();
    final picks = <int>{};
    while (picks.length < size) {
      picks.add(rand.nextInt(count));
    }
    final list = picks.toList()..shuffle(rand);
    return list;
  }

  List<int> _normalizeHeroIndices(List<int> indices, int count) {
    if (count <= 0) return [];
    final valid = indices.where((i) => i >= 0 && i < count).toList();
    if (valid.isEmpty) return _pickHeroIndices(count);
    return valid;
  }

  NotionDailyRecommendationBindings _resolveBindings(
    MappingConfig config,
    NotionDailyRecommendationBindings legacyBindings,
  ) {
    return config.dailyRecommendationBindings.isEmpty
        ? legacyBindings
        : config.dailyRecommendationBindings;
  }

  void _startRotationTimer() {
    _rotationTimer?.cancel();
    if (_heroIndices.length <= 1) return;
    _rotationTimer = Timer.periodic(rotationInterval, (_) {
      _advanceHeroIndex();
    });
  }

  void _stopRotationTimer() {
    _rotationTimer?.cancel();
    _rotationTimer = null;
  }

  void _resetRotationTimer() {
    _startRotationTimer();
  }

  void _advanceHeroIndex() {
    if (_heroIndices.length <= 1) return;
    final nextIndex = (_currentHeroIndex + 1) % _heroIndices.length;
    _currentHeroIndex = nextIndex;
    _showLongReview = false;
    notifyListeners();
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
      (index) =>
          RecommendationScoreBin(label: scoreLabels[index], count: counts[index]),
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
