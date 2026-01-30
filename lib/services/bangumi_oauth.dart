import 'dart:convert';
import 'dart:io';
import 'dart:math';

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

  String _buildState() {
    final rand = Random.secure();
    final values = List<int>.generate(16, (_) => rand.nextInt(256));
    return base64Url.encode(values);
  }

  Future<String> _resolveRedirectUri() async {
    if (Platform.isWindows) {
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
    if (Platform.isWindows) {
      await _storage.saveBangumiRedirectPort('$_windowsLoopbackPort');
    }
    final authUri = Uri.parse(_authBase).replace(queryParameters: {
      'client_id': appId,
      'response_type': 'code',
      'redirect_uri': redirectUri,
      'state': state,
    });

    final result = await FlutterWebAuth2.authenticate(
      url: authUri.toString(),
      callbackUrlScheme: _resolveCallbackScheme(redirectUri),
    );

    final callbackUri = Uri.parse(result);
    final code = callbackUri.queryParameters['code'];
    final returnedState = callbackUri.queryParameters['state'];

    if (code == null || returnedState != state) {
      throw Exception('Bangumi 授权失败：未收到有效授权码');
    }

    final response = await _client.post(
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
    );

    if (response.statusCode != 200) {
      throw Exception('Bangumi 获取 Token 失败：${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final token = data['access_token'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('Bangumi 返回 Token 为空');
    }

    return token;
  }
}
