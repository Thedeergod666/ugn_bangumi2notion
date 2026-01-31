class BangumiSearchItem {
  const BangumiSearchItem({
    required this.id,
    required this.name,
    required this.nameCn,
    required this.summary,
    required this.imageUrl,
    required this.airDate,
  });

  final int id;
  final String name;
  final String nameCn;
  final String summary;
  final String imageUrl;
  final String airDate;

  factory BangumiSearchItem.fromJson(Map<String, dynamic> json) {
    final images = json['images'] as Map<String, dynamic>?;
    return BangumiSearchItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      nameCn: json['name_cn'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      imageUrl: images?['medium'] as String? ?? '',
      airDate: json['date'] as String? ?? '',
    );
  }
}

class BangumiSubjectDetail {
  const BangumiSubjectDetail({
    required this.id,
    required this.name,
    required this.nameCn,
    required this.summary,
    required this.imageUrl,
    required this.airDate,
    required this.epsCount,
    required this.tags,
    required this.studio,
    required this.director,
    required this.script,
    required this.storyboard,
    required this.animationProduction,
    required this.score,
    required this.ratingTotal,
    required this.ratingCount,
    this.rank,
    required this.infoboxMap,
  });

  final int id;
  final String name;
  final String nameCn;
  final String summary;
  final String imageUrl;
  final String airDate;
  final int epsCount;
  final List<String> tags;
  final String studio;
  final String director;
  final String script;
  final String storyboard;
  final String animationProduction;
  final double score;
  final int ratingTotal;
  final Map<String, int> ratingCount;
  final int? rank;
  final Map<String, String> infoboxMap;

  factory BangumiSubjectDetail.fromJson(Map<String, dynamic> json) {
    final images = json['images'] as Map<String, dynamic>?;
    final tagsJson = json['tags'] as List<dynamic>? ?? [];
    final infoboxList = json['infobox'] as List<dynamic>? ?? [];
    final rating = json['rating'] as Map<String, dynamic>?;

    final infoboxMap = _buildInfoboxMap(infoboxList);

    return BangumiSubjectDetail(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      nameCn: json['name_cn'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      imageUrl: images?['large'] as String? ?? images?['medium'] as String? ?? '',
      airDate: json['date'] as String? ?? '',
      epsCount: (json['eps'] as num?)?.toInt() ?? 0,
      tags: tagsJson
          .map((tag) => tag is Map<String, dynamic> ? tag['name'] as String? : null)
          .whereType<String>()
          .toList(),
      studio: _getFromInfoboxMap(infoboxMap, ['动画制作', '制作', '制作会社']),
      director: _getFromInfoboxMap(infoboxMap, ['导演', '監督']),
      script: _getFromInfoboxMap(infoboxMap, ['脚本']),
      storyboard: _getFromInfoboxMap(infoboxMap, ['分镜', '絵コンテ']),
      animationProduction: _getFromInfoboxMap(infoboxMap, ['动画制作', 'アニメーション制作']),
      score: (rating?['score'] as num?)?.toDouble() ?? 0.0,
      ratingTotal: (rating?['total'] as num?)?.toInt() ?? 0,
      ratingCount: (rating?['count'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, (value as num).toInt()),
          ) ??
          {},
      rank: (json['rating']?['rank'] as num?)?.toInt() ?? (json['rank'] as num?)?.toInt(),
      infoboxMap: infoboxMap,
    );
  }

  static Map<String, String> _buildInfoboxMap(List<dynamic> infobox) {
    final Map<String, String> result = {};
    for (final item in infobox) {
      if (item is Map<String, dynamic>) {
        final key = item['key'] as String? ?? '';
        if (key.isEmpty) continue;
        final value = item['value'];
        String valueStr = '';
        if (value is String) {
          valueStr = value;
        } else if (value is List) {
          valueStr = value
              .map((v) {
                if (v is Map<String, dynamic>) {
                  return v['v'] as String? ?? '';
                }
                return v.toString();
              })
              .where((v) => v.isNotEmpty)
              .join('、');
        }
        if (valueStr.isNotEmpty) {
          result[key] = valueStr;
        }
      }
    }
    return result;
  }

  static String _getFromInfoboxMap(Map<String, String> map, List<String> keys) {
    for (final key in keys) {
      if (map.containsKey(key)) return map[key]!;
    }
    // 如果没有精确匹配，尝试包含匹配
    for (final entry in map.entries) {
      if (keys.any((k) => entry.key.contains(k))) {
        return entry.value;
      }
    }
    return '';
  }
}

class BangumiUser {
  const BangumiUser({
    required this.nickname,
    required this.avatar,
  });

  final String nickname;
  final String avatar;

  factory BangumiUser.fromJson(Map<String, dynamic> json) {
    final avatarMap = json['avatar'] as Map<String, dynamic>?;
    return BangumiUser(
      nickname: json['nickname'] as String? ?? '',
      avatar: avatarMap?['large'] as String? ??
          avatarMap?['medium'] as String? ??
          avatarMap?['small'] as String? ??
          '',
    );
  }
}

class BangumiComment {
  const BangumiComment({
    required this.user,
    required this.rate,
    required this.updatedAt,
    required this.comment,
  });

  final BangumiUser user;
  final int rate;
  final String updatedAt;
  final String comment;

  factory BangumiComment.fromJson(Map<String, dynamic> json) {
    return BangumiComment(
      user: BangumiUser.fromJson(json['user'] as Map<String, dynamic>? ?? {}),
      rate: (json['rate'] as num?)?.toInt() ?? 0,
      updatedAt: json['updated_at'] as String? ?? '',
      comment: json['comment'] as String? ?? '',
    );
  }
}
