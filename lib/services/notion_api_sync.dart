part of 'notion_api.dart';

extension NotionApiSync on NotionApi {
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
      _logger.debug('Schema fetch failed in getBangumiIdSet: $e');
    }

    final url = Uri.parse(NotionApi._baseUrl).replace(
        pathSegments: ['v1', 'databases', normalizedDatabaseId, 'query']);
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
              body: jsonEncode(body),
            )
            .timeout(NotionApi._queryTimeout),
      );

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

    _logger.debug(
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
      _logger.debug('Schema fetch failed in getBangumiProgressMap: $e');
    }

    final url = Uri.parse(NotionApi._baseUrl).replace(
        pathSegments: ['v1', 'databases', normalizedDatabaseId, 'query']);
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
              body: jsonEncode(body),
            )
            .timeout(NotionApi._queryTimeout),
      );

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

    _logger.debug(
      'getBangumiProgressMap done: pages=$pageCount items=${progress.length}',
    );
    return progress;
  }

  Future<Map<int, BangumiProgressInfo>> getBangumiProgressInfo({
    required String token,
    required String databaseId,
    required String idPropertyName,
    String? watchedEpisodesProperty,
    String? yougnScoreProperty,
    String? statusPropertyName,
    String? statusValue,
  }) async {
    final normalizedDatabaseId = _normalizePageId(databaseId);
    if (normalizedDatabaseId == null) {
      throw Exception('Notion Database ID 鏃犳晥');
    }
    if (idPropertyName.trim().isEmpty) {
      return <int, BangumiProgressInfo>{};
    }

    String idPropertyType = 'number';
    String watchedPropertyType = 'number';
    String yougnScoreType = '';
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
      if (yougnScoreProperty != null && yougnScoreProperty.trim().isNotEmpty) {
        yougnScoreType = typeMap[yougnScoreProperty] ?? '';
      }
      if (statusPropertyName != null && statusPropertyName.trim().isNotEmpty) {
        statusPropertyType = typeMap[statusPropertyName] ?? '';
      }
    } catch (e) {
      _logger.debug('Schema fetch failed in getBangumiProgressInfo: $e');
    }

    final url = Uri.parse(NotionApi._baseUrl).replace(
        pathSegments: ['v1', 'databases', normalizedDatabaseId, 'query']);
    final progress = <int, BangumiProgressInfo>{};
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
              body: jsonEncode(body),
            )
            .timeout(NotionApi._queryTimeout),
      );

      if (response.statusCode != 200) {
        throw Exception(_mapNotionError('璇诲彇 Bangumi 杩界暘杩涘害', response));
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

        double? yougnScore;
        if (yougnScoreProperty != null &&
            yougnScoreProperty.trim().isNotEmpty) {
          final scoreProp =
              properties[yougnScoreProperty] as Map<String, dynamic>?;
          if (scoreProp != null) {
            if (yougnScoreType == 'number') {
              yougnScore = _extractNumberValue(scoreProp);
            } else {
              yougnScore = _extractNumberValue(scoreProp) ??
                  _parseScoreFromText(_extractPlainText(scoreProp));
            }
          }
        }

        progress[id] = BangumiProgressInfo(
          watchedEpisodes: watched,
          yougnScore: yougnScore,
        );
      }

      hasMore = data['has_more'] == true;
      nextCursor = data['next_cursor']?.toString();
    }

    _logger.debug(
      'getBangumiProgressInfo done: pages=$pageCount items=${progress.length}',
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
    final url = Uri.parse(NotionApi._baseUrl).replace(
        pathSegments: ['v1', 'databases', normalizedDatabaseId, 'query']);
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
            body: jsonEncode({
              'filter': {
                'property': 'ID',
                'unique_id': {
                  'equals': uniqueId,
                },
              },
            }),
          )
          .timeout(NotionApi._timeout),
    );

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
      _logger.debug('Schema fetch failed in findPageByProperty: $e');
    }

    final url = Uri.parse(NotionApi._baseUrl).replace(
        pathSegments: ['v1', 'databases', normalizedDatabaseId, 'query']);

    Map<String, dynamic> filter;

    if (actualType == 'unique_id') {
      final uniqueIdVal = _parseUniqueId(value);
      if (uniqueIdVal == null) {
        // 无法从值中解析出 ID 数字，返回空
        _logger.debug('无法从 "$value" 解析出 unique_id');
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
          .timeout(NotionApi._timeout),
    );

    if (response.statusCode != 200) {
      _logger.error('Notion Query Error:');
      _logger.error('URL: $url');
      _logger.error('Request Body: $requestBody');
      _logger.error('Status Code: ${response.statusCode}');
      _logger.error('Response Body: ${response.body}');
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
    final url = Uri.parse(NotionApi._baseUrl)
        .replace(pathSegments: ['v1', 'blocks', normalizedId, 'children']);
    final response = await sendWithRetry(
      logger: _logger,
      label: 'Notion patch',
      request: () => _client
          .patch(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Notion-Version': NotionApi._notionVersion,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'children': blocks,
            }),
          )
          .timeout(NotionApi._timeout),
    );

    if (response.statusCode != 200) {
      throw Exception(_mapNotionError('追加页面内容', response));
    }
  }

  Future<List<String>?> _getPageMultiSelectTags({
    required String token,
    required String pageId,
    required String propertyName,
  }) async {
    final normalizedId = _normalizePageId(pageId);
    if (normalizedId == null) {
      throw Exception('Notion 页面 ID 无效');
    }
    if (propertyName.trim().isEmpty) return null;

    final url = Uri.parse(NotionApi._baseUrl)
        .replace(pathSegments: ['v1', 'pages', normalizedId]);
    final response = await sendWithRetry(
      logger: _logger,
      label: 'Notion get page',
      request: () => _client
          .get(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Notion-Version': NotionApi._notionVersion,
              'Content-Type': 'application/json',
            },
          )
          .timeout(NotionApi._timeout),
    );

    if (response.statusCode != 200) {
      throw Exception(_mapNotionError('读取页面', response));
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final properties = data['properties'] as Map<String, dynamic>? ?? {};
    final property = properties[propertyName] as Map<String, dynamic>?;
    if (property == null) return null;
    final type = property['type']?.toString() ?? '';
    if (type != 'multi_select') return null;
    final raw = property['multi_select'];
    if (raw is! List) return <String>[];
    return raw
        .map((tag) =>
            tag is Map<String, dynamic> ? tag['name']?.toString() : null)
        .whereType<String>()
        .toList();
  }

  List<String> _mergeTags(List<String> existing, List<String> incoming) {
    final merged = <String>[...existing];
    final existingNormalized =
        existing.map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toSet();
    for (final tag in incoming) {
      final trimmed = tag.trim();
      if (trimmed.isEmpty) continue;
      if (existingNormalized.add(trimmed)) {
        merged.add(trimmed);
      }
    }
    return merged;
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
      _logger.debug('获取数据库 Schema 失败: $e');
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
    final bool shouldWriteTags =
        config.tags.isNotEmpty &&
        (enabledFields == null || enabledFields.contains('tags'));
    var tagsToWrite = detail.tags;
    if (shouldWriteTags && targetPageId != null && detail.tags.isNotEmpty) {
      try {
        final existingTags = await _getPageMultiSelectTags(
          token: token,
          pageId: targetPageId,
          propertyName: config.tags,
        );
        if (existingTags != null) {
          tagsToWrite = _mergeTags(existingTags, detail.tags);
        }
      } catch (e) {
        _logger.debug('读取 Notion 标签失败，跳过标签更新: $e');
        tagsToWrite = <String>[];
      }
    }


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
          _logger.debug('属性不存在，跳过: $notionKey');
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
              'multi_select': [
                {'name': value}
              ]
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
    addProperty('tags', config.tags, tagsToWrite, 'multi_select');
    addProperty('imageUrl', config.imageUrl, detail.imageUrl, 'url');
    addProperty('bangumiId', config.bangumiId, detail.id, 'number');
    addProperty('score', config.score, detail.score, 'number');
    addProperty('totalEpisodes', config.totalEpisodes, detail.epsCount, 'number');
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
      config.totalEpisodes,
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
        addProperty(
            'infobox_${entry.key}', entry.key, entry.value, 'rich_text');
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
        ? Uri.parse(NotionApi._baseUrl)
            .replace(pathSegments: ['v1', 'pages', normalizedTargetId])
        : Uri.parse(NotionApi._baseUrl).replace(pathSegments: ['v1', 'pages']);

    final response = await sendWithRetry(
      logger: _logger,
      label: normalizedTargetId != null
          ? 'Notion update page'
          : 'Notion create page',
      request: () => (normalizedTargetId != null
              ? _client.patch(
                  url,
                  headers: {
                    'Authorization': 'Bearer $token',
                    'Notion-Version': NotionApi._notionVersion,
                    'Content-Type': 'application/json',
                  },
                  body: jsonEncode(body),
                )
              : _client.post(
                  url,
                  headers: {
                    'Authorization': 'Bearer $token',
                    'Notion-Version': NotionApi._notionVersion,
                    'Content-Type': 'application/json',
                  },
                  body: jsonEncode(body),
                ))
          .timeout(NotionApi._timeout),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(_mapNotionError(
          normalizedTargetId != null ? 'Notion 更新' : 'Notion 导入', response));
    }
  }
}
