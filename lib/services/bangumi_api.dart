import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/bangumi_models.dart';

class BangumiApi {
  BangumiApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _baseUrl = 'https://api.bgm.tv';
  static const Duration _timeout = Duration(seconds: 12);
  static const int _maxKeywordLength = 50;

  String _mapBangumiError(String action, http.Response response) {
    switch (response.statusCode) {
      case 401:
      case 403:
        return '$action失败：权限不足或凭证无效';
      case 429:
        return '$action失败：请求过于频繁，请稍后重试';
      default:
        if (response.statusCode >= 500) {
          return '$action失败：Bangumi 服务异常';
        }
        return '$action失败：请求异常';
    }
  }

  Future<List<BangumiSearchItem>> search({
    required String keyword,
    required String accessToken,
  }) async {
    final normalizedKeyword = keyword.trim();
    final limitedKeyword = normalizedKeyword.length > _maxKeywordLength
        ? normalizedKeyword.substring(0, _maxKeywordLength)
        : normalizedKeyword;
    if (limitedKeyword.isEmpty) {
      throw Exception('关键词无效');
    }
    final uri = Uri.parse('$_baseUrl/v0/search/subjects');
    final response = await _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode({
            'keyword': limitedKeyword,
            'sort': 'match',
            'filter': {
              'type': [2],
            },
          }),
        )
        .timeout(_timeout);

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

  Future<BangumiSubjectDetail> fetchDetail({
    required int subjectId,
    required String accessToken,
  }) async {
    final uri = Uri.parse('$_baseUrl/v0/subjects/$subjectId');
    final response = await _client
        .get(
          uri,
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception(_mapBangumiError('Bangumi 详情', response));
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return BangumiSubjectDetail.fromJson(data);
  }

  Future<List<BangumiComment>> fetchSubjectComments({
    required int subjectId,
    required String accessToken,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/v0/subjects/$subjectId/comments');
      final response = await _client
          .get(
            uri,
            headers: {
              if (accessToken.isNotEmpty) 'Authorization': 'Bearer $accessToken',
              'Accept': 'application/json',
              'User-Agent': 'BangumiImporter/1.0',
            },
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        print('[BangumiApi] fetchSubjectComments error: ${response.statusCode} ${response.body}');
        return [];
      }

      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic> && data.containsKey('data')) {
        final list = data['data'] as List<dynamic>? ?? [];
        return list.whereType<Map<String, dynamic>>().map(BangumiComment.fromJson).toList();
      }
      
      print('[BangumiApi] fetchSubjectComments: Unexpected response format or empty data');
      return [];
    } catch (e) {
      print('[BangumiApi] fetchSubjectComments failed: $e');
      return [];
    }
  }
}
