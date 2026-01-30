import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/bangumi_models.dart';

class BangumiApi {
  BangumiApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _baseUrl = 'https://api.bgm.tv';

  Future<List<BangumiSearchItem>> search({
    required String keyword,
    required String accessToken,
  }) async {
    final uri = Uri.parse('$_baseUrl/v0/search/subjects');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'keyword': keyword,
        'sort': 'match',
        'filter': {
          'type': [2],
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Bangumi 搜索失败：${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final list = data['data'] as List<dynamic>? ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(BangumiSearchItem.fromJson)
        .toList();
  }

  Future<BangumiSubjectDetail> fetchDetail({
    required int subjectId,
    required String accessToken,
  }) async {
    final uri = Uri.parse('$_baseUrl/v0/subjects/$subjectId');
    final response = await _client.get(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Bangumi 详情失败：${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return BangumiSubjectDetail.fromJson(data);
  }
}
