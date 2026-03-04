import '../../../models/bangumi_models.dart';
import '../../../models/notion_models.dart';
import 'batch_binding_similarity.dart';

enum BatchSortMode {
  similarity,
  score,
  year,
}

enum BatchItemStatus {
  pending,
  bound,
  conflict,
}

enum BatchMatchLevel {
  best,
  near,
  suspicious,
}

BatchMatchLevel resolveMatchLevel(int similarity) {
  if (similarity >= 85) {
    return BatchMatchLevel.best;
  }
  if (similarity >= 60) {
    return BatchMatchLevel.near;
  }
  return BatchMatchLevel.suspicious;
}

String matchLevelText(BatchMatchLevel level) {
  switch (level) {
    case BatchMatchLevel.best:
      return '最匹配';
    case BatchMatchLevel.near:
      return '标题相近';
    case BatchMatchLevel.suspicious:
      return '疑似误匹配';
  }
}

class BatchScoredMatch {
  const BatchScoredMatch({
    required this.item,
    required this.similarity,
    required this.year,
  });

  final BangumiSearchItem item;
  final int similarity;
  final int year;

  String get displayTitle {
    final nameCn = item.nameCn.trim();
    if (nameCn.isNotEmpty) {
      return nameCn;
    }
    return item.name.trim();
  }

  BatchMatchLevel get level => resolveMatchLevel(similarity);
}

class BatchUiItem {
  const BatchUiItem({
    required this.candidate,
    required this.scoredMatches,
    required this.status,
    required this.selected,
  });

  final BatchImportCandidate candidate;
  final List<BatchScoredMatch> scoredMatches;
  final BatchItemStatus status;
  final bool selected;

  String get pageId => candidate.notionItem.id;

  String get title => candidate.notionItem.title;

  String? get notionId => candidate.notionItem.notionId;

  String get notionUrl => candidate.notionItem.url;

  bool get isBound => status == BatchItemStatus.bound;

  int get bestSimilarity {
    if (scoredMatches.isEmpty) {
      return 0;
    }
    return scoredMatches
        .map((match) => match.similarity)
        .reduce((left, right) => left > right ? left : right);
  }

  BatchScoredMatch? get bestSimilarityMatch {
    if (scoredMatches.isEmpty) {
      return null;
    }
    BatchScoredMatch best = scoredMatches.first;
    for (final match in scoredMatches.skip(1)) {
      if (match.similarity > best.similarity) {
        best = match;
      }
    }
    return best;
  }

  BatchScoredMatch? get highestScoreMatch {
    if (scoredMatches.isEmpty) {
      return null;
    }
    BatchScoredMatch best = scoredMatches.first;
    for (final match in scoredMatches.skip(1)) {
      final scoreCompare = match.item.score.compareTo(best.item.score);
      if (scoreCompare > 0) {
        best = match;
        continue;
      }
      if (scoreCompare == 0 && match.similarity > best.similarity) {
        best = match;
      }
    }
    return best;
  }

  double get scoreSortValue => highestScoreMatch?.item.score ?? 0;

  int get yearSortValue => highestScoreMatch?.year ?? 0;

  bool matchesQuery(String query) {
    final normalizedQuery = normalizeText(query);
    if (normalizedQuery.isEmpty) {
      return true;
    }
    if (normalizeText(title).contains(normalizedQuery)) {
      return true;
    }
    for (final match in scoredMatches) {
      if (match.item.id.toString().contains(normalizedQuery)) {
        return true;
      }
    }
    return false;
  }

  BatchUiItem copyWith({
    BatchImportCandidate? candidate,
    List<BatchScoredMatch>? scoredMatches,
    BatchItemStatus? status,
    bool? selected,
  }) {
    return BatchUiItem(
      candidate: candidate ?? this.candidate,
      scoredMatches: scoredMatches ?? this.scoredMatches,
      status: status ?? this.status,
      selected: selected ?? this.selected,
    );
  }
}

BatchUiItem buildBatchUiItem(BatchImportCandidate candidate) {
  final notionTitle = candidate.notionItem.title;
  final scoredMatches = candidate.matches
      .map(
        (item) => BatchScoredMatch(
          item: item,
          similarity: computeTitleSimilarity(
            notionTitle,
            item.nameCn.trim().isEmpty ? item.name : item.nameCn,
          ),
          year: extractAirYear(item.airDate),
        ),
      )
      .toList(growable: false);

  return BatchUiItem(
    candidate: candidate,
    scoredMatches: scoredMatches,
    status: candidate.bound ? BatchItemStatus.bound : BatchItemStatus.pending,
    selected: false,
  );
}
