import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/bangumi_models.dart';
import 'http_retry.dart';
import 'logging.dart';

class BangumiApi {
  BangumiApi({http.Client? client, Logger? logger})
      : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _logger = logger ?? Logger();

  final http.Client _client;
  final bool _ownsClient;
  final Logger _logger;

  static const _baseUrl = 'https://api.bgm.tv';
  static const _nextBaseUrl = 'https://next.bgm.tv/p1';
  static const Duration _timeout = Duration(seconds: 12);
  static const int _maxKeywordLength = 50;
  static const int _staffPageLimit = 50;
  static const int _staffMaxItems = 200;
  static const int _episodePageLimit = 100;
  static const Duration _selfTimeout = Duration(seconds: 10);
  static const int _logTextLimit = 200;

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  String _mapBangumiError(String action, http.Response response) {
    switch (response.statusCode) {
      case 401:
      case 403:
        return '$action失败：权限不足或凭证无效';
      case 404:
        return '$action失败：资源不存在';
      case 429:
        return '$action失败：请求过于频繁，请稍后重试';
      default:
        if (response.statusCode >= 500) {
          return '$action失败：Bangumi 服务异常';
        }
        return '$action失败：请求异常 (${response.statusCode})';
    }
  }

  Map<String, String> _buildHeaders({String? accessToken}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent':
          'FlutterUTools/1.0.0 (https://github.com/yourusername/flutter_utools)',
    };
    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    return headers;
  }

  Future<BangumiUser> fetchSelf({required String accessToken}) async {
    final uri = Uri.parse('$_baseUrl/v0/me');
    final response = await sendWithRetry(
      logger: _logger,
      label: 'Bangumi fetchSelf',
      request: () => _client
          .get(
            uri,
            headers: _buildHeaders(accessToken: accessToken),
          )
          .timeout(_selfTimeout),
    );

    if (response.statusCode != 200) {
      throw Exception(_mapBangumiError('获取用户信息', response));
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return BangumiUser.fromJson(data);
  }

  Future<List<BangumiSearchItem>> search({
    required String keyword,
    String? accessToken,
  }) async {
    final normalizedKeyword = keyword.trim();
    final limitedKeyword = normalizedKeyword.length > _maxKeywordLength
        ? normalizedKeyword.substring(0, _maxKeywordLength)
        : normalizedKeyword;
    if (limitedKeyword.isEmpty) {
      throw Exception('关键词无效');
    }
    final uri = Uri.parse('$_baseUrl/v0/search/subjects');
    Future<http.Response> performSearch({String? token}) {
      return sendWithRetry(
        logger: _logger,
        label: 'Bangumi search',
        request: () => _client
            .post(
              uri,
              headers: _buildHeaders(accessToken: token),
              body: jsonEncode({
                'keyword': limitedKeyword,
                'sort': 'match',
                'filter': {
                  'type': [2], // 2 = 动画
                },
              }),
            )
            .timeout(_timeout),
      );
    }

    var response = await performSearch(token: accessToken);
    if ((response.statusCode == 401 || response.statusCode == 403) &&
        accessToken != null &&
        accessToken.isNotEmpty) {
      _logger.info(
        '[BangumiApi] search unauthorized, retrying without access token',
      );
      response = await performSearch(token: null);
    }

    if (response.statusCode != 200) {
      throw Exception(_mapBangumiError('Bangumi 搜索', response));
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final list = data['data'] as List<dynamic>? ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(BangumiSearchItem.fromJson)
        .toList();
  }

  Future<List<BangumiCalendarDay>> fetchCalendar() async {
    final uri = Uri.parse('$_baseUrl/calendar');
    final response = await sendWithRetry(
      logger: _logger,
      label: 'Bangumi calendar',
      request: () => _client
          .get(
            uri,
            headers: _buildHeaders(),
          )
          .timeout(_timeout),
    );

    if (response.statusCode != 200) {
      throw Exception(_mapBangumiError('Bangumi 放送列表', response));
    }

    final data = jsonDecode(response.body) as List<dynamic>? ?? [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(BangumiCalendarDay.fromJson)
        .toList();
  }

  Future<BangumiSubjectDetail> fetchDetail({
    required int subjectId,
    String? accessToken,
  }) async {
    // 并行获取番剧基本信息和制作人员信息
    final subjectFuture = _fetchSubjectBase(subjectId, accessToken);
    final staffFuture = _fetchStaff(subjectId);

    try {
      final results = await Future.wait([subjectFuture, staffFuture]);
      var detail = results[0] as BangumiSubjectDetail;
      final staffResponse = results[1] as StaffResponse?;

      // 如果成功获取到制作人员信息，合并到详情中
      if (staffResponse != null && staffResponse.data.isNotEmpty) {
        detail = _enrichDetailWithStaff(detail, staffResponse.data);
      }
      String clip(String value) {
        final trimmed = value.trim();
        if (trimmed.length <= _logTextLimit) return trimmed;
        return '${trimmed.substring(0, _logTextLimit)}…';
      }

      _logger.debug(
        '[DailyReco][Bangumi] detail id=${detail.id} '
        'title="${clip(detail.nameCn.isNotEmpty ? detail.nameCn : detail.name)}" '
        'score=${detail.score.toStringAsFixed(1)} year=${detail.airDate.split('-').first}',
      );
      return detail;
    } catch (e) {
      // 如果并行请求失败，尝试至少返回基本信息
      try {
        return await subjectFuture;
      } catch (e) {
        rethrow;
      }
    }
  }

  Future<BangumiSubjectDetail> fetchSubjectBase({
    required int subjectId,
    String? accessToken,
  }) async {
    return _fetchSubjectBase(subjectId, accessToken);
  }

  Future<BangumiSubjectDetail> _fetchSubjectBase(
      int subjectId, String? accessToken) async {
    final uri = Uri.parse('$_baseUrl/v0/subjects/$subjectId');
    final response = await sendWithRetry(
      logger: _logger,
      label: 'Bangumi subject detail',
      request: () => _client
          .get(
            uri,
            headers: _buildHeaders(accessToken: accessToken),
          )
          .timeout(_timeout),
    );

    if (response.statusCode != 200) {
      throw Exception(_mapBangumiError('Bangumi 详情', response));
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return BangumiSubjectDetail.fromJson(data);
  }

  Future<List<BangumiEpisode>> fetchSubjectEpisodes({
    required int subjectId,
    String? accessToken,
    int? type,
  }) async {
    final episodes = <BangumiEpisode>[];
    int offset = 0;
    int? total;

    while (true) {
      final query = <String, String>{
        'subject_id': subjectId.toString(),
        'limit': _episodePageLimit.toString(),
        'offset': offset.toString(),
        if (type != null) 'type': type.toString(),
      };
      final uri =
          Uri.parse('$_baseUrl/v0/episodes').replace(queryParameters: query);
      final response = await sendWithRetry(
        logger: _logger,
        label: 'Bangumi episodes',
        request: () => _client
            .get(
              uri,
              headers: _buildHeaders(accessToken: accessToken),
            )
            .timeout(_timeout),
      );

      if (response.statusCode != 200) {
        throw Exception(_mapBangumiError('Bangumi 绔犺妭鍒楄〃', response));
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = data['data'] as List<dynamic>? ?? [];
      episodes.addAll(
        list
            .whereType<Map<String, dynamic>>()
            .map(BangumiEpisode.fromJson),
      );
      total ??= (data['total'] as num?)?.toInt();

      if (list.length < _episodePageLimit) break;
      if (total != null && episodes.length >= total) break;

      offset += _episodePageLimit;
    }

    return episodes;
  }

  Future<int> fetchLatestEpisodeNumber({
    required int subjectId,
    String? accessToken,
    int? type = 0,
  }) async {
    final episodes = await fetchSubjectEpisodes(
      subjectId: subjectId,
      accessToken: accessToken,
      type: type,
    );
    if (episodes.isEmpty) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int pickNumber(BangumiEpisode e) {
      final value = e.ep > 0 ? e.ep : e.sort;
      return value.round();
    }

    final dated = <BangumiEpisode>[];
    for (final episode in episodes) {
      final raw = episode.airDate.trim();
      if (raw.isEmpty) continue;
      final parsed = DateTime.tryParse(raw);
      if (parsed == null) continue;
      if (!parsed.isAfter(today)) {
        dated.add(episode);
      }
    }

    List<BangumiEpisode> candidates = dated;
    if (candidates.isEmpty) {
      candidates = episodes
          .where((e) => e.airDate.trim().isNotEmpty)
          .toList();
    }
    if (candidates.isEmpty) return 0;

    final best = candidates.reduce((a, b) {
      final av = pickNumber(a);
      final bv = pickNumber(b);
      return av >= bv ? a : b;
    });
    return pickNumber(best);
  }

  Future<String?> fetchLastEpisodeAirDate({
    required int subjectId,
    int? totalEpisodes,
    String? accessToken,
  }) async {
    final episodes = await fetchSubjectEpisodes(
      subjectId: subjectId,
      accessToken: accessToken,
      type: 0,
    );
    if (episodes.isEmpty) return null;

    final candidates =
        episodes.where((e) => e.airDate.trim().isNotEmpty).toList();
    if (candidates.isEmpty) return null;

    BangumiEpisode? target;
    if (totalEpisodes != null && totalEpisodes > 0) {
      final matches = candidates.where((e) {
        final sort = e.sort.round();
        final ep = e.ep.round();
        return sort == totalEpisodes || ep == totalEpisodes;
      }).toList();
      if (matches.isNotEmpty) {
        target = matches.reduce((a, b) => a.sort >= b.sort ? a : b);
      }
    }

    target ??= candidates.reduce((a, b) => a.sort >= b.sort ? a : b);
    return target.airDate.trim();
  }

  Future<StaffResponse?> _fetchStaff(int subjectId) async {
    try {
      final allStaff = <BangumiStaff>[];
      int offset = 0;
      const limit = _staffPageLimit; // 使用分页获取所有 staff，避免单次 limit 过大出错
      int? total;

      while (true) {
        final uri = Uri.parse(
            '$_nextBaseUrl/subjects/$subjectId/staffs/persons?limit=$limit&offset=$offset');
        final response = await sendWithRetry(
          logger: _logger,
          label: 'Bangumi staff',
          request: () => _client
              .get(
                uri,
                headers: _buildHeaders(), // p1 API ????? Token
              )
              .timeout(_timeout),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final pageResponse = StaffResponse.fromJson(data);
          total ??= pageResponse.total > 0 ? pageResponse.total : null;

          if (pageResponse.data.isEmpty) {
            break;
          }

          allStaff.addAll(pageResponse.data);

          if (total != null && allStaff.length >= total) {
            break;
          }

          if (allStaff.length >= _staffMaxItems) {
            _logger.info(
                '[BangumiApi] fetchStaff reached max cap $_staffMaxItems for subject $subjectId');
            break;
          }

          offset += limit;
        } else {
          _logger.error(
              '[BangumiApi] fetchStaff error: ${response.statusCode} at offset $offset');
          break;
        }
      }

      if (allStaff.isNotEmpty) {
        return StaffResponse(
          total: allStaff.length,
          limit: allStaff.length,
          offset: 0,
          data: allStaff,
        );
      }
    } catch (e) {
      _logger.error('[BangumiApi] fetchStaff failed: $e');
    }
    return null;
  }

  BangumiSubjectDetail _enrichDetailWithStaff(
      BangumiSubjectDetail detail, List<BangumiStaff> staffList) {
    // 提取各类职位的人员
    final normalized = {
      '动画制作': <String>{},
      '导演': <String>{},
      '脚本': <String>{},
      '分镜': <String>{},
    };
    final studios = <String>{};
    // 回退：标准化失败时，仍保留原始职位，便于 UI 展示/发现同义词
    final Map<String, Set<String>> rawJobBuckets = {};

    // debug 模式一次性采样日志：前 N 条 staff 的 job 原始值与标准化结果
    // 目的：方便发现新同义词/字段变化；release 不输出。
    final bool shouldLogSample =
        _logger.level.index >= LogLevel.debug.index && staffList.isNotEmpty;
    int logged = 0;
    const int logLimit = 12;

    for (final staff in staffList) {
      final jobs = staff.jobs ?? [];
      final name = staff.nameCn ?? staff.name;

      if (jobs.isEmpty) continue;

      for (final job in jobs) {
        final normalizedKey = _normalizeStaffJob(job);

        if (shouldLogSample && logged < logLimit) {
          _logger.debug(
              '[BangumiApi] staff sample subject=${detail.id} name=$name job="$job" => ${normalizedKey ?? "(unmapped)"}');
          logged++;
        }

        if (normalizedKey != null) {
          normalized[normalizedKey]?.add(name);
        } else {
          if (!_isStudioJob(job)) {
            rawJobBuckets.putIfAbsent(job, () => <String>{}).add(name);
          }
        }
        if (_isStudioJob(job)) {
          studios.add(name);
        }
      }
    }

    final directors = normalized['导演']?.toList() ?? [];
    final scripts = normalized['脚本']?.toList() ?? [];
    final storyboards = normalized['分镜']?.toList() ?? [];
    final productions = normalized['动画制作']?.toList() ?? [];

    // 更新 infoboxMap (UI 使用此 Map 显示)
    final newInfoboxMap = Map<String, String>.from(detail.infoboxMap);

    void updateField(String key, List<String> values) {
      if (values.isNotEmpty) {
        // 如果 API 返回的数据更全，优先使用（这里简单地覆盖或追加）
        // 策略：如果原数据没有，直接写入。如果原数据有，合并去重。
        final existing = newInfoboxMap[key]?.split('、') ?? [];
        final merged = {...existing, ...values}.join('、');
        newInfoboxMap[key] = merged;
      }
    }

    updateField('导演', directors);
    updateField('脚本', scripts);
    updateField('分镜', storyboards);
    updateField('动画制作', productions);
    // 制作会社有时也叫制作
    if (studios.isNotEmpty) {
      updateField('制作', studios.toList());
    }

    // 将未标准化命中的职位也写入 infoboxMap（做上限，避免过度膨胀）
    if (rawJobBuckets.isNotEmpty) {
      final keys = rawJobBuckets.keys.toList()..sort();
      for (final key in keys.take(30)) {
        updateField(key, rawJobBuckets[key]!.toList());
      }
    }

    // 同时更新字段
    return detail.copyWith(
      director: directors.isNotEmpty ? directors.join('、') : detail.director,
      script: scripts.isNotEmpty ? scripts.join('、') : detail.script,
      storyboard:
          storyboards.isNotEmpty ? storyboards.join('、') : detail.storyboard,
      animationProduction: productions.isNotEmpty
          ? productions.join('、')
          : detail.animationProduction,
      studio: studios.isNotEmpty ? studios.join('、') : detail.studio,
      infoboxMap: newInfoboxMap,
    );
  }

  String? _normalizeStaffJob(String job) {
    var normalized = job.trim();
    if (normalized.isEmpty) return null;

    // 统一常见分隔符/空白，避免因为格式差异导致 contains 匹配失败
    normalized = normalized
        .replaceAll('：', ':')
        .replaceAll('／', '/')
        .replaceAll(RegExp(r'\s+'), ' ');
    final lower = normalized.toLowerCase();

    if (_isLikelyDirectorJob(normalized, lower)) {
      return '导演';
    }

    if (_matchesAny(lower, const [
      'script',
      'screenplay',
      'series composition',
      'series compose',
      '脚本',
      '剧本',
      '系列构成',
      '構成',
      'シリーズ構成',
    ])) {
      return '脚本';
    }

    if (_matchesAny(lower, const [
      'storyboard',
      '分镜',
      '分鏡',
      '絵コンテ',
      'コンテ',
      // 注意：项目里历史上出现过“绘コンテ”这种混用写法
      '绘コンテ',
      '绘コンテ',
      '绘コンテ',
      '绘コン테',
    ])) {
      return '分镜';
    }

    if (_matchesAny(lower, const [
      'animation work',
      'animation production',
      'animation',
      '动画制作',
      'アニメーション制作',
      // 常见等价：岗位里会直接写 studio
      'studio',
    ])) {
      return '动画制作';
    }

    return null;
  }

  bool _matchesAny(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword.toLowerCase()));
  }

  bool _isLikelyDirectorJob(String normalized, String lower) {
    final compact = normalized.replaceAll(RegExp(r'\s+'), '');
    const cnExact = {
      '导演',
      '总导演',
      '系列导演',
      '监督',
      '監督',
    };
    const enExact = {
      'director',
      'director/direction',
      'chief director',
      'series director',
    };

    if (cnExact.contains(compact)) {
      return true;
    }

    if (enExact.contains(lower)) {
      return true;
    }

    return false;
  }

  bool _isStudioJob(String job) {
    final normalized = job.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    if (normalized == '制作' || normalized == '制作会社') return true;
    if (normalized.contains('制作会社') ||
        normalized.contains('制作') ||
        normalized.contains('studio')) {
      return true;
    }
    return false;
  }

  Future<List<BangumiComment>> fetchSubjectComments({
    required int subjectId,
    String? accessToken,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // 使用 p1 API 获取评论
      final uri = Uri.parse(
          '$_nextBaseUrl/subjects/$subjectId/comments?limit=$limit&offset=$offset');
      final response = await sendWithRetry(
        logger: _logger,
        label: 'Bangumi comments',
        request: () => _client
            .get(
              uri,
              headers: _buildHeaders(accessToken: accessToken),
            )
            .timeout(_timeout),
      );

      if (response.statusCode != 200) {
        _logger.error(
            '[BangumiApi] fetchSubjectComments error: ${response.statusCode} for $uri');
        return [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = data['data'] as List<dynamic>? ?? [];

      return list
          .map((e) => BangumiComment.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _logger.error('[BangumiApi] fetchSubjectComments failed: $e');
      return [];
    }
  }
}
