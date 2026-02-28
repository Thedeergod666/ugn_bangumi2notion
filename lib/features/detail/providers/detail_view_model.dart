import 'package:flutter/foundation.dart';

import '../app/app_settings.dart';
import '../models/bangumi_models.dart';
import '../models/mapping_config.dart';
import '../services/bangumi_api.dart';
import '../services/notion_api.dart';
import '../services/settings_storage.dart';

class DetailImportPreparation {
  final MappingConfig mappingConfig;
  final String? existingPageId;

  const DetailImportPreparation({
    required this.mappingConfig,
    required this.existingPageId,
  });
}

class DetailImportResult {
  final bool success;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  const DetailImportResult._({
    required this.success,
    required this.message,
    this.error,
    this.stackTrace,
  });

  factory DetailImportResult.success(String message) {
    return DetailImportResult._(success: true, message: message);
  }

  factory DetailImportResult.failure(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    return DetailImportResult._(
      success: false,
      message: message,
      error: error,
      stackTrace: stackTrace,
    );
  }
}

class DetailViewModel extends ChangeNotifier {
  DetailViewModel({
    required int subjectId,
    required BangumiApi bangumiApi,
    required NotionApi notionApi,
    required AppSettings settings,
    SettingsStorage? settingsStorage,
  })  : _subjectId = subjectId,
        _bangumiApi = bangumiApi,
        _notionApi = notionApi,
        _settings = settings,
        _settingsStorage = settingsStorage ?? SettingsStorage();

  final int _subjectId;
  final BangumiApi _bangumiApi;
  final NotionApi _notionApi;
  final AppSettings _settings;
  final SettingsStorage _settingsStorage;

  BangumiSubjectDetail? _detail;
  List<BangumiComment> _comments = [];
  bool _loading = true;
  bool _commentsLoading = true;
  bool _importing = false;
  bool _isSummaryExpanded = false;
  String? _errorMessage;
  Object? _error;
  StackTrace? _stackTrace;

  BangumiSubjectDetail? get detail => _detail;
  List<BangumiComment> get comments => _comments;
  bool get isLoading => _loading;
  bool get isCommentsLoading => _commentsLoading;
  bool get isImporting => _importing;
  bool get isSummaryExpanded => _isSummaryExpanded;
  String? get errorMessage => _errorMessage;
  Object? get error => _error;
  StackTrace? get stackTrace => _stackTrace;

  Future<void> load() async {
    _loading = true;
    _errorMessage = null;
    _error = null;
    _stackTrace = null;
    notifyListeners();

    try {
      final token = _settings.bangumiAccessToken;
      final detail = await _bangumiApi.fetchDetail(
        subjectId: _subjectId,
        accessToken: token.isEmpty ? null : token,
      );
      _detail = detail;
      _loading = false;
      notifyListeners();
      await loadComments();
    } catch (e, stackTrace) {
      _errorMessage = '加载失败，请稍后重试: $e';
      _loading = false;
      _error = e;
      _stackTrace = stackTrace;
      notifyListeners();
    }
  }

  Future<void> loadComments() async {
    _commentsLoading = true;
    notifyListeners();
    try {
      final token = _settings.bangumiAccessToken;
      final comments = await _bangumiApi.fetchSubjectComments(
        subjectId: _subjectId,
        accessToken: token.isEmpty ? null : token,
      );
      _comments = comments;
    } catch (e) {
      debugPrint('Failed to load comments: $e');
    } finally {
      _commentsLoading = false;
      notifyListeners();
    }
  }

  void toggleSummaryExpanded() {
    _isSummaryExpanded = !_isSummaryExpanded;
    notifyListeners();
  }

  Future<DetailImportPreparation> prepareImport() async {
    _setImporting(true);
    String? existingPageId;
    final mappingConfig = await _settingsStorage.getMappingConfig();

    try {
      final token = _settings.notionToken;
      final databaseId = _settings.notionDatabaseId;
      if (token.isNotEmpty && databaseId.isNotEmpty && _detail != null) {
        existingPageId = await _notionApi.findPageByBangumiId(
          token: token,
          databaseId: databaseId,
          bangumiId: _detail!.id,
          propertyName: mappingConfig.bangumiId.isNotEmpty
              ? mappingConfig.bangumiId
              : 'Bangumi ID',
        );
      }
    } catch (_) {
      debugPrint('Pre-check failed');
    } finally {
      _setImporting(false);
    }

    return DetailImportPreparation(
      mappingConfig: mappingConfig,
      existingPageId: existingPageId,
    );
  }

  Future<String?> resolveBindingTargetPageId({
    required MappingConfig mappingConfig,
    String? bangumiId,
    String? notionId,
  }) async {
    final token = _settings.notionToken;
    final databaseId = _settings.notionDatabaseId;
    if (token.isEmpty || databaseId.isEmpty) {
      throw Exception('请先在设置页配置 Notion Token 和 Database ID');
    }
    if ((bangumiId ?? '').isEmpty && (notionId ?? '').isEmpty) {
      return null;
    }

    _setImporting(true);
    try {
      if (bangumiId != null && bangumiId.isNotEmpty) {
        return await _notionApi.findPageByProperty(
          token: token,
          databaseId: databaseId,
          propertyName: mappingConfig.idPropertyName,
          value: int.tryParse(bangumiId) ?? 0,
          type: 'number',
        );
      }
      if (notionId != null && notionId.isNotEmpty) {
        return await _notionApi.findPageByProperty(
          token: token,
          databaseId: databaseId,
          propertyName: mappingConfig.notionId,
          value: notionId,
          type: 'rich_text',
        );
      }
    } finally {
      _setImporting(false);
    }
    return null;
  }

  Future<DetailImportResult> importToNotion({
    required Set<String> enabledFields,
    required MappingConfig mappingConfig,
    List<String>? selectedTags,
    String? targetPageId,
  }) async {
    if (_detail == null) {
      return DetailImportResult.failure('暂无可导入的数据');
    }

    _setImporting(true);
    try {
      final token = _settings.notionToken;
      final databaseId = _settings.notionDatabaseId;

      if (token.isEmpty || databaseId.isEmpty) {
        throw Exception('请先在设置页配置 Notion Token 和 Database ID');
      }

      final detailToImport = BangumiSubjectDetail(
        id: _detail!.id,
        name: _detail!.name,
        nameCn: _detail!.nameCn,
        summary: _detail!.summary,
        imageUrl: _detail!.imageUrl,
        airDate: _detail!.airDate,
        epsCount: _detail!.epsCount,
        tags: selectedTags ?? [],
        tagDetails: _detail!.tagDetails,
        studio: _detail!.studio,
        director: _detail!.director,
        script: _detail!.script,
        storyboard: _detail!.storyboard,
        animationProduction: _detail!.animationProduction,
        score: _detail!.score,
        ratingTotal: _detail!.ratingTotal,
        ratingCount: _detail!.ratingCount,
        rank: _detail!.rank,
        infoboxMap: _detail!.infoboxMap,
      );

      await _notionApi.createAnimePage(
        token: token,
        databaseId: databaseId,
        detail: detailToImport,
        mappingConfig: mappingConfig,
        enabledFields: enabledFields,
        existingPageId: targetPageId,
      );

      return DetailImportResult.success('操作成功');
    } catch (e, stackTrace) {
      final errorMessage = e.toString().replaceAll('Exception: ', '');
      return DetailImportResult.failure(
        errorMessage,
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _setImporting(false);
    }
  }

  void _setImporting(bool value) {
    if (_importing == value) return;
    _importing = value;
    notifyListeners();
  }
}
