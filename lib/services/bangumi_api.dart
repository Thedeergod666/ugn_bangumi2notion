import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;

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
      // 这里的爬虫逻辑基于 https://bgm.tv/subject/$subjectId/comments
      final uri = Uri.parse('https://bgm.tv/subject/$subjectId/comments');
      final response = await _client.get(
        uri,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        },
      ).timeout(_timeout);

      if (response.statusCode != 200) {
        debugPrint(
            '[BangumiApi] fetchSubjectComments error: ${response.statusCode} for $uri');
        return [];
      }

      final document = parse(utf8.decode(response.bodyBytes));
      final commentItems = document.querySelectorAll('#comment_box .item');
      final List<BangumiComment> comments = [];

      for (final item in commentItems) {
        try {
          // 解析头像
          final avatarElement = item.querySelector('a.avatar');
          String avatar = '';
          if (avatarElement != null) {
            final span = avatarElement.querySelector('span');
            if (span != null) {
              final style = span.attributes['style'] ?? '';
              final match = RegExp(r"background-image:url\('([^']+)'\)").firstMatch(style);
              if (match != null) {
                avatar = match.group(1) ?? '';
              }
            }
            if (avatar.isEmpty) {
              final img = avatarElement.querySelector('img');
              avatar = img?.attributes['src'] ?? '';
            }
          }
          if (avatar.startsWith('//')) {
            avatar = 'https:$avatar';
          }

          // 解析用户名
          final userElement = item.querySelector('.text a');
          final nickname = userElement?.text.trim() ?? 'Unknown';

          // 解析评分
          final starsElement = item.querySelector('.starsinfo');
          int rate = 0;
          if (starsElement != null) {
            final classAttr = starsElement.attributes['class'] ?? '';
            final match = RegExp(r'stars(\d+)').firstMatch(classAttr);
            if (match != null) {
              rate = int.tryParse(match.group(1) ?? '0') ?? 0;
            }
          }

          // 解析日期
          final dateElement = item.querySelector('.grey');
          var updatedAt = dateElement?.text.trim() ?? '';
          if (updatedAt.startsWith('@ ')) {
            updatedAt = updatedAt.substring(2);
          }

          // 解析评论内容
          final textElement = item.querySelector('.text');
          String commentText = '';
          if (textElement != null) {
            // 我们只需要 .text 下的直接文本或者是除了 meta 信息之外的内容
            // 简单的做法是克隆节点，移除 meta 信息
            final clone = textElement.clone(true);
            // 移除 a 标签 (用户名) 和 span 标签 (评分) 以及 grey 标签 (日期)
            clone.querySelectorAll('a').forEach((e) => e.remove());
            clone.querySelectorAll('.starsinfo').forEach((e) => e.remove());
            clone.querySelectorAll('.grey').forEach((e) => e.remove());
            commentText = clone.text.trim();
          }

          comments.add(BangumiComment(
            user: BangumiUser(nickname: nickname, avatar: avatar),
            rate: rate,
            updatedAt: updatedAt,
            comment: commentText,
          ));
        } catch (e) {
          debugPrint('[BangumiApi] Parsing individual comment failed: $e');
        }
      }

      return comments;
    } catch (e) {
      debugPrint('[BangumiApi] fetchSubjectComments failed: $e');
      return [];
    }
  }
}
