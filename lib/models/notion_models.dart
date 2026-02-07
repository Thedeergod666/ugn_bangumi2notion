class NotionProperty {
  final String name;
  final String type;

  NotionProperty({required this.name, required this.type});

  Map<String, String> toJson() {
    return {
      'name': name,
      'type': type,
    };
  }

  factory NotionProperty.fromJson(Map<String, dynamic> json) {
    return NotionProperty(
      name: json['name'] ?? '',
      type: json['type'] ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotionProperty &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          type == other.type;

  @override
  int get hashCode => name.hashCode ^ type.hashCode;
}

class DailyRecommendation {
  final String title;
  final double? yougnScore;
  final double? bangumiScore;
  final DateTime? airDate;
  final DateTime? airEndDate;
  final DateTime? followDate;
  final List<String> tags;
  final String? type;
  final String? shortReview;
  final String? longReview;
  final String? cover;
  final String? contentCoverUrl;
  final String? contentLongReview;
  final String? bangumiId;
  final String? subjectId;
  final String? pageId;
  final String? pageUrl;
  final String? animationProduction;
  final String? director;
  final String? script;
  final String? storyboard;

  const DailyRecommendation({
    required this.title,
    required this.yougnScore,
    required this.bangumiScore,
    required this.airDate,
    required this.airEndDate,
    required this.followDate,
    required this.tags,
    required this.type,
    required this.shortReview,
    required this.longReview,
    required this.cover,
    this.contentCoverUrl,
    this.contentLongReview,
    required this.bangumiId,
    required this.subjectId,
    required this.pageId,
    required this.pageUrl,
    required this.animationProduction,
    required this.director,
    required this.script,
    required this.storyboard,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'yougnScore': yougnScore,
      'bangumiScore': bangumiScore,
      'airDate': airDate?.toIso8601String(),
      'airEndDate': airEndDate?.toIso8601String(),
      'followDate': followDate?.toIso8601String(),
      'tags': tags,
      'type': type,
      'shortReview': shortReview,
      'longReview': longReview,
      'cover': cover,
      'contentCoverUrl': contentCoverUrl,
      'contentLongReview': contentLongReview,
      'bangumiId': bangumiId,
      'subjectId': subjectId,
      'pageId': pageId,
      'pageUrl': pageUrl,
      'animationProduction': animationProduction,
      'director': director,
      'script': script,
      'storyboard': storyboard,
    };
  }

  factory DailyRecommendation.fromJson(Map<String, dynamic> json) {
    final tagsRaw = json['tags'];
    final tags = tagsRaw is List
        ? tagsRaw
            .map((e) => e?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toList()
        : <String>[];
    final airDateText = json['airDate']?.toString();
    final airEndDateText = json['airEndDate']?.toString();
    final followDateText = json['followDate']?.toString();
    return DailyRecommendation(
      title: json['title']?.toString() ?? '',
      yougnScore: (json['yougnScore'] as num?)?.toDouble(),
      bangumiScore: (json['bangumiScore'] as num?)?.toDouble(),
      airDate: airDateText != null && airDateText.isNotEmpty
          ? DateTime.tryParse(airDateText)
          : null,
      airEndDate: airEndDateText != null && airEndDateText.isNotEmpty
          ? DateTime.tryParse(airEndDateText)
          : null,
      followDate: followDateText != null && followDateText.isNotEmpty
          ? DateTime.tryParse(followDateText)
          : null,
      tags: tags,
      type: json['type']?.toString(),
      shortReview: json['shortReview']?.toString(),
      longReview: json['longReview']?.toString(),
      cover: json['cover']?.toString(),
      contentCoverUrl: json['contentCoverUrl']?.toString(),
      contentLongReview: json['contentLongReview']?.toString(),
      bangumiId: json['bangumiId']?.toString(),
      subjectId: json['subjectId']?.toString(),
      pageId: json['pageId']?.toString(),
      pageUrl: json['pageUrl']?.toString(),
      animationProduction: json['animationProduction']?.toString(),
      director: json['director']?.toString(),
      script: json['script']?.toString(),
      storyboard: json['storyboard']?.toString(),
    );
  }
}

class NotionScoreEntry {
  final double yougnScore;
  final double bangumiScore;

  const NotionScoreEntry({
    required this.yougnScore,
    required this.bangumiScore,
  });
}

class NotionSearchItem {
  final String id;
  final String title;
  final String url;

  const NotionSearchItem({
    required this.id,
    required this.title,
    required this.url,
  });
}

class BangumiProgressInfo {
  final int watchedEpisodes;
  final double? yougnScore;

  const BangumiProgressInfo({
    required this.watchedEpisodes,
    this.yougnScore,
  });
}
