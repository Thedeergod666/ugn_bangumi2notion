import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../models/mapping_config.dart';
import '../models/notion_models.dart';
import '../app/app_services.dart';
import '../app/app_settings.dart';
import '../services/notion_api.dart';
import '../services/settings_storage.dart';
import '../widgets/error_detail_dialog.dart';
import '../widgets/navigation_shell.dart';

class _DailyCacheData {
  final List<DailyRecommendation> candidates;
  final int index;

  const _DailyCacheData({
    required this.candidates,
    required this.index,
  });
}

class RecommendationPage extends StatefulWidget {
  const RecommendationPage({super.key});

  @override
  State<RecommendationPage> createState() => _RecommendationPageState();
}

class _RecommendationPageState extends State<RecommendationPage> {
  static const double _minScore = 6.5;
  static const int _logTextLimit = 200;

  late final NotionApi _notionApi;
  final SettingsStorage _settingsStorage = SettingsStorage();

  bool _loading = true;
  DailyRecommendation? _recommendation;
  List<DailyRecommendation> _dailyCandidates = [];
  int _dailyIndex = 0;
  String? _errorMessage;
  String? _emptyMessage;
  String? _configurationMessage;
  String? _configurationRoute;
  Object? _error;
  StackTrace? _stackTrace;

  @override
  void initState() {
    super.initState();
    _notionApi = context.read<AppServices>().notionApi;
    _loadRecommendation();
  }

