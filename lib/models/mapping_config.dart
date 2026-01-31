class MappingConfig {
  final String title;
  final bool titleEnabled;
  final String airDate;
  final bool airDateEnabled;
  final String tags;
  final bool tagsEnabled;
  final String imageUrl;
  final bool imageUrlEnabled;
  final String bangumiId;
  final bool bangumiIdEnabled;
  final String score;
  final bool scoreEnabled;
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

  MappingConfig({
    this.title = '',
    this.titleEnabled = true,
    this.airDate = '',
    this.airDateEnabled = true,
    this.tags = '',
    this.tagsEnabled = true,
    this.imageUrl = '',
    this.imageUrlEnabled = true,
    this.bangumiId = '',
    this.bangumiIdEnabled = true,
    this.score = '',
    this.scoreEnabled = true,
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
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'titleEnabled': titleEnabled,
      'airDate': airDate,
      'airDateEnabled': airDateEnabled,
      'tags': tags,
      'tagsEnabled': tagsEnabled,
      'imageUrl': imageUrl,
      'imageUrlEnabled': imageUrlEnabled,
      'bangumiId': bangumiId,
      'bangumiIdEnabled': bangumiIdEnabled,
      'score': score,
      'scoreEnabled': scoreEnabled,
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
    };
  }

  factory MappingConfig.fromJson(Map<String, dynamic> json) {
    return MappingConfig(
      title: json['title'] ?? '',
      titleEnabled: json['titleEnabled'] ?? true,
      airDate: json['airDate'] ?? '',
      airDateEnabled: json['airDateEnabled'] ?? true,
      tags: json['tags'] ?? '',
      tagsEnabled: json['tagsEnabled'] ?? true,
      imageUrl: json['imageUrl'] ?? '',
      imageUrlEnabled: json['imageUrlEnabled'] ?? true,
      bangumiId: json['bangumiId'] ?? '',
      bangumiIdEnabled: json['bangumiIdEnabled'] ?? true,
      score: json['score'] ?? '',
      scoreEnabled: json['scoreEnabled'] ?? true,
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
    );
  }

  MappingConfig copyWith({
    String? title,
    bool? titleEnabled,
    String? airDate,
    bool? airDateEnabled,
    String? tags,
    bool? tagsEnabled,
    String? imageUrl,
    bool? imageUrlEnabled,
    String? bangumiId,
    bool? bangumiIdEnabled,
    String? score,
    bool? scoreEnabled,
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
  }) {
    return MappingConfig(
      title: title ?? this.title,
      titleEnabled: titleEnabled ?? this.titleEnabled,
      airDate: airDate ?? this.airDate,
      airDateEnabled: airDateEnabled ?? this.airDateEnabled,
      tags: tags ?? this.tags,
      tagsEnabled: tagsEnabled ?? this.tagsEnabled,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrlEnabled: imageUrlEnabled ?? this.imageUrlEnabled,
      bangumiId: bangumiId ?? this.bangumiId,
      bangumiIdEnabled: bangumiIdEnabled ?? this.bangumiIdEnabled,
      score: score ?? this.score,
      scoreEnabled: scoreEnabled ?? this.scoreEnabled,
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
    );
  }
}
