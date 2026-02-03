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
  final DateTime? airDate;
  final List<String> tags;
  final String? type;
  final String? shortReview;
  final String? longReview;
  final String? cover;
  final String? contentCoverUrl;
  final String? contentLongReview;
  final String? bangumiId;
  final String? subjectId;

  const DailyRecommendation({
    required this.title,
    required this.yougnScore,
    required this.airDate,
    required this.tags,
    required this.type,
    required this.shortReview,
    required this.longReview,
    required this.cover,
    this.contentCoverUrl,
    this.contentLongReview,
    required this.bangumiId,
    required this.subjectId,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'yougnScore': yougnScore,
      'airDate': airDate?.toIso8601String(),
      'tags': tags,
      'type': type,
      'shortReview': shortReview,
      'longReview': longReview,
      'cover': cover,
      'contentCoverUrl': contentCoverUrl,
      'contentLongReview': contentLongReview,
      'bangumiId': bangumiId,
      'subjectId': subjectId,
    };
  }

  factory DailyRecommendation.fromJson(Map<String, dynamic> json) {
    final tagsRaw = json['tags'];
    final tags = tagsRaw is List
        ? tagsRaw.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList()
        : <String>[];
    final airDateText = json['airDate']?.toString();
    return DailyRecommendation(
      title: json['title']?.toString() ?? '',
      yougnScore: (json['yougnScore'] as num?)?.toDouble(),
      airDate: airDateText != null && airDateText.isNotEmpty
          ? DateTime.tryParse(airDateText)
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
    );
  }
}
