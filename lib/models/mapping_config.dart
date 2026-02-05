class MappingConfig {
  final String title;
  final bool titleEnabled;
  final String airDate;
  final bool airDateEnabled;
  final String airDateRange;
  final bool airDateRangeEnabled;
  final String tags;
  final bool tagsEnabled;
  final String imageUrl;
  final bool imageUrlEnabled;
  final String bangumiId;
  final bool bangumiIdEnabled;
  final String score;
  final bool scoreEnabled;
  final String totalEpisodes;
  final bool totalEpisodesEnabled;
  final String link;
  final bool linkEnabled;
  final String animationProduction;
  final bool animationProductionEnabled;
  final String director;
  final bool directorEnabled;
  final String script;
  final bool scriptEnabled;
  final String storyboard;
  final bool storyboardEnabled;
  final String content;
  final bool contentEnabled;
  final String description;
  final bool descriptionEnabled;
  final String idPropertyName;
  final String notionId;
  final String watchingStatus;
  final String watchingStatusValue;
  final String watchedEpisodes;
  final NotionDailyRecommendationBindings dailyRecommendationBindings;

  MappingConfig({
    this.title = '',
    this.titleEnabled = true,
    this.airDate = '',
    this.airDateEnabled = true,
    this.airDateRange = '',
    this.airDateRangeEnabled = true,
    this.tags = '',
    this.tagsEnabled = true,
    this.imageUrl = '',
    this.imageUrlEnabled = true,
    this.bangumiId = '',
    this.bangumiIdEnabled = true,
    this.score = '',
    this.scoreEnabled = true,
    this.totalEpisodes = '',
    this.totalEpisodesEnabled = true,
    this.link = '',
    this.linkEnabled = true,
    this.animationProduction = '',
    this.animationProductionEnabled = true,
    this.director = '',
    this.directorEnabled = true,
    this.script = '',
    this.scriptEnabled = true,
    this.storyboard = '',
    this.storyboardEnabled = true,
    this.content = '',
    this.contentEnabled = true,
    this.description = '',
    this.descriptionEnabled = true,
    this.idPropertyName = 'Bangumi ID',
    this.notionId = 'Notion ID',
    this.watchingStatus = '',
    this.watchingStatusValue = '',
    this.watchedEpisodes = '',
    this.dailyRecommendationBindings =
        const NotionDailyRecommendationBindings(),
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'titleEnabled': titleEnabled,
      'airDate': airDate,
      'airDateEnabled': airDateEnabled,
      'airDateRange': airDateRange,
      'airDateRangeEnabled': airDateRangeEnabled,
      'tags': tags,
      'tagsEnabled': tagsEnabled,
      'imageUrl': imageUrl,
      'imageUrlEnabled': imageUrlEnabled,
      'bangumiId': bangumiId,
      'bangumiIdEnabled': bangumiIdEnabled,
      'score': score,
      'scoreEnabled': scoreEnabled,
      'totalEpisodes': totalEpisodes,
      'totalEpisodesEnabled': totalEpisodesEnabled,
      'link': link,
      'linkEnabled': linkEnabled,
      'animationProduction': animationProduction,
      'animationProductionEnabled': animationProductionEnabled,
      'director': director,
      'directorEnabled': directorEnabled,
      'script': script,
      'scriptEnabled': scriptEnabled,
      'storyboard': storyboard,
      'storyboardEnabled': storyboardEnabled,
      'content': content,
      'contentEnabled': contentEnabled,
      'description': description,
      'descriptionEnabled': descriptionEnabled,
      'idPropertyName': idPropertyName,
      'notionId': notionId,
      'watchingStatus': watchingStatus,
      'watchingStatusValue': watchingStatusValue,
      'watchedEpisodes': watchedEpisodes,
      'dailyRecommendationBindings': dailyRecommendationBindings.toJson(),
    };
  }

  factory MappingConfig.fromJson(Map<String, dynamic> json) {
    return MappingConfig(
      title: json['title'] ?? '',
      titleEnabled: json['titleEnabled'] ?? true,
      airDate: json['airDate'] ?? '',
      airDateEnabled: json['airDateEnabled'] ?? true,
      airDateRange: json['airDateRange'] ?? '',
      airDateRangeEnabled: json['airDateRangeEnabled'] ?? true,
      tags: json['tags'] ?? '',
      tagsEnabled: json['tagsEnabled'] ?? true,
      imageUrl: json['imageUrl'] ?? '',
      imageUrlEnabled: json['imageUrlEnabled'] ?? true,
      bangumiId: json['bangumiId'] ?? '',
      bangumiIdEnabled: json['bangumiIdEnabled'] ?? true,
      score: json['score'] ?? '',
      scoreEnabled: json['scoreEnabled'] ?? true,
      totalEpisodes: json['totalEpisodes'] ?? '',
      totalEpisodesEnabled: json['totalEpisodesEnabled'] ?? true,
      link: json['link'] ?? '',
      linkEnabled: json['linkEnabled'] ?? true,
      animationProduction: json['animationProduction'] ?? '',
      animationProductionEnabled: json['animationProductionEnabled'] ?? true,
      director: json['director'] ?? '',
      directorEnabled: json['directorEnabled'] ?? true,
      script: json['script'] ?? '',
      scriptEnabled: json['scriptEnabled'] ?? true,
      storyboard: json['storyboard'] ?? '',
      storyboardEnabled: json['storyboardEnabled'] ?? true,
      content: json['content'] ?? '',
      contentEnabled: json['contentEnabled'] ?? true,
      description: json['description'] ?? '',
      descriptionEnabled: json['descriptionEnabled'] ?? true,
      idPropertyName: json['idPropertyName'] ?? 'Bangumi ID',
      notionId: json['notionId'] ?? 'Notion ID',
      watchingStatus: json['watchingStatus'] ?? '',
      watchingStatusValue: json['watchingStatusValue'] ?? '',
      watchedEpisodes: json['watchedEpisodes'] ?? '',
      dailyRecommendationBindings: NotionDailyRecommendationBindings.fromJson(
        json['dailyRecommendationBindings'] ?? {},
      ),
    );
  }

  MappingConfig copyWith({
    String? title,
    bool? titleEnabled,
    String? airDate,
    bool? airDateEnabled,
    String? airDateRange,
    bool? airDateRangeEnabled,
    String? tags,
    bool? tagsEnabled,
    String? imageUrl,
    bool? imageUrlEnabled,
    String? bangumiId,
    bool? bangumiIdEnabled,
    String? score,
    bool? scoreEnabled,
    String? totalEpisodes,
    bool? totalEpisodesEnabled,
    String? link,
    bool? linkEnabled,
    String? animationProduction,
    bool? animationProductionEnabled,
    String? director,
    bool? directorEnabled,
    String? script,
    bool? scriptEnabled,
    String? storyboard,
    bool? storyboardEnabled,
    String? content,
    bool? contentEnabled,
    String? description,
    bool? descriptionEnabled,
    String? idPropertyName,
    String? notionId,
    String? watchingStatus,
    String? watchingStatusValue,
    String? watchedEpisodes,
    NotionDailyRecommendationBindings? dailyRecommendationBindings,
  }) {
    return MappingConfig(
      title: title ?? this.title,
      titleEnabled: titleEnabled ?? this.titleEnabled,
      airDate: airDate ?? this.airDate,
      airDateEnabled: airDateEnabled ?? this.airDateEnabled,
      airDateRange: airDateRange ?? this.airDateRange,
      airDateRangeEnabled: airDateRangeEnabled ?? this.airDateRangeEnabled,
      tags: tags ?? this.tags,
      tagsEnabled: tagsEnabled ?? this.tagsEnabled,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrlEnabled: imageUrlEnabled ?? this.imageUrlEnabled,
      bangumiId: bangumiId ?? this.bangumiId,
      bangumiIdEnabled: bangumiIdEnabled ?? this.bangumiIdEnabled,
      score: score ?? this.score,
      scoreEnabled: scoreEnabled ?? this.scoreEnabled,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      totalEpisodesEnabled: totalEpisodesEnabled ?? this.totalEpisodesEnabled,
      link: link ?? this.link,
      linkEnabled: linkEnabled ?? this.linkEnabled,
      animationProduction: animationProduction ?? this.animationProduction,
      animationProductionEnabled:
          animationProductionEnabled ?? this.animationProductionEnabled,
      director: director ?? this.director,
      directorEnabled: directorEnabled ?? this.directorEnabled,
      script: script ?? this.script,
      scriptEnabled: scriptEnabled ?? this.scriptEnabled,
      storyboard: storyboard ?? this.storyboard,
      storyboardEnabled: storyboardEnabled ?? this.storyboardEnabled,
      content: content ?? this.content,
      contentEnabled: contentEnabled ?? this.contentEnabled,
      description: description ?? this.description,
      descriptionEnabled: descriptionEnabled ?? this.descriptionEnabled,
      idPropertyName: idPropertyName ?? this.idPropertyName,
      notionId: notionId ?? this.notionId,
      watchingStatus: watchingStatus ?? this.watchingStatus,
      watchingStatusValue: watchingStatusValue ?? this.watchingStatusValue,
      watchedEpisodes: watchedEpisodes ?? this.watchedEpisodes,
      dailyRecommendationBindings:
          dailyRecommendationBindings ?? this.dailyRecommendationBindings,
    );
  }
}

