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

class BangumiCalendarWeekday {
  const BangumiCalendarWeekday({
    required this.id,
    required this.en,
    required this.cn,
    required this.ja,
  });

  final int id;
  final String en;
  final String cn;
  final String ja;

  factory BangumiCalendarWeekday.fromJson(Map<String, dynamic> json) {
    return BangumiCalendarWeekday(
      id: (json['id'] as num?)?.toInt() ?? 0,
      en: json['en'] as String? ?? '',
      cn: json['cn'] as String? ?? '',
      ja: json['ja'] as String? ?? '',
    );
  }
}

class BangumiCalendarItem {
  const BangumiCalendarItem({
    required this.id,
    required this.type,
    required this.name,
    required this.nameCn,
    required this.summary,
    required this.imageUrl,
    required this.airDate,
    required this.airWeekday,
    required this.eps,
    required this.epsCount,
  });

  final int id;
  final int type;
  final String name;
  final String nameCn;
  final String summary;
  final String imageUrl;
  final String airDate;
  final int airWeekday;
  final int eps;
  final int epsCount;

  factory BangumiCalendarItem.fromJson(Map<String, dynamic> json) {
    final images = json['images'] as Map<String, dynamic>?;
    int parseInt(dynamic value) {
      if (value is num) return value.toInt();
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) return 0;
        return int.tryParse(trimmed) ??
            double.tryParse(trimmed)?.round() ??
            0;
      }
      return 0;
    }
    return BangumiCalendarItem(
      id: parseInt(json['id']),
      type: parseInt(json['type']),
      name: json['name'] as String? ?? '',
      nameCn: json['name_cn'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      imageUrl: images?['medium'] as String? ??
          images?['common'] as String? ??
          images?['small'] as String? ??
          '',
      airDate: json['air_date'] as String? ?? '',
      airWeekday: parseInt(json['air_weekday']),
      eps: parseInt(json['eps']),
      epsCount: parseInt(json['eps_count']),
    );
  }
}

class BangumiCalendarDay {
  const BangumiCalendarDay({
    required this.weekday,
    required this.items,
  });

  final BangumiCalendarWeekday weekday;
  final List<BangumiCalendarItem> items;

  factory BangumiCalendarDay.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return BangumiCalendarDay(
      weekday: BangumiCalendarWeekday.fromJson(
        json['weekday'] as Map<String, dynamic>? ?? {},
      ),
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(BangumiCalendarItem.fromJson)
          .toList(),
    );
  }
}

class BangumiEpisode {
  const BangumiEpisode({
    required this.id,
    required this.type,
    required this.sort,
    required this.ep,
    required this.airDate,
  });

  final int id;
  final int type;
  final double sort;
  final double ep;
  final String airDate;

  factory BangumiEpisode.fromJson(Map<String, dynamic> json) {
    return BangumiEpisode(
      id: (json['id'] as num?)?.toInt() ?? 0,
      type: (json['type'] as num?)?.toInt() ?? 0,
      sort: (json['sort'] as num?)?.toDouble() ?? 0,
      ep: (json['ep'] as num?)?.toDouble() ??
          (json['sort'] as num?)?.toDouble() ??
          0,
      airDate: json['airdate'] as String? ?? '',
    );
  }
}

class BangumiTag {
  final String name;
  final int count;

  const BangumiTag({
    required this.name,
    required this.count,
  });

