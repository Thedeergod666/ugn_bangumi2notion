import 'dart:collection';

import 'package:flutter/material.dart';

import '../../../app/app_settings.dart';
import '../../../core/database/settings_storage.dart';
import '../../../core/network/bangumi_api.dart';
import '../../../core/network/notion_api.dart';
import '../../../models/bangumi_models.dart';
import '../../../models/mapping_config.dart';

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
  int _loadToken = 0;

  bool _loading = true;
  String? _errorMessage;
  List<BangumiCalendarDay> _days = [];
  Set<int> _boundIds = {};
  Map<int, int> _watchedEpisodes = {};
  Map<int, double?> _yougnScores = {};
  Map<int, DateTime?> _lastWatchedAt = {};
  Map<int, String> _notionPageIds = {};
  Map<int, BangumiSubjectDetail> _detailCache = {};
  final Set<int> _detailLoading = {};
  Map<int, String?> _airEndDateCache = {};
  final Set<int> _airEndDateLoading = {};
  Map<int, int> _latestEpisodeCache = {};
  final Set<int> _latestEpisodeLoading = {};
  final Queue<int> _latestEpisodeQueue = Queue<int>();
  int _latestEpisodeInFlight = 0;
  static const int _latestEpisodeMaxConcurrency = 3;
  Map<int, List<BangumiCalendarItem>> _weekdayItems = {};
  Map<int, int> _weekdayBoundCounts = {};
  List<BangumiCalendarItem> _boundItems = [];
  Set<int> _crossSeasonCandidateIds = {};
  bool _notionConfigured = false;
  int _selectedWeekday = DateTime.now().weekday;

  bool get isLoading => _loading;
  String? get errorMessage => _errorMessage;
  List<BangumiCalendarDay> get days => _days;
  Set<int> get boundIds => _boundIds;
  Map<int, int> get watchedEpisodes => _watchedEpisodes;
  Map<int, double?> get yougnScores => _yougnScores;
  Map<int, DateTime?> get lastWatchedAt => _lastWatchedAt;
  Map<int, BangumiSubjectDetail> get detailCache => _detailCache;
  Map<int, String?> get airEndDateCache => _airEndDateCache;
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
    final currentToken = ++_loadToken;
    _settings = settings;
    _loading = true;
    _errorMessage = null;
    _days = [];
    _boundIds = {};
    _boundItems = [];
    _watchedEpisodes = {};
    _yougnScores = {};
    _lastWatchedAt = {};
    _notionPageIds = {};
    _detailCache = {};
    _detailLoading.clear();
    _airEndDateCache = {};
    _airEndDateLoading.clear();
    _latestEpisodeCache = {};
    _latestEpisodeLoading.clear();
    _latestEpisodeQueue.clear();
    _latestEpisodeInFlight = 0;
    _crossSeasonCandidateIds = {};
    _notionConfigured = false;
    _notify();

    bool shouldAppendOngoing = false;
    Set<int> boundIds = {};
    Map<int, int> watchedEpisodes = {};
    Map<int, double?> yougnScores = {};
    Map<int, DateTime?> lastWatchedAt = {};
    Map<int, String> notionPageIds = {};
    bool notionReady = false;
    try {
      final calendar = await _bangumiApi.fetchCalendar();
      final filteredDays = _filterCalendarDays(calendar);

      final notionToken = settings.notionToken;
      final notionDbId = settings.notionDatabaseId;
      if (notionToken.isNotEmpty && notionDbId.isNotEmpty) {
        try {
          final mappingConfig = await _settingsStorage.getMappingConfig();
          final watchBindings = mappingConfig.watchBindings;
          final notionPropertyName = watchBindings.bangumiId.trim().isNotEmpty
              ? watchBindings.bangumiId.trim()
              : _resolveBangumiIdProperty(mappingConfig);
          final dailyBindings =
              await _settingsStorage.getDailyRecommendationBindings();
          final yougnScoreProperty = watchBindings.yougnScore.trim().isNotEmpty
              ? watchBindings.yougnScore.trim()
              : (dailyBindings.yougnScore.isNotEmpty
                  ? dailyBindings.yougnScore
                  : mappingConfig.dailyRecommendationBindings.yougnScore);
          final watchedEpisodesProperty =
              watchBindings.watchedEpisodes.isNotEmpty
                  ? watchBindings.watchedEpisodes
                  : mappingConfig.watchedEpisodes;
          final lastWatchedAtProperty = watchBindings.lastWatchedAt.isNotEmpty
              ? watchBindings.lastWatchedAt
              : mappingConfig.lastWatchedAt;
          final followDateProperty = watchBindings.followDate.isNotEmpty
              ? watchBindings.followDate
              : mappingConfig.followDate;
          final statusProperty = watchBindings.watchingStatus.isNotEmpty
              ? watchBindings.watchingStatus
              : mappingConfig.watchingStatus;

          if (notionPropertyName.isNotEmpty) {
            notionReady = true;
            final progressMap = await _notionApi.getBangumiProgressInfo(
              token: notionToken,
              databaseId: notionDbId,
              idPropertyName: notionPropertyName,
              watchedEpisodesProperty: watchedEpisodesProperty,
              yougnScoreProperty: yougnScoreProperty,
              lastWatchedAtProperty: lastWatchedAtProperty,
              followDateProperty: followDateProperty,
              statusPropertyName: statusProperty,
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
            lastWatchedAt = {
              for (final entry in progressMap.entries)
                entry.key: entry.value.lastWatchedAt
            };
            notionPageIds = {
              for (final entry in progressMap.entries)
                if ((entry.value.pageId ?? '').isNotEmpty)
                  entry.key: entry.value.pageId!,
            };
            boundIds = progressMap.keys.toSet();
            _crossSeasonCandidateIds = boundIds;
          }
        } catch (error, stackTrace) {
          notionReady = false;
          boundIds = {};
          watchedEpisodes = {};
          yougnScores = {};
          lastWatchedAt = {};
          notionPageIds = {};
          _crossSeasonCandidateIds = {};
          debugPrint(
            'Calendar load: notion progress sync failed: $error\n$stackTrace',
          );
        }
      }

      _days = filteredDays;
      _boundIds = boundIds;
      _watchedEpisodes = watchedEpisodes;
      _yougnScores = yougnScores;
      _lastWatchedAt = lastWatchedAt;
      _notionPageIds = notionPageIds;
      _weekdayItems = _buildWeekdayItems(filteredDays, boundIds);
      _weekdayBoundCounts = _buildWeekdayBoundCounts(filteredDays, boundIds);
      _boundItems = _buildBoundItems(filteredDays, boundIds);
      _notionConfigured = notionReady;
      _loading = false;
      shouldAppendOngoing =
          _notionConfigured && _crossSeasonCandidateIds.isNotEmpty;
    } catch (error, stackTrace) {
      _loading = false;
      _errorMessage = '加载放送列表失败，请稍后重试';
      debugPrint('Calendar load failed: $error\n$stackTrace');
    }
    _notify();
    if (shouldAppendOngoing &&
        !_disposed &&
        currentToken == _loadToken &&
        _errorMessage == null) {
      _appendBoundItemsFromNotion(currentToken);
    }
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

  void scheduleAirEndDateLoad(int subjectId, {int? totalEpisodes}) {
    if (_airEndDateCache.containsKey(subjectId) ||
        _airEndDateLoading.contains(subjectId)) {
      return;
    }
    _airEndDateLoading.add(subjectId);
    _loadAirEndDate(subjectId, totalEpisodes: totalEpisodes);
  }

  void scheduleLatestEpisodeLoad(int subjectId) {
    if (_latestEpisodeCache.containsKey(subjectId) ||
        _latestEpisodeLoading.contains(subjectId)) {
      return;
    }
    _latestEpisodeLoading.add(subjectId);
    _latestEpisodeQueue.add(subjectId);
    _drainLatestEpisodeQueue();
  }

  void _drainLatestEpisodeQueue() {
    if (_latestEpisodeInFlight >= _latestEpisodeMaxConcurrency) {
      return;
    }
    if (_latestEpisodeQueue.isEmpty) {
      return;
    }
    final subjectId = _latestEpisodeQueue.removeFirst();
    _latestEpisodeInFlight += 1;
    _loadLatestEpisode(subjectId).whenComplete(() {
      _latestEpisodeInFlight -= 1;
      _drainLatestEpisodeQueue();
    });
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
    int latest = 0;
    try {
      final token = _settings?.bangumiAccessToken ?? '';
      latest = await _bangumiApi.fetchLatestEpisodeNumber(
        subjectId: subjectId,
        accessToken: token.isEmpty ? null : token,
        type: 0,
      );
    } catch (_) {
      try {
        latest = await _bangumiApi.fetchLatestEpisodeNumber(
          subjectId: subjectId,
          accessToken: null,
          type: null,
        );
      } catch (_) {
        latest = 0;
      }
    } finally {
      _latestEpisodeLoading.remove(subjectId);
    }
    _latestEpisodeCache[subjectId] = latest;
    _notify();
  }

  Future<void> _loadDetail(int subjectId) async {
    try {
      final token = _settings?.bangumiAccessToken ?? '';
      final detail = await _bangumiApi.fetchSubjectBase(
        subjectId: subjectId,
        accessToken: token.isEmpty ? null : token,
      );
      _detailCache[subjectId] = detail;
      final endFromInfobox = _extractEndDateFromInfobox(detail.infoboxMap);
      if (endFromInfobox != null && endFromInfobox.isNotEmpty) {
        _airEndDateCache[subjectId] = endFromInfobox;
      }
      _notify();
    } catch (_) {
      // Ignore
    } finally {
      _detailLoading.remove(subjectId);
    }
  }

  Future<void> _loadAirEndDate(int subjectId, {int? totalEpisodes}) async {
    try {
      final end = await _bangumiApi.fetchLastEpisodeAirDate(
        subjectId: subjectId,
        totalEpisodes: totalEpisodes,
        accessToken: _settings?.bangumiAccessToken,
      );
      if (end != null && end.trim().isNotEmpty) {
        _airEndDateCache[subjectId] = end.trim();
        _notify();
      }
    } catch (_) {
      // ignore
    } finally {
      _airEndDateLoading.remove(subjectId);
    }
  }

  String? _extractEndDateFromInfobox(Map<String, String> infobox) {
    final keys = [
      '放送结束',
      '放送完毕',
      '放送终了',
      '播放结束',
      '播出结束',
      '上映结束',
    ];
    for (final key in keys) {
      final value = infobox[key];
      final extracted = value == null ? null : _extractFirstDateString(value);
      if (extracted != null) return extracted;
    }
    // fallback: try to extract date range
    for (final entry in infobox.entries) {
      if (entry.key.contains('放送') || entry.key.contains('播出')) {
        final dates = _extractDates(entry.value);
        if (dates.length >= 2) return dates.last;
      }
    }
    return null;
  }

  String? _extractFirstDateString(String raw) {
    final dates = _extractDates(raw);
    return dates.isEmpty ? null : dates.first;
  }

  List<String> _extractDates(String raw) {
    if (raw.trim().isEmpty) return const [];
    final results = <String>[];
    final seen = <String>{};
    void add(String y, String m, String d) {
      final value =
          '${y.padLeft(4, '0')}-${m.padLeft(2, '0')}-${d.padLeft(2, '0')}';
      if (seen.add(value)) {
        results.add(value);
      }
    }

    final iso = RegExp(r'(\\d{4})[./-](\\d{1,2})[./-](\\d{1,2})');
    for (final match in iso.allMatches(raw)) {
      add(match.group(1)!, match.group(2)!, match.group(3)!);
    }
    final cjk =
        RegExp(r'(\\d{4})\\u5e74(\\d{1,2})\\u6708(\\d{1,2})\\u65e5');
    for (final match in cjk.allMatches(raw)) {
      add(match.group(1)!, match.group(2)!, match.group(3)!);
    }
    return results;
  }

  Future<WatchUpdateResult?> incrementWatchedEpisodes(int subjectId) async {
    final settings = _settings;
    if (settings == null) return null;
    final token = settings.notionToken;
    final databaseId = settings.notionDatabaseId;
    if (token.isEmpty || databaseId.isEmpty) return null;

    final mappingConfig = await _settingsStorage.getMappingConfig();
    final watchBindings = mappingConfig.watchBindings;
    final watchedProperty = watchBindings.watchedEpisodes.isNotEmpty
        ? watchBindings.watchedEpisodes
        : mappingConfig.watchedEpisodes;
    final lastWatchedProperty = watchBindings.lastWatchedAt.isNotEmpty
        ? watchBindings.lastWatchedAt
        : mappingConfig.lastWatchedAt;
    final idPropertyName = watchBindings.bangumiId.trim().isNotEmpty
        ? watchBindings.bangumiId.trim()
        : _resolveBangumiIdProperty(mappingConfig);

    if (watchedProperty.trim().isEmpty) return null;

    final currentWatched = _watchedEpisodes[subjectId] ?? 0;
    final newWatched = currentWatched + 1;
    final previousWatchedAt = _lastWatchedAt[subjectId];
    final now = DateTime.now();

    String? pageId = _notionPageIds[subjectId];
    if (pageId == null || pageId.isEmpty) {
      pageId = await _notionApi.findPageByBangumiId(
        token: token,
        databaseId: databaseId,
        bangumiId: subjectId,
        propertyName: idPropertyName,
      );
      if (pageId != null && pageId.isNotEmpty) {
        _notionPageIds[subjectId] = pageId;
      }
    }
    if (pageId == null || pageId.isEmpty) return null;

    await _notionApi.updateWatchProgress(
      token: token,
      pageId: pageId,
      watchedEpisodesProperty: watchedProperty,
      watchedEpisodes: newWatched,
      lastWatchedAtProperty:
          lastWatchedProperty.trim().isEmpty ? null : lastWatchedProperty,
      lastWatchedAt:
          lastWatchedProperty.trim().isEmpty ? null : now,
    );

    _watchedEpisodes[subjectId] = newWatched;
    _lastWatchedAt[subjectId] =
        lastWatchedProperty.trim().isEmpty ? previousWatchedAt : now;
    _notify();

    final bangumiToken = settings.bangumiAccessToken;
    if (bangumiToken.isNotEmpty) {
      try {
        await _bangumiApi.updateEpisodeProgress(
          subjectId: subjectId,
          watchedEpisodes: newWatched,
          accessToken: bangumiToken,
        );
      } catch (_) {
        // ignore sync failures
      }
    }

    return WatchUpdateResult(
      subjectId: subjectId,
      oldWatched: currentWatched,
      newWatched: newWatched,
      oldLastWatchedAt: previousWatchedAt,
      newLastWatchedAt: now,
    );
  }

  Future<void> revertWatchedEpisodes(WatchUpdateResult result) async {
    final settings = _settings;
    if (settings == null) return;
    final token = settings.notionToken;
    if (token.isEmpty) return;

    final mappingConfig = await _settingsStorage.getMappingConfig();
    final watchBindings = mappingConfig.watchBindings;
    final watchedProperty = watchBindings.watchedEpisodes.isNotEmpty
        ? watchBindings.watchedEpisodes
        : mappingConfig.watchedEpisodes;
    final lastWatchedProperty = watchBindings.lastWatchedAt.isNotEmpty
        ? watchBindings.lastWatchedAt
        : mappingConfig.lastWatchedAt;

    if (watchedProperty.trim().isEmpty) return;

    final pageId = _notionPageIds[result.subjectId];
    if (pageId == null || pageId.isEmpty) return;

    await _notionApi.updateWatchProgress(
      token: token,
      pageId: pageId,
      watchedEpisodesProperty: watchedProperty,
      watchedEpisodes: result.oldWatched,
      lastWatchedAtProperty:
          lastWatchedProperty.trim().isEmpty ? null : lastWatchedProperty,
      lastWatchedAt: result.oldLastWatchedAt,
    );

    _watchedEpisodes[result.subjectId] = result.oldWatched;
    _lastWatchedAt[result.subjectId] = result.oldLastWatchedAt;
    _notify();
  }

  Future<void> _appendBoundItemsFromNotion(int token) async {
    if (_disposed || token != _loadToken) return;
    if (_crossSeasonCandidateIds.isEmpty) return;

    final calendarIds = <int>{};
    for (final day in _days) {
      for (final item in day.items) {
        calendarIds.add(item.id);
      }
    }
    final missingIds = _crossSeasonCandidateIds.difference(calendarIds);
    if (missingIds.isEmpty) return;

    final details = await _fetchOngoingSubjectDetails(missingIds);
    if (_disposed || token != _loadToken) return;
    if (details.isEmpty) return;

    final weekdayMap = <int, BangumiCalendarWeekday>{};
    for (final day in _days) {
      weekdayMap[normalizeWeekdayId(day.weekday.id)] = day.weekday;
    }

    final extraByWeekday = <int, List<BangumiCalendarItem>>{};
    for (final detail in details) {
      final weekday = _guessAirWeekday(detail);
      final item = _buildCalendarItemFromDetail(detail, weekday);
      extraByWeekday.putIfAbsent(weekday, () => []).add(item);
      _detailCache[detail.id] = detail;
    }

    final updatedDays = [..._days];
    final indexByWeekday = <int, int>{};
    for (var i = 0; i < updatedDays.length; i += 1) {
      indexByWeekday[normalizeWeekdayId(updatedDays[i].weekday.id)] = i;
    }

    for (final entry in extraByWeekday.entries) {
      final weekday = entry.key;
      final items = entry.value;
      final idx = indexByWeekday[weekday];
      if (idx != null) {
        final existing = updatedDays[idx];
        updatedDays[idx] = BangumiCalendarDay(
          weekday: existing.weekday,
          items: [...existing.items, ...items],
        );
      } else {
        final weekdayInfo = weekdayMap[weekday] ?? _fallbackWeekday(weekday);
        updatedDays.add(
          BangumiCalendarDay(weekday: weekdayInfo, items: items),
        );
      }
    }

    updatedDays.sort((a, b) {
      final aId = normalizeWeekdayId(a.weekday.id);
      final bId = normalizeWeekdayId(b.weekday.id);
      return aId.compareTo(bId);
    });

    _days = updatedDays;
    _weekdayItems = _buildWeekdayItems(updatedDays, _boundIds);
    _weekdayBoundCounts = _buildWeekdayBoundCounts(updatedDays, _boundIds);
    _boundItems = _buildBoundItems(updatedDays, _boundIds);
    _notify();
  }

  Future<List<BangumiSubjectDetail>> _fetchOngoingSubjectDetails(
    Set<int> subjectIds,
  ) async {
    final token = _settings?.bangumiAccessToken ?? '';
    final ids = subjectIds.toList()..sort();
    const chunkSize = 2;
    final details = <BangumiSubjectDetail>[];

    for (var i = 0; i < ids.length; i += chunkSize) {
      final end = (i + chunkSize) < ids.length ? (i + chunkSize) : ids.length;
      final chunk = ids.sublist(i, end);
      final results = await Future.wait(
        chunk.map((id) async {
          BangumiSubjectDetail? detail;
          try {
            detail = await _bangumiApi.fetchSubjectBase(
              subjectId: id,
              accessToken: token.isEmpty ? null : token,
            );
          } catch (_) {
            return null;
          }

          final shouldInclude = await _isCrossSeasonAndOngoing(detail);
          if (!shouldInclude) return null;
          return detail;
        }),
      );
      details.addAll(results.whereType<BangumiSubjectDetail>());
    }

    return details;
  }

  Future<bool> _isCrossSeasonAndOngoing(BangumiSubjectDetail detail) async {
    try {
      final token = _settings?.bangumiAccessToken ?? '';
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final seasonStart = _currentSeasonStart(now);
      final previousSeasonStart = _previousSeasonStart(now);

      var startDate = _resolveAirStartDate(detail);
      List<BangumiEpisode> episodes = const [];

      if (startDate == null) {
        try {
          episodes = await _bangumiApi.fetchSubjectEpisodes(
            subjectId: detail.id,
            accessToken: token.isEmpty ? null : token,
            type: 0,
          );
          if (episodes.isNotEmpty) {
            startDate ??= _earliestEpisodeAirDate(episodes);
          }
        } catch (_) {
          episodes = const [];
        }
      }

      if (startDate == null ||
          startDate.isBefore(previousSeasonStart) ||
          !startDate.isBefore(seasonStart)) {
        return false;
      }

      if (episodes.isEmpty) {
        try {
          episodes = await _bangumiApi.fetchSubjectEpisodes(
            subjectId: detail.id,
            accessToken: token.isEmpty ? null : token,
            type: 0,
          );
        } catch (_) {
          episodes = const [];
        }
      }

      if (episodes.isEmpty) {
        return true;
      }

      int maxNumber = 0;
      int latestAiredNumber = 0;
      DateTime? latestAiredDate;
      bool hasFuture = false;

      for (final episode in episodes) {
        final number = _pickEpisodeNumber(episode);
        if (number > maxNumber) maxNumber = number;
        final airDate = _parseEpisodeAirDate(episode.airDate);
        if (airDate == null) continue;
        if (airDate.isAfter(today)) {
          hasFuture = true;
          continue;
        }
        if (latestAiredDate == null || airDate.isAfter(latestAiredDate)) {
          latestAiredDate = airDate;
          latestAiredNumber = number;
        }
      }

      if (detail.epsCount > 0 && maxNumber > 0) {
        if (latestAiredNumber > 0 && latestAiredNumber < detail.epsCount) {
          return true;
        }
        if (maxNumber < detail.epsCount) {
          return true;
        }
      }

      if (hasFuture) return true;

      if (latestAiredDate != null) {
        final diff = today.difference(latestAiredDate).inDays;
        return diff <= 21;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  DateTime _currentSeasonStart(DateTime now) {
    final startMonth = ((now.month - 1) ~/ 3) * 3 + 1;
    return DateTime(now.year, startMonth, 1);
  }

  DateTime _previousSeasonStart(DateTime now) {
    final currentStart = _currentSeasonStart(now);
    final prevMonth = currentStart.month - 3;
    if (prevMonth >= 1) {
      return DateTime(currentStart.year, prevMonth, 1);
    }
    return DateTime(currentStart.year - 1, 10, 1);
  }

  DateTime? _resolveAirStartDate(BangumiSubjectDetail detail) {
    final direct = _parseAirDate(detail.airDate);
    if (direct != null) return direct;

    final raw = _findInfoboxValue(
      detail.infoboxMap,
      const [
        '放送开始',
        '放送開始',
        '放送日期',
        '放送日',
        '首播',
        '播放开始',
        '播放日期',
        '播放日',
        '播出开始',
        '播出日期',
        '播出日',
        '开播',
      ],
    );
    if (raw == null || raw.trim().isEmpty) return null;
    final extracted = _extractFirstDate(raw);
    if (extracted != null) return extracted;
    return _parseAirDate(raw);
  }

  DateTime? _extractFirstDate(String raw) {
    final iso = RegExp(r'(\d{4})[./-](\d{1,2})[./-](\d{1,2})')
        .firstMatch(raw);
    if (iso != null) {
      return _buildDate(iso.group(1)!, iso.group(2)!, iso.group(3)!);
    }
    final cjk = RegExp(r'(\d{4})年(\d{1,2})月(\d{1,2})日')
        .firstMatch(raw);
    if (cjk != null) {
      return _buildDate(cjk.group(1)!, cjk.group(2)!, cjk.group(3)!);
    }
    final isoYm = RegExp(r'(\d{4})[./-](\d{1,2})').firstMatch(raw);
    if (isoYm != null) {
      return DateTime(int.parse(isoYm.group(1)!), int.parse(isoYm.group(2)!), 1);
    }
    final cjkYm = RegExp(r'(\d{4})年(\d{1,2})月').firstMatch(raw);
    if (cjkYm != null) {
      return DateTime(int.parse(cjkYm.group(1)!), int.parse(cjkYm.group(2)!), 1);
    }
    return null;
  }

  DateTime _buildDate(String y, String m, String d) {
    return DateTime(int.parse(y), int.parse(m), int.parse(d));
  }

  DateTime? _parseAirDate(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final full = DateTime.tryParse(text);
    if (full != null) return full;

    final ym = RegExp(r'^(\d{4})-(\d{1,2})$').firstMatch(text);
    if (ym != null) {
      return DateTime(int.parse(ym.group(1)!), int.parse(ym.group(2)!), 1);
    }
    final y = RegExp(r'^(\d{4})$').firstMatch(text);
    if (y != null) {
      return DateTime(int.parse(y.group(1)!), 1, 1);
    }
    return null;
  }

  DateTime? _parseEpisodeAirDate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final parsed = DateTime.tryParse(trimmed);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  DateTime? _earliestEpisodeAirDate(List<BangumiEpisode> episodes) {
    DateTime? earliest;
    for (final episode in episodes) {
      final airDate = _parseEpisodeAirDate(episode.airDate);
      if (airDate == null) continue;
      if (earliest == null || airDate.isBefore(earliest)) {
        earliest = airDate;
      }
    }
    return earliest;
  }

  int _pickEpisodeNumber(BangumiEpisode episode) {
    final value = episode.ep > 0 ? episode.ep : episode.sort;
    return value.round();
  }

  BangumiCalendarItem _buildCalendarItemFromDetail(
    BangumiSubjectDetail detail,
    int weekday,
  ) {
    return BangumiCalendarItem(
      id: detail.id,
      type: 2,
      name: detail.name,
      nameCn: detail.nameCn,
      summary: detail.summary,
      imageUrl: detail.imageUrl,
      airDate: detail.airDate,
      airWeekday: weekday,
      eps: 0,
      epsCount: detail.epsCount,
    );
  }

  int _guessAirWeekday(BangumiSubjectDetail detail) {
    final raw = _findInfoboxValue(
      detail.infoboxMap,
      const [
        '放送星期',
        '放送日',
        '播放星期',
        '播出星期',
        '播出日',
        '放送曜',
      ],
    );
    final parsed = raw != null ? _parseWeekdayText(raw) : null;
    if (parsed != null) return parsed;

    final date = DateTime.tryParse(detail.airDate);
    if (date != null) return date.weekday;

    return DateTime.now().weekday;
  }

  String? _findInfoboxValue(
    Map<String, String> map,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = map[key];
      if (value != null && value.trim().isNotEmpty) return value;
    }
    for (final entry in map.entries) {
      for (final key in keys) {
        if (entry.key.contains(key) && entry.value.trim().isNotEmpty) {
          return entry.value;
        }
      }
    }
    return null;
  }

  int? _parseWeekdayText(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    final cnMatch =
        RegExp(r'(星期|周|礼拜|禮拜|每周|毎週)\s*([一二三四五六日天])')
            .firstMatch(text);
    if (cnMatch != null) {
      return _mapCjkWeekday(cnMatch.group(2)!);
    }

    final jpMatch = RegExp(r'([月火水木金土日])曜').firstMatch(text);
    if (jpMatch != null) {
      return _mapCjkWeekday(jpMatch.group(1)!);
    }

    final lower = text.toLowerCase();
    final enMatch =
        RegExp(r'\b(mon|tue|wed|thu|fri|sat|sun)\b').firstMatch(lower);
    if (enMatch != null) {
      return _mapEnglishWeekday(enMatch.group(1)!);
    }

    return null;
  }

  int? _mapCjkWeekday(String token) {
    switch (token) {
      case '一':
      case '月':
        return 1;
      case '二':
      case '火':
        return 2;
      case '三':
      case '水':
        return 3;
      case '四':
      case '木':
        return 4;
      case '五':
      case '金':
        return 5;
      case '六':
      case '土':
        return 6;
      case '日':
      case '天':
        return 7;
      default:
        return null;
    }
  }

  int? _mapEnglishWeekday(String token) {
    switch (token) {
      case 'mon':
        return 1;
      case 'tue':
        return 2;
      case 'wed':
        return 3;
      case 'thu':
        return 4;
      case 'fri':
        return 5;
      case 'sat':
        return 6;
      case 'sun':
        return 7;
      default:
        return null;
    }
  }

  BangumiCalendarWeekday _fallbackWeekday(int weekday) {
    const cn = <int, String>{
      1: '星期一',
      2: '星期二',
      3: '星期三',
      4: '星期四',
      5: '星期五',
      6: '星期六',
      7: '星期日',
    };
    const en = <int, String>{
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };
    return BangumiCalendarWeekday(
      id: weekday,
      en: en[weekday] ?? '',
      cn: cn[weekday] ?? '',
      ja: '',
    );
  }
}

class WatchUpdateResult {
  final int subjectId;
  final int oldWatched;
  final int newWatched;
  final DateTime? oldLastWatchedAt;
  final DateTime? newLastWatchedAt;

  const WatchUpdateResult({
    required this.subjectId,
    required this.oldWatched,
    required this.newWatched,
    required this.oldLastWatchedAt,
    required this.newLastWatchedAt,
  });
}
