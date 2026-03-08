import 'package:flutter/foundation.dart';

import 'batch_binding_ui_models.dart';
import 'batch_import_view_model.dart';

class BatchBindingUiController extends ChangeNotifier {
  BatchBindingUiController({
    this.autoBindThreshold = 85,
    bool onlyUnboundDefault = true,
  }) : _onlyUnbound = onlyUnboundDefault;

  final int autoBindThreshold;
  final Map<String, BatchUiItem> _itemsByPageId = {};
  final Set<String> _dismissedPageIds = {};

  String _query = '';
  bool _onlyUnbound;
  BatchSortMode _sortMode = BatchSortMode.similarity;
  String? _activePageId;

  String get query => _query;
  bool get onlyUnbound => _onlyUnbound;
  BatchSortMode get sortMode => _sortMode;

  List<BatchUiItem> get allItems =>
      List<BatchUiItem>.unmodifiable(_itemsByPageId.values);

  List<BatchUiItem> get visibleItems {
    final filtered = _itemsByPageId.values.where(_isVisible).toList();
    filtered.sort(_compareItems);
    return filtered;
  }

  BatchUiItem? get activeItem {
    final current =
        _activePageId == null ? null : _itemsByPageId[_activePageId];
    if (current != null && _isVisible(current)) {
      return current;
    }
    final visible = visibleItems;
    if (visible.isEmpty) {
      return null;
    }
    return visible.first;
  }

  int get pendingVisibleCount =>
      visibleItems.where((item) => !item.isBound).length;

  int get completedVisibleCount =>
      visibleItems.where((item) => item.isBound).length;

  int get selectedVisibleCount =>
      visibleItems.where((item) => item.selected).length;

  bool get hasVisibleSelection => selectedVisibleCount > 0;

  void applyCandidates(List<BatchImportCandidate> candidates) {
    final next = <String, BatchUiItem>{};
    for (final candidate in candidates) {
      final pageId = candidate.notionItem.id;
      if (pageId.trim().isEmpty) {
        continue;
      }
      if (_dismissedPageIds.contains(pageId)) {
        continue;
      }

      final previous = _itemsByPageId[pageId];
      final built = buildBatchUiItem(candidate);

      BatchItemStatus status = built.status;
      if (previous?.status == BatchItemStatus.conflict && !candidate.bound) {
        status = BatchItemStatus.conflict;
      }
      if (candidate.bound || previous?.status == BatchItemStatus.bound) {
        status = BatchItemStatus.bound;
      }

      next[pageId] = built.copyWith(
        status: status,
        selected: previous?.selected ?? false,
        selectedMatchId: _resolveRetainedSelectedMatchId(
          previous: previous,
          current: built,
        ),
      );
    }

    _itemsByPageId
      ..clear()
      ..addAll(next);

    _ensureActiveItem();
    notifyListeners();
  }

  void setQuery(String value) {
    if (_query == value) {
      return;
    }
    _query = value;
    _ensureActiveItem();
    notifyListeners();
  }

  void setOnlyUnbound(bool value) {
    if (_onlyUnbound == value) {
      return;
    }
    _onlyUnbound = value;
    _ensureActiveItem();
    notifyListeners();
  }

  void setSortMode(BatchSortMode value) {
    if (_sortMode == value) {
      return;
    }
    _sortMode = value;
    _ensureActiveItem();
    notifyListeners();
  }

  void selectItem(String pageId) {
    if (!_itemsByPageId.containsKey(pageId)) {
      return;
    }
    if (_activePageId == pageId) {
      return;
    }
    _activePageId = pageId;
    notifyListeners();
  }

  void selectCandidate(String pageId, int bangumiId) {
    final item = _itemsByPageId[pageId];
    if (item == null) {
      return;
    }
    final exists =
        item.scoredMatches.any((match) => match.item.id == bangumiId);
    if (!exists) {
      return;
    }
    if (item.selectedMatchId == bangumiId) {
      return;
    }
    _itemsByPageId[pageId] = item.copyWith(selectedMatchId: bangumiId);
    notifyListeners();
  }

