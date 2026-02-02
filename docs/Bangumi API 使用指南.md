## 概述

本指南详细介绍如何在 Flutter 应用中正确使用 Bangumi API，实现读取操作无需 token，仅写入和用户相关操作需要认证的设计模式。基于 Kazumi 项目的实际实现经验整理。

## API 版本对比

### v0 API (`api.bgm.tv`)
专注于基础数据查询，性能优异，适合高频访问。

```dart
// 基础端点
const String bangumiApiBase = 'https://api.bgm.tv/v0';
const String bangumiApiEndpoints = {
  'subject': '/subjects/{id}',              // 番剧基础信息
  'search': '/search/subjects',              // 搜索功能
  'characters': '/subjects/{id}/characters', // 角色信息
  'episodes': '/episodes',                  // 剧集列表
};
```

### p1 API (`next.bgm.tv`)
提供增强功能和社交数据，适合需要详细信息的场景。

```dart
// 增强端点
const String bangumiNextBase = 'https://next.bgm.tv/p1';
const String bangumiNextEndpoints = {
  'calendar': '/calendar',                          // 每日放送
  'trending': '/trending/subjects',                 // 趋势数据
  'comments': '/subjects/{id}/comments',            // 评论系统
  'staff': '/subjects/{id}/staffs/persons',         // 完整制作人员
  'character': '/characters/{id}',                 // 完整角色信息
};
```

## 认证机制

### 无需 Token 的操作

以下所有读取操作都可以在没有认证的情况下直接访问：

#### ✅ 公共读取操作

| 功能 | API 端点 | 说明 |
|------|----------|------|
| **番剧信息** | `GET /v0/subjects/{id}` | 基础番剧数据 |
| **搜索番剧** | `POST /v0/search/subjects` | 支持复杂过滤的搜索 |
| **制作人员** | `GET /p1/subjects/{id}/staffs/persons` | 完整的脚本、导演等信息 |
| **评论列表** | `GET /p1/subjects/{id}/comments` | 公开评论 |
| **角色信息** | `GET /v0/subjects/{id}/characters` | 基础角色列表 |
| **完整角色** | `GET /p1/characters/{id}` | 详细角色信息 |
| **每日放送** | `GET /p1/calendar` | 按星期分类的番剧 |
| **趋势数据** | `GET /p1/trending/subjects` | 热门番剧 |
| **剧集信息** | `GET /v0/episodes` | 剧集列表 |

### 需要 Token 的操作

以下操作必须携带有效的 Access Token：

#### ❌ 认证必需操作

| 功能 | API 端点 | 说明 |
|------|----------|------|
| **收藏番剧** | `POST /collection/{id}` | 添加到收藏 |
| **取消收藏** | `DELETE /collection/{id}` | 移除收藏 |
| **评分** | `PUT /collection/{id}` | 更新评分 |
| **个人评论** | `POST /subject/{id}/comments` | 发表评论 |
| **收藏列表** | `GET /user/{username}/collections` | 用户收藏 |
| **观看进度** | `POST /episodes/{id}/status` | 更新观看状态 |
| **个人资料** | `GET /user/{username}` | 用户详细信息 |

## 核心实现

### 1. HTTP 客户端封装

