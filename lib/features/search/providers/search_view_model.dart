import 'package:flutter/material.dart';

import '../app/app_settings.dart';
import '../models/bangumi_models.dart';
import '../models/notion_models.dart';
import '../services/bangumi_api.dart';
import '../services/notion_api.dart';
import '../services/settings_storage.dart';

enum SearchSource {
  bangumi,
  notion,
}

enum SearchSort {
  match,
  heat,
  collect,
}

extension SearchSortX on SearchSort {
  String get key {
    switch (this) {
      case SearchSort.heat:
        return 'heat';
      case SearchSort.collect:
        return 'collects';
      case SearchSort.match:
        return 'match';
    }
  }

  static SearchSort fromKey(String raw) {
    switch (raw) {
      case 'heat':
        return SearchSort.heat;
      case 'collects':
        return SearchSort.collect;
      default:
        return SearchSort.match;
    }
  }
}

class SearchViewModel extends ChangeNotifier {
  SearchViewModel({
    required BangumiApi bangumiApi,
    required NotionApi notionApi,
    required AppSettings settings,
    SettingsStorage? storage,
  })  : _bangumiApi = bangumiApi,
        _notionApi = notionApi,
        _settings = settings,
        _settingsStorage = storage ?? SettingsStorage();

  void initialize() {
    _sort = SearchSortX.fromKey(_settings.searchSort);
    loadHistory();
  }

  static const int maxKeywordLength = 50;

  final BangumiApi _bangumiApi;
  final NotionApi _notionApi;
  final AppSettings _settings;
  final SettingsStorage _settingsStorage;

  SearchSource _source = SearchSource.bangumi;
  SearchSort _sort = SearchSort.match;
  List<BangumiSearchItem> _items = [];
  List<NotionSearchItem> _notionItems = [];
  List<String> _history = [];
  bool _loading = false;
  String? _errorMessage;

  SearchSource get source => _source;
  SearchSort get sort => _sort;
  List<BangumiSearchItem> get items => _items;
  List<NotionSearchItem> get notionItems => _notionItems;
  bool get isLoading => _loading;
  String? get errorMessage => _errorMessage;
  List<String> get history => _history;

  void setSource(SearchSource source) {
    if (_source == source) return;
    _source = source;
    _items = [];
    _notionItems = [];
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> setSort(SearchSort sort) async {
    if (_sort == sort) return;
    _sort = sort;
    await _settings.setSearchSort(sort.key);
    notifyListeners();
  }

  Future<void> loadHistory() async {
    _history = await _settingsStorage.getSearchHistory();
    notifyListeners();
  }

  Future<void> addToHistory(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return;
    final updated = [trimmed, ..._history.where((e) => e != trimmed)];
    _history = updated.take(20).toList();
    await _settingsStorage.saveSearchHistory(_history);
    notifyListeners();
  }

  Future<void> removeHistory(String keyword) async {
    _history = _history.where((e) => e != keyword).toList();
    await _settingsStorage.saveSearchHistory(_history);
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _history = [];
    await _settingsStorage.saveSearchHistory(_history);
    notifyListeners();
  }

  List<String> suggestionsFor(String input) {
    final keyword = input.trim();
    if (keyword.isEmpty) return _history;
    return _history.where((e) => e.contains(keyword)).toList();
  }

  Future<void> search(String rawKeyword) async {
    if (_source == SearchSource.bangumi) {
      await _searchBangumi(rawKeyword);
    } else {
      await _searchNotion(rawKeyword);
    }
  }

  String _sanitizeKeyword({required String keyword, required bool allowDefault}) {
    var resolved = keyword.trim();
    if (resolved.isEmpty && allowDefault) {
      resolved = '进击的巨人';
    }
    if (resolved.isEmpty) {
      throw Exception('请输入搜索关键词');
    }
    if (resolved.length > maxKeywordLength) {
      resolved = resolved.substring(0, maxKeywordLength);
    }
    return resolved;
  }

  Future<void> _searchBangumi(String rawKeyword) async {
    _loading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final keyword = _sanitizeKeyword(keyword: rawKeyword, allowDefault: true);
      final token = _settings.bangumiAccessToken;
      List<BangumiSearchItem> items;
      try {
        items = await _bangumiApi.search(
          keyword: keyword,
          accessToken: token.isEmpty ? null : token,
          sort: _sort.key,
        );
      } catch (_) {
        if (_sort != SearchSort.match) {
          items = await _bangumiApi.search(
            keyword: keyword,
            accessToken: token.isEmpty ? null : token,
            sort: SearchSort.match.key,
          );
        } else {
          rethrow;
        }
      }
      _items = items;
      _notionItems = [];
      await addToHistory(keyword);
    } catch (_) {
      _errorMessage = '搜索 Bangumi 失败';
      _items = [];
      _notionItems = [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _searchNotion(String rawKeyword) async {
    _loading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final keyword = _sanitizeKeyword(keyword: rawKeyword, allowDefault: false);
      final token = _settings.notionToken;
      final databaseId = _settings.notionDatabaseId;
      if (token.isEmpty || databaseId.isEmpty) {
        throw Exception('请先在设置页配置 Notion Token 和 Database ID');
      }

      final mappingConfig = await _settingsStorage.getMappingConfig();
      final titleProperty = mappingConfig.title.trim();
      if (titleProperty.isEmpty) {
        throw Exception('请先在映射配置中绑定 Notion 标题字段');
      }

      final items = await _notionApi.searchDatabase(
        token: token,
        databaseId: databaseId,
        titlePropertyName: titleProperty,
        keyword: keyword,
      );
      _notionItems = items;
      _items = [];
      await addToHistory(keyword);
    } catch (error) {
      _errorMessage = error.toString().replaceAll('Exception: ', '');
      _notionItems = [];
      _items = [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
