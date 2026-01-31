import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

import 'settings_storage.dart';

class BangumiOAuth {
  BangumiOAuth({http.Client? client, SettingsStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? SettingsStorage();

  final http.Client _client;
  final SettingsStorage _storage;

  static const _authBase = 'https://bgm.tv/oauth/authorize';
  static const _tokenUrl = 'https://bgm.tv/oauth/access_token';
  static const _customScheme = 'bangumi-importer';
  static const _customRedirectUri = 'bangumi-importer://oauth2redirect';
  static const _windowsLoopbackPort = 61390;

  bool _isValidLoopbackCallback(Uri callbackUri, int port) {
    final isLocalhost = callbackUri.host == 'localhost' ||
        callbackUri.host == '127.0.0.1' ||
        callbackUri.host == '::1';
    return callbackUri.scheme == 'http' &&
        isLocalhost &&
        callbackUri.port == port &&
        (callbackUri.path.isEmpty || callbackUri.path == '/');
  }

  String _buildState() {
    final rand = Random.secure();
    final values = List<int>.generate(16, (_) => rand.nextInt(256));
    return base64Url.encode(values);
  }

  Future<String> _resolveRedirectUri() async {
    if (Platform.isWindows) {
      await _storage.saveBangumiRedirectPort('$_windowsLoopbackPort');
      return 'http://localhost:$_windowsLoopbackPort';
    }
    return _customRedirectUri;
  }

  String _resolveCallbackScheme(String redirectUri) {
    if (Platform.isWindows) {
      return redirectUri;
    }
    return _customScheme;
  }

  Future<String> authorize({
    required String appId,
    required String appSecret,
  }) async {
    final state = _buildState();
    final redirectUri = await _resolveRedirectUri();
    final callbackScheme = _resolveCallbackScheme(redirectUri);
    // debug: 打印 OAuth 回调相关信息，便于排查 redirect_uri_mismatch
    debugPrint('[BangumiOAuth] platform=${Platform.operatingSystem} redirectUri=$redirectUri callbackScheme=$callbackScheme');
    final authUri = Uri.parse(_authBase).replace(queryParameters: {
      'client_id': appId,
      'response_type': 'code',
      'redirect_uri': redirectUri,
      'state': state,
    });
    debugPrint('[BangumiOAuth] authUrl=${authUri.toString()}');

    final result = await FlutterWebAuth2.authenticate(
      url: authUri.toString(),
      callbackUrlScheme: callbackScheme,
    );

    final callbackUri = Uri.parse(result);
    debugPrint('[BangumiOAuth] callbackUri=$callbackUri');
    final code = callbackUri.queryParameters['code'];
    final returnedState = callbackUri.queryParameters['state'];

    if (Platform.isWindows) {
      final redirect = Uri.parse(redirectUri);
      if (!_isValidLoopbackCallback(callbackUri, redirect.port)) {
        throw Exception('Bangumi 授权失败：回调地址校验失败');
      }
    }

    if (code == null || returnedState != state) {
      throw Exception('Bangumi 授权失败：未收到有效授权码');
    }

    final response = await _client
        .post(
          Uri.parse(_tokenUrl),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'grant_type': 'authorization_code',
            'client_id': appId,
            'client_secret': appSecret,
            'code': code,
            'redirect_uri': redirectUri,
          }),
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw Exception('Bangumi 获取 Token 失败');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final token = data['access_token'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('Bangumi 返回 Token 为空');
    }

    return token;
  }
}
