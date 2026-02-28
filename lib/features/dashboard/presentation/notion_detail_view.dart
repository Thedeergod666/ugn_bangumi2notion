import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../models/notion_models.dart';

class NotionDetailViewState {
  const NotionDetailViewState({
    required this.recommendation,
    required this.coverUrl,
    required this.longReview,
    required this.tags,
    required this.bangumiScore,
    required this.loadingContent,
  });

  final DailyRecommendation recommendation;
  final String coverUrl;
  final String longReview;
  final List<String> tags;
  final double? bangumiScore;
  final bool loadingContent;
}

class NotionDetailViewCallbacks {
  const NotionDetailViewCallbacks({
    required this.onBack,
    required this.onSyncContent,
    required this.onOpenNotionPage,
    required this.onOpenBangumiPage,
  });

  final VoidCallback onBack;
  final VoidCallback onSyncContent;
  final VoidCallback onOpenNotionPage;
  final VoidCallback onOpenBangumiPage;
}

class NotionDetailView extends StatelessWidget {
  const NotionDetailView({
    super.key,
    required this.state,
    required this.callbacks,
  });

  final NotionDetailViewState state;
  final NotionDetailViewCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _buildBackground(colorScheme)),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(context),
                        const SizedBox(height: 20),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 980;
                            if (isNarrow) {
                              return Column(
                                children: [
                                  _buildLeftPanel(context),
                                  const SizedBox(height: 20),
                                  _buildRightPanel(context),
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(width: 320, child: _buildLeftPanel(context)),
                                const SizedBox(width: 20),
                                Expanded(child: _buildRightPanel(context)),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground(ColorScheme colorScheme) {
    final coverUrl = state.coverUrl.trim();
    return Stack(
      children: [
        if (coverUrl.isNotEmpty)
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Image.network(
              coverUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: colorScheme.surfaceContainerHighest,
              ),
            ),
          )
        else
          Container(color: colorScheme.surfaceContainerHighest),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.35),
                colorScheme.surface.withValues(alpha: 0.9),
                colorScheme.surface,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = _resolveTitle();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: callbacks.onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            color: colorScheme.onSurface,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: state.loadingContent ? null : callbacks.onSyncContent,
            icon: const Icon(Icons.sync_rounded, size: 18),
            label: const Text('同步数据'),
          ),
          const SizedBox(width: 8),
          const IconButton(
            onPressed: null,
            icon: Icon(Icons.more_horiz_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final title = _resolveTitle();
    final coverUrl = state.coverUrl;
    final tags = state.tags.where((t) => t.trim().isNotEmpty).toList();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CoverCard(imageUrl: coverUrl, width: 130, height: 190),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (tags.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: tags.map((tag) => _tagChip(context, tag)).toList(),
                ),
              const SizedBox(height: 12),
              Text(
                'Notion 页面 · 详情聚合 · 自动同步',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeftPanel(BuildContext context) {
    final recommendation = state.recommendation;
    final yougnScore = recommendation.yougnScore;
    final bangumiScore = state.bangumiScore ?? recommendation.bangumiScore;
    final type = recommendation.type?.trim() ?? '';
    final followDate = _formatDate(recommendation.followDate);
    final airDate = _formatDateRange(
      start: recommendation.airDate,
      end: recommendation.airEndDate,
    );
    final animationProduction = recommendation.animationProduction?.trim() ?? '';
    final director = recommendation.director?.trim() ?? '';
    final script = recommendation.script?.trim() ?? '';
    final storyboard = recommendation.storyboard?.trim() ?? '';
    final bangumiId = recommendation.bangumiId?.trim() ?? '';
    final subjectId = recommendation.subjectId?.trim() ?? '';

    return Column(
      children: [
        _glassCard(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '用户评分 (Bangumi 参考分)',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    yougnScore?.toStringAsFixed(1) ?? '-',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(width: 6),
                  Text('/10', style: Theme.of(context).textTheme.titleSmall),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Bangumi 参考分：${bangumiScore?.toStringAsFixed(1) ?? '-'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _glassCard(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('档期 / 类型', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 12),
              _infoRow(context, '类型', type.isEmpty ? '-' : type),
              _infoRow(context, '追番', followDate),
              _infoRow(context, '放送', airDate),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _glassCard(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('制作信息', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 12),
              _infoRow(context, '制作', animationProduction.isEmpty ? '-' : animationProduction),
              _infoRow(context, '导演', director.isEmpty ? '-' : director),
              _infoRow(context, '脚本', script.isEmpty ? '-' : script),
              _infoRow(context, '分镜', storyboard.isEmpty ? '-' : storyboard),
              if (bangumiId.isNotEmpty) _infoRow(context, 'Bangumi ID', bangumiId),
              if (subjectId.isNotEmpty && subjectId != bangumiId) _infoRow(context, 'Subject ID', subjectId),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRightPanel(BuildContext context) {
    final recommendation = state.recommendation;
    final shortReview = recommendation.shortReview?.trim() ?? '';
    final longReview = state.longReview.trim();
    final showShortReview = shortReview.isNotEmpty;
    final showLongReview = longReview.isNotEmpty;

    final shortReviewText = showShortReview ? shortReview : '暂无短评';
    final longReviewText = showLongReview
        ? longReview
        : (state.loadingContent ? '正文加载中...' : '暂无长评');

    final pageUrl = recommendation.pageUrl?.trim() ?? '';
    final bangumiUrl = _buildBangumiUrl(recommendation);

    return Column(
      children: [
        _glassCard(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(context, '短评 (Short Review)'),
              const SizedBox(height: 10),
              Text(
                shortReviewText,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: showShortReview
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _glassCard(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(context, '正文 / 长评 (Body / Long Review)'),
              const SizedBox(height: 12),
              Text(
                longReviewText,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: showLongReview
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.6,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            FilledButton.icon(
              onPressed: pageUrl.isEmpty ? null : callbacks.onOpenNotionPage,
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('打开 Notion 页面'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: bangumiUrl.isEmpty ? null : callbacks.onOpenBangumiPage,
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('查看 Bangumi 原网页'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _glassCard(BuildContext context, {required Widget child}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              '$label：',
              style: textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: textTheme.bodySmall)),
        ],
      ),
    );
  }

  Widget _tagChip(BuildContext context, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall),
    );
  }

  String _resolveTitle() {
    final title = state.recommendation.title.trim();
    return title.isEmpty ? '未命名条目' : title;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    final local = date.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatDateRange({
    required DateTime? start,
    required DateTime? end,
  }) {
    final startText = _formatDate(start);
    final endText = _formatDate(end);
    if (start == null && end == null) return '-';
    if (end == null || endText == '-') return startText;
    if (startText == endText) return startText;
    return '$startText ~ $endText';
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
}

class _CoverCard extends StatelessWidget {
  const _CoverCard({
    required this.imageUrl,
    required this.width,
    required this.height,
  });

  final String imageUrl;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: imageUrl.isEmpty
            ? Icon(
                Icons.image_not_supported_rounded,
                color: colorScheme.onSurfaceVariant,
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.image_not_supported_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
      ),
    );
  }
}
