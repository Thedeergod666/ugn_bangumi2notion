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
}
