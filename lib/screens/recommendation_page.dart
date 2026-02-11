import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_services.dart';
import '../app/app_settings.dart';
import '../models/bangumi_models.dart';
import '../models/mapping_config.dart';
import '../models/notion_models.dart';
import '../services/bangumi_api.dart';
import '../services/notion_api.dart';
import '../services/settings_storage.dart';
import '../widgets/error_detail_dialog.dart';
import '../widgets/navigation_shell.dart';

class _DailyCacheData {
  final List<DailyRecommendation> candidates;
  final List<int> indices;
  final int currentIndex;

  const _DailyCacheData({
    required this.candidates,
    required this.indices,
    required this.currentIndex,
  });
}

class _NotionContent {
  final String? coverUrl;
  final String? longReview;

  const _NotionContent({
    required this.coverUrl,
    required this.longReview,
  });
}

class _ScoreBin {
  final String label;
  final int count;

  const _ScoreBin({
    required this.label,
    required this.count,
  });
}

class RecommendationPage extends StatefulWidget {
  const RecommendationPage({super.key});

  @override
  State<RecommendationPage> createState() => _RecommendationPageState();
}

class _RecommendationPageState extends State<RecommendationPage> {
  static const double _minScore = 6.5;
  static const int _heroSize = 3;
  static const int _logTextLimit = 200;
  static const Duration _rotationInterval = Duration(seconds: 20);
  static const List<String> _scoreLabels = [
    '10',
    '9',
    '8',
    '7',
    '6',
    '5',
    '4',
    '3',
    '2',
    '1',
  ];

  late final NotionApi _notionApi;
  late final BangumiApi _bangumiApi;
  final SettingsStorage _settingsStorage = SettingsStorage();
  final PageController _pageController = PageController();
  final TextEditingController _notionSearchController =
      TextEditingController();

  bool _loading = true;
  List<DailyRecommendation> _dailyCandidates = [];
  List<int> _heroIndices = [];
  int _currentHeroIndex = 0;
  bool _statsLoading = false;

  String? _errorMessage;
  String? _emptyMessage;
  String? _configurationMessage;
  String? _configurationRoute;
  Object? _error;
  StackTrace? _stackTrace;

  bool _showLongReview = false;
  Timer? _rotationTimer;

  final Map<int, BangumiSubjectDetail> _bangumiDetailCache = {};
  final Set<int> _bangumiDetailLoading = {};
  final Map<String, _NotionContent> _notionContentCache = {};
  final Set<String> _notionContentLoading = {};

  List<NotionScoreEntry> _scoreEntries = [];
  List<_ScoreBin> _scoreBins = [];
  int _scoreTotal = 0;

  @override
  void initState() {
    super.initState();
    final services = context.read<AppServices>();
    _notionApi = services.notionApi;
    _bangumiApi = services.bangumiApi;
    _loadRecommendation();
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _pageController.dispose();
    _notionSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecommendation({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _dailyCandidates = [];
        _heroIndices = [];
        _currentHeroIndex = 0;
        _errorMessage = null;
        _emptyMessage = null;
        _configurationMessage = null;
        _configurationRoute = null;
        _error = null;
        _stackTrace = null;
      });
    }
    _stopRotationTimer();

