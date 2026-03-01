import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_services.dart';
import '../../app/app_settings.dart';
import '../network/notion_api.dart';
import '../../models/notion_models.dart';
import '../../features/detail/presentation/detail_page.dart';
import '../database/settings_storage.dart';

class SidebarRecommendationCard extends StatefulWidget {
  const SidebarRecommendationCard({
    super.key,
    required this.extended,
    required this.compact,
  });

  final bool extended;
  final bool compact;

  @override
  State<SidebarRecommendationCard> createState() =>
      _SidebarRecommendationCardState();
}

class _SidebarRecommendationCardState extends State<SidebarRecommendationCard> {
  final SettingsStorage _storage = SettingsStorage();
  Future<_SidebarRecommendation?>? _future;

  @override
  void initState() {
    super.initState();
    _future = _loadRecommendation();
  }

  @override
  void didUpdateWidget(covariant SidebarRecommendationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.extended != widget.extended ||
        oldWidget.compact != widget.compact) {
      _future = _loadRecommendation();
    }
  }

  String _todayKey() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<_SidebarRecommendation?> _loadRecommendation() async {
    final cacheDate = await _storage.getDailyRecommendationCacheDate();
    final payload = await _storage.getDailyRecommendationCachePayload();
    if (cacheDate == null ||
        payload == null ||
        payload.isEmpty ||
        cacheDate != _todayKey()) {
      return null;
    }

    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        if (decoded['candidates'] is List) {
          final rawList = decoded['candidates'] as List;
          final candidates = rawList
              .whereType<Map<String, dynamic>>()
              .map(DailyRecommendation.fromJson)
              .toList();
          if (candidates.isEmpty) {
            return null;
          }
          final indices = (decoded['indices'] as List?)
                  ?.map((e) => int.tryParse(e.toString()) ?? 0)
                  .where((e) => e >= 0 && e < candidates.length)
                  .toList() ??
              <int>[];
          final currentIndex =
              int.tryParse(decoded['currentIndex']?.toString() ?? '') ?? 0;
          final resolvedIndex =
              indices.isNotEmpty ? indices[currentIndex % indices.length] : 0;
          final recommendation =
              _SidebarRecommendation.from(candidates[resolvedIndex]);
          return _resolveSidebarCover(recommendation);
        }
        final recommendation = DailyRecommendation.fromJson(decoded);
        return _resolveSidebarCover(
            _SidebarRecommendation.from(recommendation));
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<_SidebarRecommendation> _resolveSidebarCover(
    _SidebarRecommendation recommendation,
  ) async {
    final directCover = recommendation.coverUrl?.trim() ?? '';
    if (directCover.isNotEmpty) return recommendation;

    final pageId = recommendation.pageId?.trim() ?? '';
    if (pageId.isEmpty) return recommendation;

    final token = context.read<AppSettings>().notionToken.trim();
    if (token.isEmpty) return recommendation;

    try {
      final notionApi = context.read<AppServices>().notionApi;
      final content = await notionApi.getPageContent(
        token: token,
        pageId: pageId,
      );
      final contentCover = content.coverUrl?.trim() ?? '';
      if (contentCover.isEmpty) return recommendation;
      return recommendation.copyWith(coverUrl: contentCover);
    } catch (_) {
      return recommendation;
    }
  }

  void _openDetail(int subjectId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetailPage(subjectId: subjectId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final isConfigured =
        settings.notionToken.isNotEmpty && settings.notionDatabaseId.isNotEmpty;

    return FutureBuilder<_SidebarRecommendation?>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (!isConfigured) {
          return _buildPlaceholder(context, '绑定 Notion 后显示');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildPlaceholder(context, '加载推荐...');
        }
        if (data == null) {
          return _buildPlaceholder(context, '暂无推荐');
        }
        return widget.compact
            ? _buildCompactCard(context, data)
            : _buildExtendedCard(context, data);
      },
    );
  }

  Widget _buildPlaceholder(BuildContext context, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: colorScheme.onSurfaceVariant),
      ),
    );
  }

  Widget _buildCompactCard(
    BuildContext context,
    _SidebarRecommendation data,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: data.subjectId == null ? null : () => _openDetail(data.subjectId!),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          children: [
            Text(
              '今日推荐',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Expanded(
              child: RotatedBox(
                quarterTurns: 3,
                child: Text(
                  data.title,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),
            if (data.yougnScoreText != null) ...[
              const SizedBox(height: 6),
              Text(
                '悠gn ${data.yougnScoreText}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.tertiary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExtendedCard(
    BuildContext context,
    _SidebarRecommendation data,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (data.coverUrl != null && data.coverUrl!.isNotEmpty)
            SizedBox(
              height: 110,
              child: InkWell(
                onTap: data.subjectId == null
                    ? null
                    : () => _openDetail(data.subjectId!),
                child: Image.network(
                  data.coverUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.image_outlined),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '今日推荐',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  data.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (data.yougnScoreText != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '悠gn ${data.yougnScoreText}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: colorScheme.tertiary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarRecommendation {
  final String title;
  final String? coverUrl;
  final String? yougnScoreText;
  final int? subjectId;
  final String? pageId;

  const _SidebarRecommendation({
    required this.title,
    required this.coverUrl,
    required this.yougnScoreText,
    required this.subjectId,
    required this.pageId,
  });

  factory _SidebarRecommendation.from(DailyRecommendation recommendation) {
    final rawId = recommendation.subjectId?.trim().isNotEmpty == true
        ? recommendation.subjectId
        : recommendation.bangumiId;
    final subjectId = rawId == null ? null : int.tryParse(rawId.trim());
    final directCover = recommendation.cover?.trim() ?? '';
    final contentCover = recommendation.contentCoverUrl?.trim() ?? '';
    final resolvedCover = directCover.isNotEmpty
        ? directCover
        : (contentCover.isNotEmpty ? contentCover : null);
    final rawPageId = recommendation.pageId?.trim() ?? '';
    return _SidebarRecommendation(
      title: recommendation.title,
      coverUrl: resolvedCover,
      yougnScoreText: recommendation.yougnScore?.toStringAsFixed(1),
      subjectId: subjectId,
      pageId: rawPageId.isEmpty ? null : rawPageId,
    );
  }

  _SidebarRecommendation copyWith({
    String? title,
    String? coverUrl,
    String? yougnScoreText,
    int? subjectId,
    String? pageId,
  }) {
    return _SidebarRecommendation(
      title: title ?? this.title,
      coverUrl: coverUrl ?? this.coverUrl,
      yougnScoreText: yougnScoreText ?? this.yougnScoreText,
      subjectId: subjectId ?? this.subjectId,
      pageId: pageId ?? this.pageId,
    );
  }
}
