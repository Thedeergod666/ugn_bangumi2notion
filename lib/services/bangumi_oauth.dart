import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../config/bangumi_oauth_config.dart';
import '../models/bangumi_models.dart';
import 'bangumi_api.dart';
import 'settings_storage.dart';

class BangumiOAuth {
  BangumiOAuth({http.Client? client, SettingsStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? SettingsStorage();

  final http.Client _client;
  final SettingsStorage _storage;

  static const _authBase = 'https://bgm.tv/oauth/authorize';
  static const _tokenUrl = 'https://bgm.tv/oauth/access_token';
  static const _redirectUri = BangumiOAuthConfig.redirectUri;

  bool _isDesktopPlatform() {
    return !kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
  }

  String _buildState() {
    final rand = Random.secure();
    final values = List<int>.generate(16, (_) => rand.nextInt(256));
    return base64Url.encode(values);
  }

  Future<OAuthAuthorizeResult> authorize() async {
    if (!_isDesktopPlatform()) {
      throw Exception('当前平台不支持桌面端本地回调授权，请在桌面端使用。');
    }

    BangumiOAuthConfig.validate();
    final appId = BangumiOAuthConfig.clientId;
    final appSecret = BangumiOAuthConfig.clientSecret;

    final state = _buildState();
    final server = _LocalOAuthServer(expectedState: state);
    await server.start();

    final authUri = Uri.parse(_authBase).replace(queryParameters: {
      'client_id': appId,
      'response_type': 'code',
      'redirect_uri': _redirectUri,
      'state': state,
    });
    debugPrint('[BangumiOAuth] authUrl=${authUri.toString()}');

    final launched = await launchUrl(
      authUri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      await server.close();
      throw Exception('无法打开系统浏览器进行授权');
    }

    final code = await server.waitForCode();
    final token = await _exchangeCodeForToken(
      code: code,
      appId: appId,
      appSecret: appSecret,
    );

    await _storage.saveBangumiAccessToken(token);

    final user = await _fetchUserSafely(token);

    return OAuthAuthorizeResult(
      accessToken: token,
      user: user,
      isTokenValid: true,
    );
  }

  Future<String> _exchangeCodeForToken({
    required String code,
    required String appId,
    required String appSecret,
  }) async {
    final response = await _client.post(
      Uri.parse(_tokenUrl),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'grant_type': 'authorization_code',
        'client_id': appId,
        'client_secret': appSecret,
        'code': code,
        'redirect_uri': _redirectUri,
      },
    ).timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw Exception('Bangumi 获取 Token 失败 (${response.statusCode})');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final token = data['access_token'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('Bangumi 返回 Token 为空');
    }

    return token;
  }

  Future<BangumiUser?> _fetchUserSafely(String accessToken) async {
    try {
      final api = BangumiApi(client: _client);
      return await api.fetchSelf(accessToken: accessToken);
    } catch (e) {
      debugPrint('[BangumiOAuth] fetchSelf failed: $e');
      return null;
    }
  }

  Future<void> logout() async {
    await _storage.clearBangumiAccessToken();
  }

  Future<String?> getStoredAccessToken() async {
    final data = await _storage.loadAll();
    final token = data[SettingsKeys.bangumiAccessToken] ?? '';
    return token.isEmpty ? null : token;
  }

  Future<bool> isTokenValid({String? accessToken}) async {
    final token = accessToken ?? await getStoredAccessToken();
    if (token == null || token.isEmpty) {
      return false;
    }
    try {
      final api = BangumiApi(client: _client);
      await api.fetchSelf(accessToken: token);
      return true;
    } catch (e) {
      debugPrint('[BangumiOAuth] token validate failed: $e');
      return false;
    }
  }
}

class OAuthAuthorizeResult {
  const OAuthAuthorizeResult({
    required this.accessToken,
    required this.user,
    required this.isTokenValid,
  });

  final String accessToken;
  final BangumiUser? user;
  final bool isTokenValid;
}

class _LocalOAuthServer {
  _LocalOAuthServer({required String expectedState})
      : _expectedState = expectedState;

  static const int _port = 8080;
  static const String _path = '/auth/callback';

  final String _expectedState;
  HttpServer? _server;
  Completer<String>? _codeCompleter;

  Future<void> start() async {
    _server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      _port,
    );
    _server!.listen(_handleRequest);
    debugPrint(
        '[BangumiOAuth] local server started on http://localhost:$_port$_path');
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (request.uri.path != _path) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('Not Found');
      await request.response.close();
      return;
    }

    final code = request.uri.queryParameters['code'];
    final state = request.uri.queryParameters['state'];

    if (state != _expectedState) {
      await _writeHtmlResponse(
        request,
        HttpStatus.forbidden,
        _buildErrorHtml('授权验证失败，请回到应用重试。'),
      );
      return;
    }

    if (code == null || code.isEmpty) {
      await _writeHtmlResponse(
        request,
        HttpStatus.badRequest,
        _buildErrorHtml('未收到授权码，请回到应用重试。'),
      );
      return;
    }

    if (_codeCompleter != null && !_codeCompleter!.isCompleted) {
      _codeCompleter!.complete(code);
    }

    await _writeHtmlResponse(
      request,
      HttpStatus.ok,
      _buildSuccessHtml(),
    );
  }

  Future<void> _writeHtmlResponse(
    HttpRequest request,
    int statusCode,
    String html,
  ) async {
    request.response.statusCode = statusCode;
    request.response.headers.contentType =
        ContentType('text', 'html', charset: 'utf-8');
    request.response.write(html);
    await request.response.close();
  }

  Future<String> waitForCode(
      {Duration timeout = const Duration(minutes: 5)}) async {
    _codeCompleter = Completer<String>();
    try {
      return await _codeCompleter!.future.timeout(
        timeout,
        onTimeout: () {
          throw TimeoutException('授权超时，请重试。', timeout);
        },
      );
    } finally {
      await close();
    }
  }

  Future<void> close() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
      debugPrint('[BangumiOAuth] local server closed');
    }
  }

  String _buildSuccessHtml() {
    return '''
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>登录成功</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; text-align: center; padding: 40px; }
    h1 { color: #2e7d32; }
    p { color: #666; }
  </style>
</head>
<body>
  <h1>登录成功</h1>
  <p>可以关闭此页面并返回应用。</p>
  <script>setTimeout(() => window.close(), 1500);</script>
</body>
</html>
''';
  }

  String _buildErrorHtml(String message) {
    return '''
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>登录失败</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; text-align: center; padding: 40px; }
    h1 { color: #c62828; }
    p { color: #666; }
  </style>
</head>
<body>
  <h1>登录失败</h1>
  <p>$message</p>
</body>
</html>
''';
  }
}
