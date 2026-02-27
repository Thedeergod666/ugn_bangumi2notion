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
  final String watchingStatusValueWatched;
  final String watchedEpisodes;
  final String followDate;
  final String lastWatchedAt;
  final String bangumiUpdatedAt;
  final String globalIdPropertyName;
  final NotionDailyRecommendationBindings dailyRecommendationBindings;
  final NotionWatchBindings watchBindings;

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
    this.watchingStatusValueWatched = '已看',
    this.watchedEpisodes = '',
    this.followDate = '',
    this.lastWatchedAt = '',
    this.bangumiUpdatedAt = '',
    this.globalIdPropertyName = 'Bangumi ID',
    this.dailyRecommendationBindings =
        const NotionDailyRecommendationBindings(),
    this.watchBindings = const NotionWatchBindings(),
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
      'watchingStatusValueWatched': watchingStatusValueWatched,
      'watchedEpisodes': watchedEpisodes,
      'followDate': followDate,
      'lastWatchedAt': lastWatchedAt,
      'bangumiUpdatedAt': bangumiUpdatedAt,
      'globalIdPropertyName': globalIdPropertyName,
      'dailyRecommendationBindings': dailyRecommendationBindings.toJson(),
      'watchBindings': watchBindings.toJson(),
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
      watchingStatusValueWatched: json['watchingStatusValueWatched'] ?? '已看',
      watchedEpisodes: json['watchedEpisodes'] ?? '',
      followDate: json['followDate'] ?? '',
      lastWatchedAt: json['lastWatchedAt'] ?? '',
      bangumiUpdatedAt: json['bangumiUpdatedAt'] ?? '',
      globalIdPropertyName:
          json['globalIdPropertyName'] ?? 'Bangumi ID',
      dailyRecommendationBindings: NotionDailyRecommendationBindings.fromJson(
        json['dailyRecommendationBindings'] ?? {},
      ),
      watchBindings:
          NotionWatchBindings.fromJson(json['watchBindings'] ?? {}),
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
    String? watchingStatusValueWatched,
    String? watchedEpisodes,
    String? followDate,
    String? lastWatchedAt,
    String? bangumiUpdatedAt,
    String? globalIdPropertyName,
    NotionDailyRecommendationBindings? dailyRecommendationBindings,
    NotionWatchBindings? watchBindings,
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
      watchingStatusValueWatched:
          watchingStatusValueWatched ?? this.watchingStatusValueWatched,
      watchedEpisodes: watchedEpisodes ?? this.watchedEpisodes,
      followDate: followDate ?? this.followDate,
      lastWatchedAt: lastWatchedAt ?? this.lastWatchedAt,
      bangumiUpdatedAt: bangumiUpdatedAt ?? this.bangumiUpdatedAt,
      globalIdPropertyName:
          globalIdPropertyName ?? this.globalIdPropertyName,
      dailyRecommendationBindings:
          dailyRecommendationBindings ?? this.dailyRecommendationBindings,
      watchBindings: watchBindings ?? this.watchBindings,
    );
  }
}

class NotionWatchBindings {
  final String title;
  final String cover;
  final String bangumiId;
  final String watchedEpisodes;
  final String totalEpisodes;
  final String watchingStatus;
  final String followDate;
  final String lastWatchedAt;
  final String tags;
  final String yougnScore;

  const NotionWatchBindings({
    this.title = '',
    this.cover = '',
    this.bangumiId = '',
    this.watchedEpisodes = '',
    this.totalEpisodes = '',
    this.watchingStatus = '',
    this.followDate = '',
    this.lastWatchedAt = '',
    this.tags = '',
    this.yougnScore = '',
  });

  bool get isEmpty {
    return title.isEmpty &&
        cover.isEmpty &&
        bangumiId.isEmpty &&
        watchedEpisodes.isEmpty &&
        totalEpisodes.isEmpty &&
        watchingStatus.isEmpty &&
        followDate.isEmpty &&
        lastWatchedAt.isEmpty &&
        tags.isEmpty &&
        yougnScore.isEmpty;
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'cover': cover,
      'bangumiId': bangumiId,
      'watchedEpisodes': watchedEpisodes,
      'totalEpisodes': totalEpisodes,
      'watchingStatus': watchingStatus,
      'followDate': followDate,
      'lastWatchedAt': lastWatchedAt,
      'tags': tags,
      'yougnScore': yougnScore,
    };
  }

  factory NotionWatchBindings.fromJson(Map<String, dynamic> json) {
    return NotionWatchBindings(
      title: json['title'] ?? '',
      cover: json['cover'] ?? '',
      bangumiId: json['bangumiId'] ?? '',
      watchedEpisodes: json['watchedEpisodes'] ?? '',
      totalEpisodes: json['totalEpisodes'] ?? '',
      watchingStatus: json['watchingStatus'] ?? '',
      followDate: json['followDate'] ?? '',
      lastWatchedAt: json['lastWatchedAt'] ?? '',
      tags: json['tags'] ?? '',
      yougnScore: json['yougnScore'] ?? '',
    );
  }

  NotionWatchBindings copyWith({
    String? title,
    String? cover,
    String? bangumiId,
    String? watchedEpisodes,
    String? totalEpisodes,
    String? watchingStatus,
    String? followDate,
    String? lastWatchedAt,
    String? tags,
    String? yougnScore,
  }) {
    return NotionWatchBindings(
      title: title ?? this.title,
      cover: cover ?? this.cover,
      bangumiId: bangumiId ?? this.bangumiId,
      watchedEpisodes: watchedEpisodes ?? this.watchedEpisodes,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      watchingStatus: watchingStatus ?? this.watchingStatus,
      followDate: followDate ?? this.followDate,
      lastWatchedAt: lastWatchedAt ?? this.lastWatchedAt,
      tags: tags ?? this.tags,
      yougnScore: yougnScore ?? this.yougnScore,
    );
  }
}

