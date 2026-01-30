class MappingConfig {
  final String title;
  final String airDate;
  final String tags;
  final String imageUrl;
  final String bangumiId;
  final String score;
  final String link;
  final String animationProduction;
  final String director;
  final String script;
  final String storyboard;
  final String content;
  final String description;
  final String idPropertyName;

  MappingConfig({
    this.title = '',
    this.airDate = '',
    this.tags = '',
    this.imageUrl = '',
    this.bangumiId = '',
    this.score = '',
    this.link = '',
    this.animationProduction = '',
    this.director = '',
    this.script = '',
    this.storyboard = '',
    this.content = '',
    this.description = '',
    this.idPropertyName = '',
  });

  Map<String, String> toJson() {
    return {
      'title': title,
      'airDate': airDate,
      'tags': tags,
      'imageUrl': imageUrl,
      'bangumiId': bangumiId,
      'score': score,
      'link': link,
      'animationProduction': animationProduction,
      'director': director,
      'script': script,
      'storyboard': storyboard,
      'content': content,
      'description': description,
      'idPropertyName': idPropertyName,
    };
  }

  factory MappingConfig.fromJson(Map<String, dynamic> json) {
    return MappingConfig(
      title: json['title'] ?? '',
      airDate: json['airDate'] ?? '',
      tags: json['tags'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      bangumiId: json['bangumiId'] ?? '',
      score: json['score'] ?? '',
      link: json['link'] ?? '',
      animationProduction: json['animationProduction'] ?? '',
      director: json['director'] ?? '',
      script: json['script'] ?? '',
      storyboard: json['storyboard'] ?? '',
      content: json['content'] ?? '',
      description: json['description'] ?? '',
      idPropertyName: json['idPropertyName'] ?? '',
    );
  }

  MappingConfig copyWith({
    String? title,
    String? airDate,
    String? tags,
    String? imageUrl,
    String? bangumiId,
    String? score,
    String? link,
    String? animationProduction,
    String? director,
    String? script,
    String? storyboard,
    String? content,
    String? description,
    String? idPropertyName,
  }) {
    return MappingConfig(
      title: title ?? this.title,
      airDate: airDate ?? this.airDate,
      tags: tags ?? this.tags,
      imageUrl: imageUrl ?? this.imageUrl,
      bangumiId: bangumiId ?? this.bangumiId,
      score: score ?? this.score,
      link: link ?? this.link,
      animationProduction: animationProduction ?? this.animationProduction,
      director: director ?? this.director,
      script: script ?? this.script,
      storyboard: storyboard ?? this.storyboard,
      content: content ?? this.content,
      description: description ?? this.description,
      idPropertyName: idPropertyName ?? this.idPropertyName,
    );
  }
}
