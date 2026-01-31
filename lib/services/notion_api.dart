import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/bangumi_models.dart';
import '../models/mapping_config.dart';
import '../models/notion_models.dart';

class NotionApi {
  static const String _baseUrl = 'https://api.notion.com/v1';
  static const String _notionVersion = '2022-06-28';
  static const Duration _timeout = Duration(seconds: 12);

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
    switch (response.statusCode) {
      case 401:
      case 403:
        return '$action失败：权限不足或凭证无效';
      case 429:
        return '$action失败：请求过于频繁，请稍后重试';
      default:
        if (response.statusCode >= 500) {
          return '$action失败：Notion 服务异常';
        }
        return '$action失败：请求异常';
    }
  }

  String? normalizePageId(String input) => _normalizePageId(input);

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

  Future<String?> findPageByProperty({
    required String token,
    required String databaseId,
    required String propertyName,
    required dynamic value,
    String type = 'number', // 'number' or 'rich_text'
  }) async {
    final normalizedDatabaseId = _normalizePageId(databaseId);
    if (normalizedDatabaseId == null) {
      throw Exception('Notion Database ID 无效');
    }
    final url = Uri.parse(_baseUrl)
        .replace(pathSegments: ['v1', 'databases', normalizedDatabaseId, 'query']);

    Map<String, dynamic> filter;
    if (type == 'number') {
      filter = {
        'property': propertyName,
        'number': {
          'equals': value is String ? int.tryParse(value) ?? 0 : value,
        },
      };
    } else {
      filter = {
        'property': propertyName,
        'rich_text': {
          'equals': value.toString(),
        },
      };
    }

    final response = await http
        .post(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Notion-Version': _notionVersion,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'filter': filter,
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

    throw Exception(_mapNotionError('查询 $propertyName', response));
  }

  Future<String?> findPageByBangumiId({
    required String token,
    required String databaseId,
    required int bangumiId,
    String propertyName = 'Bangumi ID',
  }) async {
    return findPageByProperty(
      token: token,
      databaseId: databaseId,
      propertyName: propertyName,
      value: bangumiId,
      type: 'number',
    );
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

    // 1. 查找是否存在现有页面 (如果未提供)
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
        String fieldKey, String notionKey, dynamic value, String type) {
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

      // 记录已映射的属性
      mappedPropertyKeys.add(notionKey);

      switch (type) {
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
          if (value.toString().isNotEmpty) {
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
          if (value is num) {
            properties[notionKey] = {'number': value};
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
          if (value is List && value.isNotEmpty) {
            properties[notionKey] = {
              'multi_select':
                  value.map((tag) => {'name': tag.toString()}).toList()
            };
          }
          break;
        case 'url':
          if (value.toString().isNotEmpty) {
            properties[notionKey] = {'url': value.toString()};
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

    // 确保简介 (Page Content) 映射的属性名不会出现在 properties 中
    // 因为它映射的是正文 Block，而不是数据库属性
    if (config.content.isNotEmpty) {
      properties.remove(config.content);
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

      // 如果没有显式映射到“正文”，但 content 被映射到了其他属性且启用了，则不再重复添加到正文
      // 除非 content 显式映射到了“正文” (已经在 bodyBlocks 中了)
      if (config.content.isNotEmpty &&
          config.content != '正文' &&
          (enabledFields == null || enabledFields.contains('content')) &&
          detail.summary.isNotEmpty) {
        // 如果 content 映射的是一个非空属性，之前 addProperty 会把它加入 properties
        // 这里我们要保持向后兼容：如果 content 被映射了，默认也加入正文？
        // 原逻辑是只要 config.content 不为空就加入正文。
        children.add({
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [
              {
                'type': 'text',
                'text': {'content': detail.summary}
              }
            ]
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
