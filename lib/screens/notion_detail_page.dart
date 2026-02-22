import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_services.dart';
import '../app/app_settings.dart';
import '../models/notion_models.dart';
import '../services/notion_api.dart';

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

  DailyRecommendation? get _recommendation => widget.recommendation;

  @override
  void initState() {
    super.initState();
    _contentCoverUrl = widget.recommendation?.contentCoverUrl;
    _contentLongReview = widget.recommendation?.contentLongReview;
    _loadNotionContentIfNeeded();
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
      final content = await context.read<AppServices>().notionApi.getPageContent(
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
                                SizedBox(
                                  width: 320,
                                  child: _buildLeftPanel(context),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: _buildRightPanel(context),
                                ),
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
    final recommendation = _recommendation;
    final coverUrl =
        recommendation == null ? '' : _resolveCoverUrl(recommendation);
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
            onPressed: () => Navigator.maybePop(context),
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
            onPressed: _loadingContent ? null : _loadNotionContentIfNeeded,
            icon: const Icon(Icons.sync_rounded, size: 18),
            label: const Text('同步数据'),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_horiz_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final title = _resolveTitle();
    final coverUrl = _resolveCoverUrl(_recommendation!);
    final tags = _resolveTags();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CoverCard(
          imageUrl: coverUrl,
          width: 130,
          height: 190,
        ),
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
    final recommendation = _recommendation!;
    final yougnScore = recommendation.yougnScore;
    final bangumiScore = widget.bangumiScore ?? recommendation.bangumiScore;
    final type = recommendation.type?.trim() ?? '';
    final followDate = _formatDate(recommendation.followDate);
    final airDate = _formatDateRange(
      start: recommendation.airDate,
      end: recommendation.airEndDate,
    );
    final animationProduction =
        recommendation.animationProduction?.trim() ?? '';
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
                '用户评分 (Bangumi评分)',
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
                  Text(
                    '/10',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
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
              Text(
                '档期 / 类型',
                style: Theme.of(context).textTheme.labelLarge,
              ),
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
              _infoRow(
                context,
                '制作',
                animationProduction.isEmpty ? '-' : animationProduction,
              ),
              _infoRow(context, '导演', director.isEmpty ? '-' : director),
              _infoRow(context, '脚本', script.isEmpty ? '-' : script),
              _infoRow(context, '分镜', storyboard.isEmpty ? '-' : storyboard),
              if (bangumiId.isNotEmpty)
                _infoRow(context, 'Bangumi ID', bangumiId),
              if (subjectId.isNotEmpty && subjectId != bangumiId)
                _infoRow(context, 'Subject ID', subjectId),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRightPanel(BuildContext context) {
    final recommendation = _recommendation!;
    final shortReview = recommendation.shortReview?.trim() ?? '';
    final longReview = _resolveLongReview(recommendation);
    final showShortReview = shortReview.isNotEmpty;
    final showLongReview = longReview.trim().isNotEmpty;
    final shortReviewText = showShortReview ? shortReview : '暂无短评';
    final longReviewText =
        showLongReview ? longReview : (_loadingContent ? '正文加载中...' : '暂无长评');
    final type = recommendation.type?.trim() ?? '';
    final animationProduction =
        recommendation.animationProduction?.trim() ?? '';
    final director = recommendation.director?.trim() ?? '';
    final editorNote = _buildEditorNote(
      type: type,
      animationProduction: animationProduction,
      director: director,
    );
    final pageHint = _buildPageHint(recommendation.pageId);
    final coverUrl = _resolveCoverUrl(recommendation);
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
              _sectionTitle(context, '正文 / 长评 (Body / Long Review - Rich Text)'),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 720;
                  final outline = _buildOutlineList(context);
                  final editor = _buildEditorPanel(
                    context,
                    longReviewText: longReviewText,
                    showLongReview: showLongReview,
                    editorNote: editorNote,
                    coverUrl: coverUrl,
                    pageHint: pageHint,
                  );
                  if (isCompact) {
                    return Column(
                      children: [
                        outline,
                        const SizedBox(height: 16),
                        editor,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 180, child: outline),
                      const SizedBox(width: 16),
                      Expanded(child: editor),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            FilledButton.icon(
              onPressed: pageUrl.isEmpty ? null : () => _openUrl(pageUrl),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('打开 Notion 页面'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: bangumiUrl.isEmpty ? null : () => _openUrl(bangumiUrl),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('查看 Bangumi 原网页'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOutlineList(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final items = [
      '#### 观察笔记',
      '#### 人物变化',
      '#### 主题动机',
      '#### 画面叙事',
      '#### 长评',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        final isActive = item.contains('观察笔记');
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isActive
                ? colorScheme.primary.withValues(alpha: 0.18)
                : colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            item,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isActive
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEditorPanel(
    BuildContext context, {
    required String longReviewText,
    required bool showLongReview,
    required String editorNote,
    required String coverUrl,
    required String pageHint,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _EditorIcon(icon: Icons.format_bold_rounded),
              _EditorIcon(icon: Icons.format_italic_rounded),
              _EditorIcon(icon: Icons.format_underlined_rounded),
              _EditorIcon(icon: Icons.format_list_bulleted_rounded),
              _EditorIcon(icon: Icons.format_list_numbered_rounded),
              _EditorIcon(icon: Icons.link_rounded),
              _EditorIcon(icon: Icons.image_rounded),
              _EditorIcon(icon: Icons.table_chart_rounded),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: colorScheme.outlineVariant),
          const SizedBox(height: 12),
          Text(
            '#### 观察笔记',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            longReviewText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: showLongReview
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
                ),
          ),
          if (editorNote.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              editorNote,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
          if (coverUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                coverUrl,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 160,
                  color: colorScheme.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.image_not_supported_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
          if (pageHint.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              pageHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
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
          Expanded(
            child: Text(
              value,
              style: textTheme.bodySmall,
            ),
          ),
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
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }

  String _resolveTitle() {
    final title = _recommendation?.title.trim() ?? '';
    return title.isEmpty ? '未命名条目' : title;
  }

  String _resolveCoverUrl(DailyRecommendation recommendation) {
    final override = widget.coverUrl?.trim() ?? '';
    if (override.isNotEmpty) return override;
    final cover = recommendation.cover?.trim() ?? '';
    if (cover.isNotEmpty) return cover;
    final cached = recommendation.contentCoverUrl?.trim() ?? '';
    if (cached.isNotEmpty) return cached;
    final loaded = _contentCoverUrl?.trim() ?? '';
    return loaded;
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

  List<String> _resolveTags() {
    final tags = widget.tags ?? _recommendation?.tags ?? const <String>[];
    return tags.where((tag) => tag.trim().isNotEmpty).toList();
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

  String _buildEditorNote({
    required String type,
    required String animationProduction,
    required String director,
  }) {
    final parts = <String>[];
    if (type.isNotEmpty) parts.add('类型：$type');
    if (animationProduction.isNotEmpty) {
      parts.add('制作：$animationProduction');
    }
    if (director.isNotEmpty) parts.add('导演：$director');
    return parts.join(' · ');
  }

  String _buildPageHint(String? pageId) {
    final id = pageId?.trim() ?? '';
    if (id.isEmpty) return '';
    final shortId = id.length > 8 ? id.substring(0, 8) : id;
    return 'Notion 页面 ID：$shortId';
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
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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

class _EditorIcon extends StatelessWidget {
  const _EditorIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
    );
  }
}