class NotionDailyRecommendationBindings {
  final String title;
  final String yougnScore;
  final String bangumiScore;
  final String bangumiRank;
  final String followDate;
  final String airDate;
  final String airDateRange;
  final String tags;
  final String type;
  final String shortReview;
  final String longReview;
  final String cover;
  final String animationProduction;
  final String director;
  final String script;
  final String storyboard;
  final String? bangumiId;
  final String? subjectId;

  const NotionDailyRecommendationBindings({
    this.title = '',
    this.yougnScore = '',
    this.bangumiScore = '',
    this.bangumiRank = '',
    this.followDate = '',
    this.airDate = '',
    this.airDateRange = '',
    this.tags = '',
    this.type = '',
    this.shortReview = '',
    this.longReview = '',
    this.cover = '',
    this.animationProduction = '',
    this.director = '',
    this.script = '',
    this.storyboard = '',
    this.bangumiId,
    this.subjectId,
  });

  bool get isEmpty {
    return title.isEmpty &&
        yougnScore.isEmpty &&
        bangumiScore.isEmpty &&
        bangumiRank.isEmpty &&
        followDate.isEmpty &&
        airDate.isEmpty &&
        airDateRange.isEmpty &&
        tags.isEmpty &&
        type.isEmpty &&
        shortReview.isEmpty &&
        longReview.isEmpty &&
        cover.isEmpty &&
        animationProduction.isEmpty &&
        director.isEmpty &&
        script.isEmpty &&
        storyboard.isEmpty &&
        (bangumiId == null || bangumiId!.isEmpty) &&
        (subjectId == null || subjectId!.isEmpty);
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'yougnScore': yougnScore,
      'bangumiScore': bangumiScore,
      'bangumiRank': bangumiRank,
      'followDate': followDate,
      'airDate': airDate,
      'airDateRange': airDateRange,
      'tags': tags,
      'type': type,
      'shortReview': shortReview,
      'longReview': longReview,
      'cover': cover,
      'animationProduction': animationProduction,
      'director': director,
      'script': script,
      'storyboard': storyboard,
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
      bangumiScore: json['bangumiScore'] ?? '',
      bangumiRank: json['bangumiRank'] ?? '',
      followDate: json['followDate'] ?? '',
      airDate: json['airDate'] ?? '',
      airDateRange: json['airDateRange'] ?? '',
      tags: json['tags'] ?? '',
      type: json['type'] ?? '',
      shortReview: json['shortReview'] ?? '',
      longReview: json['longReview'] ?? '',
      cover: json['cover'] ?? '',
      animationProduction: json['animationProduction'] ?? '',
      director: json['director'] ?? '',
      script: json['script'] ?? '',
      storyboard: json['storyboard'] ?? '',
      bangumiId: normalizeOptionalString(json['bangumiId']),
      subjectId: normalizeOptionalString(json['subjectId']),
    );
  }

  NotionDailyRecommendationBindings copyWith({
    String? title,
    String? yougnScore,
    String? bangumiScore,
    String? bangumiRank,
    String? followDate,
    String? airDate,
    String? airDateRange,
    String? tags,
    String? type,
    String? shortReview,
    String? longReview,
    String? cover,
    String? animationProduction,
    String? director,
    String? script,
    String? storyboard,
    String? bangumiId,
    String? subjectId,
  }) {
    return NotionDailyRecommendationBindings(
      title: title ?? this.title,
      yougnScore: yougnScore ?? this.yougnScore,
      bangumiScore: bangumiScore ?? this.bangumiScore,
      bangumiRank: bangumiRank ?? this.bangumiRank,
      followDate: followDate ?? this.followDate,
      airDate: airDate ?? this.airDate,
      airDateRange: airDateRange ?? this.airDateRange,
      tags: tags ?? this.tags,
      type: type ?? this.type,
      shortReview: shortReview ?? this.shortReview,
      longReview: longReview ?? this.longReview,
      cover: cover ?? this.cover,
      animationProduction: animationProduction ?? this.animationProduction,
      director: director ?? this.director,
      script: script ?? this.script,
      storyboard: storyboard ?? this.storyboard,
      bangumiId: bangumiId ?? this.bangumiId,
      subjectId: subjectId ?? this.subjectId,
    );
  }
}
