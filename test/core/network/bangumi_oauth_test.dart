import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:flutter_utools/core/database/settings_storage.dart';
import 'package:flutter_utools/core/network/bangumi_oauth.dart';

class _MemorySettingsStorage extends SettingsStorage {
  String? savedToken;

  @override
  Future<void> saveBangumiAccessToken(String token) async {
    savedToken = token;
  }
}

class _FastCallbackLauncher extends UrlLauncherPlatform {
  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async {
    final state = Uri.parse(url).queryParameters['state'] ?? '';
    final callbackPath = Uri(
      path: '/auth/callback',
      queryParameters: {
        'code': 'fast-code',
        'state': state,
      },
    ).toString();
    final socket = await Socket.connect(InternetAddress.loopbackIPv4, 8080);
    socket.write(
      'GET $callbackPath HTTP/1.1\r\n'
      'Host: localhost\r\n'
      'Connection: close\r\n'
      '\r\n',
    );
    await socket.flush();
    await socket.drain<void>();
    await socket.close();
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('authorize succeeds when callback arrives immediately after launch',
      () async {
    final previousLauncher = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = _FastCallbackLauncher();
    addTearDown(() {
      UrlLauncherPlatform.instance = previousLauncher;
    });

    final storage = _MemorySettingsStorage();
    final client = MockClient((request) async {
      if (request.url.path == '/oauth/access_token') {
        return http.Response('{"access_token":"access-123"}', 200);
      }
      if (request.url.path == '/v0/me') {
        return http.Response(
          '{"nickname":"tester","avatar":{"large":"https://img.example.com/a.png"}}',
          200,
        );
      }
      return http.Response('{"message":"not found"}', 404);
    });

    final oauth = BangumiOAuth(client: client, storage: storage);
    final result =
        await oauth.authorize().timeout(const Duration(milliseconds: 500));

    expect(result.accessToken, 'access-123');
    expect(result.user?.nickname, 'tester');
    expect(storage.savedToken, 'access-123');
  });
}