  void toggleItemSelected(String pageId) {
    final item = _itemsByPageId[pageId];
    if (item == null) {
      return;
    }
    _itemsByPageId[pageId] = item.copyWith(selected: !item.selected);
    notifyListeners();
  }

  void clearSelection() {
    var changed = false;
    for (final entry in _itemsByPageId.entries.toList()) {
      if (!entry.value.selected) {
        continue;
      }
      changed = true;
      _itemsByPageId[entry.key] = entry.value.copyWith(selected: false);
    }
    if (!changed) {
      return;
    }
    notifyListeners();
  }

  void markBound(String pageId) {
    final item = _itemsByPageId[pageId];
    if (item == null) {
      return;
    }
    final nextCandidate = item.candidate.copyWith(bound: true);
    _itemsByPageId[pageId] = item.copyWith(
      candidate: nextCandidate,
      status: BatchItemStatus.bound,
      selected: false,
    );
    _ensureActiveItem();
    notifyListeners();
  }

  void toggleConflict(String pageId) {
    final item = _itemsByPageId[pageId];
    if (item == null || item.isBound) {
      return;
    }
    final nextStatus = item.status == BatchItemStatus.conflict
        ? BatchItemStatus.pending
        : BatchItemStatus.conflict;
    _itemsByPageId[pageId] = item.copyWith(status: nextStatus);
    notifyListeners();
  }

  List<BatchUiItem> removeSelectedVisibleItems() {
    final targets = visibleItems.where((item) => item.selected).toList();
    if (targets.isEmpty) {
      return const [];
    }

    for (final item in targets) {
      _dismissedPageIds.add(item.pageId);
      _itemsByPageId.remove(item.pageId);
    }

    _ensureActiveItem();
    notifyListeners();
    return targets;
  }

  List<BatchUiItem> selectedVisibleItemsForBinding() {
    return visibleItems
        .where((item) =>
            item.selected && !item.isBound && item.scoredMatches.isNotEmpty)
        .toList();
  }

  int? preferredBangumiIdFor(BatchUiItem item) {
    return item.selectedMatch?.item.id ?? item.bestSimilarityMatch?.item.id;
  }

  List<BatchUiItem> autoBindableVisibleItems() {
    return visibleItems
        .where(
          (item) =>
              !item.isBound &&
              item.scoredMatches.isNotEmpty &&
              item.bestSimilarity >= autoBindThreshold,
        )
        .toList();
  }

  bool _isVisible(BatchUiItem item) {
    if (_dismissedPageIds.contains(item.pageId)) {
      return false;
    }
    if (_onlyUnbound && item.isBound) {
      return false;
    }
    return item.matchesQuery(_query);
  }

  Map<String, dynamic> exportSnapshot() {
    final selectedPageIds = _itemsByPageId.values
        .where((item) => item.selected)
        .map((item) => item.pageId)
        .toList(growable: false);
    final selectedMatchByPageId = <String, int>{};
    final conflictPageIds = <String>[];
    for (final item in _itemsByPageId.values) {
      final selectedMatchId = item.selectedMatchId;
      if (selectedMatchId != null) {
        selectedMatchByPageId[item.pageId] = selectedMatchId;
      }
      if (item.status == BatchItemStatus.conflict) {
        conflictPageIds.add(item.pageId);
      }
    }

    return {
      'query': _query,
      'onlyUnbound': _onlyUnbound,
      'sortMode': _sortMode.name,
      'activePageId': _activePageId,
      'selectedPageIds': selectedPageIds,
      'selectedMatchByPageId': selectedMatchByPageId,
      'conflictPageIds': conflictPageIds,
      'dismissedPageIds': _dismissedPageIds.toList(growable: false),
    };
  }

