import 'package:flutter/material.dart';

import '../app/app_settings.dart';
import '../models/bangumi_models.dart';
import '../models/mapping_config.dart';
import '../services/bangumi_api.dart';
import '../services/notion_api.dart';
import '../services/settings_storage.dart';

class CalendarViewModel extends ChangeNotifier {
  CalendarViewModel({
    required BangumiApi bangumiApi,
    required NotionApi notionApi,
    SettingsStorage? settingsStorage,
  })  : _bangumiApi = bangumiApi,
        _notionApi = notionApi,
        _settingsStorage = settingsStorage ?? SettingsStorage();

  final BangumiApi _bangumiApi;
  final NotionApi _notionApi;
  final SettingsStorage _settingsStorage;

  AppSettings? _settings;
  bool _disposed = false;

  bool _loading = true;
  String? _errorMessage;
  List<BangumiCalendarDay> _days = [];
  Set<int> _boundIds = {};
  Map<int, int> _watchedEpisodes = {};
  Map<int, double?> _yougnScores = {};
  Map<int, BangumiSubjectDetail> _detailCache = {};
  final Set<int> _detailLoading = {};
  Map<int, int> _latestEpisodeCache = {};
  final Set<int> _latestEpisodeLoading = {};
  Map<int, List<BangumiCalendarItem>> _weekdayItems = {};
  Map<int, int> _weekdayBoundCounts = {};
  List<BangumiCalendarItem> _boundItems = [];
  bool _notionConfigured = false;
  int _selectedWeekday = DateTime.now().weekday;

  bool get isLoading => _loading;
  String? get errorMessage => _errorMessage;
  List<BangumiCalendarDay> get days => _days;
  Set<int> get boundIds => _boundIds;
  Map<int, int> get watchedEpisodes => _watchedEpisodes;
  Map<int, double?> get yougnScores => _yougnScores;
  Map<int, BangumiSubjectDetail> get detailCache => _detailCache;
  Map<int, int> get latestEpisodeCache => _latestEpisodeCache;
  Map<int, List<BangumiCalendarItem>> get weekdayItems => _weekdayItems;
  Map<int, int> get weekdayBoundCounts => _weekdayBoundCounts;
  List<BangumiCalendarItem> get boundItems => _boundItems;
  bool get notionConfigured => _notionConfigured;
  int get selectedWeekday => _selectedWeekday;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  Future<void> load(AppSettings settings) async {
    _settings = settings;
    _loading = true;
    _errorMessage = null;
    _days = [];
    _boundIds = {};
    _boundItems = [];
    _watchedEpisodes = {};
    _yougnScores = {};
    _detailCache = {};
    _detailLoading.clear();
    _latestEpisodeCache = {};
    _latestEpisodeLoading.clear();
    _notionConfigured = false;
    _notify();

    try {
      final calendar = await _bangumiApi.fetchCalendar();
      final filteredDays = _filterCalendarDays(calendar);

      final notionToken = settings.notionToken;
      final notionDbId = settings.notionDatabaseId;
      final mappingConfig = await _settingsStorage.getMappingConfig();
      final notionPropertyName = _resolveBangumiIdProperty(mappingConfig);

      final dailyBindings =
          await _settingsStorage.getDailyRecommendationBindings();
      final yougnScoreProperty = dailyBindings.yougnScore.isNotEmpty
          ? dailyBindings.yougnScore
          : mappingConfig.dailyRecommendationBindings.yougnScore;

      Set<int> boundIds = {};
      Map<int, int> watchedEpisodes = {};
      Map<int, double?> yougnScores = {};
      bool notionReady = false;
      if (notionToken.isNotEmpty &&
          notionDbId.isNotEmpty &&
          notionPropertyName.isNotEmpty) {
        notionReady = true;
        final progressMap = await _notionApi.getBangumiProgressInfo(
          token: notionToken,
          databaseId: notionDbId,
          idPropertyName: notionPropertyName,
          watchedEpisodesProperty: mappingConfig.watchedEpisodes,
          yougnScoreProperty: yougnScoreProperty,
          statusPropertyName: mappingConfig.watchingStatus,
          statusValue: mappingConfig.watchingStatusValue,
        );
        watchedEpisodes = {
          for (final entry in progressMap.entries)
            entry.key: entry.value.watchedEpisodes
        };
        yougnScores = {
          for (final entry in progressMap.entries)
            entry.key: entry.value.yougnScore
        };
        boundIds = progressMap.keys.toSet();
      }

      _days = filteredDays;
      _boundIds = boundIds;
      _watchedEpisodes = watchedEpisodes;
      _yougnScores = yougnScores;
      _weekdayItems = _buildWeekdayItems(filteredDays, boundIds);
      _weekdayBoundCounts = _buildWeekdayBoundCounts(filteredDays, boundIds);
      _boundItems = _buildBoundItems(filteredDays, boundIds);
      _notionConfigured = notionReady;
      _loading = false;
    } catch (_) {
      _loading = false;
      _errorMessage = '加载放送列表失败，请稍后重试';
    }
    _notify();
  }

