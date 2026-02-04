part of 'notion_api.dart';

extension NotionApiDailyRecommendation on NotionApi {
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
      final url = Uri.parse(NotionApi._baseUrl).replace(
        pathSegments: ['v1', 'blocks', normalizedId, 'children'],
        queryParameters: query.isEmpty ? null : query,
      );
      final response = await sendWithRetry(
        logger: _logger,
        label: 'Notion blocks',
        request: () => _client.get(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Notion-Version': NotionApi._notionVersion,
          },
        ).timeout(NotionApi._blocksTimeout),
      );

      _logger.debug(
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

    _logger.debug(
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
    _logger.debug(
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
      final detail = await _bangumiApi.fetchDetail(subjectId: id);
      _logger.debug(
        'Bangumi cover fallback in ${sw.elapsedMilliseconds}ms (id=$id)',
      );
      return detail.imageUrl.isNotEmpty ? detail.imageUrl : null;
    } catch (e) {
      _logger.debug('Bangumi cover fallback failed: $e');
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
    final url = Uri.parse(NotionApi._baseUrl)
        .replace(pathSegments: ['v1', 'databases', normalizedDatabaseId]);
    final response = await sendWithRetry(
      logger: _logger,
      label: 'Notion get',
      request: () => _client.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Notion-Version': NotionApi._notionVersion,
        },
      ).timeout(NotionApi._timeout),
    );

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
    final url = Uri.parse(NotionApi._baseUrl)
        .replace(pathSegments: ['v1', 'databases', normalizedDatabaseId]);
    final response = await sendWithRetry(
      logger: _logger,
      label: 'Notion get',
      request: () => _client.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Notion-Version': NotionApi._notionVersion,
        },
      ).timeout(NotionApi._timeout),
    );

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
    double minScore = NotionApi.defaultYougnScoreThreshold,
  }) async {
    final totalSw = Stopwatch()..start();
    final normalizedDatabaseId = _normalizePageId(databaseId);
    if (normalizedDatabaseId == null) {
      throw Exception('Notion Database ID 无效');
    }
    if (bindings.yougnScore.isEmpty) {
      throw Exception('未配置悠gn评分映射字段');
    }

    final url = Uri.parse(NotionApi._baseUrl).replace(
        pathSegments: ['v1', 'databases', normalizedDatabaseId, 'query']);

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
      _logger.debug('Schema fetch failed in getDailyRecommendation: $e');
    }

    bool useNumberFilter = yougnScoreType == 'number';
    List<dynamic> results = [];
    String? nextCursor;
    bool hasMore = true;

    int pageCount = 0;
    while (hasMore &&
        results.length < NotionApi._dailyRecommendationMaxQueryItems) {
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
      final response = await sendWithRetry(
        logger: _logger,
        label: 'Notion post',
        request: () => _client
            .post(
              url,
              headers: {
                'Authorization': 'Bearer $token',
                'Notion-Version': NotionApi._notionVersion,
                'Content-Type': 'application/json',
              },
              body: requestBody,
            )
            .timeout(NotionApi._queryTimeout),
      );

      _logger.debug(
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
      if (useNumberFilter &&
          results.length >= NotionApi._dailyRecommendationTargetItems) {
        hasMore = false;
      }
    }

    if (!useNumberFilter) {
      results = results.where((item) {
        if (item is! Map<String, dynamic>) return false;
        final properties = item['properties'] as Map<String, dynamic>? ?? {};
        final scoreProperty =
            properties[bindings.yougnScore] as Map<String, dynamic>?;
        if (scoreProperty == null) return false;
        final rawText = _extractPlainText(scoreProperty);
        final score = _parseScoreFromText(rawText);
        return score != null && score >= minScore;
      }).toList();
    }

    _logger.debug(
      'getDailyRecommendation query done: pages=$pageCount, results=${results.length}, '
      'elapsed=${totalSw.elapsedMilliseconds}ms',
    );

    if (_logger.level.index >= LogLevel.debug.index) {
      final ids = results
          .whereType<Map<String, dynamic>>()
          .map((item) => item['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      final sampleIds = ids
          .take(5)
          .map((id) => id.length > 8 ? id.substring(0, 8) : id)
          .toList();
      _logger.debug(
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

    final score = readNumber(bindings.yougnScore) ??
        readScoreFallback(bindings.yougnScore);
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
        _logger.debug('读取 Notion 正文失败: $e');
      }
    }

    final bangumiId = readText(bindings.bangumiId ?? '');
    final subjectId = readText(bindings.subjectId ?? '');
    final bangumiCover = await _resolveBangumiCover(
      bangumiId: bangumiId,
      subjectId: subjectId,
    );

    if (_logger.level.index >= LogLevel.debug.index) {
      String clip(String? value) {
        if (value == null) return '';
        final trimmed = value.trim();
        if (trimmed.length <= NotionApi._logTextLimit) return trimmed;
        return '${trimmed.substring(0, NotionApi._logTextLimit)}…';
      }

      final tags = readTags(bindings.tags);
      _logger.debug(
        '[DailyReco][Notion] pick title="${clip(title)}" '
        'score=${score.toStringAsFixed(1)} '
        'pageId=${pageId != null ? (pageId.length > 8 ? pageId.substring(0, 8) : pageId) : ""} '
        'bangumiId=${clip(bangumiId)} subjectId=${clip(subjectId)} '
        'type=${clip(readSelect(bindings.type))} tags=${tags.take(6).join("/")}',
      );
    }

    _logger.debug(
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
    double minScore = NotionApi.defaultYougnScoreThreshold,
  }) async {
    final totalSw = Stopwatch()..start();
    final normalizedDatabaseId = _normalizePageId(databaseId);
    if (normalizedDatabaseId == null) {
      throw Exception('Notion Database ID 无效');
    }
    if (bindings.yougnScore.isEmpty) {
      throw Exception('未配置悠gn评分映射字段');
    }

    final url = Uri.parse(NotionApi._baseUrl).replace(
        pathSegments: ['v1', 'databases', normalizedDatabaseId, 'query']);

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
      _logger
          .debug('Schema fetch failed in getDailyRecommendationCandidates: $e');
    }

    final useNumberFilter = yougnScoreType == 'number';
    List<dynamic> results = [];
    String? nextCursor;
    bool hasMore = true;

    int pageCount = 0;
    while (hasMore &&
        results.length < NotionApi._dailyRecommendationMaxQueryItems) {
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
      final response = await sendWithRetry(
        logger: _logger,
        label: 'Notion post',
        request: () => _client
            .post(
              url,
              headers: {
                'Authorization': 'Bearer $token',
                'Notion-Version': NotionApi._notionVersion,
                'Content-Type': 'application/json',
              },
              body: requestBody,
            )
            .timeout(NotionApi._queryTimeout),
      );

      _logger.debug(
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
      if (useNumberFilter &&
          results.length >= NotionApi._dailyRecommendationTargetItems) {
        hasMore = false;
      }
    }

    if (!useNumberFilter) {
      results = results.where((item) {
        if (item is! Map<String, dynamic>) return false;
        final properties = item['properties'] as Map<String, dynamic>? ?? {};
        final scoreProperty =
            properties[bindings.yougnScore] as Map<String, dynamic>?;
        if (scoreProperty == null) return false;
        final rawText = _extractPlainText(scoreProperty);
        final score = _parseScoreFromText(rawText);
        return score != null && score >= minScore;
      }).toList();
    }

    _logger.debug(
      'getDailyRecommendationCandidates query done: pages=$pageCount, results=${results.length}, '
      'elapsed=${totalSw.elapsedMilliseconds}ms',
    );

    if (_logger.level.index >= LogLevel.debug.index) {
      final ids = results
          .whereType<Map<String, dynamic>>()
          .map((item) => item['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      final sampleIds = ids
          .take(5)
          .map((id) => id.length > 8 ? id.substring(0, 8) : id)
          .toList();
      _logger.debug(
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

    _logger.debug(
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
}