  factory BangumiTag.fromJson(Map<String, dynamic> json) {
    return BangumiTag(
      name: json['name']?.toString() ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class BangumiSubjectDetail {
  BangumiSubjectDetail({
    required this.id,
    required this.name,
    required this.nameCn,
    required this.summary,
    required this.imageUrl,
    required this.airDate,
    required this.epsCount,
    required this.tags,
    required this.tagDetails,
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
  final List<BangumiTag> tagDetails;
  String studio;
  String director;
  String script;
  String storyboard;
  String animationProduction;
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

    final tagDetails = tagsJson
        .whereType<Map<String, dynamic>>()
        .map(BangumiTag.fromJson)
        .where((tag) => tag.name.isNotEmpty)
        .toList();
    final tagNames = tagDetails.map((tag) => tag.name).toList();

    return BangumiSubjectDetail(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      nameCn: json['name_cn'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      imageUrl:
          images?['large'] as String? ?? images?['medium'] as String? ?? '',
      airDate: json['date'] as String? ?? '',
      epsCount: (json['eps'] as num?)?.toInt() ?? 0,
      tags: tagNames,
      tagDetails: tagDetails,
      studio: _getFromInfoboxMap(infoboxMap, ['动画制作', '制作', '制作会社']),
      director: _getFromInfoboxMap(infoboxMap, ['导演', '監督']),
      script:
          _getFromInfoboxMap(infoboxMap, ['脚本', '剧本', '系列构成', '构成', 'シリーズ構成']),
      storyboard: _getFromInfoboxMap(infoboxMap, ['分镜', '絵コンテ', 'コンテ']),
      animationProduction:
          _getFromInfoboxMap(infoboxMap, ['动画制作', 'アニメーション制作']),
      score: (rating?['score'] as num?)?.toDouble() ?? 0.0,
      ratingTotal: (rating?['total'] as num?)?.toInt() ?? 0,
      ratingCount: (rating?['count'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, (value as num).toInt()),
          ) ??
          {},
      rank: (json['rating']?['rank'] as num?)?.toInt() ??
          (json['rank'] as num?)?.toInt(),
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

  BangumiSubjectDetail copyWith({
    int? id,
    String? name,
    String? nameCn,
    String? summary,
    String? imageUrl,
    String? airDate,
    int? epsCount,
    List<String>? tags,
    List<BangumiTag>? tagDetails,
    String? studio,
    String? director,
    String? script,
    String? storyboard,
    String? animationProduction,
    double? score,
    int? ratingTotal,
    Map<String, int>? ratingCount,
    int? rank,
    Map<String, String>? infoboxMap,
  }) {
    return BangumiSubjectDetail(
      id: id ?? this.id,
      name: name ?? this.name,
      nameCn: nameCn ?? this.nameCn,
      summary: summary ?? this.summary,
      imageUrl: imageUrl ?? this.imageUrl,
      airDate: airDate ?? this.airDate,
      epsCount: epsCount ?? this.epsCount,
      tags: tags ?? this.tags,
      tagDetails: tagDetails ?? this.tagDetails,
      studio: studio ?? this.studio,
      director: director ?? this.director,
      script: script ?? this.script,
      storyboard: storyboard ?? this.storyboard,
      animationProduction: animationProduction ?? this.animationProduction,
      score: score ?? this.score,
      ratingTotal: ratingTotal ?? this.ratingTotal,
      ratingCount: ratingCount ?? this.ratingCount,
      rank: rank ?? this.rank,
      infoboxMap: infoboxMap ?? this.infoboxMap,
    );
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
      updatedAt:
          json['created_at'] as String? ?? json['updated_at'] as String? ?? '',
      comment: json['comment'] as String? ?? json['content'] as String? ?? '',
    );
  }
}

class BangumiStaff {
  final int id;
  final String name;
  final String? nameCn;
  final String? avatar;
  final String? summary;
  final List<String>? jobs;

  BangumiStaff({
    required this.id,
    required this.name,
    this.nameCn,
    this.avatar,
    this.summary,
    this.jobs,
  });

  factory BangumiStaff.fromJson(Map<String, dynamic> json) {
    // p1 API 返回结构：{ staff: {...}, positions: [...] }
    // 旧结构（或其他接口）：{ id, name, name_cn, jobs/positions/... }
    final staffJson = (json['staff'] is Map<String, dynamic>)
        ? (json['staff'] as Map<String, dynamic>)
        : json;

    return BangumiStaff(
      id: (staffJson['id'] as num?)?.toInt() ?? 0,
      name: staffJson['name'] as String? ?? '',
      // name_cn (v0) / nameCN (p1)
      nameCn: (staffJson['name_cn'] as String?) ??
          (staffJson['nameCN'] as String?) ??
          (staffJson['nameCn'] as String?),
      avatar: (staffJson['images'] is Map)
          ? ((staffJson['images'] as Map)['medium'] as String?)
          : null,
      summary: staffJson['summary'] as String? ?? staffJson['info'] as String?,
      jobs: _parseJobs(json),
    );
  }

  static List<String>? _parseJobs(Map<String, dynamic> json) {
    final rawJobs = json['jobs'] ??
        json['positions'] ??
        json['position'] ??
        json['job'] ??
        json['role'];
    final parsed = _normalizeJobList(rawJobs);
    return parsed.isEmpty ? null : parsed;
  }

  static List<String> _normalizeJobList(dynamic rawJobs) {
    if (rawJobs == null) return [];
    if (rawJobs is List) {
      // p1 positions: [{ type: { cn/en/jp }, ... }]
      final out = <String>[];
      for (final e in rawJobs) {
        if (e is Map) {
          final type = e['type'];
          if (type is Map) {
            String pick(dynamic v) => (v is String) ? v.trim() : '';
            final cn = pick(type['cn']);
            final en = pick(type['en']);
            final jp = pick(type['jp']);
            final label = cn.isNotEmpty ? cn : (en.isNotEmpty ? en : jp);
            if (label.isNotEmpty) out.add(label);
            continue;
          }
        }
        final s = e.toString().trim();
        if (s.isNotEmpty) out.add(s);
      }
      return out;
    }
    if (rawJobs is String) {
      return rawJobs
          .split(RegExp(r'[、,/，;；|]|\\r?\\n'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [rawJobs.toString()];
  }

  @override
  String toString() => 'BangumiStaff($nameCn, $name)';
}

class StaffResponse {
  final int total;
  final int limit;
  final int offset;
  final List<BangumiStaff> data;

  StaffResponse({
    required this.total,
    required this.limit,
    required this.offset,
    required this.data,
  });

  factory StaffResponse.fromJson(Map<String, dynamic> json) {
    return StaffResponse(
      total: json['total'] as int? ?? 0,
      limit: json['limit'] as int? ?? 20,
      offset: json['offset'] as int? ?? 0,
      data: (json['data'] as List<dynamic>?)
              ?.map((e) => BangumiStaff.fromJson(e))
              .toList() ??
          [],
    );
  }
}