  void selectWeekday(int weekday) {
    _selectedWeekday = weekday;
    _notify();
  }

  void scheduleDetailLoad(int subjectId) {
    if (_detailCache.containsKey(subjectId) ||
        _detailLoading.contains(subjectId)) {
      return;
    }
    _detailLoading.add(subjectId);
    _loadDetail(subjectId);
  }

  void scheduleLatestEpisodeLoad(int subjectId, int currentLatest) {
    if (currentLatest > 0 ||
        _latestEpisodeCache.containsKey(subjectId) ||
        _latestEpisodeLoading.contains(subjectId)) {
      return;
    }
    _latestEpisodeLoading.add(subjectId);
    _loadLatestEpisode(subjectId);
  }

  DateTime nextDateForWeekday(int weekday, DateTime now) {
    final base = DateTime(now.year, now.month, now.day);
    int diff = weekday - now.weekday;
    if (diff < 0) diff += 7;
    return base.add(Duration(days: diff));
  }

  int normalizeWeekdayId(int id) {
    if (id == 0) return 7;
    return id;
  }

  String _resolveBangumiIdProperty(MappingConfig config) {
    if (config.bangumiId.trim().isNotEmpty) {
      return config.bangumiId.trim();
    }
    return config.idPropertyName.trim();
  }

  List<BangumiCalendarDay> _filterCalendarDays(List<BangumiCalendarDay> days) {
    final filtered = <BangumiCalendarDay>[];
    for (final day in days) {
      final items = day.items.where((item) => item.type == 2).toList();
      if (items.isEmpty) continue;
      filtered.add(BangumiCalendarDay(weekday: day.weekday, items: items));
    }
    return filtered;
  }

  Map<int, List<BangumiCalendarItem>> _buildWeekdayItems(
    List<BangumiCalendarDay> days,
    Set<int> boundIds,
  ) {
    final result = <int, List<BangumiCalendarItem>>{};
    for (final day in days) {
      final items = [...day.items];
      items.sort((a, b) {
        final aBound = boundIds.contains(a.id);
        final bBound = boundIds.contains(b.id);
        if (aBound == bBound) return 0;
        return aBound ? -1 : 1;
      });
      result[normalizeWeekdayId(day.weekday.id)] = items;
    }
    return result;
  }

  Map<int, int> _buildWeekdayBoundCounts(
    List<BangumiCalendarDay> days,
    Set<int> boundIds,
  ) {
    final counts = <int, int>{};
    for (final day in days) {
      int count = 0;
      for (final item in day.items) {
        if (boundIds.contains(item.id)) count += 1;
      }
      counts[normalizeWeekdayId(day.weekday.id)] = count;
    }
    return counts;
  }

  List<BangumiCalendarItem> _buildBoundItems(
    List<BangumiCalendarDay> days,
    Set<int> boundIds,
  ) {
    final result = <BangumiCalendarItem>[];
    final seen = <int>{};
    for (final day in days) {
      for (final item in day.items) {
        if (!boundIds.contains(item.id)) continue;
        if (seen.add(item.id)) {
          result.add(item);
        }
      }
    }
    return result;
  }

  Future<void> _loadLatestEpisode(int subjectId) async {
    try {
      final token = _settings?.bangumiAccessToken ?? '';
      final latest = await _bangumiApi.fetchLatestEpisodeNumber(
        subjectId: subjectId,
        accessToken: token.isEmpty ? null : token,
      );
      if (latest > 0) {
        _latestEpisodeCache[subjectId] = latest;
        _notify();
      }
    } catch (_) {
      // Ignore
    } finally {
      _latestEpisodeLoading.remove(subjectId);
    }
  }

  Future<void> _loadDetail(int subjectId) async {
    try {
      final token = _settings?.bangumiAccessToken ?? '';
      final detail = await _bangumiApi.fetchSubjectBase(
        subjectId: subjectId,
        accessToken: token.isEmpty ? null : token,
      );
      _detailCache[subjectId] = detail;
      _notify();
    } catch (_) {
      // Ignore
    } finally {
      _detailLoading.remove(subjectId);
    }
  }
}
