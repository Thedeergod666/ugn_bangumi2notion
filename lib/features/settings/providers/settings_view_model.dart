import 'dart:io';

import 'package:flutter/material.dart';

import '../app/app_services.dart';
import '../app/app_settings.dart';
import '../config/bangumi_oauth_config.dart';
import '../models/bangumi_models.dart';
import '../services/bangumi_api.dart';
import '../services/bangumi_oauth.dart';

class SettingsActionResult {
  final bool success;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  const SettingsActionResult({
    required this.success,
    required this.message,
    this.error,
    this.stackTrace,
  });
}

class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel({
    required AppServices services,
    required AppSettings settings,
  })  : _settings = settings,
        _oauth = services.bangumiOAuth,
        _bangumiApi = services.bangumiApi;

  final AppSettings _settings;
  final BangumiOAuth _oauth;
  final BangumiApi _bangumiApi;

  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;
  String? _successMessage;
  bool _bangumiLoading = false;
  bool _bangumiHasToken = false;
  bool _bangumiTokenValid = false;
  BangumiUser? _bangumiUser;
  Object? _lastError;
  StackTrace? _lastStackTrace;

  bool get isLoading => _loading;
  bool get isSaving => _saving;
  bool get isBangumiLoading => _bangumiLoading;
  bool get bangumiHasToken => _bangumiHasToken;
  bool get bangumiTokenValid => _bangumiTokenValid;
  BangumiUser? get bangumiUser => _bangumiUser;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  Object? get lastError => _lastError;
  StackTrace? get lastStackTrace => _lastStackTrace;
  bool get isBangumiConfigured => BangumiOAuthConfig.isConfigured;

  Future<void> load() async {
    _loading = false;
    notifyListeners();
    await refreshBangumiStatus();
  }

  void clearMessages() {
    if (_errorMessage == null && _successMessage == null) {
      return;
    }
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  Future<void> refreshBangumiStatus() async {
    final token = _settings.bangumiAccessToken;
    if (token.isEmpty) {
      _bangumiHasToken = false;
      _bangumiTokenValid = false;
      _bangumiUser = null;
      notifyListeners();
      return;
    }

    try {
      final user = await _bangumiApi.fetchSelf(accessToken: token);
      _bangumiHasToken = true;
      _bangumiTokenValid = true;
      _bangumiUser = user;
      notifyListeners();
    } catch (_) {
      _bangumiHasToken = true;
      _bangumiTokenValid = false;
      _bangumiUser = null;
      notifyListeners();
    }
  }

  Future<SettingsActionResult> authorize() async {
    _saving = true;
    _bangumiLoading = true;
    _errorMessage = null;
    _successMessage = null;
    _lastError = null;
    _lastStackTrace = null;
    notifyListeners();

    try {
      final result = await _oauth.authorize();
      await _settings.saveBangumiAccessToken(result.accessToken);
      _successMessage = 'Bangumi 授权成功';
      _bangumiHasToken = true;
      _bangumiTokenValid = result.isTokenValid;
      _bangumiUser = result.user;
      return const SettingsActionResult(
        success: true,
        message: 'Bangumi 授权成功',
      );
    } catch (error, stackTrace) {
      _errorMessage = '授权失败，请稍后重试';
      _lastError = error;
      _lastStackTrace = stackTrace;
      return SettingsActionResult(
        success: false,
        message: '授权失败，请稍后重试',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _saving = false;
      _bangumiLoading = false;
      notifyListeners();
    }
  }

  Future<SettingsActionResult> logout() async {
    _saving = true;
    _bangumiLoading = true;
    _errorMessage = null;
    _successMessage = null;
    _lastError = null;
    _lastStackTrace = null;
    notifyListeners();

    try {
      await _oauth.logout();
      await _settings.clearBangumiAccessToken();
      _bangumiHasToken = false;
      _bangumiTokenValid = false;
      _bangumiUser = null;
      _successMessage = '已退出 Bangumi 授权';
      return const SettingsActionResult(
        success: true,
        message: '已退出 Bangumi 授权',
      );
    } catch (error, stackTrace) {
      _errorMessage = '退出失败，请稍后重试';
      _lastError = error;
      _lastStackTrace = stackTrace;
      return SettingsActionResult(
        success: false,
        message: '退出失败，请稍后重试',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _saving = false;
      _bangumiLoading = false;
      notifyListeners();
    }
  }

  Future<void> applyBangumiEnvVariables({
    required String clientId,
    required String clientSecret,
  }) async {
    if (Platform.isWindows) {
      final resultId = await Process.run(
        'cmd',
        ['/c', 'setx', 'BANGUMI_CLIENT_ID', clientId],
      );
      final resultSecret = await Process.run(
        'cmd',
        ['/c', 'setx', 'BANGUMI_CLIENT_SECRET', clientSecret],
      );
      if (resultId.exitCode != 0 || resultSecret.exitCode != 0) {
        throw Exception('写入 Windows 环境变量失败');
      }
      return;
    }

    if (Platform.isMacOS) {
      final resultId = await Process.run(
        'launchctl',
        ['setenv', 'BANGUMI_CLIENT_ID', clientId],
      );
      final resultSecret = await Process.run(
        'launchctl',
        ['setenv', 'BANGUMI_CLIENT_SECRET', clientSecret],
      );
      if (resultId.exitCode != 0 || resultSecret.exitCode != 0) {
        throw Exception('写入 macOS 环境变量失败');
      }
      return;
    }

    if (Platform.isLinux) {
      final home = Platform.environment['HOME'];
      if (home == null || home.isEmpty) {
        throw Exception('无法获取 HOME 目录，无法写入 ~/.profile');
      }
      final profile = File('$home/.profile');
      final content =
          await profile.exists() ? await profile.readAsString() : '';
      var updated = _upsertEnvLine(
        content,
        key: 'BANGUMI_CLIENT_ID',
        value: clientId,
      );
      updated = _upsertEnvLine(
        updated,
        key: 'BANGUMI_CLIENT_SECRET',
        value: clientSecret,
      );
      await profile.writeAsString(updated);
      return;
    }

    throw Exception('当前平台不支持自动写入环境变量');
  }

  String _upsertEnvLine(
    String content, {
    required String key,
    required String value,
  }) {
    final escapedValue = value.replaceAll('"', r'\"');
    final line = 'export $key="$escapedValue"';
    final pattern = '^export\\s+${RegExp.escape(key)}=.*';
    final regex = RegExp(pattern, multiLine: true);
    if (regex.hasMatch(content)) {
      return content.replaceAll(regex, '$line\n');
    }
    if (content.isNotEmpty && !content.endsWith('\n')) {
      content += '\n';
    }
    return '$content$line\n';
  }
}
