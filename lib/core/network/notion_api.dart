import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../../models/bangumi_models.dart';
import '../../models/mapping_config.dart';
import '../../models/notion_models.dart';
import '../utils/logging.dart';
import 'bangumi_api.dart';
import 'http_retry.dart';
part 'notion_api_daily_reco.dart';
part 'notion_api_sync.dart';

class NotionApi {
  NotionApi({http.Client? client, Logger? logger})
      : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _logger = logger ?? Logger();

  final http.Client _client;
  final bool _ownsClient;
  final Logger _logger;
  late final BangumiApi _bangumiApi = BangumiApi(
    client: _client,
    logger: _logger,
  );

  static const String _baseUrl = 'https://api.notion.com/v1';
  static const String _notionVersion = '2022-06-28';
  static const Duration _timeout = Duration(seconds: 12);
  static const Duration _queryTimeout = Duration(seconds: 30);
  static const Duration _blocksTimeout = Duration(seconds: 20);
  static const double defaultYougnScoreThreshold = 6.5;
  static const int _dailyRecommendationMaxQueryItems = 200;
  static const int _dailyRecommendationTargetItems = 50;
  static const int _scoreHistogramMaxItems = 1000;
  static const int _logTextLimit = 200;
  static const Set<String> _imageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.gif',
    '.bmp',
    '.avif',
    '.svg',
  };
  static final RegExp _urlPattern = RegExp('https?://[^\\s<>"\\\']+');

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  String? _normalizePageId(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    final urlMatch =
        RegExp(r"https?://(www\.)?notion\.so/.+").hasMatch(trimmed);
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
    double? parseNumber(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    final number = property['number'];
    final direct = parseNumber(number);
    if (direct != null) return direct;

    final formula = property['formula'];
    if (formula is Map<String, dynamic>) {
      final type = formula['type']?.toString();
      if (type == 'number') {
        final value = parseNumber(formula['number']);
        if (value != null) return value;
      }
    }

    final rollup = property['rollup'];
    if (rollup is Map<String, dynamic>) {
      final type = rollup['type']?.toString();
      if (type == 'number') {
        final value = parseNumber(rollup['number']);
        if (value != null) return value;
      }
    }

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
      return title.map((e) => e['plain_text'] ?? '').join().trim();
    }
    if (property.containsKey('rich_text')) {
      final List<dynamic>? text = property['rich_text'];
      if (text == null || text.isEmpty) return null;
      return text.map((e) => e['plain_text'] ?? '').join().trim();
    }
    final formula = property['formula'];
    if (formula is Map<String, dynamic>) {
      final type = formula['type']?.toString();
      if (type == 'string') {
        final text = formula['string']?.toString().trim() ?? '';
        return text.isEmpty ? null : text;
      }
      if (type == 'number') {
        final number = formula['number'];
        if (number is num) return number.toString();
        if (number is String) {
          final text = number.trim();
          return text.isEmpty ? null : text;
        }
      }
    }
    final rollup = property['rollup'];
    if (rollup is Map<String, dynamic>) {
      final type = rollup['type']?.toString();
      if (type == 'number') {
        final number = rollup['number'];
        if (number is num) return number.toString();
        if (number is String) {
          final text = number.trim();
          return text.isEmpty ? null : text;
        }
      }
      if (type == 'string') {
        final text = rollup['string']?.toString().trim() ?? '';
        return text.isEmpty ? null : text;
      }
    }
    return null;
  }

  DateTime? _extractDateValue(Map<String, dynamic> property) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is String && value.trim().isNotEmpty) {
        return DateTime.tryParse(value.trim());
      }
      return null;
    }

    final date = property['date'];
    if (date is Map<String, dynamic>) {
      final start = parseDate(date['start']);
      if (start != null) return start;
    }

    final formula = property['formula'];
    if (formula is Map<String, dynamic>) {
      final type = formula['type']?.toString();
      if (type == 'date') {
        final raw = formula['date'];
        if (raw is Map<String, dynamic>) {
          final start = parseDate(raw['start']);
          if (start != null) return start;
        }
      }
    }

    final rollup = property['rollup'];
    if (rollup is Map<String, dynamic>) {
      final type = rollup['type']?.toString();
      if (type == 'date') {
        final raw = rollup['date'];
        if (raw is Map<String, dynamic>) {
          final start = parseDate(raw['start']);
          if (start != null) return start;
        }
      }
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
        .map((e) =>
            e is Map<String, dynamic> ? (e['plain_text'] ?? '').toString() : '')
        .join()
        .trim();
    return text.isEmpty ? null : text;
  }

  bool _isLikelyImageUrl(String? raw) {
    if (raw == null) return false;
    final candidate = raw.trim();
    if (candidate.isEmpty) return false;
    final uri = Uri.tryParse(candidate);
    if (uri == null) return false;
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    final path = uri.path.toLowerCase();
    if (path.isEmpty) return false;
    return _imageExtensions.any(path.endsWith);
  }

  String _normalizeUrlCandidate(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return value;
    const leading = '<(["\'';
    const trailing = ')>],;"\'!?.';

    while (value.isNotEmpty && leading.contains(value[0])) {
      value = value.substring(1);
    }
    while (value.isNotEmpty && trailing.contains(value[value.length - 1])) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  String? _extractImageUrlFromText(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    for (final match in _urlPattern.allMatches(text)) {
      final hit = match.group(0);
      if (hit == null || hit.isEmpty) continue;
      final candidate = _normalizeUrlCandidate(hit);
      if (_isLikelyImageUrl(candidate)) {
        return candidate;
      }
    }
    return null;
  }

  String? _extractImageUrlFromRichText(List<dynamic>? richText) {
    if (richText == null || richText.isEmpty) return null;
    for (final item in richText) {
      if (item is! Map<String, dynamic>) continue;
      final href = _normalizeUrlCandidate(item['href']?.toString() ?? '');
      if (_isLikelyImageUrl(href)) return href;

      final text = item['text'];
      if (text is Map<String, dynamic>) {
        final link = text['link'];
        if (link is Map<String, dynamic>) {
          final linked = _normalizeUrlCandidate(link['url']?.toString() ?? '');
          if (_isLikelyImageUrl(linked)) return linked;
        }
        final content =
            _extractImageUrlFromText(text['content']?.toString() ?? '');
        if (content != null) return content;
      }

      final plain = _extractImageUrlFromText(item['plain_text']?.toString());
      if (plain != null) return plain;
    }
    return null;
  }

  String? _extractMediaUrlFromBlock(Map<String, dynamic> block) {
    final type = block['type']?.toString();
    if (type == null || type.isEmpty) return null;
    if (type == 'image') {
      return _extractImageUrlFromBlock(block);
    }

    String? candidate;
    final data = block[type];
    if (data is! Map<String, dynamic>) return null;

    switch (type) {
      case 'bookmark':
      case 'embed':
      case 'link_preview':
        candidate = data['url']?.toString();
        break;
      case 'video':
      case 'file':
      case 'pdf':
        final sourceType = data['type']?.toString();
        if (sourceType == 'external') {
          candidate = data['external']?['url']?.toString();
        } else if (sourceType == 'file') {
          candidate = data['file']?['url']?.toString();
        }
        candidate ??= data['url']?.toString();
        break;
    }

    if (candidate == null || candidate.trim().isEmpty) return null;
    final normalized = _normalizeUrlCandidate(candidate);
    return _isLikelyImageUrl(normalized) ? normalized : null;
  }

  List<dynamic>? _extractRichTextListFromBlock(Map<String, dynamic> block) {
    final type = block['type']?.toString();
    if (type == null || type.isEmpty) return null;
    final data = block[type];
    if (data is! Map<String, dynamic>) return null;
    final richText = data['rich_text'];
    if (richText is! List || richText.isEmpty) return null;
    return richText;
  }

  String? _extractCoverUrlFromPage(Map<String, dynamic> page) {
    final cover = page['cover'];
    if (cover is! Map<String, dynamic>) return null;
    final type = cover['type']?.toString();
    if (type == 'external') {
      final url = cover['external']?['url']?.toString() ?? '';
      return url.trim().isEmpty ? null : url.trim();
    }
    if (type == 'file') {
      final url = cover['file']?['url']?.toString() ?? '';
      return url.trim().isEmpty ? null : url.trim();
    }
    return null;
  }

  String? _extractImageUrlFromBlock(Map<String, dynamic> block) {
    if (block['type'] != 'image') return null;
    final image = block['image'] as Map<String, dynamic>?;
    if (image == null) return null;
    final type = image['type']?.toString();
    if (type == 'external') {
      final url = image['external']?['url']?.toString() ?? '';
      return url.trim().isEmpty ? null : url.trim();
    }
    if (type == 'file') {
      final url = image['file']?['url']?.toString() ?? '';
      return url.trim().isEmpty ? null : url.trim();
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
}
