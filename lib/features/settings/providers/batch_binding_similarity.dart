import 'dart:math' as math;

String normalizeText(String raw) {
  final trimmed = raw.trim().toLowerCase();
  if (trimmed.isEmpty) {
    return '';
  }
  return trimmed.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');
}

int computeTitleSimilarity(String source, String target) {
  final a = normalizeText(source);
  final b = normalizeText(target);
  if (a.isEmpty || b.isEmpty) {
    return 0;
  }
  if (a == b) {
    return 100;
  }

  final editRatio = _levenshteinRatio(a, b);
  final ngramRatio = _ngramJaccard(a, b, 2);

  var score = (editRatio * 0.65 + ngramRatio * 0.35) * 100;

  if (a.contains(b) || b.contains(a)) {
    score = math.max(score, 85);
  }
  final aNoLatin = a.replaceAll(RegExp(r'[a-z0-9]+'), '');
  final bNoLatin = b.replaceAll(RegExp(r'[a-z0-9]+'), '');
  if (aNoLatin.isNotEmpty && bNoLatin.isNotEmpty) {
    if (aNoLatin.contains(bNoLatin) || bNoLatin.contains(aNoLatin)) {
      score = math.max(score, 88);
    }
    final overlap = _charOverlapRatio(aNoLatin, bNoLatin);
    if (overlap >= 0.75) {
      score = math.max(score, overlap * 100);
    }
  }

  return score.round().clamp(0, 100);
}

int? parseBangumiIdInput(String raw) {
  final text = raw.trim();
  if (text.isEmpty) {
    return null;
  }

  final number = int.tryParse(text);
  if (number != null && number > 0) {
    return number;
  }

  final uri = Uri.tryParse(text);
  if (uri == null) {
    return null;
  }

  final segments = uri.pathSegments;
  for (var i = 0; i < segments.length; i++) {
    if (segments[i] == 'subject' && i + 1 < segments.length) {
      final id = int.tryParse(segments[i + 1]);
      if (id != null && id > 0) {
        return id;
      }
    }
  }

  return null;
}

int extractAirYear(String airDate) {
  final match = RegExp(r'(19|20)\d{2}').firstMatch(airDate);
  if (match == null) {
    return 0;
  }
  return int.tryParse(match.group(0) ?? '') ?? 0;
}

double _levenshteinRatio(String a, String b) {
  final distance = _levenshteinDistance(a, b);
  final maxLen = math.max(a.length, b.length);
  if (maxLen == 0) {
    return 1;
  }
  return 1 - distance / maxLen;
}

int _levenshteinDistance(String a, String b) {
  if (a == b) {
    return 0;
  }
  if (a.isEmpty) {
    return b.length;
  }
  if (b.isEmpty) {
    return a.length;
  }

  final previous = List<int>.generate(b.length + 1, (index) => index);
  final current = List<int>.filled(b.length + 1, 0);

  for (var i = 1; i <= a.length; i++) {
    current[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      current[j] = math.min(
        math.min(current[j - 1] + 1, previous[j] + 1),
        previous[j - 1] + cost,
      );
    }
    for (var j = 0; j <= b.length; j++) {
      previous[j] = current[j];
    }
  }

  return previous[b.length];
}

double _ngramJaccard(String a, String b, int n) {
  final gramsA = _buildNgrams(a, n);
  final gramsB = _buildNgrams(b, n);

  if (gramsA.isEmpty || gramsB.isEmpty) {
    return 0;
  }

  final intersection = gramsA.intersection(gramsB).length;
  final union = gramsA.union(gramsB).length;
  if (union == 0) {
    return 0;
  }
  return intersection / union;
}

Set<String> _buildNgrams(String text, int n) {
  if (text.length < n) {
    return {text};
  }
  final grams = <String>{};
  for (var i = 0; i <= text.length - n; i++) {
    grams.add(text.substring(i, i + n));
  }
  return grams;
}

double _charOverlapRatio(String a, String b) {
  if (a.isEmpty || b.isEmpty) {
    return 0;
  }
  final setA = a.split('').toSet();
  final setB = b.split('').toSet();
  final intersection = setA.intersection(setB).length;
  final denominator = math.min(setA.length, setB.length);
  if (denominator == 0) {
    return 0;
  }
  return intersection / denominator;
}