```dart
import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

class BangumiHttpClient {
  static final BangumiHttpClient _instance = BangumiHttpClient._internal();
  factory BangumiHttpClient() => _instance;

  late final Dio _dio;
  String? _accessToken;
  static const String _version = '1.0.0';

  BangumiHttpClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: 'https://api.bgm.tv',
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
      headers: _buildHeaders(),
    ));

    // 添加日志拦截器（仅调试模式）
    _dio.interceptors.add(PrettyDioLogger(
      requestHeader: false,
      responseBody: true,
      error: true,
    ));
  }

  // 设置认证 token
  void setAccessToken(String? token) {
    _accessToken = token;
    _updateHeaders();
  }

  // 构建请求头
  Map<String, String> _buildHeaders({bool authenticated = false}) {
    final headers = <String, String>{
      'user-agent': 'YourApp/$_version (Flutter) (https://yourapp.com)',
      'referer': '',
      'content-type': 'application/json',
      'accept': 'application/json',
    };

    if (authenticated && _accessToken != null) {
      headers['authorization'] = 'Bearer $_accessToken';
    }

    return headers;
  }

  // 更新请求头
  void _updateHeaders() {
    _dio.options.headers = _buildHeaders();
  }

  // 通用 GET 请求
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool authenticated = false,
    Options? options,
  }) async {
    final headers = _buildHeaders(authenticated: authenticated);
    
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: (options ?? Options()).copyWith(headers: headers),
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // 通用 POST 请求
  Future<dynamic> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool authenticated = false,
    Options? options,
  }) async {
    final headers = _buildHeaders(authenticated: authenticated);
    
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: (options ?? Options()).copyWith(headers: headers),
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // 错误处理
  Exception _handleError(DioException error) {
    switch (error.type) {
      case DioExceptionType.badCertificate:
        return const BangumiException('证书有误！');
      case DioExceptionType.badResponse:
        return BangumiException('服务器异常: ${error.response?.statusCode}');
      case DioExceptionType.cancel:
        return const BangumiException('请求已被取消');
      case DioExceptionType.connectionError:
        return const BangumiException('连接错误，请检查网络设置');
      case DioExceptionType.connectionTimeout:
        return const BangumiException('网络连接超时');
      case DioExceptionType.receiveTimeout:
        return const BangumiException('响应超时');
      case DioExceptionType.sendTimeout:
        return const BangumiException('发送请求超时');
      case DioExceptionType.unknown:
        return BangumiException('网络异常: ${error.message}');
    }
  }
}

// 自定义异常类
class BangumiException implements Exception {
  final String message;
  const BangumiException(this.message);

  @override
  String toString() => 'BangumiException: $message';
}
```

### 2. 数据模型定义

```dart
// 番剧基础信息模型
class BangumiSubject {
  final int id;
  final String name;
  final String nameCn;
  final String? summary;
  final String? images;
  final Map<String, dynamic>? rating;
  final int? eps;
  final String? airDate;
  final int? airWeekday;
  final String? url;

  BangumiSubject({
    required this.id,
    required this.name,
    required this.nameCn,
    this.summary,
    this.images,
    this.rating,
    this.eps,
    this.airDate,
    this.airWeekday,
    this.url,
  });

  factory BangumiSubject.fromJson(Map<String, dynamic> json) {
    return BangumiSubject(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      nameCn: json['name_cn'] as String? ?? '',
      summary: json['summary'] as String?,
      images: json['images']?.toString(),
      rating: json['rating'] as Map<String, dynamic>?,
      eps: json['eps'] as int?,
      airDate: json['air_date'] as String?,
      airWeekday: json['air_weekday'] as int?,
      url: json['url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'name_cn': nameCn,
      'summary': summary,
      'images': images,
      'rating': rating,
      'eps': eps,
      'air_date': airDate,
      'air_weekday': airWeekday,
      'url': url,
    };
  }

  @override
  String toString() => 'BangumiSubject($nameCn, $name)';
}
```

```dart
// 制作人员信息模型
class BangumiStaff {
  final int id;
  final String name;
  final String? nameCn;
  final String? avatar;
  final String? summary;
  final List<String>? jobs;

  BangumiStaff({
    required this.id,
    required this.name,
    this.nameCn,
    this.avatar,
    this.summary,
    this.jobs,
  });

  factory BangumiStaff.fromJson(Map<String, dynamic> json) {
    return BangumiStaff(
      id: json['id'] as int,
      name: json['name'] as String,
      nameCn: json['name_cn'] as String?,
      avatar: json['images']?['medium'] as String?,
      summary: json['summary'] as String?,
      jobs: (json['jobs'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
    );
  }

  @override
  String toString() => 'BangumiStaff($nameCn, $name)';
}
```

