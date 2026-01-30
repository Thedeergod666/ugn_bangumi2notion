import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/bangumi_models.dart';
import '../models/mapping_config.dart';

class NotionApi {
  static const String _baseUrl = 'https://api.notion.com/v1';
  static const String _notionVersion = '2022-06-28';

  Future<void> testConnection({
    required String token,
    required String databaseId,
  }) async {
    final url = Uri.parse('$_baseUrl/databases/$databaseId');
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Notion-Version': _notionVersion,
      },
    );

    if (response.statusCode != 200) {
      try {
        final errorData = jsonDecode(response.body);
        throw Exception(
            'Notion 连接失败: ${errorData['message'] ?? response.reasonPhrase}');
      } catch (_) {
        throw Exception(
            'Notion 连接失败: ${response.statusCode} ${response.reasonPhrase}');
      }
    }
  }

  Future<List<String>> getDatabaseProperties({
    required String token,
    required String databaseId,
  }) async {
    final url = Uri.parse('$_baseUrl/databases/$databaseId');
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Notion-Version': _notionVersion,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final properties = data['properties'] as Map<String, dynamic>?;
      if (properties != null) {
        return properties.keys.toList();
      }
      return [];
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(
          '获取数据库属性失败: ${errorData['message'] ?? response.reasonPhrase}');
    }
  }

  Future<String?> findPageByUniqueId({
    required String token,
    required String databaseId,
    required int uniqueId,
  }) async {
    final url = Uri.parse('$_baseUrl/databases/$databaseId/query');
    final response = await http.post(
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
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final results = data['results'] as List;
      if (results.isNotEmpty) {
        return results.first['id'];
      }
      return null;
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(
          '查询 Unique ID 失败: ${errorData['message'] ?? response.reasonPhrase}');
    }
  }

  Future<String?> findPageByBangumiId({
    required String token,
    required String databaseId,
    required int bangumiId,
    String propertyName = 'Bangumi ID',
  }) async {
    final url = Uri.parse('$_baseUrl/databases/$databaseId/query');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Notion-Version': _notionVersion,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'filter': {
          'property': propertyName,
          'number': {
            'equals': bangumiId,
          },
        },
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final results = data['results'] as List;
      if (results.isNotEmpty) {
        return results.first['id'];
      }
      return null;
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(
          '查询 Bangumi ID 失败: ${errorData['message'] ?? response.reasonPhrase}');
    }
  }

  Future<void> appendBlockChildren({
    required String token,
    required String pageId,
    required List<Map<String, dynamic>> blocks,
  }) async {
    final url = Uri.parse('$_baseUrl/blocks/$pageId/children');
    final response = await http.patch(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Notion-Version': _notionVersion,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'children': blocks,
      }),
    );

    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(
          '追加页面内容失败: ${errorData['message'] ?? response.reasonPhrase}');
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
    final config = mappingConfig ?? MappingConfig();

    // 1. 查找是否存在现有页面 (如果未提供)
    final targetPageId = existingPageId ??
        await findPageByBangumiId(
          token: token,
          databaseId: databaseId,
          propertyName:
              config.bangumiId.isNotEmpty ? config.bangumiId : 'Bangumi ID',
          bangumiId: detail.id,
        );

    final title = detail.nameCn.isNotEmpty ? detail.nameCn : detail.name;
    final Map<String, dynamic> properties = {};

    // 记录哪些字段被映射到了 Notion 的属性中
    final Set<String> mappedPropertyKeys = {};

    void addProperty(
        String fieldKey, String notionKey, dynamic value, String type) {
      if (notionKey.isEmpty) return;
      if (enabledFields != null && !enabledFields.contains(fieldKey)) return;

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
      body['parent'] = {'database_id': databaseId};

      final List<Map<String, dynamic>> children = [];

      // 如果启用了正文图片
      if (enabledFields != null &&
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

      // 如果 content 字段被映射了，且启用了该字段，则将其作为简介内容
      if (config.content.isNotEmpty &&
          (enabledFields == null || enabledFields.contains('content')) &&
          detail.summary.isNotEmpty) {
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

    final url = targetPageId != null
        ? Uri.parse('$_baseUrl/pages/$targetPageId')
        : Uri.parse('$_baseUrl/pages');

    final response = await (targetPageId != null
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
          ));

    if (response.statusCode != 200 && response.statusCode != 201) {
      final errorData = jsonDecode(response.body);
      throw Exception(
          'Notion ${targetPageId != null ? "更新" : "导入"}失败: ${errorData['message'] ?? response.reasonPhrase}');
    }
  }
}
