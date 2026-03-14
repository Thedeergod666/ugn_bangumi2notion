class ProgressSegments {
  final int watched;
  final int updated;
  final int total;

  const ProgressSegments({
    required this.watched,
    required this.updated,
    required this.total,
  });
}

class EpisodeReleaseSummary {
  final int? latestAiredEpisode;
  final DateTime? latestAiredAt;
  final int? nextEpisode;
  final DateTime? nextAiredAt;

  const EpisodeReleaseSummary({
    this.latestAiredEpisode,
    this.latestAiredAt,
    this.nextEpisode,
    this.nextAiredAt,
  });

  static const empty = EpisodeReleaseSummary();

  int get updatedEpisodes => latestAiredEpisode ?? 0;
  bool get hasAnyData =>
      latestAiredEpisode != null ||
      latestAiredAt != null ||
      nextEpisode != null ||
      nextAiredAt != null;
}