```dart
// 制作人员响应模型
class StaffResponse {
  final int total;
  final int limit;
  final int offset;
  final List<BangumiStaff> data;

  StaffResponse({
    required this.total,
    required this.limit,
    required this.offset,
    required this.data,
  });

  factory StaffResponse.fromJson(Map<String, dynamic> json) {
    return StaffResponse(
      total: json['total'] as int? ?? 0,
      limit: json['limit'] as int? ?? 20,
      offset: json['offset'] as int? ?? 0,
      data: (json['data'] as List<dynamic>?)
              ?.map((e) => BangumiStaff.fromJson(e))
              .toList() ??
          [],
    );
  }
}
```

### 3. API 服务类

```dart
import 'package:dio/dio.dart';

class BangumiApiService {
  final BangumiHttpClient _httpClient = BangumiHttpClient();
  
  // v0 API 基础 URL
  static const String _baseUrl = 'https://api.bgm.tv';
  // p1 API 基础 URL
  static const String _nextBaseUrl = 'https://next.bgm.tv';

  // ========== 无需认证的操作 ==========
  
  // 获取番剧基础信息
  Future<BangumiSubject> getSubject(int id) async {
    final response = await _httpClient.get(
      '$_baseUrl/v0/subjects/$id',
      authenticated: false,
    );
    return BangumiSubject.fromJson(response);
  }

  // 获取制作人员信息
  Future<StaffResponse> getStaff(int id) async {
    final response = await _httpClient.get(
      '$_nextBaseUrl/p1/subjects/$id/staffs/persons',
      authenticated: false,
    );
    return StaffResponse.fromJson(response);
  }

  // 搜索番剧
  Future<List<BangumiSubject>> searchSubjects({
    required String keyword,
    List<String> tags = const [],
    String sort = 'rank',
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _httpClient.post(
      '$_baseUrl/v0/search/subjects?limit=$limit&offset=$offset',
      data: {
        'keyword': keyword,
        'sort': sort,
        'filter': {
          'type': [2], // 2 = 动画
          'tag': tags.isEmpty ? ['日本'] : tags,
          'rank': sort == 'rank' ? ['>0', '<=99999'] : ['>=0', '<=99999'],
          'nsfw': false,
        },
      },
      authenticated: false,
    );

    final results = response['data'] as List<dynamic>;
    return results
        .map((e) => BangumiSubject.fromJson(e as Map<String, dynamic>))
        .where((subject) => subject.nameCn.isNotEmpty)
        .toList();
  }

  // 获取剧集列表
  Future<List<dynamic>> getEpisodes({
    required int subjectId,
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _httpClient.get(
      '$_baseUrl/v0/episodes',
      queryParameters: {
        'subject_id': subjectId,
        'limit': limit,
        'offset': offset,
      },
      authenticated: false,
    );
    return response['data'] as List<dynamic>;
  }

  // 获取评论列表
  Future<List<dynamic>> getComments({
    required int subjectId,
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _httpClient.get(
      '$_nextBaseUrl/p1/subjects/$subjectId/comments?limit=$limit&offset=$offset',
      authenticated: false,
    );
    return response['data'] as List<dynamic>;
  }

  // 获取每日日历
  Future<Map<int, List<BangumiSubject>>> getCalendar() async {
    final response = await _httpClient.get(
      '$_nextBaseUrl/p1/calendar',
      authenticated: false,
    );

    final Map<int, List<BangumiSubject>> calendar = {};
    for (int i = 1; i <= 7; i++) {
      final dayData = response[i.toString()] as List<dynamic>;
      calendar[i] = dayData
          .map((e) => BangumiSubject.fromJson(e['subject'] as Map<String, dynamic>))
          .toList();
    }
    return calendar;
  }

  // 获取趋势数据
  Future<List<BangumiSubject>> getTrending({
    int limit = 24,
    int offset = 0,
  }) async {
    final response = await _httpClient.get(
      '$_nextBaseUrl/p1/trending/subjects',
      queryParameters: {
        'limit': limit,
        'offset': offset,
      },
      authenticated: false,
    );

    final results = response['data'] as List<dynamic>;
    return results
        .map((e) => BangumiSubject.fromJson(e['subject'] as Map<String, dynamic>))
        .toList();
  }

  // ========== 需要认证的操作 ==========
  
  // 收藏番剧
  Future<void> addToCollection({
    required int subjectId,
    required int collectionType,
    String comment = '',
    bool isPrivate = false,
  }) async {
    await _httpClient.post(
      '$_baseUrl/collection/$subjectId',
      data: {
        'type': collectionType, // 1=想看, 2=看过, 3=在看, 4=搁置, 5=抛弃
        'comment': comment,
        'private': isPrivate,
      },
      authenticated: true,
    );
  }

  // 更新收藏状态
  Future<void> updateCollection({
    required int subjectId,
    required int collectionType,
    int? score,
  }) async {
    await _httpClient.put(
      '$_baseUrl/collection/$subjectId',
      data: {
        'type': collectionType,
        if (score != null) 'score': score,
      },
      authenticated: true,
    );
  }

  // 获取用户收藏列表
  Future<List<BangumiSubject>> getUserCollections({
    required String username,
    String? type,
    int limit = 30,
    int offset = 0,
  }) async {
    final response = await _httpClient.get(
      '$_baseUrl/user/$username/collections',
      queryParameters: {
        if (type != null) 'type': type,
        'limit': limit,
        'offset': offset,
      },
      authenticated: true,
    );

    final results = response['data'] as List<dynamic>;
    return results
        .map((e) => BangumiSubject.fromJson(e['subject'] as Map<String, dynamic>))
        .toList();
  }

  // 发表评论
  Future<void> postComment({
    required int subjectId,
    required String content,
  }) async {
    await _httpClient.post(
      '$_baseUrl/subject/$subjectId/comments',
      data: {
        'content': content,
      },
      authenticated: true,
    );
  }

  // 设置认证 Token
  void setAuthToken(String token) {
    _httpClient.setAccessToken(token);
  }

  // 清除认证 Token
  void clearAuthToken() {
    _httpClient.setAccessToken(null);
  }
}
```