    try {
      final appSettings = context.read<AppSettings>();
      final cached = await _loadDailyCache();
      if (cached != null) {
        if (kDebugMode) {
          debugPrint('[DailyReco] cache hit');
        }
        final indices = _normalizeHeroIndices(
          cached.indices,
          cached.candidates.length,
        );
        final currentIndex =
            (cached.currentIndex >= 0 && cached.currentIndex < indices.length)
                ? cached.currentIndex
                : 0;
        if (!mounted) return;
        setState(() {
          _dailyCandidates = cached.candidates;
          _heroIndices = indices;
          _currentHeroIndex = currentIndex;
          _loading = false;
          _emptyMessage = _dailyCandidates.isEmpty
              ? '暂无 ${_minScore.toStringAsFixed(1)}+ 条目'
              : null;
        });
        _jumpToHeroIndex(currentIndex);
        _startRotationTimer();
        final bindings = await _loadBindings();
        if (bindings != null) {
          await _loadLibraryStats(
            token: appSettings.notionToken,
            databaseId: appSettings.notionDatabaseId,
            bindings: bindings,
          );
        }
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

      final bindings = await _loadBindings();
      if (bindings == null ||
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

      final indices = _pickHeroIndices(candidates.length);
      await _saveDailyCache(
        candidates: candidates,
        indices: indices,
        currentIndex: 0,
      );

      if (!mounted) return;
      setState(() {
        _dailyCandidates = candidates;
        _heroIndices = indices;
        _currentHeroIndex = 0;
        _loading = false;
        if (candidates.isEmpty) {
          _emptyMessage = '暂无 ${_minScore.toStringAsFixed(1)}+ 条目';
        }
      });
      _jumpToHeroIndex(0);
      _startRotationTimer();
      await _loadLibraryStats(
        token: token,
        databaseId: databaseId,
        bindings: bindings,
      );
    } catch (error, stackTrace) {
      if (!mounted) return;
      final isTimeout = error is TimeoutException;
      setState(() {
        _loading = false;
        _errorMessage =
            isTimeout ? '网络较慢，点击换一部重试' : '加载失败，请稍后重试';
        _error = error;
        _stackTrace = stackTrace;
      });
      _stopRotationTimer();
      _showErrorSnackBar(error, stackTrace);
    }
  }

  Future<NotionDailyRecommendationBindings?> _loadBindings() async {
    final mappingConfig = await _settingsStorage.getMappingConfig();
    final legacyBindings =
        await _settingsStorage.getDailyRecommendationBindings();
    final bindings = _resolveBindings(mappingConfig, legacyBindings);
    return bindings.isEmpty ? null : bindings;
  }

  Future<void> _loadLibraryStats({
    required String token,
    required String databaseId,
    required NotionDailyRecommendationBindings bindings,
  }) async {
    if (token.isEmpty || databaseId.isEmpty || bindings.yougnScore.isEmpty) {
      return;
    }
    if (_statsLoading) return;
    setState(() => _statsLoading = true);
    try {
      final entries = await _notionApi.getYougnScoreEntries(
        token: token,
        databaseId: databaseId,
        yougnScoreProperty: bindings.yougnScore,
        bangumiScoreProperty:
            bindings.bangumiScore.isEmpty ? null : bindings.bangumiScore,
      );
      final bins = _buildScoreBins(entries);
      if (!mounted) return;
      setState(() {
        _scoreEntries = entries;
        _scoreBins = bins;
        _scoreTotal = entries.length;
        _statsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _statsLoading = false;
        _scoreEntries = [];
        _scoreBins = [];
        _scoreTotal = 0;
      });
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
    return '${trimmed.substring(0, _logTextLimit)}...';
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
        final indices = _parseIndices(decoded['indices'], candidates.length);
        var currentIndex =
            int.tryParse(decoded['currentIndex']?.toString() ?? '') ??
                int.tryParse(decoded['index']?.toString() ?? '') ??
                0;
        if (currentIndex < 0) currentIndex = 0;
        if (currentIndex >= indices.length && indices.isNotEmpty) {
          currentIndex = 0;
        }
        if (kDebugMode) {
          final currentTitle = candidates.isNotEmpty
              ? candidates[indices.isNotEmpty ? indices.first : 0].title
              : '';
          final currentScore = candidates.isNotEmpty
              ? candidates[indices.isNotEmpty ? indices.first : 0]
                      .yougnScore
                      ?.toStringAsFixed(1) ??
                  '-'
              : '-';
          debugPrint(
            '[DailyReco] cache payload candidates=${candidates.length} '
            'indices=${indices.length} title="${_clipLog(currentTitle)}" '
            'score=$currentScore',
          );
        }
        return _DailyCacheData(
          candidates: candidates,
          indices: indices,
          currentIndex: currentIndex,
        );
      }
      final recommendation = DailyRecommendation.fromJson(decoded);
      if (kDebugMode) {
        debugPrint(
          '[DailyReco] cache payload title="${_clipLog(recommendation.title)}" '
          'score=${recommendation.yougnScore?.toStringAsFixed(1) ?? "-"}',
        );
      }
      return _DailyCacheData(
        candidates: [recommendation],
        indices: const [0],
        currentIndex: 0,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveDailyCache({
    required List<DailyRecommendation> candidates,
    required List<int> indices,
    required int currentIndex,
  }) async {
    final payload = jsonEncode({
      'version': 3,
      'currentIndex': currentIndex,
      'indices': indices,
      'candidates': candidates.map((item) => item.toJson()).toList(),
    });
    await _settingsStorage.saveDailyRecommendationCache(
      date: _buildTodayKey(),
      payload: payload,
    );
  }

  List<int> _parseIndices(dynamic raw, int max) {
    if (raw is! List) return [];
    final indices = <int>[];
    for (final value in raw) {
      final parsed = int.tryParse(value.toString());
      if (parsed == null) continue;
      if (parsed < 0 || parsed >= max) continue;
      if (!indices.contains(parsed)) indices.add(parsed);
    }
    return indices;
  }

  List<int> _pickHeroIndices(int count) {
    if (count <= 0) return [];
    final size = min(count, _heroSize);
    final rand = Random();
    final picks = <int>{};
    while (picks.length < size) {
      picks.add(rand.nextInt(count));
    }
    final list = picks.toList()..shuffle(rand);
    return list;
  }

  List<int> _normalizeHeroIndices(List<int> indices, int count) {
    if (count <= 0) return [];
    final valid = indices.where((i) => i >= 0 && i < count).toList();
    if (valid.isEmpty) return _pickHeroIndices(count);
    return valid;
  }

  void _jumpToHeroIndex(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_pageController.hasClients) return;
      if (index < 0 || index >= _heroIndices.length) return;
      _pageController.jumpToPage(index);
    });
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
    _stopRotationTimer();
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

  Future<void> _reshuffleRecommendations() async {
    if (_dailyCandidates.isEmpty) {
      await _loadRecommendation();
      return;
    }
    final indices = _pickHeroIndices(_dailyCandidates.length);
    if (indices.isEmpty) return;
    if (!mounted) return;
    setState(() {
      _heroIndices = indices;
      _currentHeroIndex = 0;
      _showLongReview = false;
    });
    await _saveDailyCache(
      candidates: _dailyCandidates,
      indices: _heroIndices,
      currentIndex: _currentHeroIndex,
    );
    _jumpToHeroIndex(0);
    _startRotationTimer();
  }

  void _startRotationTimer() {
    _rotationTimer?.cancel();
    if (_heroIndices.length <= 1) return;
    _rotationTimer = Timer.periodic(_rotationInterval, (_) {
      _advanceHeroPage();
    });
  }

  void _stopRotationTimer() {
    _rotationTimer?.cancel();
    _rotationTimer = null;
  }

  void _resetRotationTimer() {
    _startRotationTimer();
  }

  void _advanceHeroPage() {
    if (!_pageController.hasClients) return;
    if (_heroIndices.length <= 1) return;
    final nextIndex = (_currentHeroIndex + 1) % _heroIndices.length;
    _pageController.animateToPage(
      nextIndex,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  int? _resolveSubjectId(DailyRecommendation recommendation) {
    final raw = (recommendation.subjectId?.trim().isNotEmpty == true)
        ? recommendation.subjectId
        : recommendation.bangumiId;
    if (raw == null || raw.trim().isEmpty) return null;
    return int.tryParse(raw.trim());
  }

  void _scheduleBangumiDetailLoad(int subjectId) {
    if (_bangumiDetailCache.containsKey(subjectId) ||
        _bangumiDetailLoading.contains(subjectId)) {
      return;
    }
    _bangumiDetailLoading.add(subjectId);
    _loadBangumiDetail(subjectId);
  }

  Future<void> _loadBangumiDetail(int subjectId) async {
    try {
      final token = context.read<AppSettings>().bangumiAccessToken;
      final detail = await _bangumiApi.fetchDetail(
        subjectId: subjectId,
        accessToken: token.isEmpty ? null : token,
      );
      if (!mounted) return;
      setState(() {
        _bangumiDetailCache[subjectId] = detail;
      });
    } catch (_) {
      // Ignore bangumi detail failures
    } finally {
      _bangumiDetailLoading.remove(subjectId);
    }
  }

  void _scheduleNotionContentLoad(String? pageId) {
    if (pageId == null || pageId.trim().isEmpty) return;
    if (_notionContentCache.containsKey(pageId) ||
        _notionContentLoading.contains(pageId)) {
      return;
    }
    _notionContentLoading.add(pageId);
    _loadNotionContent(pageId);
  }

  Future<void> _loadNotionContent(String pageId) async {
    try {
      final token = context.read<AppSettings>().notionToken;
      if (token.isEmpty) return;
      final content = await _notionApi.getPageContent(
        token: token,
        pageId: pageId,
      );
      if (!mounted) return;
      setState(() {
        _notionContentCache[pageId] = _NotionContent(
          coverUrl: content.coverUrl,
          longReview: content.longReview,
        );
      });
    } catch (_) {
      // Ignore notion content failures
    } finally {
      _notionContentLoading.remove(pageId);
    }
  }

  _NotionContent? _resolveNotionContent(DailyRecommendation recommendation) {
    final pageId = recommendation.pageId?.trim() ?? '';
    if (pageId.isEmpty) return null;
    return _notionContentCache[pageId];
  }

  String _resolveCoverUrl(
    DailyRecommendation recommendation,
    BangumiSubjectDetail? detail,
    _NotionContent? content,
  ) {
    final detailCover = detail?.imageUrl ?? '';
    if (detailCover.isNotEmpty) return detailCover;
    final cover = recommendation.cover?.trim() ?? '';
    if (cover.isNotEmpty) return cover;
    final cachedCover = recommendation.contentCoverUrl?.trim() ?? '';
    if (cachedCover.isNotEmpty) return cachedCover;
    final contentCover = content?.coverUrl?.trim() ?? '';
    if (contentCover.isNotEmpty) return contentCover;
    return '';
  }

  String _resolveLongReview(
    DailyRecommendation recommendation,
    _NotionContent? content,
  ) {
    final direct = recommendation.longReview?.trim() ?? '';
    if (direct.isNotEmpty) return direct;
    final cached = recommendation.contentLongReview?.trim() ?? '';
    if (cached.isNotEmpty) return cached;
    final contentText = content?.longReview?.trim() ?? '';
    return contentText;
  }

  List<String> _resolveTags(
    DailyRecommendation recommendation,
    BangumiSubjectDetail? detail,
  ) {
    if (detail != null && detail.tagDetails.isNotEmpty) {
      final sorted = [...detail.tagDetails]
        ..sort((a, b) => b.count.compareTo(a.count));
      return sorted.take(8).map((tag) => tag.name).toList();
    }
    return recommendation.tags.take(8).toList();
  }

  String _pickNotionOrBangumi(String? notionValue, String? bangumiValue) {
    final notion = notionValue?.trim() ?? '';
    if (notion.isNotEmpty) return notion;
    return bangumiValue?.trim() ?? '';
  }

  int? _computeYougnRank(double? yougnScore, double? bangumiScore) {
    if (yougnScore == null || _scoreEntries.isEmpty) return null;
    final compareBangumiScore = bangumiScore ?? 0;
    var rank = 1;
    for (final entry in _scoreEntries) {
      if (entry.yougnScore > yougnScore) {
        rank += 1;
        continue;
      }
      if (entry.yougnScore == yougnScore &&
          entry.bangumiScore > compareBangumiScore) {
        rank += 1;
      }
    }
    return rank;
  }

  List<_ScoreBin> _buildScoreBins(List<NotionScoreEntry> entries) {
    final counts = List<int>.filled(_scoreLabels.length, 0);
    for (final entry in entries) {
      final index = _scoreToBinIndex(entry.yougnScore);
      counts[index] += 1;
    }
    return List.generate(
      _scoreLabels.length,
      (index) => _ScoreBin(label: _scoreLabels[index], count: counts[index]),
    );
  }

  int _scoreToBinIndex(double score) {
    if (score >= 10) return 0;
    final clamped = score.clamp(1, 9.999);
    final bucket = clamped.floor();
    return 10 - bucket;
  }

  String _scoreToBinLabel(double score) {
    return _scoreLabels[_scoreToBinIndex(score)];
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    final local = date.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _openNotionPage(String? url) async {
    final trimmed = url?.trim() ?? '';
    if (trimmed.isEmpty) return;
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
        actionLabel: '换一部',
        onAction: _loading ? null : _reshuffleRecommendations,
      );
    }

    if (_dailyCandidates.isEmpty || _heroIndices.isEmpty) {
      return _buildCenteredMessage(
        context,
        icon: Icons.inbox_outlined,
        title: '暂无推荐内容',
        actionLabel: '换一部',
        onAction: _loading ? null : _reshuffleRecommendations,
      );
    }

    return PageView.builder(
      controller: _pageController,
      itemCount: _heroIndices.length,
      onPageChanged: (index) {
        if (!mounted) return;
        setState(() {
          _currentHeroIndex = index;
          _showLongReview = false;
        });
        _resetRotationTimer();
        _saveDailyCache(
          candidates: _dailyCandidates,
          indices: _heroIndices,
          currentIndex: _currentHeroIndex,
        );
      },
      itemBuilder: (context, index) {
        final candidateIndex = _heroIndices[index];
        final recommendation = _dailyCandidates[candidateIndex];
        return _buildHeroPage(context, recommendation);
      },
    );
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

  Widget _buildHeroPage(
    BuildContext context,
    DailyRecommendation recommendation,
  ) {
    final showRatings = context.watch<AppSettings>().showRatings;
    final subjectId = _resolveSubjectId(recommendation);
    if (subjectId != null) {
      _scheduleBangumiDetailLoad(subjectId);
    }
    if ((recommendation.longReview?.trim().isEmpty ?? true) ||
        (recommendation.cover?.trim().isEmpty ?? true)) {
      _scheduleNotionContentLoad(recommendation.pageId);
    }

    final detail = subjectId != null ? _bangumiDetailCache[subjectId] : null;
    final notionContent = _resolveNotionContent(recommendation);
    final coverUrl = _resolveCoverUrl(recommendation, detail, notionContent);
    final tags = _resolveTags(recommendation, detail);
    final longReview = _resolveLongReview(recommendation, notionContent);

    final bangumiScore = detail != null && detail.score > 0
        ? detail.score
        : recommendation.bangumiScore;
    final yougnRank = _computeYougnRank(
      recommendation.yougnScore,
      bangumiScore,
    );
    final bangumiRank = detail?.rank;

    final animationProduction = _pickNotionOrBangumi(
      recommendation.animationProduction,
      detail?.animationProduction,
    );
    final director = _pickNotionOrBangumi(
      recommendation.director,
      detail?.director,
    );
    final script = _pickNotionOrBangumi(
      recommendation.script,
      detail?.script,
    );
    final storyboard = _pickNotionOrBangumi(
      recommendation.storyboard,
      detail?.storyboard,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1200;
        final isMedium = constraints.maxWidth >= 900;
        final isCompact = constraints.maxWidth < 720;

        final coverImage = _buildCoverImage(
          context,
          coverUrl: coverUrl,
          stretch: isMedium,
          onTap: recommendation.pageUrl?.isNotEmpty == true
              ? () => _openNotionPage(recommendation.pageUrl)
              : null,
        );
        final infoContent = _buildInfoContent(
          context,
          recommendation: recommendation,
          showRatings: showRatings,
          yougnRank: yougnRank,
          bangumiScore: bangumiScore,
          bangumiRank: bangumiRank,
          followDate: recommendation.followDate,
          airDate: recommendation.airDate,
          airEndDate: recommendation.airEndDate,
          animationProduction: animationProduction,
          director: director,
          script: script,
          storyboard: storyboard,
          tags: tags,
        );
        final leftPanel = _buildLeftPanel(
          context,
          cover: coverImage,
          info: infoContent,
          horizontal: isMedium,
        );
        final rightPanel = _buildRightPanel(
          context,
          recommendation: recommendation,
          showBoth: isWide,
          longReview: longReview,
        );

        final header = _buildHeader(context);
        final searchBar = _buildNotionSearchBar(context);
        final pageIndicator = _buildPageIndicator();

        Widget content;
        if (isMedium) {
          content = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 6, child: leftPanel),
              const SizedBox(width: 16),
              Expanded(flex: 5, child: rightPanel),
            ],
          );
        } else {
          content = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              leftPanel,
              const SizedBox(height: 16),
              rightPanel,
            ],
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              const SizedBox(height: 12),
              searchBar,
              if (pageIndicator != null) ...[
                const SizedBox(height: 12),
                pageIndicator,
              ],
              const SizedBox(height: 16),
              content,
              if (isCompact) const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Text(
          '今日推荐',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const Spacer(),
        FilledButton.icon(
          onPressed: _loading ? null : _reshuffleRecommendations,
          icon: const Icon(Icons.shuffle),
          label: const Text('换一下'),
        ),
      ],
    );
  }