  void restoreSnapshot(
    Map<String, dynamic> snapshot, {
    bool notify = true,
  }) {
    final query = snapshot['query']?.toString() ?? '';
    final onlyUnbound = snapshot['onlyUnbound'] == true;
    final sortModeName = snapshot['sortMode']?.toString();
    final activePageId = snapshot['activePageId']?.toString();
    final dismissed = _parseStringSet(snapshot['dismissedPageIds']);

    _query = query;
    _onlyUnbound = onlyUnbound;
    _sortMode = BatchSortMode.values.firstWhere(
      (item) => item.name == sortModeName,
      orElse: () => BatchSortMode.similarity,
    );
    _activePageId = activePageId;

    _dismissedPageIds
      ..clear()
      ..addAll(dismissed);

    final selectedPageIds = _parseStringSet(snapshot['selectedPageIds']);
    final selectedMatchByPageId =
        _parseSelectedMatchMap(snapshot['selectedMatchByPageId']);
    final conflictPageIds = _parseStringSet(snapshot['conflictPageIds']);

    final keys = _itemsByPageId.keys.toList(growable: false);
    for (final pageId in keys) {
      final current = _itemsByPageId[pageId];
      if (current == null) continue;
      final selected = selectedPageIds.contains(pageId);
      final selectedMatchId = selectedMatchByPageId[pageId];
      final keepSelectedMatch = selectedMatchId != null &&
          current.scoredMatches
              .any((match) => match.item.id == selectedMatchId);
      final status = current.isBound
          ? BatchItemStatus.bound
          : (conflictPageIds.contains(pageId)
              ? BatchItemStatus.conflict
              : BatchItemStatus.pending);
      _itemsByPageId[pageId] = current.copyWith(
        selected: selected,
        status: status,
        selectedMatchId: keepSelectedMatch ? selectedMatchId : null,
        clearSelectedMatchId: !keepSelectedMatch,
      );
    }

    _ensureActiveItem();
    if (notify) {
      notifyListeners();
    }
  }

  Set<String> _parseStringSet(dynamic raw) {
    if (raw is! List) return <String>{};
    return raw
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toSet();
  }

  Map<String, int> _parseSelectedMatchMap(dynamic raw) {
    if (raw is! Map) return const {};
    final result = <String, int>{};
    for (final entry in raw.entries) {
      final key = entry.key.toString();
      final value = int.tryParse(entry.value.toString());
      if (key.trim().isEmpty || value == null) continue;
      result[key] = value;
    }
    return result;
  }

  void _ensureActiveItem() {
    final visible = visibleItems;
    if (visible.isEmpty) {
      _activePageId = null;
      return;
    }

    if (_activePageId != null) {
      final current = _itemsByPageId[_activePageId!];
      if (current != null && _isVisible(current)) {
        return;
      }
    }

    _activePageId = visible.first.pageId;
  }

  int _compareItems(BatchUiItem left, BatchUiItem right) {
    int result;
    switch (_sortMode) {
      case BatchSortMode.similarity:
        result = right.bestSimilarity.compareTo(left.bestSimilarity);
        break;
      case BatchSortMode.score:
        result = right.scoreSortValue.compareTo(left.scoreSortValue);
        break;
      case BatchSortMode.year:
        result = right.yearSortValue.compareTo(left.yearSortValue);
        break;
    }

    if (result != 0) {
      return result;
    }

    result = right.bestSimilarity.compareTo(left.bestSimilarity);
    if (result != 0) {
      return result;
    }

    return left.title.toLowerCase().compareTo(right.title.toLowerCase());
  }

  int? _resolveRetainedSelectedMatchId({
    required BatchUiItem? previous,
    required BatchUiItem current,
  }) {
    final previousSelectedId = previous?.selectedMatchId;
    if (previousSelectedId == null) {
      return current.selectedMatchId;
    }
    final exists = current.scoredMatches
        .any((match) => match.item.id == previousSelectedId);
    if (exists) {
      return previousSelectedId;
    }
    return current.selectedMatchId;
  }
}