### 4. 缓存管理器

```dart
import 'package:shared_preferences/shared_preferences.dart';

class BangumiCacheManager {
  static final BangumiCacheManager _instance = BangumiCacheManager._internal();
  factory BangumiCacheManager() => _instance;

  final Map<String, _CacheEntry> _memoryCache = {};
  static const Duration _defaultCacheDuration = Duration(minutes: 30);

  BangumiCacheManager._internal();

  // 缓存条目
  class _CacheEntry {
    final dynamic data;
    final DateTime timestamp;
    final Duration duration;

    _CacheEntry(this.data, this.duration) : timestamp = DateTime.now();

    bool get isExpired => DateTime.now().difference(timestamp) > duration;
  }

  // 保存数据到缓存
  void put(String key, dynamic data, {Duration? duration}) {
    _memoryCache[key] = _CacheEntry(data, duration ?? _defaultCacheDuration);
  }

  // 从缓存获取数据
  T? get<T>(String key) {
    final entry = _memoryCache[key];
    if (entry == null) return null;

    if (entry.isExpired) {
      _memoryCache.remove(key);
      return null;
    }

    return entry.data as T?;
  }

  // 移除指定缓存
  void remove(String key) {
    _memoryCache.remove(key);
  }

  // 清空所有缓存
  void clear() {
    _memoryCache.clear();
  }

  // 获取带缓存的异步方法
  Future<T> getOrFetch<T>({
    required String cacheKey,
    required Future<T> Function() fetchFn,
    Duration? cacheDuration,
  }) async {
    // 检查缓存
    final cachedData = get<T>(cacheKey);
    if (cachedData != null) {
      return cachedData;
    }

    // 没有缓存，获取数据
    try {
      final data = await fetchFn();
      put(cacheKey, data, duration: cacheDuration);
      return data;
    } catch (e) {
      // 如果获取失败，检查是否有过期但可用的缓存
      final entry = _memoryCache[cacheKey];
      if (entry != null && entry.data is T) {
        return entry.data as T;
      }
      rethrow;
    }
  }

  // 持久化缓存到本地存储
  Future<void> saveToPreferences(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  // 从本地存储读取缓存
  Future<String?> getFromPreferences(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  // 清除本地存储中的缓存
  Future<void> clearPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
```

