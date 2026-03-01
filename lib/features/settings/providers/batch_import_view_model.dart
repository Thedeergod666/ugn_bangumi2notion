import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../app/app_settings.dart';
import '../../../core/database/settings_storage.dart';
import '../../../core/network/bangumi_api.dart';
import '../../../core/network/notion_api.dart';
import '../../../models/bangumi_models.dart';
import '../../../models/notion_models.dart';

class BatchImportCandidate {
  final NotionSearchItem notionItem;
  final List<BangumiSearchItem> matches;
  final bool bound;

  const BatchImportCandidate({
    required this.notionItem,
    required this.matches,
    this.bound = false,
  });

  BatchImportCandidate copyWith({
    List<BangumiSearchItem>? matches,
    bool? bound,
  }) {
    return BatchImportCandidate(
      notionItem: notionItem,
      matches: matches ?? this.matches,
      bound: bound ?? this.bound,
    );
  }
}

class BatchImportViewModel extends ChangeNotifier {
  BatchImportViewModel({
    required NotionApi notionApi,
    required BangumiApi bangumiApi,
    required AppSettings settings,
    SettingsStorage? storage,
  })  : _notionApi = notionApi,
        _bangumiApi = bangumiApi,
        _settings = settings,
        _settingsStorage = storage ?? SettingsStorage();

  final NotionApi _notionApi;
  final BangumiApi _bangumiApi;
  final AppSettings _settings;
  final SettingsStorage _settingsStorage;

  bool _loading = false;
  String? _errorMessage;
  List<BatchImportCandidate> _candidates = [];

  bool get isLoading => _loading;
  String? get errorMessage => _errorMessage;
  List<BatchImportCandidate> get candidates => _candidates;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _errorMessage = null;
    _candidates = [];
    notifyListeners();

    try {
      final token = _settings.notionToken;
      final databaseId = _settings.notionDatabaseId;
      if (token.isEmpty || databaseId.isEmpty) {
        throw Exception('请先配置 Notion Token 与 Database ID');
      }

      final mappingConfig = await _settingsStorage.getMappingConfig();
      final watchBindings = mappingConfig.watchBindings;
      final idProperty = watchBindings.bangumiId.trim().isNotEmpty
          ? watchBindings.bangumiId.trim()
          : (mappingConfig.bangumiId.trim().isNotEmpty
              ? mappingConfig.bangumiId.trim()
              : mappingConfig.idPropertyName.trim());
      final titleProperty = watchBindings.title.trim().isNotEmpty
          ? watchBindings.title.trim()
          : (mappingConfig.title.trim().isNotEmpty
              ? mappingConfig.title.trim()
              : '');

      if (idProperty.isEmpty || titleProperty.isEmpty) {
        throw Exception('请在映射配置中设置 Bangumi ID 与标题字段');
      }

      final pages = await _notionApi.getPagesWithoutBangumiId(
        token: token,
        databaseId: databaseId,
        idPropertyName: idProperty,
        titlePropertyName: titleProperty,
        notionIdPropertyName: mappingConfig.notionId.trim(),
        limit: 30,
      );

      final results = <BatchImportCandidate>[];
      for (final item in pages) {
        final keyword = item.title.trim();
        if (keyword.isEmpty) continue;
        final matches = await _bangumiApi.search(
          keyword: keyword,
          accessToken: _settings.bangumiAccessToken.isEmpty
              ? null
              : _settings.bangumiAccessToken,
          sort: 'match',
        );
        results.add(
          BatchImportCandidate(
            notionItem: item,
            matches: matches.take(3).toList(),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 400));
      }

      _candidates = results;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> bindCandidate({
    required BatchImportCandidate candidate,
    required int bangumiId,
  }) async {
    final token = _settings.notionToken;
    final databaseId = _settings.notionDatabaseId;
    if (token.isEmpty || databaseId.isEmpty) {
      throw Exception('请先配置 Notion Token 与 Database ID');
    }

    final mappingConfig = await _settingsStorage.getMappingConfig();
    final watchBindings = mappingConfig.watchBindings;
    final idProperty = watchBindings.bangumiId.trim().isNotEmpty
        ? watchBindings.bangumiId.trim()
        : (mappingConfig.bangumiId.trim().isNotEmpty
            ? mappingConfig.bangumiId.trim()
            : mappingConfig.idPropertyName.trim());

    await _notionApi.updatePageNumberProperty(
      token: token,
      pageId: candidate.notionItem.id,
      propertyName: idProperty,
      value: bangumiId,
    );

    _candidates = _candidates
        .map((item) => item.notionItem.id == candidate.notionItem.id
            ? item.copyWith(bound: true)
            : item)
        .toList();
    notifyListeners();
  }
}
