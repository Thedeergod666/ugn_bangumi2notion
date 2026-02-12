import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../app/app_settings.dart';
import '../services/notion_api.dart';

class DatabaseSettingsViewModel extends ChangeNotifier {
  DatabaseSettingsViewModel({
    required NotionApi notionApi,
    required AppSettings settings,
  })  : _notionApi = notionApi,
        _settings = settings;

  final NotionApi _notionApi;
  final AppSettings _settings;

  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;
  String? _successMessage;
  String _notionToken = '';
  String _notionDatabaseId = '';

  bool get isLoading => _loading;
  bool get isSaving => _saving;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  String get notionToken => _notionToken;
  String get notionDatabaseId => _notionDatabaseId;

  Future<void> load() async {
    var token = _settings.notionToken;
    if (token.isEmpty) {
      token = dotenv.env['NOTION_TOKEN'] ?? '';
    }

    var databaseId = _settings.notionDatabaseId;
    if (databaseId.isEmpty) {
      databaseId = dotenv.env['NOTION_DATABASE_ID'] ?? '';
    }

    _notionToken = token;
    _notionDatabaseId = databaseId;
    _loading = false;
    notifyListeners();
  }

  void updateToken(String value) {
    _notionToken = value;
    notifyListeners();
  }

  void updateDatabaseId(String value) {
    _notionDatabaseId = value;
    notifyListeners();
  }

  Future<void> autoSave() async {
    try {
      await _settings.saveNotionSettings(
        token: _notionToken.trim(),
        databaseId: _notionDatabaseId.trim(),
      );
    } catch (_) {}
  }

  Future<void> saveAll() async {
    _saving = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await _settings.saveNotionSettings(
        token: _notionToken.trim(),
        databaseId: _notionDatabaseId.trim(),
      );
      _successMessage = '设置已保存';
    } catch (_) {
      _errorMessage = '保存失败，请稍后重试';
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<void> testConnection() async {
    _saving = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final token = _notionToken.trim();
      final databaseId = _notionDatabaseId.trim();

      if (token.isEmpty || databaseId.isEmpty) {
        throw Exception('请先填写 Notion Token 与 Database ID');
      }

      await _notionApi.testConnection(
        token: token,
        databaseId: databaseId,
      );

      _successMessage = 'Notion 连接成功';
    } catch (_) {
      _errorMessage = '连接失败，请稍后重试';
    } finally {
      _saving = false;
      notifyListeners();
    }
  }
}