### 5. Flutter UI 集成示例

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Riverpod Provider
final bangumiApiProvider = Provider<BangumiApiService>((ref) {
  return BangumiApiService();
});

final cacheManagerProvider = Provider<BangumiCacheManager>((ref) {
  return BangumiCacheManager();
});

// 番剧详情页面
class BangumiDetailPage extends ConsumerStatefulWidget {
  final int subjectId;

  const BangumiDetailPage({
    super.key,
    required this.subjectId,
  });

  @override
  ConsumerState<BangumiDetailPage> createState() => _BangumiDetailPageState();
}

class _BangumiDetailPageState extends ConsumerState<BangumiDetailPage> {
  final BangumiApiService _apiService = BangumiApiService();
  final BangumiCacheManager _cache = BangumiCacheManager();

  BangumiSubject? _subject;
  StaffResponse? _staff;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 使用缓存获取番剧信息
      _subject = await _cache.getOrFetch<BangumiSubject>(
        cacheKey: 'bangumi_${widget.subjectId}',
        fetchFn: () => _apiService.getSubject(widget.subjectId),
        cacheDuration: const Duration(hours: 2),
      );

      // 获取制作人员信息
      _staff = await _cache.getOrFetch<StaffResponse>(
        cacheKey: 'staff_${widget.subjectId}',
        fetchFn: () => _apiService.getStaff(widget.subjectId),
        cacheDuration: const Duration(hours: 24),
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_subject?.nameCn ?? '番剧详情')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBasicInfo(),
          const SizedBox(height: 24),
          _buildStaffInfo(),
          const SizedBox(height: 24),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildBasicInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _subject!.nameCn,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        Text(
          _subject!.name,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.grey,
          ),
        ),
        if (_subject!.summary != null) ...[
          const SizedBox(height: 16),
          Text(_subject!.summary!),
        ],
      ],
    );
  }

  Widget _buildStaffInfo() {
    if (_staff == null || _staff!.data.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '制作人员',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        ..._staff!.data.map((staff) => ListTile(
          leading: CircleAvatar(
            backgroundImage: staff.avatar != null
                ? NetworkImage(staff.avatar!)
                : null,
          ),
          title: Text(staff.nameCn ?? staff.name),
          subtitle: staff.jobs?.join(', ') != null
              ? Text(staff.jobs!.join(', '))
              : null,
        )),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        ElevatedButton(
          onPressed: () => _addToCollection(3), // 在看
          child: const Text('在看'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () => _addToCollection(2), // 看过
          child: const Text('看过'),
        ),
      ],
    );
  }

  Future<void> _addToCollection(int collectionType) async {
    try {
      await _apiService.addToCollection(
        subjectId: widget.subjectId,
        collectionType: collectionType,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('收藏成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('收藏失败: $e')),
        );
      }
    }
  }
}
```

### 6. 搜索功能示例

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 搜索结果 Provider
final searchResultsProvider = StateProvider<List<BangumiSubject>>((ref) => []);

// 搜索页面
class BangumiSearchPage extends ConsumerStatefulWidget {
  const BangumiSearchPage({super.key});

  @override
  ConsumerState<BangumiSearchPage> createState() => _BangumiSearchPageState();
}

class _BangumiSearchPageState extends ConsumerState<BangumiSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final BangumiApiService _apiService = BangumiApiService();
  bool _isSearching = false;

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      ref.read(searchResultsProvider.notifier).state = [];
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await _apiService.searchSubjects(
        keyword: query,
        limit: 20,
      );

      if (mounted) {
        ref.read(searchResultsProvider.notifier).state = results;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('搜索失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: '搜索番剧...',
            border: InputBorder.none,
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: _performSearch,
        ),
      ),
      body: _buildBody(results),
    );
  }

  Widget _buildBody(List<BangumiSubject> results) {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (results.isEmpty && _searchController.text.isNotEmpty) {
      return const Center(child: Text('未找到相关番剧'));
    }

    if (results.isEmpty && _searchController.text.isEmpty) {
      return const Center(child: Text('请输入搜索关键词'));
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final subject = results[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: subject.images != null
                ? NetworkImage(subject.images!)
                : null,
            child: subject.images == null ? Text(subject.name[0]) : null,
          ),
          title: Text(subject.nameCn),
          subtitle: Text(subject.name),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BangumiDetailPage(subjectId: subject.id),
              ),
            );
          },
        );
      },
    );
  }
}
```

