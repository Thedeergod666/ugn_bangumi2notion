import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/bangumi_models.dart';
import '../services/bangumi_api.dart';
import '../models/mapping_config.dart';
import '../models/notion_models.dart';

class NotionApi {
  static const String _baseUrl = 'https://api.notion.com/v1';
  static const String _notionVersion = '2022-06-28';
  static const Duration _timeout = Duration(seconds: 12);
  static const Duration _queryTimeout = Duration(seconds: 30);
  static const Duration _blocksTimeout = Duration(seconds: 20);
  static const double defaultYougnScoreThreshold = 6.5;
  static const int _dailyRecommendationMaxQueryItems = 200;
  static const int _dailyRecommendationTargetItems = 50;
  static const int _logTextLimit = 200;

  String? _normalizePageId(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    final urlMatch = RegExp(r"https?://(www\.)?notion\.so/.+").hasMatch(trimmed);
    final raw = urlMatch ? _extractPageIdFromUrl(trimmed) : trimmed;
    if (raw == null) return null;
    final cleaned = raw.replaceAll('-', '').toLowerCase();
    if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(cleaned)) {
      return null;
    }
    return cleaned;
  }

  String? _extractPageIdFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      if (segments.isEmpty) return null;
      final last = segments.last;
      final match = RegExp(r'([0-9a-fA-F]{32})').firstMatch(last);
      return match?.group(1);
    } catch (_) {
      return null;
    }
  }

  String _mapNotionError(String action, http.Response response) {
    try {
      final body = jsonDecode(response.body);
      // 优先显示 Notion 返回的具体错误信息
      if (body is Map && body.containsKey('message')) {
        final message = body['message'].toString();
        // 如果是常见的属性不存在错误，进行中文化优化
        if (message.contains('does not exist')) {
          return '$action失败：$message。请检查 Notion 数据库属性名称是否匹配。';
        }
        return '$action失败：$message';
      }
    } catch (_) {
      // JSON 解析失败，忽略
    }

    switch (response.statusCode) {
      case 401:
      case 403:
        return '$action失败：权限不足或凭证无效 (HTTP ${response.statusCode})';
      case 404:
        return '$action失败：资源不存在 (HTTP 404)';
      case 429:
        return '$action失败：请求过于频繁，请稍后重试';
      default:
        if (response.statusCode >= 500) {
          return '$action失败：Notion 服务异常 (HTTP ${response.statusCode})';
        }
        return '$action失败：请求异常 (HTTP ${response.statusCode})';
    }
  }

  String? normalizePageId(String input) => _normalizePageId(input);

  double? _extractNumberValue(Map<String, dynamic> property) {
    final number = property['number'];
    if (number is num) return number.toDouble();
    if (number is String) return double.tryParse(number);
    return null;
  }

  int? _extractIntValue(Map<String, dynamic> property) {
    final number = _extractNumberValue(property);
    if (number != null) return number.round();
    final text = _extractPlainText(property);
    if (text == null || text.isEmpty) return null;
    final match = RegExp(r'(\d+)').firstMatch(text);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  String? _extractPlainText(Map<String, dynamic> property) {
    if (property.containsKey('title')) {
      final List<dynamic>? title = property['title'];
      if (title == null || title.isEmpty) return null;
      return title
          .map((e) => e['plain_text'] ?? '')
          .join()
          .trim();
    }
    if (property.containsKey('rich_text')) {
      final List<dynamic>? text = property['rich_text'];
      if (text == null || text.isEmpty) return null;
      return text
          .map((e) => e['plain_text'] ?? '')
          .join()
          .trim();
    }
    return null;
  }

  double? _parseScoreFromText(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(trimmed);
    if (match == null) return null;
    return double.tryParse(match.group(1)!);
  }

  String? _extractRichTextPlain(Map<String, dynamic> block, String key) {
    final data = block[key];
    if (data is! Map<String, dynamic>) return null;
    final richText = data['rich_text'];
    if (richText is! List || richText.isEmpty) return null;
    final text = richText
        .map((e) => e is Map<String, dynamic> ? (e['plain_text'] ?? '').toString() : '')
        .join()
        .trim();
    return text.isEmpty ? null : text;
  }

  String? _extractImageUrlFromBlock(Map<String, dynamic> block) {
    if (block['type'] != 'image') return null;
    final image = block['image'] as Map<String, dynamic>?;
    if (image == null) return null;
    final type = image['type']?.toString();
    if (type == 'external') {
      return image['external']?['url']?.toString();
    }
    if (type == 'file') {
      return image['file']?['url']?.toString();
    }
    return null;
  }

  String? _extractTextFromBlock(Map<String, dynamic> block) {
    final type = block['type']?.toString();
    if (type == null) return null;
    switch (type) {
      case 'paragraph':
      case 'heading_1':
      case 'heading_2':
      case 'heading_3':
      case 'bulleted_list_item':
      case 'numbered_list_item':
      case 'quote':
      case 'callout':
        return _extractRichTextPlain(block, type);
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _fetchPageBlocks({
    required String token,
    required String pageId,
  }) async {
    final normalizedId = _normalizePageId(pageId);
    if (normalizedId == null) {
      throw Exception('Notion 页面 ID 无效');
    }
    final blocks = <Map<String, dynamic>>[];
    String? nextCursor;
    bool hasMore = true;

    int pageCount = 0;
    final totalSw = Stopwatch()..start();
    while (hasMore) {
      pageCount += 1;
      final pageSw = Stopwatch()..start();
      final query = <String, String>{};
      if (nextCursor != null && nextCursor.isNotEmpty) {
        query['start_cursor'] = nextCursor;
      }
      final url = Uri.parse(_baseUrl).replace(
        pathSegments: ['v1', 'blocks', normalizedId, 'children'],
        queryParameters: query.isEmpty ? null : query,
      );
      final response = await http
          .get(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Notion-Version': _notionVersion,
            },
          )
          .timeout(_blocksTimeout);

      developer.log(
        'Notion blocks.children page $pageCount finished in ${pageSw.elapsedMilliseconds}ms'
        ' (status=${response.statusCode})',
      );

      if (response.statusCode != 200) {
        throw Exception(_mapNotionError('读取页面正文', response));
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];
      for (final item in results) {
        if (item is Map<String, dynamic>) {
          blocks.add(item);
        }
      }
      hasMore = data['has_more'] == true;
      nextCursor = data['next_cursor']?.toString();
    }

    developer.log(
      'Notion blocks.children total ${blocks.length} blocks in '
      '${totalSw.elapsedMilliseconds}ms',
    );

    return blocks;
  }

  Future<({String? coverUrl, String? longReview})> getPageContent({
    required String token,
    required String pageId,
  }) async {
    final sw = Stopwatch()..start();
    final blocks = await _fetchPageBlocks(token: token, pageId: pageId);
    String? coverUrl;
    final paragraphs = <String>[];
    for (final block in blocks) {
      coverUrl ??= _extractImageUrlFromBlock(block);
      final text = _extractTextFromBlock(block);
      if (text != null && text.isNotEmpty) {
        paragraphs.add(text);
      }
    }
    final longReview = paragraphs.isEmpty ? null : paragraphs.join('\n');
    developer.log(
      'getPageContent parsed ${blocks.length} blocks in ${sw.elapsedMilliseconds}ms',
    );
    return (coverUrl: coverUrl, longReview: longReview);
  }

  Future<String?> _resolveBangumiCover({
    required String? bangumiId,
    required String? subjectId,
  }) async {
    final sw = Stopwatch()..start();
    int? id;
    if (subjectId != null && subjectId.trim().isNotEmpty) {
      id = int.tryParse(subjectId.trim());
    }
    if (id == null && bangumiId != null && bangumiId.trim().isNotEmpty) {
      id = int.tryParse(bangumiId.trim());
    }
    if (id == null) return null;
    try {
      final detail = await BangumiApi().fetchDetail(subjectId: id);
      developer.log(
        'Bangumi cover fallback in ${sw.elapsedMilliseconds}ms (id=$id)',
      );
      return detail.imageUrl.isNotEmpty ? detail.imageUrl : null;
    } catch (e) {
      developer.log('Bangumi cover fallback failed: $e');
      return null;
    }
  }

  List<String> _extractMultiSelect(Map<String, dynamic> property) {
    final List<dynamic>? items = property['multi_select'];
    if (items == null) return [];
    return items
        .map((e) => e['name']?.toString() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String? _extractSelect(Map<String, dynamic> property) {
    final Map<String, dynamic>? item = property['select'];
    if (item == null) return null;
    final name = item['name']?.toString() ?? '';
    return name.isEmpty ? null : name;
  }

  DateTime? _extractDate(Map<String, dynamic> property) {
    final Map<String, dynamic>? date = property['date'];
    if (date == null) return null;
    final start = date['start']?.toString();
    if (start == null || start.isEmpty) return null;
    return DateTime.tryParse(start);
  }

  String? _extractUrl(Map<String, dynamic> property) {
    final url = property['url']?.toString() ?? '';
    return url.isEmpty ? null : url;
  }

  String? _extractFallbackText(Map<String, dynamic> property) {
    return _extractPlainText(property) ??
        _extractSelect(property) ??
        _extractUrl(property);
  }

  Map<String, String> _buildPropertyTypeMap(List<NotionProperty> properties) {
    return {
      for (final property in properties) property.name: property.type,
    };
  }

  Map<String, dynamic>? _buildStatusFilter({
    required String propertyName,
    required String propertyType,
    required String value,
  }) {
    if (propertyName.trim().isEmpty || value.trim().isEmpty) return null;
    switch (propertyType) {
      case 'status':
        return {
          'property': propertyName,
          'status': {'equals': value},
        };
      case 'select':
        return {
          'property': propertyName,
          'select': {'equals': value},
        };
      case 'multi_select':
        return {
          'property': propertyName,
          'multi_select': {'contains': value},
        };
      case 'rich_text':
      case 'title':
        return {
          'property': propertyName,
          'rich_text': {'equals': value},
        };
    }
    return null;
  }

  Future<void> testConnection({
    required String token,
    required String databaseId,
  }) async {
    final normalizedDatabaseId = _normalizePageId(databaseId);
    if (normalizedDatabaseId == null) {
      throw Exception('Notion Database ID 无效');
    }
    final url = Uri.parse(_baseUrl)
        .replace(pathSegments: ['v1', 'databases', normalizedDatabaseId]);
    final response = await http
        .get(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Notion-Version': _notionVersion,
          },
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception(_mapNotionError('Notion 连接', response));
    }
  }

  Future<List<NotionProperty>> getDatabaseProperties({
    required String token,
    required String databaseId,
  }) async {
    final normalizedDatabaseId = _normalizePageId(databaseId);
    if (normalizedDatabaseId == null) {
      throw Exception('Notion Database ID 无效');
    }
    final url = Uri.parse(_baseUrl)
        .replace(pathSegments: ['v1', 'databases', normalizedDatabaseId]);
    final response = await http
        .get(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Notion-Version': _notionVersion,
          },
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final properties = data['properties'] as Map<String, dynamic>?;
      if (properties != null) {
        return properties.entries.map((e) {
          final val = e.value as Map<String, dynamic>;
          return NotionProperty(
            name: e.key,
            type: val['type'] ?? '',
          );
        }).toList();
      }
      return [];
    }

    throw Exception(_mapNotionError('获取数据库属性', response));
  }

  Future<DailyRecommendation?> getDailyRecommendation({
    required String token,
    required String databaseId,
    required NotionDailyRecommendationBindings bindings,
    double minScore = defaultYougnScoreThreshold,
  }) async {
    final totalSw = Stopwatch()..start();
    final normalizedDatabaseId = _normalizePageId(databaseId);
    if (normalizedDatabaseId == null) {
      throw Exception('Notion Database ID 无效');
    }
    if (bindings.yougnScore.isEmpty) {
      throw Exception('未配置悠gn评分映射字段');
    }

    final url = Uri.parse(_baseUrl)
        .replace(pathSegments: ['v1', 'databases', normalizedDatabaseId, 'query']);

    String? yougnScoreType;
    try {
      final properties = await getDatabaseProperties(
        token: token,
        databaseId: normalizedDatabaseId,
      );
      yougnScoreType = properties
          .firstWhere(
            (p) => p.name == bindings.yougnScore,
            orElse: () => NotionProperty(name: bindings.yougnScore, type: ''),
          )
          .type;
    } catch (e) {
      developer.log('Schema fetch failed in getDailyRecommendation: $e');
    }

    bool useNumberFilter = yougnScoreType == 'number';
    List<dynamic> results = [];
    String? nextCursor;
    bool hasMore = true;

    int pageCount = 0;
    while (hasMore && results.length < _dailyRecommendationMaxQueryItems) {
      pageCount += 1;
      final pageSw = Stopwatch()..start();
      final body = <String, dynamic>{};
      if (useNumberFilter) {
        body['filter'] = {
          'property': bindings.yougnScore,
          'number': {
            'greater_than_or_equal_to': minScore,
          },
        };
      }
      if (nextCursor != null && nextCursor.isNotEmpty) {
        body['start_cursor'] = nextCursor;
      }
      final requestBody = jsonEncode(body);
      final response = await http
          .post(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Notion-Version': _notionVersion,
              'Content-Type': 'application/json',
            },
            body: requestBody,
          )
          .timeout(_queryTimeout);

      developer.log(
        'Notion databases.query page $pageCount finished in '
        '${pageSw.elapsedMilliseconds}ms (status=${response.statusCode})',
      );

      if (response.statusCode != 200) {
        throw Exception(_mapNotionError('获取每日推荐', response));
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final pageResults = data['results'] as List<dynamic>;
      results.addAll(pageResults);
      hasMore = data['has_more'] == true;
      nextCursor = data['next_cursor']?.toString();
      if (useNumberFilter && results.length >= _dailyRecommendationTargetItems) {
        hasMore = false;
      }
    }

    if (!useNumberFilter) {
      results = results.where((item) {
        if (item is! Map<String, dynamic>) return false;
        final properties = item['properties'] as Map<String, dynamic>? ?? {};
        final scoreProperty = properties[bindings.yougnScore] as Map<String, dynamic>?;
        if (scoreProperty == null) return false;
        final rawText = _extractPlainText(scoreProperty);
        final score = _parseScoreFromText(rawText);
        return score != null && score >= minScore;
      }).toList();
    }

    developer.log(
      'getDailyRecommendation query done: pages=$pageCount, results=${results.length}, '
      'elapsed=${totalSw.elapsedMilliseconds}ms',
    );

    if (kDebugMode) {
      final ids = results
          .whereType<Map<String, dynamic>>()
          .map((item) => item['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      final sampleIds = ids.take(5).map((id) => id.length > 8 ? id.substring(0, 8) : id).toList();
      developer.log(
        '[DailyReco][Notion] results=${results.length} pageIds=${sampleIds.join(",")}',
      );
    }

    if (results.isEmpty) {
      return null;
    }

    final randomIndex = Random().nextInt(results.length);
    final page = results[randomIndex] as Map<String, dynamic>;
    final properties = page['properties'] as Map<String, dynamic>? ?? {};

    String? readText(String key) {
      if (key.isEmpty) return null;
      final property = properties[key] as Map<String, dynamic>?;
      if (property == null) return null;
      return _extractFallbackText(property);
    }

    double? readNumber(String key) {
      if (key.isEmpty) return null;
      final property = properties[key] as Map<String, dynamic>?;
      if (property == null) return null;
      return _extractNumberValue(property);
    }

    double? readScoreFallback(String key) {
      if (key.isEmpty) return null;
      final property = properties[key] as Map<String, dynamic>?;
      if (property == null) return null;
      return _parseScoreFromText(_extractPlainText(property));
    }

    DateTime? readDate(String key) {
      if (key.isEmpty) return null;
      final property = properties[key] as Map<String, dynamic>?;
      if (property == null) return null;
      return _extractDate(property);
    }

    List<String> readTags(String key) {
      if (key.isEmpty) return [];
      final property = properties[key] as Map<String, dynamic>?;
      if (property == null) return [];
      return _extractMultiSelect(property);
    }

    String? readSelect(String key) {
      if (key.isEmpty) return null;
      final property = properties[key] as Map<String, dynamic>?;
      if (property == null) return null;
      return _extractSelect(property) ?? _extractPlainText(property);
    }

    final title = readText(bindings.title) ?? '';
    if (title.isEmpty) {
      throw Exception('每日推荐解析失败：标题字段为空或类型不匹配');
    }

    final score = readNumber(bindings.yougnScore) ?? readScoreFallback(bindings.yougnScore);
    if (score == null) {
      throw Exception('每日推荐解析失败：评分字段类型不匹配');
    }

    final pageId = page['id']?.toString();
    String? contentLongReview;
    if (pageId != null && pageId.isNotEmpty && bindings.longReview.isEmpty) {
      try {
        final content = await getPageContent(token: token, pageId: pageId);
        contentLongReview = content.longReview;
      } catch (e) {
        developer.log('读取 Notion 正文失败: $e');
      }
    }

    final bangumiId = readText(bindings.bangumiId ?? '');
    final subjectId = readText(bindings.subjectId ?? '');
    final bangumiCover = await _resolveBangumiCover(
      bangumiId: bangumiId,
      subjectId: subjectId,
    );

    if (kDebugMode) {
      String clip(String? value) {
        if (value == null) return '';
        final trimmed = value.trim();
        if (trimmed.length <= _logTextLimit) return trimmed;
        return '${trimmed.substring(0, _logTextLimit)}…';
      }

      final tags = readTags(bindings.tags);
      developer.log(
        '[DailyReco][Notion] pick title="${clip(title)}" '
        'score=${score.toStringAsFixed(1)} '
        'pageId=${pageId != null ? (pageId.length > 8 ? pageId.substring(0, 8) : pageId) : ""} '
        'bangumiId=${clip(bangumiId)} subjectId=${clip(subjectId)} '
        'type=${clip(readSelect(bindings.type))} tags=${tags.take(6).join("/")}',
      );
    }

    developer.log(
      'getDailyRecommendation total elapsed=${totalSw.elapsedMilliseconds}ms',
    );

    return DailyRecommendation(
      title: title,
      yougnScore: score,
      airDate: readDate(bindings.airDate),
      tags: readTags(bindings.tags),
      type: readSelect(bindings.type),
      shortReview: readText(bindings.shortReview),
      longReview: readText(bindings.longReview),
      cover: bangumiCover,
      contentCoverUrl: null,
      contentLongReview: contentLongReview,
      bangumiId: bangumiId,
      subjectId: subjectId,
    );
  }

  Future<List<DailyRecommendation>> getDailyRecommendationCandidates({
    required String token,
    required String databaseId,
    required NotionDailyRecommendationBindings bindings,
    double minScore = defaultYougnScoreThreshold,
  }) async {
    final totalSw = Stopwatch()..start();
    final normalizedDatabaseId = _normalizePageId(databaseId);
    if (normalizedDatabaseId == null) {
      throw Exception('Notion Database ID 无效');
    }
    if (bindings.yougnScore.isEmpty) {
      throw Exception('未配置悠gn评分映射字段');
    }

    final url = Uri.parse(_baseUrl)
        .replace(pathSegments: ['v1', 'databases', normalizedDatabaseId, 'query']);

    String? yougnScoreType;
    try {
      final properties = await getDatabaseProperties(
        token: token,
        databaseId: normalizedDatabaseId,
      );
      yougnScoreType = properties
          .firstWhere(
            (p) => p.name == bindings.yougnScore,
            orElse: () => NotionProperty(name: bindings.yougnScore, type: ''),
          )
          .type;
    } catch (e) {
      developer.log('Schema fetch failed in getDailyRecommendationCandidates: $e');
    }

    final useNumberFilter = yougnScoreType == 'number';
    List<dynamic> results = [];
    String? nextCursor;
    bool hasMore = true;

    int pageCount = 0;
    while (hasMore && results.length < _dailyRecommendationMaxQueryItems) {
      pageCount += 1;
      final pageSw = Stopwatch()..start();
      final body = <String, dynamic>{};
      if (useNumberFilter) {
        body['filter'] = {
          'property': bindings.yougnScore,
          'number': {
            'greater_than_or_equal_to': minScore,
          },
        };
      }
      if (nextCursor != null && nextCursor.isNotEmpty) {
        body['start_cursor'] = nextCursor;
      }
      final requestBody = jsonEncode(body);
      final response = await http
          .post(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Notion-Version': _notionVersion,
              'Content-Type': 'application/json',
            },
            body: requestBody,
          )
          .timeout(_queryTimeout);

      developer.log(
        'Notion databases.query page $pageCount finished in '
        '${pageSw.elapsedMilliseconds}ms (status=${response.statusCode})',
      );

      if (response.statusCode != 200) {
        throw Exception(_mapNotionError('获取每日推荐', response));
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final pageResults = data['results'] as List<dynamic>;
      results.addAll(pageResults);
      hasMore = data['has_more'] == true;
      nextCursor = data['next_cursor']?.toString();
      if (useNumberFilter && results.length >= _dailyRecommendationTargetItems) {
        hasMore = false;
      }
    }

    if (!useNumberFilter) {
      results = results.where((item) {
        if (item is! Map<String, dynamic>) return false;
        final properties = item['properties'] as Map<String, dynamic>? ?? {};
        final scoreProperty = properties[bindings.yougnScore] as Map<String, dynamic>?;
        if (scoreProperty == null) return false;
        final rawText = _extractPlainText(scoreProperty);
        final score = _parseScoreFromText(rawText);
        return score != null && score >= minScore;
      }).toList();
    }

    developer.log(
      'getDailyRecommendationCandidates query done: pages=$pageCount, results=${results.length}, '
      'elapsed=${totalSw.elapsedMilliseconds}ms',
    );

    if (kDebugMode) {
      final ids = results
          .whereType<Map<String, dynamic>>()
          .map((item) => item['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      final sampleIds = ids.take(5).map((id) => id.length > 8 ? id.substring(0, 8) : id).toList();
      developer.log(
        '[DailyReco][Notion] candidates=${results.length} pageIds=${sampleIds.join(",")}',
      );
    }

    if (results.isEmpty) {
      return [];
    }

    String? readText(Map<String, dynamic> properties, String key) {
      if (key.isEmpty) return null;
      final property = properties[key] as Map<String, dynamic>?;
      if (property == null) return null;
      return _extractFallbackText(property);
    }

    double? readNumber(Map<String, dynamic> properties, String key) {
      if (key.isEmpty) return null;
      final property = properties[key] as Map<String, dynamic>?;
      if (property == null) return null;
      return _extractNumberValue(property);
    }

    double? readScoreFallback(Map<String, dynamic> properties, String key) {
      if (key.isEmpty) return null;
      final property = properties[key] as Map<String, dynamic>?;
      if (property == null) return null;
      return _parseScoreFromText(_extractPlainText(property));
    }

    DateTime? readDate(Map<String, dynamic> properties, String key) {
      if (key.isEmpty) return null;
      final property = properties[key] as Map<String, dynamic>?;
      if (property == null) return null;
      return _extractDate(property);
    }

    List<String> readTags(Map<String, dynamic> properties, String key) {
      if (key.isEmpty) return [];
      final property = properties[key] as Map<String, dynamic>?;
      if (property == null) return [];
      return _extractMultiSelect(property);
    }

    String? readSelect(Map<String, dynamic> properties, String key) {
      if (key.isEmpty) return null;
      final property = properties[key] as Map<String, dynamic>?;
      if (property == null) return null;
      return _extractSelect(property) ?? _extractPlainText(property);
    }

    final Map<String, String?> coverCache = {};
    final candidates = <DailyRecommendation>[];
    for (final item in results) {
      if (item is! Map<String, dynamic>) continue;
      final properties = item['properties'] as Map<String, dynamic>? ?? {};
      final title = readText(properties, bindings.title) ?? '';
      if (title.isEmpty) continue;

      final score = readNumber(properties, bindings.yougnScore) ??
          readScoreFallback(properties, bindings.yougnScore);
      if (score == null) continue;

      final bangumiId = readText(properties, bindings.bangumiId ?? '');
      final subjectId = readText(properties, bindings.subjectId ?? '');
      final coverKey = (subjectId?.trim().isNotEmpty == true)
          ? subjectId!.trim()
          : (bangumiId?.trim().isNotEmpty == true ? bangumiId!.trim() : '');
      String? cover = coverKey.isNotEmpty ? coverCache[coverKey] : null;
      if (coverKey.isNotEmpty && cover == null) {
        cover = await _resolveBangumiCover(
          bangumiId: bangumiId,
          subjectId: subjectId,
        );
        coverCache[coverKey] = cover;
      }

      candidates.add(
        DailyRecommendation(
          title: title,
          yougnScore: score,
          airDate: readDate(properties, bindings.airDate),
          tags: readTags(properties, bindings.tags),
          type: readSelect(properties, bindings.type),
          shortReview: readText(properties, bindings.shortReview),
          longReview: readText(properties, bindings.longReview),
          cover: cover,
          contentCoverUrl: null,
          contentLongReview: null,
          bangumiId: bangumiId,
          subjectId: subjectId,
        ),
      );
    }

    developer.log(
      'getDailyRecommendationCandidates total elapsed=${totalSw.elapsedMilliseconds}ms',
    );

    return candidates;
  }

  int? _extractBangumiIdFromProperty(
    Map<String, dynamic> property,
    String propertyType,
  ) {
    if (propertyType == 'number') {
      final number = _extractNumberValue(property);
      return number?.round();
    }
    final text = _extractPlainText(property);
    if (text == null || text.isEmpty) return null;
    return int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), ''));
  }

  Future<Set<int>> getBangumiIdSet({
    required String token,
    required String databaseId,
    required String propertyName,
    String? statusPropertyName,
    String? statusValue,
  }) async {
    final normalizedDatabaseId = _normalizePageId(databaseId);
    if (normalizedDatabaseId == null) {
      throw Exception('Notion Database ID 无效');
    }
    if (propertyName.trim().isEmpty) {
      return <int>{};
    }

    String propertyType = 'number';
    String statusPropertyType = '';
    try {
      final properties = await getDatabaseProperties(
        token: token,
        databaseId: normalizedDatabaseId,
      );
      final typeMap = _buildPropertyTypeMap(properties);
      propertyType = typeMap[propertyName] ?? 'number';
      if (statusPropertyName != null && statusPropertyName.trim().isNotEmpty) {
        statusPropertyType = typeMap[statusPropertyName] ?? '';
      }
    } catch (e) {
      developer.log('Schema fetch failed in getBangumiIdSet: $e');
    }

    final url = Uri.parse(_baseUrl)
        .replace(pathSegments: ['v1', 'databases', normalizedDatabaseId, 'query']);
    final ids = <int>{};
    String? nextCursor;
    bool hasMore = true;
    int pageCount = 0;

    final statusFilter = (statusPropertyName != null &&
            statusValue != null &&
            statusPropertyName.trim().isNotEmpty &&
            statusValue.trim().isNotEmpty)
        ? _buildStatusFilter(
            propertyName: statusPropertyName,
            propertyType: statusPropertyType,
            value: statusValue.trim(),
          )
        : null;

    while (hasMore) {
      pageCount += 1;
      final body = <String, dynamic>{};
      if (nextCursor != null && nextCursor.isNotEmpty) {
        body['start_cursor'] = nextCursor;
      }
      if (statusFilter != null) {
        body['filter'] = statusFilter;
      }
      final response = await http
          .post(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Notion-Version': _notionVersion,
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(_queryTimeout);

      if (response.statusCode != 200) {
        throw Exception(_mapNotionError('读取 Bangumi ID 列表', response));
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];
      for (final item in results) {
        if (item is! Map<String, dynamic>) continue;
        final properties = item['properties'] as Map<String, dynamic>? ?? {};
        final property = properties[propertyName] as Map<String, dynamic>?;
        if (property == null) continue;
        final id = _extractBangumiIdFromProperty(property, propertyType);
        if (id != null && id > 0) {
          ids.add(id);
        }
      }
      hasMore = data['has_more'] == true;
      nextCursor = data['next_cursor']?.toString();
    }

    developer.log(
      'getBangumiIdSet done: pages=$pageCount ids=${ids.length}',
    );
    return ids;
  }

  Future<Map<int, int>> getBangumiProgressMap({
    required String token,
    required String databaseId,
    required String idPropertyName,
    String? watchedEpisodesProperty,
    String? statusPropertyName,
    String? statusValue,
  }) async {
    final normalizedDatabaseId = _normalizePageId(databaseId);
    if (normalizedDatabaseId == null) {
      throw Exception('Notion Database ID 无效');
    }
    if (idPropertyName.trim().isEmpty) {
      return <int, int>{};
    }

    String idPropertyType = 'number';
    String watchedPropertyType = 'number';
    String statusPropertyType = '';
    try {
      final properties = await getDatabaseProperties(
        token: token,
        databaseId: normalizedDatabaseId,
      );
      final typeMap = _buildPropertyTypeMap(properties);
      idPropertyType = typeMap[idPropertyName] ?? 'number';
      if (watchedEpisodesProperty != null &&
          watchedEpisodesProperty.trim().isNotEmpty) {
        watchedPropertyType = typeMap[watchedEpisodesProperty] ?? 'number';
      }
      if (statusPropertyName != null && statusPropertyName.trim().isNotEmpty) {
        statusPropertyType = typeMap[statusPropertyName] ?? '';
      }
    } catch (e) {
      developer.log('Schema fetch failed in getBangumiProgressMap: $e');
    }

    final url = Uri.parse(_baseUrl)
        .replace(pathSegments: ['v1', 'databases', normalizedDatabaseId, 'query']);
    final progress = <int, int>{};
    String? nextCursor;
    bool hasMore = true;
    int pageCount = 0;

    final statusFilter = (statusPropertyName != null &&
            statusValue != null &&
            statusPropertyName.trim().isNotEmpty &&
            statusValue.trim().isNotEmpty)
        ? _buildStatusFilter(
            propertyName: statusPropertyName,
            propertyType: statusPropertyType,
            value: statusValue.trim(),
          )
        : null;

    while (hasMore) {
      pageCount += 1;
      final body = <String, dynamic>{};
      if (nextCursor != null && nextCursor.isNotEmpty) {
        body['start_cursor'] = nextCursor;
      }
      if (statusFilter != null) {
        body['filter'] = statusFilter;
      }
      final response = await http
          .post(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Notion-Version': _notionVersion,
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(_queryTimeout);

      if (response.statusCode != 200) {
        throw Exception(_mapNotionError('读取 Bangumi 追番进度', response));
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];
      for (final item in results) {
        if (item is! Map<String, dynamic>) continue;
        final properties = item['properties'] as Map<String, dynamic>? ?? {};
        final idProperty = properties[idPropertyName] as Map<String, dynamic>?;
        if (idProperty == null) continue;

        int? id;
        if (idPropertyType == 'number') {
          final number = _extractNumberValue(idProperty);
          id = number?.round();
        } else {
          final text = _extractPlainText(idProperty);
          if (text != null && text.isNotEmpty) {
            id = int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), ''));
          }
        }

        if (id == null || id <= 0) continue;
        int watched = 0;
        if (watchedEpisodesProperty != null &&
            watchedEpisodesProperty.trim().isNotEmpty) {
          final watchedProp =
              properties[watchedEpisodesProperty] as Map<String, dynamic>?;
          if (watchedProp != null) {
            if (watchedPropertyType == 'number') {
              watched = _extractIntValue(watchedProp) ?? 0;
            } else {
              watched = _extractIntValue(watchedProp) ?? 0;
            }
          }
        }
        progress[id] = watched;
      }

      hasMore = data['has_more'] == true;
      nextCursor = data['next_cursor']?.toString();
    }

    developer.log(
      'getBangumiProgressMap done: pages=$pageCount items=${progress.length}',
    );
    return progress;
  }

  Future<String?> findPageByUniqueId({
    required String token,
    required String databaseId,
    required int uniqueId,
  }) async {
    final normalizedDatabaseId = _normalizePageId(databaseId);
    if (normalizedDatabaseId == null) {
      throw Exception('Notion Database ID 无效');
    }
    final url = Uri.parse(_baseUrl)
        .replace(pathSegments: ['v1', 'databases', normalizedDatabaseId, 'query']);
    final response = await http
        .post(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Notion-Version': _notionVersion,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'filter': {
              'property': 'ID',
              'unique_id': {
                'equals': uniqueId,
              },
            },
          }),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final results = data['results'] as List;
      if (results.isNotEmpty) {
        return results.first['id'];
      }
      return null;
    }

    throw Exception(_mapNotionError('查询 Unique ID', response));
  }

  int? _parseUniqueId(dynamic value) {
    if (value is int) return value;
    if (value is String) {
      final asInt = int.tryParse(value);
      if (asInt != null) return asInt;
      // Extract number from end of string (e.g. "UGN-228" -> 228)
      final match = RegExp(r'(\d+)$').firstMatch(value);
      if (match != null) {
        return int.tryParse(match.group(1)!);
      }
    }
    return null;
  }

  Future<String?> findPageByProperty({
    required String token,
    required String databaseId,
    required String propertyName,
    required dynamic value,
    String? type,
  }) async {
    final normalizedDatabaseId = _normalizePageId(databaseId);
    if (normalizedDatabaseId == null) {
      throw Exception('Notion Database ID 无效');
    }

    // 1. 获取数据库 Schema，用于确定属性类型
    String actualType = type ?? 'number';
    try {
      final properties = await getDatabaseProperties(
        token: token,
        databaseId: databaseId,
      );
      final prop = properties.firstWhere(
        (p) => p.name == propertyName,
        orElse: () => NotionProperty(name: propertyName, type: ''),
      );
      if (prop.type.isNotEmpty) {
        actualType = prop.type;
      }
    } catch (e) {
      developer.log('Schema fetch failed in findPageByProperty: $e');
    }

    final url = Uri.parse(_baseUrl)
        .replace(pathSegments: ['v1', 'databases', normalizedDatabaseId, 'query']);

    Map<String, dynamic> filter;

    if (actualType == 'unique_id') {
      final uniqueIdVal = _parseUniqueId(value);
      if (uniqueIdVal == null) {
        // 无法从值中解析出 ID 数字，返回空
        developer.log('无法从 "$value" 解析出 unique_id');
        return null;
      }
      filter = {
        'property': propertyName,
        'unique_id': {
          'equals': uniqueIdVal,
        },
      };
    } else if (actualType == 'number') {
      filter = {
        'property': propertyName,
        'number': {
          'equals': value is String ? int.tryParse(value) ?? 0 : value,
        },
      };
    } else {
      // 针对不同文本类型构建正确的 filter key
      String filterKey = 'rich_text';
      if (actualType == 'title') {
        filterKey = 'title';
      } else if (actualType == 'url') {
        filterKey = 'url';
      } else if (actualType == 'email') {
        filterKey = 'email';
      } else if (actualType == 'phone_number') {
        filterKey = 'phone_number';
      }

      filter = {
        'property': propertyName,
        filterKey: {
          'equals': value.toString(),
        },
      };
    }

    final requestBody = jsonEncode({
      'filter': filter,
    });

    final response = await http
        .post(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Notion-Version': _notionVersion,
            'Content-Type': 'application/json',
          },
          body: requestBody,
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      developer.log('Notion Query Error:');
      developer.log('URL: $url');
      developer.log('Request Body: $requestBody');
      developer.log('Status Code: ${response.statusCode}');
      developer.log('Response Body: ${response.body}');
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final results = data['results'] as List;
      if (results.isNotEmpty) {
        return results.first['id'];
      }
      return null;
    }

    throw Exception(_mapNotionError('查询 $propertyName', response));
  }

  Future<String?> findPageByBangumiId({
    required String token,
    required String databaseId,
    required int bangumiId,
    String propertyName = 'Bangumi ID',
  }) async {
    try {
      return await findPageByProperty(
        token: token,
        databaseId: databaseId,
        propertyName: propertyName,
        value: bangumiId,
        type: 'number',
      );
    } catch (e) {
      final errorMsg = e.toString();
      // 如果遇到属性类型不匹配错误（用户数据库中可能是 Text 类型），尝试作为 string 查询
      // Error example: "database property text does not match filter number"
      if (errorMsg.contains('does not match filter number') ||
          errorMsg.contains('validation_error')) {
        return findPageByProperty(
          token: token,
          databaseId: databaseId,
          propertyName: propertyName,
          value: bangumiId.toString(),
          type: 'rich_text',
        );
      }
      rethrow;
    }
  }

  Future<void> appendBlockChildren({
    required String token,
    required String pageId,
    required List<Map<String, dynamic>> blocks,
  }) async {
    final normalizedId = _normalizePageId(pageId);
    if (normalizedId == null) {
      throw Exception('Notion 页面 ID 无效');
    }
    final url = Uri.parse(_baseUrl)
        .replace(pathSegments: ['v1', 'blocks', normalizedId, 'children']);
    final response = await http
        .patch(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Notion-Version': _notionVersion,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'children': blocks,
          }),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception(_mapNotionError('追加页面内容', response));
    }
  }

  Future<void> createAnimePage({
    required String token,
    required String databaseId,
    required BangumiSubjectDetail detail,
    MappingConfig? mappingConfig,
    Set<String>? enabledFields,
    String? existingPageId,
  }) async {
    final normalizedDatabaseId = _normalizePageId(databaseId);
    if (normalizedDatabaseId == null) {
      throw Exception('Notion Database ID 无效');
    }
    final config = mappingConfig ?? MappingConfig();

    // 1. 获取数据库 Schema，用于验证属性是否存在及类型匹配
    Map<String, String> schemaTypes = {};
    try {
      final schema = await getDatabaseProperties(
          token: token, databaseId: normalizedDatabaseId);
      schemaTypes = {for (var p in schema) p.name: p.type};
    } catch (e) {
      developer.log('获取数据库 Schema 失败: $e');
      // 如果获取失败，可以决定是中止还是尝试继续（可能会遇到属性不存在的错误）
      // 这里选择继续，保持原有行为，但在 addProperty 中会因为 schemaTypes 为空而稍作处理
      // 实际上如果这里失败了，后续写入大概率也会失败。但为了兼容旧逻辑，暂不强制抛出。
    }

    // 2. 查找是否存在现有页面 (如果未提供)
    final targetPageId = existingPageId ??
        await findPageByBangumiId(
          token: token,
          databaseId: normalizedDatabaseId,
          propertyName:
              config.bangumiId.isNotEmpty ? config.bangumiId : 'Bangumi ID',
          bangumiId: detail.id,
        );

    final title = detail.nameCn.isNotEmpty ? detail.nameCn : detail.name;
    final Map<String, dynamic> properties = {};

    // 记录哪些字段被映射到了 Notion 的属性中
    final Set<String> mappedPropertyKeys = {};
    final List<Map<String, dynamic>> bodyBlocks = [];

    void addProperty(
        String fieldKey, String notionKey, dynamic value, String intendedType) {
      if (notionKey.isEmpty) return;
      // 对于 infobox 中的字段，如果 enabledFields 为 null (默认全选) 或者明确包含该 key，则允许
      if (enabledFields != null &&
          !enabledFields.contains(fieldKey) &&
          !fieldKey.startsWith('infobox_')) {
        return;
      }

      // 特殊处理：如果映射到“正文”，则加入 bodyBlocks 而不是 properties
      if (notionKey == '正文') {
        if (value == null || value.toString().isEmpty) return;

        if (fieldKey == 'imageUrl') {
          bodyBlocks.add({
            'object': 'block',
            'type': 'image',
            'image': {
              'type': 'external',
              'external': {'url': value.toString()}
            }
          });
        } else {
          bodyBlocks.add({
            'object': 'block',
            'type': 'paragraph',
            'paragraph': {
              'rich_text': [
                {
                  'type': 'text',
                  'text': {'content': value.toString()}
                }
              ]
            }
          });
        }
        return;
      }

      // --- Schema 验证与自适应 ---
      // 如果成功获取了 schema，则进行检查
      if (schemaTypes.isNotEmpty) {
        if (!schemaTypes.containsKey(notionKey)) {
          // 属性在数据库中不存在，跳过，避免报错 "property does not exist"
          developer.log('属性不存在，跳过: $notionKey');
          return;
        }
      }
      
      final actualType = schemaTypes[notionKey] ?? intendedType;
      
      // 记录已映射的属性
      mappedPropertyKeys.add(notionKey);

      // 根据 actualType 决定如何写入
      switch (actualType) {
        case 'title':
          properties[notionKey] = {
            'title': [
              {
                'text': {'content': value.toString()}
              }
            ]
          };
          break;
        case 'rich_text':
          // 即使 intendedType 是 number，如果 actualType 是 rich_text，也转 string
          if (value != null && value.toString().isNotEmpty) {
            properties[notionKey] = {
              'rich_text': [
                {
                  'text': {'content': value.toString()}
                }
              ]
            };
          }
          break;
        case 'number':
          num? numValue;
          if (value is num) {
            numValue = value;
          } else if (value is String) {
            numValue = num.tryParse(value);
          }
          
          if (numValue != null) {
            properties[notionKey] = {'number': numValue};
          }
          break;
        case 'date':
          if (value.toString().isNotEmpty) {
            properties[notionKey] = {
              'date': {'start': value.toString()}
            };
          }
          break;
        case 'multi_select':
          // 如果 intendedType 不是 multi_select (比如是 rich_text)，但 actualType 是 multi_select
          // 我们尝试把值作为单个 tag 放入
          if (value is List && value.isNotEmpty) {
             properties[notionKey] = {
              'multi_select':
                  value.map((tag) => {'name': tag.toString()}).toList()
            };
          } else if (value is String && value.isNotEmpty) {
             properties[notionKey] = {
              'multi_select': [{'name': value}]
            };
          }
          break;
        case 'select': // 处理 Select 类型
          if (value != null && value.toString().isNotEmpty) {
             properties[notionKey] = {
              'select': {'name': value.toString()}
            };
          }
          break;
        case 'url':
          if (value.toString().isNotEmpty) {
            properties[notionKey] = {'url': value.toString()};
          }
          break;
         default:
           // 如果是未知类型，尝试按照 intendedType 写入，或者跳过
           // 这里为了安全，如果类型不匹配且无法转换，最好什么都不做
           // 但为了兼容，如果 schema为空，我们 switch intendedType
           if (schemaTypes.isEmpty) {
              // Fallback to original logic based on intendedType
              switch (intendedType) {
                // ... 重复之前的逻辑 ...
                // 为简化代码，其实可以将 actualType 默认为 intendedType，
                // 上面的 switch 已经覆盖了大部分情况。
                // 只有当 intendedType 和 actualType 完全不兼容且未在上面处理时才会出问题。
              }
           }
           break;
      }
    }

    addProperty('airDate', config.airDate, detail.airDate, 'date');
    addProperty('tags', config.tags, detail.tags, 'multi_select');
    addProperty('imageUrl', config.imageUrl, detail.imageUrl, 'url');
    addProperty('bangumiId', config.bangumiId, detail.id, 'number');
    addProperty('score', config.score, detail.score, 'number');
    addProperty(
        'link', config.link, 'https://bgm.tv/subject/${detail.id}', 'url');
    addProperty('animationProduction', config.animationProduction,
        detail.animationProduction, 'rich_text');
    addProperty('director', config.director, detail.director, 'rich_text');
    addProperty('script', config.script, detail.script, 'rich_text');
    addProperty(
        'storyboard', config.storyboard, detail.storyboard, 'rich_text');
    addProperty('description', config.description, detail.summary, 'rich_text');

    // 处理 infoboxMap 中剩下的所有字段
    // 如果用户在 Notion 数据库中创建了同名属性，尝试自动填充
    final knownMappedFields = {
      config.airDate,
      config.tags,
      config.imageUrl,
      config.bangumiId,
      config.score,
      config.link,
      config.animationProduction,
      config.director,
      config.script,
      config.storyboard,
      config.description,
      config.title,
    }.where((k) => k.isNotEmpty).toSet();

    for (final entry in detail.infoboxMap.entries) {
      if (!knownMappedFields.contains(entry.key)) {
        // 如果这个 key 还没有被映射过，我们尝试将其作为 rich_text 写入（前提是 Notion 数据库有同名属性）
        // addProperty 内部已经检查了 notionKey.isEmpty，但这里我们需要传入 entry.key 作为 notionKey
        addProperty('infobox_${entry.key}', entry.key, entry.value, 'rich_text');
      }
    }

    // 确保标题属性被正确处理为 title 类型，且不会被其他映射覆盖
    if (config.title.isNotEmpty &&
        (enabledFields == null || enabledFields.contains('title'))) {
      properties[config.title] = {
        'title': [
          {
            'text': {'content': title}
          }
        ]
      };
    }

    final Map<String, dynamic> body = {
      'properties': properties,
    };

    // 只有在创建新页面时才添加简介内容
    // Notion API 更新正文需要调用不同的接口，这里我们主要在创建时支持 children
    if (targetPageId == null) {
      body['parent'] = {'database_id': normalizedDatabaseId};

      final List<Map<String, dynamic>> children = [...bodyBlocks];

      // 如果没有显式映射到“正文”，但启用了 coverUrl 字段，则仍然按照旧逻辑添加（兼容性）
      final bool alreadyHasImage =
          children.any((block) => block['type'] == 'image');
      if (!alreadyHasImage &&
          enabledFields != null &&
          enabledFields.contains('coverUrl') &&
          detail.imageUrl.isNotEmpty) {
        children.add({
          'object': 'block',
          'type': 'image',
          'image': {
            'type': 'external',
            'external': {'url': detail.imageUrl}
          }
        });
      }

      if (children.isNotEmpty) {
        body['children'] = children;
      }
    }

    final normalizedTargetId =
        targetPageId != null ? _normalizePageId(targetPageId) : null;
    if (targetPageId != null && normalizedTargetId == null) {
      throw Exception('Notion 页面 ID 无效');
    }

    final url = normalizedTargetId != null
        ? Uri.parse(_baseUrl)
            .replace(pathSegments: ['v1', 'pages', normalizedTargetId])
        : Uri.parse(_baseUrl).replace(pathSegments: ['v1', 'pages']);

    final response = await (normalizedTargetId != null
        ? http.patch(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Notion-Version': _notionVersion,
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
        : http.post(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Notion-Version': _notionVersion,
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          ))
        .timeout(_timeout);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(_mapNotionError(
          normalizedTargetId != null ? 'Notion 更新' : 'Notion 导入', response));
    }
  }
}