  Widget? _buildPageIndicator() {
    if (_heroIndices.length <= 1) return null;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_heroIndices.length, (index) {
        final isActive = index == _currentHeroIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 18 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }

  Widget _buildNotionSearchBar(BuildContext context) {
    return _buildPanel(
      context,
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _notionSearchController,
              decoration: const InputDecoration(
                hintText: 'Notion 搜索',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _triggerNotionSearch(),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: _triggerNotionSearch,
            child: const Text('搜索'),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  void _triggerNotionSearch() {
    final keyword = _notionSearchController.text.trim();
    if (keyword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入关键词')),
      );
      return;
    }
    Navigator.of(context).pushNamed(
      '/search',
      arguments: {
        'source': 'notion',
        'keyword': keyword,
      },
    );
  }

  Widget _buildLeftPanel(
    BuildContext context, {
    required Widget cover,
    required Widget info,
    required bool horizontal,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final content = horizontal
        ? IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(flex: 4, child: cover),
                const SizedBox(width: 16),
                Expanded(
                  flex: 6,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: info,
                  ),
                ),
              ],
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              cover,
              Padding(
                padding: const EdgeInsets.all(16),
                child: info,
              ),
            ],
          );

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }

  Widget _buildCoverImage(
    BuildContext context, {
    required String coverUrl,
    bool stretch = false,
    VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final image = coverUrl.isEmpty
        ? Container(
            color: colorScheme.surfaceContainerHighest,
            child: const Center(
              child: Icon(Icons.image_outlined, size: 48),
            ),
          )
        : Image.network(
            coverUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              final expected = loadingProgress.expectedTotalBytes;
              final loaded = loadingProgress.cumulativeBytesLoaded;
              final progress =
                  expected != null && expected > 0 ? loaded / expected : null;
              return Center(
                child: CircularProgressIndicator(value: progress),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: colorScheme.surfaceContainerHighest,
                child: const Center(
                  child: Icon(Icons.broken_image_outlined, size: 48),
                ),
              );
            },
          );

    final child = stretch
        ? SizedBox.expand(child: image)
        : AspectRatio(aspectRatio: 3 / 4, child: image);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: child,
      ),
    );
  }

  Widget _buildInfoContent(
    BuildContext context, {
    required DailyRecommendation recommendation,
    required bool showRatings,
    required int? yougnRank,
    required double? bangumiScore,
    required int? bangumiRank,
    required DateTime? followDate,
    required DateTime? airDate,
    required DateTime? airEndDate,
    required String animationProduction,
    required String director,
    required String script,
    required String storyboard,
    required List<String> tags,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = recommendation.title;
    final shortReview = recommendation.shortReview?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        if (showRatings)
          _buildRatingLine(
            context,
            yougnScore: recommendation.yougnScore,
            yougnRank: yougnRank,
            bangumiScore: bangumiScore,
            bangumiRank: bangumiRank,
          ),
        if (showRatings) const SizedBox(height: 10),
        Text(
          '悠简评',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          shortReview.isEmpty ? '暂无简评' : shortReview,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: shortReview.isEmpty
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.onSurface,
              ),
        ),
        const SizedBox(height: 12),
        Text(
          _buildDateLine(
            followDate: followDate,
            airDate: airDate,
            airEndDate: airEndDate,
          ),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          _buildStaffLine(
            animationProduction: animationProduction,
            director: director,
            script: script,
            storyboard: storyboard,
          ),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: tags
                .map(
                  (tag) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      tag,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildRatingLine(
    BuildContext context, {
    required double? yougnScore,
    required int? yougnRank,
    required double? bangumiScore,
    required int? bangumiRank,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final yougnScoreText = yougnScore?.toStringAsFixed(1) ?? '-';
    final yougnRankText = yougnRank == null ? '-' : '#$yougnRank';
    final bangumiScoreText = bangumiScore?.toStringAsFixed(1) ?? '-';
    final bangumiRankText = bangumiRank == null ? '-' : '#$bangumiRank';

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '悠gn $yougnScoreText',
            style: TextStyle(
              color: colorScheme.tertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: ' | 排名 $yougnRankText',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          TextSpan(
            text: ' | Bangumi $bangumiScoreText',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          TextSpan(
            text: ' | 排名 $bangumiRankText',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  String _buildDateLine({
    required DateTime? followDate,
    required DateTime? airDate,
    required DateTime? airEndDate,
  }) {
    final followText = _formatDate(followDate);
    final airText = _formatDate(airDate);
    final endText = _formatDate(airEndDate);
    return '追番 $followText | 放送 $airText | 结束 $endText';
  }

  String _buildStaffLine({
    required String animationProduction,
    required String director,
    required String script,
    required String storyboard,
  }) {
    final parts = <String>[];
    if (animationProduction.isNotEmpty) {
      parts.add('动画制作 $animationProduction');
    }
    if (director.isNotEmpty) {
      parts.add('导演 $director');
    }
    if (script.isNotEmpty) {
      parts.add('脚本 $script');
    }
    if (storyboard.isNotEmpty) {
      parts.add('分镜 $storyboard');
    }
    if (parts.isEmpty) {
      return '动画制作/导演/脚本/分镜：-';
    }
    return parts.join(' | ');
  }

  Widget _buildRightPanel(
    BuildContext context, {
    required DailyRecommendation recommendation,
    required bool showBoth,
    required String longReview,
  }) {
    final hint = showBoth
        ? null
        : (_showLongReview ? '点击查看排名' : '点击查看长评');
    final rankCard = _buildRankCard(
      context,
      recommendation: recommendation,
      hint: hint,
    );
    final reviewCard = _buildLongReviewCard(
      context,
      recommendation: recommendation,
      longReview: longReview,
      hint: hint,
    );

    if (showBoth) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: rankCard),
          const SizedBox(width: 16),
          Expanded(child: reviewCard),
        ],
      );
    }

    return GestureDetector(
      onTap: () => setState(() => _showLongReview = !_showLongReview),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _showLongReview
            ? KeyedSubtree(
                key: const ValueKey('review'),
                child: reviewCard,
              )
            : KeyedSubtree(
                key: const ValueKey('rank'),
                child: rankCard,
              ),
      ),
    );
  }

  Widget _buildRankCard(
    BuildContext context, {
    required DailyRecommendation recommendation,
    String? hint,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final yougnScore = recommendation.yougnScore;
    final yougnScoreText = yougnScore?.toStringAsFixed(1) ?? '-';
    final currentLabel =
        yougnScore != null ? _scoreToBinLabel(yougnScore) : '-';
    final total = _scoreTotal;
    final maxCount = _scoreBins.fold<int>(
      0,
      (current, bin) => bin.count > current ? bin.count : current,
    );

    Widget body;
    if (_statsLoading) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_scoreBins.isEmpty || total == 0) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          '暂无评分分布数据',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
      );
    } else {
      body = Column(
        children: _scoreBins.map((bin) {
          final isActive = bin.label == currentLabel;
          return _buildScoreRow(
            context,
            bin: bin,
            total: total,
            maxCount: maxCount,
            highlight: isActive,
          );
        }).toList(),
      );
    }

    return _buildPanel(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPanelHeader(
            context,
            title: '排名分布',
            hint: hint,
          ),
          const SizedBox(height: 8),
          Text(
            '当前评分 $yougnScoreText | 当前分区 $currentLabel | 共 $total 部',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          body,
        ],
      ),
    );
  }

  Widget _buildScoreRow(
    BuildContext context, {
    required _ScoreBin bin,
    required int total,
    required int maxCount,
    required bool highlight,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final ratio = maxCount == 0 ? 0.0 : bin.count / maxCount;
    final percent = total == 0 ? 0.0 : (bin.count / total) * 100;
    final barColor = highlight ? colorScheme.primary : colorScheme.tertiary;
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color:
              highlight ? colorScheme.primary : colorScheme.onSurfaceVariant,
          fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              bin.label,
              style: labelStyle,
            ),
          ),
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: ratio == 0 ? 0 : ratio.clamp(0.05, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 84,
            child: Text(
              total == 0 ? '-' : '${percent.toStringAsFixed(1)}% / ${bin.count}',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: highlight
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLongReviewCard(
    BuildContext context, {
    required DailyRecommendation recommendation,
    required String longReview,
    String? hint,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final pageId = recommendation.pageId?.trim() ?? '';
    final isLoading =
        pageId.isNotEmpty && _notionContentLoading.contains(pageId);
    final trimmed = longReview.trim();
    final displayText = trimmed.isNotEmpty
        ? trimmed
        : (isLoading ? '长评加载中...' : '暂无长评');
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: trimmed.isNotEmpty
              ? colorScheme.onSurface
              : colorScheme.onSurfaceVariant,
          height: 1.6,
        );

    return _buildPanel(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPanelHeader(
            context,
            title: '长评',
            hint: hint,
          ),
          const SizedBox(height: 8),
          Text(
            displayText,
            style: textStyle,
          ),
        ],
      ),
    );
  }

  Widget _buildPanelHeader(
    BuildContext context, {
    required String title,
    String? hint,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const Spacer(),
        if (hint != null)
          Text(
            hint,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                ),
          ),
      ],
    );
  }

  Widget _buildPanel(
    BuildContext context,
    Widget child, {
    EdgeInsets? padding,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: child,
    );
  }
}
