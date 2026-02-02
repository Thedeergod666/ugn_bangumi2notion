## 📋 目录

1. [准备工作](#准备工作)
2. [项目结构设计](#项目结构设计)
3. [实现步骤](#实现步骤)
4. [关键代码实现](#关键代码实现)
5. [注意事项](#注意事项)
6. [常见问题](#常见问题)

---

## 准备工作

### 1. 注册 Bangumi 应用

**访问地址：** https://bgm.tv/oauth/clients

**填写信息：**

| 字段 | 值 | 说明 |
|------|-----|------|
| 应用名称 | 你的应用名 | 如"MyAnimeApp" |
| 应用描述 | 简短描述 | 如"桌面端 Bangumi 客户端" |
| 回调地址 | `http://localhost:8080/auth/callback` | 重要！本地 Web Server 监听的地址 |
| 应用类型 | 桌面应用 | 选择"桌面应用" |
| 权限 | 根据需求勾选 | 建议勾选"访问用户信息"、"修改收藏" |

**获取信息：**

- **Client ID**: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
- **Client Secret**: 可选（Bangumi 允许为空）

**保存配置：**

```dart
// lib/config/bangumi_config.dart
class BangumiConfig {
  static const String clientId = 'your_client_id_here';
  static const String clientSecret = ''; // 可选，Bangumi 允许为空
  static const String redirectUri = 'http://localhost:8080/auth/callback';
  static const String authUrl = 'https://bgm.tv/oauth/authorize';
  static const String tokenUrl = 'https://bgm.tv/oauth/access_token';
  static const String apiBaseUrl = 'https://api.bgm.tv';
}
```

---

### 2. 添加依赖

**在 `pubspec.yaml` 中添加：**

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # HTTP 请求
  http: ^1.2.0
  
  # 本地 Web Server
  shelf: ^1.4.1
  shelf_router: ^1.1.4
  
  # UUID 生成（用于 state）
  uuid: ^4.3.3
  
  # 本地存储（保存 token）
  shared_preferences: ^2.2.2
  
  # 打开浏览器
  url_launcher: ^6.2.2
  
  # JSON 序列化
  json_annotation: ^4.8.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  
  # JSON 生成
  build_runner: ^2.4.7
  json_serializable: ^6.7.1
```

**运行命令：**

```bash
flutter pub get
```

---

## 项目结构设计

```
lib/
├── main.dart
├── config/
│   └── bangumi_config.dart          # Bangumi 配置
├── models/
│   ├── bangumi_token.dart           # Token 模型
│   ├── bangumi_user.dart            # 用户模型
│   └── collection.dart              # 收藏模型
├── services/
│   ├── oauth/
│   │   ├── local_oauth_server.dart  # 本地 Web Server
│   │   ├── bangumi_oauth_client.dart # OAuth 客户端
│   │   └── token_storage.dart       # Token 存储
│   └── bangumi/
│       └── bangumi_api_service.dart # Bangumi API 服务
└── ui/
    └── screens/
        └── login_screen.dart        # 登录界面
```

---

## 实现步骤

### 步骤 1：创建数据模型

**创建 `lib/models/bangumi_token.dart`：**

```dart
import 'package:json_annotation/json_annotation.dart';

part 'bangumi_token.g.dart';

@JsonSerializable()
class BangumiToken {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final String? tokenType;
  
  BangumiToken({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    this.tokenType,
  });

  factory BangumiToken.fromJson(Map<String, dynamic> json) =>
      _$BangumiTokenFromJson(json);

  Map<String, dynamic> toJson() => _$BangumiTokenToJson(this);
  
  // 计算过期时间戳
  DateTime get expiresAt => DateTime.now().add(Duration(seconds: expiresIn));
  
  // 检查是否过期
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

@JsonSerializable()
class BangumiTokenResponse {
  @JsonKey(name: 'access_token')
  final String accessToken;
  
  @JsonKey(name: 'refresh_token')
  final String refreshToken;
  
  @JsonKey(name: 'expires_in')
  final int expiresIn;
  
  @JsonKey(name: 'token_type')
  final String? tokenType;
  
  BangumiTokenResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    this.tokenType,
  });

  factory BangumiTokenResponse.fromJson(Map<String, dynamic> json) =>
      _$BangumiTokenResponseFromJson(json);

  Map<String, dynamic> toJson() => _$BangumiTokenResponseToJson(this);
  
  BangumiToken toBangumiToken() {
    return BangumiToken(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresIn: expiresIn,
      tokenType: tokenType,
    );
  }
}
```

**创建 `lib/models/bangumi_user.dart`：**

```dart
import 'package:json_annotation/json_annotation.dart';

part 'bangumi_user.g.dart';

@JsonSerializable()
class BangumiUser {
  final int id;
  final String username;
  final String? nickname;
  final String? avatar;
  
  BangumiUser({
    required this.id,
    required this.username,
    this.nickname,
    this.avatar,
  });

  factory BangumiUser.fromJson(Map<String, dynamic> json) =>
      _$BangumiUserFromJson(json);

  Map<String, dynamic> toJson() => _$BangumiUserToJson(this);
  
  @override
  String toString() => nickname ?? username;
}
```

**生成 JSON 序列化代码：**

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

---

### 步骤 2：实现 Token 存储

**创建 `lib/services/oauth/token_storage.dart`：**

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/models/bangumi_token.dart';

class TokenStorage {
  static const String _tokenKey = 'bangumi_token';
  static const String _refreshTokenKey = 'bangumi_refresh_token';
  static const String _expiresAtKey = 'bangumi_expires_at';

  // 保存 Token
  Future<void> saveToken(BangumiToken token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token.accessToken);
    await prefs.setString(_refreshTokenKey, token.refreshToken);
    await prefs.setInt(_expiresAtKey, token.expiresAt.millisecondsSinceEpoch);
  }

  // 获取 Token
  Future<BangumiToken?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString(_tokenKey);
    final refreshToken = prefs.getString(_refreshTokenKey);
    final expiresAtMs = prefs.getInt(_expiresAtKey);

    if (accessToken == null || refreshToken == null || expiresAtMs == null) {
      return null;
    }

    final expiresAt = DateTime.fromMillisecondsSinceEpoch(expiresAtMs);
    final expiresIn = expiresAt.difference(DateTime.now()).inSeconds;

    return BangumiToken(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresIn: expiresIn > 0 ? expiresIn : 0,
    );
  }

  // 清除 Token
  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_expiresAtKey);
  }

  // 检查是否有 Token
  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null;
  }

  // 检查 Token 是否有效
  Future<bool> isTokenValid() async {
    final token = await getToken();
    return token != null && !token.isExpired;
  }
}
```

---

### 步骤 3：实现本地 Web Server

**创建 `lib/services/oauth/local_oauth_server.dart`：**

```dart
import 'dart:async';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:my_app/config/bangumi_config.dart';

class LocalOAuthServer {
  HttpServer? _server;
  final int _port;
  Completer<String>? _codeCompleter;
  final String _expectedState;

  LocalOAuthServer({
    int port = 8080,
    required String expectedState,
  })  : _port = port,
        _expectedState = expectedState;

  // 启动服务器
  Future<int> start() async {
    final router = Router()
      ..get(BangumiConfig.redirectUri.split(':8080')[1], _handleCallback);

    final handler = const Pipeline()
        .addMiddleware(_corsHeaders())
        .addHandler(router.call);

    // 使用指定端口
    _server = await io.serve(handler, InternetAddress.loopbackIPv4, _port);
    
    print('🖥️ 本地 OAuth 服务器已启动: http://localhost:$_port');
    
    return _port;
  }

  // 处理回调
  Future<Response> _handleCallback(Request request) async {
    final code = request.url.queryParameters['code'];
    final state = request.url.queryParameters['state'];

    print('📥 收到 OAuth 回调');
    print('   Code: ${code?.substring(0, 20)}...');
    print('   State: $state');

    // 验证 state（防止 CSRF 攻击）
    if (state != _expectedState) {
      print('❌ State 不匹配！期望: $_expectedState, 实际: $state');
      return Response.forbidden(_getErrorResponse('state_mismatch'));
    }

    if (code == null) {
      print('❌ 未收到 code 参数');
      return Response.badRequest(body: _getErrorResponse('missing_code'));
    }

    // 通知等待中的应用
    if (_codeCompleter != null && !_codeCompleter!.isCompleted) {
      _codeCompleter!.complete(code);
    }

    // 返回成功页面
    return Response.ok(
      _getSuccessResponse(),
      headers: {'Content-Type': 'text/html; charset=utf-8'},
    );
  }

  // 等待授权码
  Future<String> waitForCode({Duration timeout = const Duration(minutes: 5)}) async {
    _codeCompleter = Completer<String>();
    
    try {
      final code = await _codeCompleter!.future.timeout(
        timeout,
        onTimeout: () {
          throw TimeoutException('OAuth 授权超时', timeout);
        },
      );
      return code;
    } finally {
      await close();
    }
  }

  // 关闭服务器
  Future<void> close() async {
    if (_server != null) {
      await _server!.close();
      _server = null;
      print('🖥️ 本地 OAuth 服务器已关闭');
    }
  }

  // CORS 中间件
  Middleware _corsHeaders() {
    return (Handler innerHandler) {
      return (Request request) async {
        final response = await innerHandler(request);
        return response.change(headers: {
          ...response.headers,
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        });
      };
    };
  }

  // 成功响应页面
  String _getSuccessResponse() {
    return '''
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>登录成功</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
      display: flex;
      justify-content: center;
      align-items: center;
      height: 100vh;
      margin: 0;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    }
    .container {
      text-align: center;
      background: white;
      padding: 60px;
      border-radius: 20px;
      box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
      animation: fadeIn 0.5s ease-in;
    }
    .icon {
      font-size: 80px;
      margin-bottom: 20px;
    }
    h1 {
      color: #333;
      margin-bottom: 10px;
    }
    p {
      color: #666;
      font-size: 18px;
    }
    @keyframes fadeIn {
      from { opacity: 0; transform: translateY(-20px); }
      to { opacity: 1; transform: translateY(0); }
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="icon">✅</div>
    <h1>登录成功！</h1>
    <p>请关闭此页面返回应用</p>
  </div>
  <script>
    // 2 秒后自动关闭窗口
    setTimeout(function() {
      window.close();
    }, 2000);
  </script>
</body>
</html>
''';
  }

  // 错误响应页面
  String _getErrorResponse(String errorType) {
    final messages = {
      'state_mismatch': '授权验证失败，请重试',
      'missing_code': '未收到授权码，请重试',
      'default': '登录失败，请重试',
    };

    return '''
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <title>登录失败</title>
  <style>
    body {
      font-family: sans-serif;
      display: flex;
      justify-content: center;
      align-items: center;
      height: 100vh;
      background: #f5f5f5;
      margin: 0;
    }
    .container {
      text-align: center;
      background: white;
      padding: 40px;
      border-radius: 10px;
      box-shadow: 0 2px 10px rgba(0,0,0,0.1);
    }
    .icon { font-size: 60px; margin-bottom: 20px; }
    h1 { color: #e74c3c; margin-bottom: 10px; }
    p { color: #666; }
  </style>
</head>
<body>
  <div class="container">
    <div class="icon">❌</div>
    <h1>登录失败</h1>
    <p>${messages[errorType] ?? messages['default']}</p>
  </div>
</body>
</html>
''';
  }
}
```

---

### 步骤 4：实现 OAuth 客户端

**创建 `lib/services/oauth/bangumi_oauth_client.dart`：**

```dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:my_app/config/bangumi_config.dart';
import 'package:my_app/models/bangumi_token.dart';
import 'package:my_app/services/oauth/local_oauth_server.dart';
import 'package:my_app/services/oauth/token_storage.dart';

class BangumiOAuthClient {
  final TokenStorage _tokenStorage;
  final Uuid _uuid = const Uuid();

  BangumiOAuthClient({
    TokenStorage? tokenStorage,
  }) : _tokenStorage = tokenStorage ?? TokenStorage();

  /// 启动 OAuth 登录流程
  Future<BangumiToken> login() async {
    print('🚀 开始 OAuth 登录流程');

    // 1. 生成 state（用于 CSRF 防护）
    final state = _uuid.v4();
    print('🎲 生成 state: $state');

    // 2. 启动本地服务器
    final server = LocalOAuthServer(expectedState: state);
    final actualPort = await server.start();

    // 3. 构造授权 URL
    final authUrl = Uri.parse(BangumiConfig.authUrl).replace(queryParameters: {
      'client_id': BangumiConfig.clientId,
      'redirect_uri': BangumiConfig.redirectUri.replaceFirst(':8080', ':$actualPort'),
      'response_type': 'code',
      'state': state,
      'scope': '', // 根据需要填写，如 'basic collection'
    });

    print('🌐 授权 URL: $authUrl');

    // 4. 打开浏览器
    final launched = await launchUrl(
      authUrl,
      mode: LaunchMode.externalApplication,  // 使用外部浏览器
    );

    if (!launched) {
      await server.close();
      throw Exception('无法打开浏览器');
    }

    // 5. 等待授权码
    print('⏳ 等待用户授权...');
    final code = await server.waitForCode();

    // 6. 用授权码换取 token
    print('🔄 正在换取 token...');
    final token = await _exchangeCodeForToken(code, actualPort);

    // 7. 保存 token
    await _tokenStorage.saveToken(token);
    print('✅ Token 已保存');

    return token;
  }

  /// 用授权码换取 access token
  Future<BangumiToken> _exchangeCodeForToken(String code, int port) async {
    final response = await http.post(
      Uri.parse(BangumiConfig.tokenUrl),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'client_id': BangumiConfig.clientId,
        'client_secret': BangumiConfig.clientSecret,
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': BangumiConfig.redirectUri.replaceFirst(':8080', ':$port'),
      },
    );

    print('📡 Token 响应: ${response.statusCode}');

    if (response.statusCode != 200) {
      final error = response.body;
      print('❌ 换取 token 失败: $error');
      throw Exception('获取 token 失败: ${response.statusCode}');
    }

    final json = jsonDecode(response.body);
    final tokenResponse = BangumiTokenResponse.fromJson(json);

    print('✅ Token 获取成功');
    print('   Access Token: ${tokenResponse.accessToken.substring(0, 20)}...');
    print('   过期时间: ${tokenResponse.expiresIn} 秒');

    return tokenResponse.toBangumiToken();
  }

  /// 刷新 token（可选，如果 Bangumi 支持）
  Future<BangumiToken?> refreshToken() async {
    final savedToken = await _tokenStorage.getToken();
    if (savedToken == null) return null;

    final response = await http.post(
      Uri.parse(BangumiConfig.tokenUrl),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'client_id': BangumiConfig.clientId,
        'client_secret': BangumiConfig.clientSecret,
        'grant_type': 'refresh_token',
        'refresh_token': savedToken.refreshToken,
      },
    );

    if (response.statusCode != 200) {
      return null;
    }

    final json = jsonDecode(response.body);
    final tokenResponse = BangumiTokenResponse.fromJson(json);
    final newToken = tokenResponse.toBangumiToken();

    await _tokenStorage.saveToken(newToken);
    return newToken;
  }

  /// 登出
  Future<void> logout() async {
    await _tokenStorage.clearToken();
    print('👋 已登出');
  }

  /// 检查是否已登录
  Future<bool> isLoggedIn() async {
    return await _tokenStorage.hasToken();
  }

  /// 检查 token 是否有效
  Future<bool> isTokenValid() async {
    return await _tokenStorage.isTokenValid();
  }

  /// 获取当前 token
  Future<BangumiToken?> getCurrentToken() async {
    return await _tokenStorage.getToken();
  }
}
```

---

### 步骤 5：实现 Bangumi API 服务

**创建 `lib/services/bangumi/bangumi_api_service.dart`：**

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:my_app/config/bangumi_config.dart';
import 'package:my_app/models/bangumi_token.dart';
import 'package:my_app/models/bangumi_user.dart';

class BangumiApiService {
  final BangumiToken token;

  BangumiApiService({required this.token});

  /// 获取当前用户信息
  Future<BangumiUser> getSelfInfo() async {
    final response = await _authenticatedGet(
      Uri.parse('${BangumiConfig.apiBaseUrl}/v0/me'),
    );

    final json = jsonDecode(response.body);
    return BangumiUser.fromJson(json);
  }

  /// 获取用户收藏列表
  Future<List<dynamic>> getCollections({
    int? subjectType,  // 1=书, 2=动画, 3=音乐, 6=游戏
    int? collectionType,  // 1=想看, 2=看过, 3=在看, 4=搁置, 5=抛弃
    int? limit,
    int? offset,
  }) async {
    final uri = Uri.parse('${BangumiConfig.apiBaseUrl}/v0/me/collections')
        .replace(queryParameters: {
      if (subjectType != null) 'subject_type': subjectType.toString(),
      if (collectionType != null) 'type': collectionType.toString(),
      if (limit != null) 'limit': limit.toString(),
      if (offset != null) 'offset': offset.toString(),
    });

    final response = await _authenticatedGet(uri);

    final json = jsonDecode(response.body);
    final data = json['data'] as List;
    return data;
  }

  /// 修改收藏状态
  Future<void> updateCollection({
    required int subjectId,
    required int type,  // 1=想看, 2=看过, 3=在看, 4=搁置, 5=抛弃
    int? rating,  // 1-10
    String? comment,
    String? tags,
  }) async {
    final response = await _authenticatedPost(
      Uri.parse('${BangumiConfig.apiBaseUrl}/v0/users/-/collections/$subjectId'),
      body: jsonEncode({
        'type': type,
        if (rating != null) 'rating': rating,
        if (comment != null) 'comment': comment,
        if (tags != null) 'tags': tags,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('修改收藏失败: ${response.statusCode}');
    }
  }

  /// 标记剧集为已看/未看
  Future<void> updateEpisode({
    required int episodeId,
    required bool watched,
    String? comment,
  }) async {
    final response = await _authenticatedPost(
      Uri.parse('${BangumiConfig.apiBaseUrl}/v0/users/-/collections/-/episodes/$episodeId'),
      body: jsonEncode({
        'type': watched ? 2 : 0,  // 2=已看, 0=未看
        if (comment != null) 'comment': comment,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('修改剧集状态失败: ${response.statusCode}');
    }
  }

  /// 获取剧集信息
  Future<Map<String, dynamic>> getSubjectEpisodes(int subjectId) async {
    final response = await _authenticatedGet(
      Uri.parse('${BangumiConfig.apiBaseUrl}/v0/subjects/$subjectId/episodes'),
    );

    if (response.statusCode != 200) {
      throw Exception('获取剧集信息失败: ${response.statusCode}');
    }

    return jsonDecode(response.body);
  }

  /// 认证的 GET 请求
  Future<http.Response> _authenticatedGet(Uri uri) async {
    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer ${token.accessToken}',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 401) {
      throw Exception('Token 无效或已过期，请重新登录');
    }

    if (response.statusCode >= 400) {
      throw Exception('API 请求失败: ${response.statusCode}');
    }

    return response;
  }

  /// 认证的 POST 请求
  Future<http.Response> _authenticatedPost(
    Uri uri, {
    required String body,
  }) async {
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer ${token.accessToken}',
        'Content-Type': 'application/json',
      },
      body: body,
    );

    if (response.statusCode == 401) {
      throw Exception('Token 无效或已过期，请重新登录');
    }

    if (response.statusCode >= 400) {
      throw Exception('API 请求失败: ${response.statusCode}');
    }

    return response;
  }
}
```

---

### 步骤 6：实现登录界面

**创建 `lib/ui/screens/login_screen.dart`：**

```dart
import 'package:flutter/material.dart';
import 'package:my_app/models/bangumi_token.dart';
import 'package:my_app/models/bangumi_user.dart';
import 'package:my_app/services/oauth/bangumi_oauth_client.dart';
import 'package:my_app/services/bangumi/bangumi_api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final BangumiOAuthClient _oauthClient = BangumiOAuthClient();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. OAuth 登录
      final token = await _oauthClient.login();

      // 2. 获取用户信息（验证 token 是否有效）
      final apiService = BangumiApiService(token: token);
      final user = await apiService.getSelfInfo();

      // 3. 登录成功，跳转到主页
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home', arguments: {
          'user': user,
          'token': token,
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo 或图标
              const Icon(
                Icons.movie,
                size: 100,
                color: Colors.blue,
              ),
              const SizedBox(height: 32),

              // 标题
              const Text(
                '我的 Bangumi 应用',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              const Text(
                '使用 Bangumi 账号登录以同步你的追番记录',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 48),

              // 登录按钮
              if (_isLoading)
                const CircularProgressIndicator()
              else
                ElevatedButton.icon(
                  onPressed: _handleLogin,
                  icon: const Icon(Icons.login),
                  label: const Text('使用 Bangumi 登录'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),

              // 错误信息
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red[900]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 说明文字
              const SizedBox(height: 32),
              const Text(
                '登录后你可以：\n'
                '• 同步追番进度\n'
                '• 管理收藏列表\n'
                '• 查看个人数据',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

### 步骤 7：集成到主应用

**修改 `lib/main.dart`：**

```dart
import 'package:flutter/material.dart';
import 'package:my_app/ui/screens/login_screen.dart';
import 'package:my_app/services/oauth/bangumi_oauth_client.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Bangumi App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}

// 启动画面：检查是否已登录
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final oauthClient = BangumiOAuthClient();
    final isLoggedIn = await oauthClient.isTokenValid();

    if (!mounted) return;

    if (isLoggedIn) {
      // 已登录，跳转到主页
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      // 未登录，跳转到登录页
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在检查登录状态...'),
          ],
        ),
      ),
    );
  }
}

// 主页示例
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BangumiOAuthClient _oauthClient = BangumiOAuthClient();
  String? _userName;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final token = await _oauthClient.getCurrentToken();
    if (token != null) {
      final apiService = BangumiApiService(token: token);
      final user = await apiService.getSelfInfo();
      setState(() {
        _userName = user.nickname ?? user.username;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('欢迎, ${_userName ?? "用户"}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _oauthClient.logout();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
      body: const Center(
        child: Text('这里是主页面'),
      ),
    );
  }
}
```

---

## 注意事项

### 1. 跨平台适配

**Windows/macOS/Linux:**
- ✅ 使用 `http://localhost:8080` 作为回调地址
- ✅ 本地 Web Server 可以正常工作
- ✅ 使用 `LaunchMode.externalApplication` 打开系统浏览器

**Android/iOS（未来扩展）:**
- ⚠️ 需要使用 Deep Link（`yourapp://auth/callback`）
- ⚠️ 需要在 `AndroidManifest.xml` 和 `Info.plist` 中配置
- ⚠️ 建议实现平台检测，使用不同的回调地址

**示例：**

```dart
import 'dart:io' show Platform;

String getRedirectUri() {
  if (Platform.isAndroid || Platform.isIOS) {
    return 'yourapp://auth/callback';
  } else {
    return 'http://localhost:8080/auth/callback';
  }
}
```

### 2. 端口冲突处理

**问题：** 如果 8080 端口被占用怎么办？

**解决方案：** 动态选择可用端口

```dart
// 在 LocalOAuthServer 中修改
Future<int> start() async {
  // 尝试多个端口
  final ports = [8080, 8081, 8082, 8083, 8084];
  
  for (final port in ports) {
    try {
      _server = await io.serve(
        handler,
        InternetAddress.loopbackIPv4,
        port,
      );
      print('✅ 服务器启动在端口 $port');
      return port;
    } catch (e) {
      // 端口被占用，尝试下一个
      continue;
    }
  }
  
  throw Exception('无法找到可用端口');
}
```

### 3. Token 刷新

**如果 Bangumi 支持 refresh_token：**

```dart
// 在每次 API 调用前检查 token 是否即将过期
Future<void> _ensureTokenValid() async {
  final token = await _oauthClient.getCurrentToken();
  
  if (token == null) {
    throw Exception('未登录');
  }
  
  // 如果 token 已过期或即将过期（剩余时间少于 1 天）
  final expiresIn = token.expiresAt.difference(DateTime.now()).inDays;
  if (expiresIn < 1) {
    print('🔄 Token 即将过期，正在刷新...');
    final newToken = await _oauthClient.refreshToken();
    if (newToken == null) {
      throw Exception('Token 刷新失败，请重新登录');
    }
  }
}
```

### 4. 错误处理

**常见错误及处理：**

```dart
try {
  await oauthClient.login();
} on TimeoutException {
  // 用户授权超时
  showError('授权超时，请重试');
} on HttpException catch (e) {
  // 网络错误
  showError('网络连接失败，请检查网络');
} on FormatException {
  // JSON 解析错误
  showError('服务器返回数据格式错误');
} catch (e) {
  // 其他错误
  showError('登录失败: ${e.toString()}');
}
```

### 5. 安全建议

**Do's（推荐做法）：**

✅ 使用 HTTPS（Bangumi API 已经是 HTTPS）  
✅ 验证 state 参数（防止 CSRF）  
✅ Token 存储在安全的地方（使用 `shared_preferences`）  
✅ 检查 token 是否过期  
✅ 实现 logout 功能清除 token  

**Don'ts（不推荐做法）：**

❌ 不要将 appid 和 secret 硬编码在公开仓库中  
❌ 不要将 token 打印到日志中（调试时可以脱敏）  
❌ 不要将 token 存储在不安全的地方（如明文文本文件）  
❌ 不要忽略 HTTPS 证书验证  

**保护敏感配置：**

```dart
// 方法 1: 使用环境变量（推荐生产环境）
const String clientId = String.fromEnvironment('BANGUMI_CLIENT_ID');

// 方法 2: 使用配置文件（不提交到 Git）
// 在项目根目录创建 config.json（在 .gitignore 中）
// {
//   "bangumi_client_id": "your_id"
// }

// 读取配置
final config = jsonDecode(await File('config.json').readAsString());
final clientId = config['bangumi_client_id'];
```

---

## 常见问题

### Q1: OAuth 授权后浏览器没有自动关闭？

**A:** 浏览器可能阻止了自动关闭脚本。用户需要手动关闭窗口，不影响登录流程。

---

### Q2: 获取到的 token 为什么很快就过期了？

**A:** 检查：
1. 是否正确保存了 `expiresIn`
2. 计算过期时间时是否使用了正确的时区
3. Bangumi 返回的过期时间单位是什么（秒还是毫秒）

---

### Q3: 为什么有时候会收到 "state 不匹配" 错误？

**A:** 可能原因：
1. 用户在多个窗口中同时发起了授权请求
2. 本地服务器重启后 state 没有更新
3. 授权页面被浏览器缓存

**解决方案：**
- 每次授权前生成新的 state
- 关闭之前的授权窗口
- 在授权 URL 中添加时间戳参数

---

### Q4: 如何在调试时测试登录流程？

**A:** 使用本地测试工具：

```dart
// 测试工具：打印完整的 OAuth 流程
Future<void> testOAuthFlow() async {
  print('🧪 开始测试 OAuth 流程\n');
  
  try {
    final token = await _oauthClient.login();
    print('✅ 登录成功');
    print('Token: ${token.accessToken}');
    print('过期时间: ${token.expiresAt}');
  } catch (e) {
    print('❌ 测试失败: $e');
  }
}
```

---

### Q5: 用户关闭了授权窗口怎么办？

**A:** `waitForCode()` 会抛出 `TimeoutException`，捕获后引导用户重新登录：

```dart
try {
  final code = await server.waitForCode(timeout: Duration(minutes: 5));
} on TimeoutException {
  // 用户未授权或超时
  showSnackBar('授权已取消或超时，请重试');
} finally {
  await server.close();
}
```

---

### Q6: 如何实现"记住登录状态"？

**A:** 使用 `shared_preferences` 保存 token，并在启动时检查：

```dart
// 在 SplashScreen 中
Future<void> _checkLoginStatus() async {
  final token = await _oauthClient.getCurrentToken();
  
  if (token != null && !token.isExpired) {
    // Token 有效，自动登录
    Navigator.of(context).pushReplacementNamed('/home');
  } else {
    // Token 无效或不存在，跳转登录页
    Navigator.of(context).pushReplacementNamed('/login');
  }
}
```

---

### Q7: 支持多用户登录吗？

**A:** 当前实现是单用户的。如需支持多用户：

```dart
class MultiUserTokenStorage {
  // 按 user_id 存储多个 token
  static const String _prefix = 'bangumi_token_';
  
  Future<void> saveToken(int userId, BangumiToken token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$userId', jsonEncode(token.toJson()));
  }
  
  Future<BangumiToken?> getToken(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('$_prefix$userId');
    if (json == null) return null;
    return BangumiToken.fromJson(jsonDecode(json));
  }
  
  Future<List<int>> getLoggedInUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(_prefix));
    return keys.map((key) => int.parse(key.substring(_prefix.length))).toList();
  }
}
```

---

### Q8: 如何防止用户伪造 token？

**A:** 你不需要担心，这是 Bangumi 的责任：

1. Bangumi 使用 JWT（JSON Web Token）签名
2. 签名密钥只有 Bangumi 服务器知道
3. 你的应用只需要验证 token 是否有效即可

```dart
// 验证 token 有效性
Future<bool> validateToken(String token) async {
  try {
    final response = await http.get(
      Uri.parse('${BangumiConfig.apiBaseUrl}/v0/me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return response.statusCode == 200;
  } catch (e) {
    return false;
  }
}
```

---

## 下一步扩展

### 1. 添加刷新 Token 功能

```dart
class TokenRefreshManager {
  final BangumiOAuthClient _oauthClient;
  Timer? _refreshTimer;

  TokenRefreshManager(this._oauthClient);

  void startAutoRefresh() {
    _refreshTimer = Timer.periodic(Duration(hours: 1), (timer) async {
      await _refreshIfNeeded();
    });
  }

  Future<void> _refreshIfNeeded() async {
    final token = await _oauthClient.getCurrentToken();
    if (token == null) return;

    final expiresIn = token.expiresAt.difference(DateTime.now());
    if (expiresIn < Duration(days: 1)) {
      await _oauthClient.refreshToken();
    }
  }

  void stop() {
    _refreshTimer?.cancel();
  }
}
```

### 2. 添加离线缓存

```dart
class OfflineCache {
  Future<void> cacheCollections(List<dynamic> collections) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_collections', jsonEncode(collections));
  }

  Future<List<dynamic>?> getCachedCollections() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('cached_collections');
    if (json == null) return null;
    return jsonDecode(json);
  }
}
```

### 3. 添加网络状态检测

```dart
class NetworkStatus {
  static Future<bool> isConnected() async {
    try {
      final response = await http.get(Uri.parse('https://api.bgm.tv/v0')).timeout(
        Duration(seconds: 5),
      );
      return response.statusCode < 500;
    } catch (e) {
      return false;
    }
  }
}
```

---

## 总结

这份指南涵盖了：

✅ **准备工作**: 注册应用、配置环境  
✅ **核心实现**: 本地 Web Server、OAuth 客户端、Token 管理  
✅ **API 调用**: 用户信息、收藏列表、剧集状态  
✅ **UI 集成**: 登录界面、主应用流程  
✅ **注意事项**: 跨平台适配、错误处理、安全建议  
✅ **常见问题**: FAQ 和解决方案  

**关键要点：**

1. 🎯 本地 Web Server 是核心，解决了桌面端回调问题
2. 🔐 Token 隔离确保用户数据安全
3. 🚀 整个流程对用户透明，体验流畅
4. 📱 易于扩展到移动端（切换到 Deep Link）

**推荐顺序实施：**

1. 先完成桌面端的本地 Web Server 方案
2. 测试登录流程和 API 调用
3. 添加错误处理和边界情况
4. 考虑扩展到移动端

---

## 参考资料

- **Bangumi API 文档**: https://github.com/bangumi/api
- **OAuth 2.0 规范**: https://oauth.net/2/
- **Flutter HTTP 包**: https://pub.dev/packages/http
- **Shelf 服务器**: https://pub.dev/packages/shelf
- **Animeko 项目**: https://github.com/open-ani/animeko

---

祝你开发顺利！如果有任何问题，可以参考 Animeko 的实现或查阅 Bangumi API 文档。🎉