class NotionDailyRecommendationBindings {
  final String title;
  final String yougnScore;
  final String airDate;
  final String tags;
  final String type;
  final String shortReview;
  final String longReview;
  final String cover;
  final String? bangumiId;
  final String? subjectId;

  const NotionDailyRecommendationBindings({
    this.title = '',
    this.yougnScore = '',
    this.airDate = '',
    this.tags = '',
    this.type = '',
    this.shortReview = '',
    this.longReview = '',
    this.cover = '',
    this.bangumiId,
    this.subjectId,
  });

  bool get isEmpty {
    return title.isEmpty &&
        yougnScore.isEmpty &&
        airDate.isEmpty &&
        tags.isEmpty &&
        type.isEmpty &&
        shortReview.isEmpty &&
        longReview.isEmpty &&
        cover.isEmpty &&
        (bangumiId == null || bangumiId!.isEmpty) &&
        (subjectId == null || subjectId!.isEmpty);
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'yougnScore': yougnScore,
      'airDate': airDate,
      'tags': tags,
      'type': type,
      'shortReview': shortReview,
      'longReview': longReview,
      'cover': cover,
      'bangumiId': bangumiId,
      'subjectId': subjectId,
    };
  }

  factory NotionDailyRecommendationBindings.fromJson(
    Map<String, dynamic> json,
  ) {
    String? normalizeOptionalString(dynamic value) {
      if (value == null) return null;
      final text = value.toString();
      return text.isEmpty ? null : text;
    }

    return NotionDailyRecommendationBindings(
      title: json['title'] ?? '',
      yougnScore: json['yougnScore'] ?? '',
      airDate: json['airDate'] ?? '',
      tags: json['tags'] ?? '',
      type: json['type'] ?? '',
      shortReview: json['shortReview'] ?? '',
      longReview: json['longReview'] ?? '',
      cover: json['cover'] ?? '',
      bangumiId: normalizeOptionalString(json['bangumiId']),
      subjectId: normalizeOptionalString(json['subjectId']),
    );
  }

  NotionDailyRecommendationBindings copyWith({
    String? title,
    String? yougnScore,
    String? airDate,
    String? tags,
    String? type,
    String? shortReview,
    String? longReview,
    String? cover,
    String? bangumiId,
    String? subjectId,
  }) {
    return NotionDailyRecommendationBindings(
      title: title ?? this.title,
      yougnScore: yougnScore ?? this.yougnScore,
      airDate: airDate ?? this.airDate,
      tags: tags ?? this.tags,
      type: type ?? this.type,
      shortReview: shortReview ?? this.shortReview,
      longReview: longReview ?? this.longReview,
      cover: cover ?? this.cover,
      bangumiId: bangumiId ?? this.bangumiId,
      subjectId: subjectId ?? this.subjectId,
    );
  }
}
