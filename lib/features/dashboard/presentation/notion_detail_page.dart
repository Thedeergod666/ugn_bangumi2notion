import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_services.dart';
import '../../../app/app_settings.dart';
import '../../../core/network/notion_api.dart';
import '../../../models/notion_models.dart';
import 'notion_detail_view.dart';

class NotionDetailPage extends StatefulWidget {
  const NotionDetailPage({
    super.key,
    this.recommendation,
    this.coverUrl,
    this.longReview,
    this.tags,
    this.bangumiScore,
  });

  final DailyRecommendation? recommendation;
  final String? coverUrl;
  final String? longReview;
  final List<String>? tags;
  final double? bangumiScore;

  @override
  State<NotionDetailPage> createState() => _NotionDetailPageState();
}

class _NotionDetailPageState extends State<NotionDetailPage> {
  String? _contentCoverUrl;
  String? _contentLongReview;
  bool _loadingContent = false;
  String? _bangumiCoverUrl;
  bool _loadingBangumiCover = false;

  DailyRecommendation? get _recommendation => widget.recommendation;

  @override
  void initState() {
    super.initState();
    _contentCoverUrl = widget.recommendation?.contentCoverUrl;
    _contentLongReview = widget.recommendation?.contentLongReview;
    unawaited(_loadNotionContentIfNeeded());
    unawaited(_loadBangumiCoverIfNeeded());
  }

  Future<void> _loadNotionContentIfNeeded() async {
    final recommendation = _recommendation;
    if (recommendation == null) return;
    final pageId = recommendation.pageId?.trim() ?? '';
    if (pageId.isEmpty) return;

    final needCover = _resolveCoverUrl(recommendation).isEmpty;
    final needReview = _resolveLongReview(recommendation).isEmpty;
    if (!needCover && !needReview) return;

    final token = context.read<AppSettings>().notionToken.trim();
    if (token.isEmpty) return;

    setState(() => _loadingContent = true);
    try {
      final content =
          await context.read<AppServices>().notionApi.getPageContent(
                token: token,
                pageId: pageId,
              );
      if (!mounted) return;
      setState(() {
        _contentCoverUrl = content.coverUrl ?? _contentCoverUrl;
        _contentLongReview = content.longReview ?? _contentLongReview;
      });
    } catch (_) {
      // ignore content errors
    } finally {
      if (mounted) {
        setState(() => _loadingContent = false);
      }
    }

    // If cover is still missing, try Bangumi as a fallback.
    await _loadBangumiCoverIfNeeded();
  }

  int? _resolveSubjectId(DailyRecommendation recommendation) {
    final raw = (recommendation.subjectId?.trim().isNotEmpty == true)
        ? recommendation.subjectId
        : recommendation.bangumiId;
    if (raw == null || raw.trim().isEmpty) return null;
    return int.tryParse(raw.trim());
  }

  Future<void> _loadBangumiCoverIfNeeded() async {
    final recommendation = _recommendation;
    if (recommendation == null) return;
    if (_loadingBangumiCover) return;

    final needCover = _resolveCoverUrl(recommendation).isEmpty;
    if (!needCover) return;

    final subjectId = _resolveSubjectId(recommendation);
    if (subjectId == null) return;
    if ((_bangumiCoverUrl?.trim() ?? '').isNotEmpty) return;

    setState(() => _loadingBangumiCover = true);
    try {
      final token = context.read<AppSettings>().bangumiAccessToken.trim();
      final detail = await context.read<AppServices>().bangumiApi.fetchDetail(
            subjectId: subjectId,
            accessToken: token.isEmpty ? null : token,
          );
      if (!mounted) return;
      final cover = detail.imageUrl.trim();
      if (cover.isEmpty) return;
      setState(() => _bangumiCoverUrl = cover);
    } catch (_) {
      // ignore Bangumi fallback failures
    } finally {
      if (mounted) {
        setState(() => _loadingBangumiCover = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recommendation = _recommendation;
    if (recommendation == null) {
      return Scaffold(
        body: Center(
          child: Text(
            '暂无 Notion 数据',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      );
    }

    final coverUrl = _resolveCoverUrl(recommendation);
    final longReview = _resolveLongReview(recommendation);
    final tags = (widget.tags ?? recommendation.tags)
        .where((tag) => tag.trim().isNotEmpty)
        .toList();

    return NotionDetailView(
      state: NotionDetailViewState(
        recommendation: recommendation,
        coverUrl: coverUrl,
        longReview: longReview,
        tags: tags,
        bangumiScore: widget.bangumiScore ?? recommendation.bangumiScore,
        loadingContent: _loadingContent,
      ),
      callbacks: NotionDetailViewCallbacks(
        onBack: () => Navigator.maybePop(context),
        onSyncContent: () => unawaited(_loadNotionContentIfNeeded()),
        onOpenNotionPage: () =>
            unawaited(_openUrl(recommendation.pageUrl ?? '')),
        onOpenBangumiPage: () =>
            unawaited(_openUrl(_buildBangumiUrl(recommendation))),
      ),
    );
  }

  String _resolveCoverUrl(DailyRecommendation recommendation) {
    final override = widget.coverUrl?.trim() ?? '';
    if (override.isNotEmpty) return override;
    final cover = recommendation.cover?.trim() ?? '';
    if (cover.isNotEmpty) return cover;
    final cached = recommendation.contentCoverUrl?.trim() ?? '';
    if (cached.isNotEmpty) return cached;
    final loaded = _contentCoverUrl?.trim() ?? '';
    if (loaded.isNotEmpty) return loaded;
    return _bangumiCoverUrl?.trim() ?? '';
  }

  String _resolveLongReview(DailyRecommendation recommendation) {
    final override = widget.longReview?.trim() ?? '';
    if (override.isNotEmpty) return override;
    final direct = recommendation.longReview?.trim() ?? '';
    if (direct.isNotEmpty) return direct;
    final cached = recommendation.contentLongReview?.trim() ?? '';
    if (cached.isNotEmpty) return cached;
    final loaded = _contentLongReview?.trim() ?? '';
    return loaded;
  }

  String _buildBangumiUrl(DailyRecommendation recommendation) {
    final subjectId = recommendation.subjectId?.trim();
    final bangumiId = recommendation.bangumiId?.trim();
    final id = (subjectId != null && subjectId.isNotEmpty)
        ? subjectId
        : (bangumiId ?? '');
    if (id.isEmpty) return '';
    return 'https://bgm.tv/subject/$id';
  }

  Future<void> _openUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