  Future<void> _loadRecommendation({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _recommendation = null;
        _dailyCandidates = [];
        _dailyIndex = 0;
        _errorMessage = null;
        _emptyMessage = null;
        _configurationMessage = null;
        _configurationRoute = null;
        _error = null;
        _stackTrace = null;
      });
    }

    try {
      final appSettings = context.read<AppSettings>();
      final cached = await _loadDailyCache();
      if (cached != null) {
        if (kDebugMode) {
          debugPrint('[DailyReco] cache hit');
        }
        if (!mounted) return;
        final current = cached.candidates.isNotEmpty
            ? cached.candidates[cached.index]
            : null;
        setState(() {
          _dailyCandidates = cached.candidates;
          _dailyIndex = cached.index;
          _recommendation = current;
          _loading = false;
          _emptyMessage =
              (cached.candidates.isEmpty || current?.title.isEmpty == true)
                  ? '暂无 ${_minScore.toStringAsFixed(1)}+ 条目'
                  : null;
        });
        return;
      }

      if (kDebugMode) {
        debugPrint('[DailyReco] cache miss');
      }
      final token = appSettings.notionToken;
      final databaseId = appSettings.notionDatabaseId;

      if (token.isEmpty || databaseId.isEmpty) {
        _setConfiguration(
          '请先在设置页面配置 Notion Token 和 Database ID',
          '/settings',
        );
        return;
      }

      final mappingConfig = await _settingsStorage.getMappingConfig();
      final legacyBindings =
          await _settingsStorage.getDailyRecommendationBindings();
      final bindings = _resolveBindings(mappingConfig, legacyBindings);

      if (bindings.isEmpty ||
          bindings.yougnScore.isEmpty ||
          bindings.title.isEmpty) {
        _setConfiguration(
          '请先在映射配置页面绑定每日推荐字段',
          '/mapping',
        );
        return;
      }

      final candidates = await _notionApi.getDailyRecommendationCandidates(
        token: token,
        databaseId: databaseId,
        bindings: bindings,
        minScore: _minScore,
      );

      final pickedIndex =
          candidates.isEmpty ? 0 : Random().nextInt(candidates.length);
      await _saveDailyCache(
        candidates: candidates,
        index: pickedIndex,
      );

      if (!mounted) return;
      setState(() {
        _dailyCandidates = candidates;
        _dailyIndex = pickedIndex;
        _recommendation =
            candidates.isNotEmpty ? candidates[pickedIndex] : null;
        _loading = false;
        if (candidates.isEmpty) {
          _emptyMessage = '暂无 ${_minScore.toStringAsFixed(1)}+ 条目';
        }
      });
    } catch (error, stackTrace) {
      if (!mounted) return;
      final isTimeout = error is TimeoutException;
      setState(() {
        _loading = false;
        _errorMessage = isTimeout ? '网络较慢，点击换一部重试' : '加载失败，请稍后重试';
        _error = error;
        _stackTrace = stackTrace;
      });
      _showErrorSnackBar(error, stackTrace);
    }
  }

  String _buildTodayKey() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _clipLog(String? value) {
    if (value == null) return '';
    final trimmed = value.trim();
    if (trimmed.length <= _logTextLimit) return trimmed;
    return '${trimmed.substring(0, _logTextLimit)}…';
  }

  Future<_DailyCacheData?> _loadDailyCache() async {
    final today = _buildTodayKey();
    final cachedDate = await _settingsStorage.getDailyRecommendationCacheDate();
    final payload = await _settingsStorage.getDailyRecommendationCachePayload();
    if (cachedDate == null || payload == null || payload.isEmpty) {
      return null;
    }
    if (cachedDate != today) {
      return null;
    }

    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['candidates'] is List) {
        final rawList = decoded['candidates'] as List;
        final candidates = rawList
            .whereType<Map<String, dynamic>>()
            .map(DailyRecommendation.fromJson)
            .toList();
        var index = int.tryParse(decoded['index']?.toString() ?? '') ?? 0;
        if (index < 0) index = 0;
        if (index >= candidates.length && candidates.isNotEmpty) {
          index = 0;
        }
        if (kDebugMode) {
          final currentTitle =
              candidates.isNotEmpty ? candidates[index].title : '';
          final currentScore = candidates.isNotEmpty
              ? candidates[index].yougnScore?.toStringAsFixed(1) ?? '-'
              : '-';
          debugPrint(
            '[DailyReco] cache payload candidates=${candidates.length} '
            'index=$index title="${_clipLog(currentTitle)}" score=$currentScore',
          );
        }
        return _DailyCacheData(candidates: candidates, index: index);
      }
      final recommendation = DailyRecommendation.fromJson(decoded);
      if (kDebugMode) {
        debugPrint(
          '[DailyReco] cache payload title="${_clipLog(recommendation.title)}" '
          'score=${recommendation.yougnScore?.toStringAsFixed(1) ?? "-"}',
        );
      }
      return _DailyCacheData(candidates: [recommendation], index: 0);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveDailyCache({
    required List<DailyRecommendation> candidates,
    required int index,
  }) async {
    final payload = jsonEncode({
      'version': 2,
      'index': index,
      'candidates': candidates.map((item) => item.toJson()).toList(),
    });
    await _settingsStorage.saveDailyRecommendationCache(
      date: _buildTodayKey(),
      payload: payload,
    );
  }

  Future<void> _nextRecommendation() async {
    if (_dailyCandidates.length <= 1) return;
    final nextIndex = (_dailyIndex + 1) % _dailyCandidates.length;
    if (kDebugMode) {
      debugPrint('[DailyReco] next index=$nextIndex');
    }
    if (!mounted) return;
    setState(() {
      _dailyIndex = nextIndex;
      _recommendation = _dailyCandidates[nextIndex];
    });
    await _saveDailyCache(candidates: _dailyCandidates, index: _dailyIndex);
  }

  NotionDailyRecommendationBindings _resolveBindings(
    MappingConfig config,
    NotionDailyRecommendationBindings legacyBindings,
  ) {
    return config.dailyRecommendationBindings.isEmpty
        ? legacyBindings
        : config.dailyRecommendationBindings;
  }

  void _setConfiguration(String message, String route) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _configurationMessage = message;
      _configurationRoute = route;
    });
  }

  void _showErrorSnackBar(Object error, StackTrace stackTrace) {
    if (!mounted) return;
    final isTimeout = error is TimeoutException;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isTimeout ? '网络较慢，点击换一部重试' : '加载失败，请稍后重试'),
        action: SnackBarAction(
          label: '详情',
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => ErrorDetailDialog(
                error: error,
                stackTrace: stackTrace,
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '未知';
    final local = date.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatCoverUrl(
    String url, {
    int head = 64,
    int tail = 48,
  }) {
    if (url.length <= head + tail + 1) {
      return url;
    }
    return '${url.substring(0, head)}…${url.substring(url.length - tail)}';
  }

  @override
  Widget build(BuildContext context) {
    return NavigationShell(
      title: '每日推荐',
      selectedRoute: '/recommendation',
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_configurationMessage != null) {
      final route = _configurationRoute;
      return _buildCenteredMessage(
        context,
        icon: Icons.settings_suggest,
        title: _configurationMessage!,
        actionLabel: route == '/mapping' ? '去映射配置' : '去设置',
        onAction: route == null
            ? null
            : () => Navigator.pushReplacementNamed(context, route),
      );
    }

    if (_errorMessage != null) {
      return _buildCenteredMessage(
        context,
        icon: Icons.error_outline,
        title: _errorMessage!,
        actionLabel: '重试',
        onAction: _loading ? null : () => _loadRecommendation(),
        secondaryLabel: '查看详情',
        onSecondaryAction: (_error != null && _stackTrace != null)
            ? () => showDialog(
                  context: context,
                  builder: (context) => ErrorDetailDialog(
                    error: _error!,
                    stackTrace: _stackTrace!,
                  ),
                )
            : null,
      );
    }

    if (_emptyMessage != null) {
      return _buildCenteredMessage(
        context,
        icon: Icons.inbox_outlined,
        title: _emptyMessage!,
        actionLabel: '再换一部',
        onAction: _loading
            ? null
            : () => _dailyCandidates.isNotEmpty
                ? _nextRecommendation()
                : _loadRecommendation(),
      );
    }

    final recommendation = _recommendation;
    if (recommendation == null) {
      return _buildCenteredMessage(
        context,
        icon: Icons.inbox_outlined,
        title: '暂无推荐内容',
        actionLabel: '再换一部',
        onAction: _loading
            ? null
            : () => _dailyCandidates.isNotEmpty
                ? _nextRecommendation()
                : _loadRecommendation(),
      );
    }

    return _buildRecommendationContent(context, recommendation);
  }

  Widget _buildCenteredMessage(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? actionLabel,
    VoidCallback? onAction,
    String? secondaryLabel,
    VoidCallback? onSecondaryAction,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 48, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  if (actionLabel != null)
                    FilledButton.icon(
                      onPressed: onAction,
                      icon: const Icon(Icons.refresh),
                      label: Text(actionLabel),
                    ),
                  if (secondaryLabel != null)
                    OutlinedButton(
                      onPressed: onSecondaryAction,
                      child: Text(secondaryLabel),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendationContent(
    BuildContext context,
    DailyRecommendation recommendation,
  ) {
    final title = recommendation.title;
    final scoreText = recommendation.yougnScore?.toStringAsFixed(1) ?? '-';
    final airDate = _formatDate(recommendation.airDate);
    final tags = recommendation.tags;
    final type = recommendation.type?.trim() ?? '';
    final shortReview = recommendation.shortReview?.trim() ?? '';
    final longReview = recommendation.longReview?.trim().isNotEmpty == true
        ? recommendation.longReview!.trim()
        : (recommendation.contentLongReview?.trim() ?? '');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '今日推荐',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _loading ? null : () => _nextRecommendation(),
                icon: const Icon(Icons.shuffle),
                label: const Text('换一部'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final cover = _buildCover(context, recommendation.cover);
              final details = _buildRecommendationDetails(
                context,
                title: title,
                scoreText: scoreText,
                airDate: airDate,
                type: type,
                tags: tags,
                shortReview: shortReview,
                longReview: longReview,
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                        width: 260,
                        child: AspectRatio(aspectRatio: 3 / 4, child: cover)),
                    const SizedBox(width: 24),
                    Expanded(child: details),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(aspectRatio: 3 / 4, child: cover),
                  const SizedBox(height: 16),
                  details,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCover(BuildContext context, String? coverUrl) {
    final colorScheme = Theme.of(context).colorScheme;
    final url = coverUrl?.trim() ?? '';
    final hasUrl = url.isNotEmpty;

    if (!hasUrl) {
      return Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: Icon(Icons.image_outlined, size: 48)),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        color: colorScheme.surfaceContainerHighest,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }
            final expectedBytes = loadingProgress.expectedTotalBytes;
            final loadedBytes = loadingProgress.cumulativeBytesLoaded;
            final progress = expectedBytes != null && expectedBytes > 0
                ? loadedBytes / expectedBytes
                : null;
            return Center(
              child: CircularProgressIndicator(value: progress),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            final displayUrl = _formatCoverUrl(url);
            final errorType = error.runtimeType.toString();
            final errorText = error.toString();
            return Container(
              width: double.infinity,
              height: double.infinity,
              color: colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '图片加载失败',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'URL：',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                    SelectableText(
                      displayUrl,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '错误类型：$errorType',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '错误信息：$errorText',
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRecommendationDetails(
    BuildContext context, {
    required String title,
    required String scoreText,
    required String airDate,
    required String type,
    required List<String> tags,
    required String shortReview,
    required String longReview,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star,
                    size: 16,
                    color: colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '悠gn评分 $scoreText',
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Chip(
              label: Text('放送日期 $airDate'),
              backgroundColor: colorScheme.surfaceContainerLow,
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            if (type.isNotEmpty)
              Chip(
                label: Text(type),
                backgroundColor: colorScheme.surfaceContainerLow,
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (tags.isNotEmpty) ...[
          Text(
            '标签',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags
                .map(
                  (tag) => Chip(
                    label: Text(tag),
                    backgroundColor: colorScheme.surfaceContainerLow,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          '悠简评',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          shortReview.isEmpty ? '暂无简评' : shortReview,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: shortReview.isEmpty
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.onSurface,
              ),
        ),
        if (longReview.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            '正文长评',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(longReview, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ],
    );
  }
}