### 7. 认证管理

```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService with ChangeNotifier {
  static const String _tokenKey = 'bangumi_access_token';
  String? _accessToken;

  String? get accessToken => _accessToken;
  bool get isAuthenticated => _accessToken != null;

  // 初始化时从本地存储加载 token
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_tokenKey);
    notifyListeners();
  }

  // 设置 token（通常通过 OAuth 流程获取）
  Future<void> setToken(String token) async {
    _accessToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    notifyListeners();
  }

  // 清除 token
  Future<void> logout() async {
    _accessToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    notifyListeners();
  }

  // 检查 token 是否有效
  Future<bool> validateToken() async {
    if (_accessToken == null) return false;

    try {
      final apiService = BangumiApiService();
      await apiService.getUserCollections(username: 'me'); // 验证请求
      return true;
    } catch (e) {
      await logout();
      return false;
    }
  }
}

// 认证 Provider
final authServiceProvider = Provider<AuthService>((ref) {
  final service = AuthService();
  service.init();
  return service;
});

// 登录页面示例
class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('登录 Bangumi')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _handleLogin(context, ref),
          child: const Text('通过 OAuth 登录'),
        ),
      ),
    );
  }

  Future<void> _handleLogin(BuildContext context, WidgetRef ref) async {
    // 这里实现 OAuth 登录流程
    // 1. 打开授权页面
    // 2. 获取授权码
    // 3. 交换 access token
    // 4. 调用 authService.setToken(token)
    
    // 示例代码（需要根据实际 OAuth 流程调整）
    try {
      final authService = ref.read(authServiceProvider);
      // final token = await _oauthLogin();
      // await authService.setToken(token);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登录成功')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('登录失败: $e')),
        );
      }
    }
  }
}
```

### 8. 错误处理和重试机制

```dart
import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException: $message (Code: $statusCode)';
}

class ApiErrorHandler {
  static ApiException handleError(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          switch (statusCode) {
            case 401:
              return const ApiException('认证失败，请重新登录', statusCode: 401);
            case 403:
              return const ApiException('权限不足', statusCode: 403);
            case 404:
              return const ApiException('资源不存在', statusCode: 404);
            case 429:
              return const ApiException('请求过于频繁，请稍后再试', statusCode: 429);
            case 500:
              return const ApiException('服务器错误', statusCode: 500);
            default:
              return ApiException('服务器异常', statusCode: statusCode);
          }
        case DioExceptionType.connectionError:
          return const ApiException('网络连接失败');
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return const ApiException('请求超时，请检查网络');
        default:
          return ApiException('网络错误: ${error.message}');
      }
    } else if (error is ApiException) {
      return error;
    } else {
      return ApiException('未知错误: $error');
    }
  }
}

// 带重试机制的 API 调用
class RetryHelper {
  static Future<T> retry<T>({
    required Future<T> Function() function,
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 1),
    bool Function(dynamic)? retryIf,
  }) async {
    int attempts = 0;
    
    while (attempts < maxRetries) {
      try {
        return await function();
      } catch (e) {
        attempts++;
        
        if (attempts >= maxRetries) {
          throw e;
        }
        
        // 检查是否应该重试
        if (retryIf != null && !retryIf(e)) {
          throw e;
        }
        
        await Future.delayed(delay * attempts);
      }
    }
    
    throw ApiException('重试失败');
  }
}

// 使用示例
class BangumiApiService with RetryHelper {
  // 带重试的搜索
  Future<List<BangumiSubject>> searchWithRetry({
    required String keyword,
  }) async {
    return retry<List<BangumiSubject>>(
      function: () => searchSubjects(keyword: keyword),
      maxRetries: 3,
      delay: const Duration(seconds: 1),
      retryIf: (error) => error is DioException &&
          error.type == DioExceptionType.connectionTimeout,
    );
  }

  // 使用示例
  Future<void> demoRetry() async {
    try {
      final results = await searchWithRetry(keyword: '葬送的芙莉莲');
      print('搜索结果: ${results.length}');
    } catch (e) {
      final apiException = ApiErrorHandler.handleError(e);
      print('错误: $apiException');
    }
  }
}
```

## 最佳实践

### 1. 依赖注入

```dart
// 使用 Riverpod 管理依赖
final bangumiApiProvider = Provider<BangumiApiService>((ref) {
  return BangumiApiService();
});

final cacheManagerProvider = Provider<BangumiCacheManager>((ref) {
  return BangumiCacheManager();
});

// 在组件中使用
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiService = ref.watch(bangumiApiProvider);
    final cache = ref.watch(cacheManagerProvider);
    
    // 使用 apiService 和 cache
    return Container();
  }
}
```

### 2. 状态管理

```dart
// 使用 StateNotifier 管理复杂状态
class BangumiNotifier extends StateNotifier<BangumiState> {
  final BangumiApiService _apiService;
  final BangumiCacheManager _cache;

  BangumiNotifier(this._apiService, this._cache)
      : super(BangumiState.initial());

  Future<void> loadSubject(int id) async {
    state = BangumiState.loading();

    try {
      final subject = await _cache.getOrFetch<BangumiSubject>(
        cacheKey: 'bangumi_$id',
        fetchFn: () => _apiService.getSubject(id),
      );

      state = BangumiState.loaded(subject);
    } catch (e) {
      state = BangumiState.error(ApiErrorHandler.handleError(e));
    }
  }
}

class BangumiState {
  final bool isLoading;
  final BangumiSubject? subject;
  final ApiException? error;

  BangumiState.initial()
      : isLoading = false,
        subject = null,
        error = null;

  BangumiState.loading()
      : isLoading = true,
        subject = null,
        error = null;

  BangumiState.loaded(this.subject)
      : isLoading = false,
        error = null;

  BangumiState.error(this.error)
      : isLoading = false,
        subject = null;
}
```

### 3. 性能优化

```dart
// 使用 computed 和 selector 优化重建
final filteredSubjectProvider = Provider<List<BangumiSubject>>((ref) {
  final results = ref.watch(searchResultsProvider);
  // 过滤逻辑
  return results.where((s) => s.nameCn.isNotEmpty).toList();
});

// 使用 autoDispose 自动清理资源
final searchResultsProvider = StateProvider.autoDispose<List<BangumiSubject>>((ref) => []);
```

## 依赖配置

### pubspec.yaml

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # HTTP 客户端
  dio: ^5.4.0
  
  # 日志
  pretty_dio_logger: ^1.3.1
  
  # 状态管理
  flutter_riverpod: ^2.4.9
  
  # 本地存储
  shared_preferences: ^2.2.2
  
  # JSON 序列化
  json_annotation: ^4.8.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  
  # JSON 序列化代码生成
  build_runner: ^2.4.7
  json_serializable: ^6.7.1
```

## 参考资源

- [Bangumi API 官方文档](https://github.com/bangumi/api)
- [Kazumi 项目源码](https://github.com/Predidit/Kazumi)
- [Dio 文档](https://pub.dev/packages/dio)
- [Riverpod 文档](https://riverpod.dev/)
- [Flutter 异步编程](https://dart.dev/async)

## 总结

通过本指南，你可以在 Flutter 应用中实现：

✅ **简洁的 API 调用**: 读取操作无需认证  
✅ **高效的状态管理**: 使用 Riverpod 管理应用状态  
✅ **智能的缓存策略**: 提升性能，减少网络请求  
✅ **完善的错误处理**: 提供良好的用户体验  
✅ **类型安全**: 使用 Dart 类型系统避免运行时错误  

核心原则：**"读数据公开访问，写数据需要认证"**，让用户无需登录即可享受核心功能。