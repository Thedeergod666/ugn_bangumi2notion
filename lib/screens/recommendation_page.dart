import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_services.dart';
import '../app/app_settings.dart';
import '../models/notion_models.dart';
import '../view_models/recommendation_view_model.dart';
import '../widgets/error_detail_dialog.dart';
import '../widgets/navigation_shell.dart';

class RecommendationPage extends StatefulWidget {
  const RecommendationPage({super.key});

  @override
  State<RecommendationPage> createState() => _RecommendationPageState();
}

class _RecommendationPageState extends State<RecommendationPage> {
  late final RecommendationViewModel _viewModel;
  late final PageController _pageController;
  late final TextEditingController _notionSearchController;
  int _lastHeroIndex = 0;

  @override
  void initState() {
    super.initState();
    final services = context.read<AppServices>();
    _viewModel = RecommendationViewModel(
      notionApi: services.notionApi,
      bangumiApi: services.bangumiApi,
    );
    _pageController = PageController();
    _notionSearchController = TextEditingController();
    _viewModel.addListener(_handleModelUpdate);
    _viewModel.load(context.read<AppSettings>());
  }

  @override
  void dispose() {
    _viewModel.removeListener(_handleModelUpdate);
    _viewModel.dispose();
    _pageController.dispose();
    _notionSearchController.dispose();
    super.dispose();
  }

  void _handleModelUpdate() {
    if (!mounted) return;
    final jumpIndex = _viewModel.takePendingJumpIndex();
    if (jumpIndex != null) {
      _lastHeroIndex = jumpIndex;
      _jumpToIndex(jumpIndex);
      return;
    }
    final index = _viewModel.currentHeroIndex;
    if (_pageController.hasClients && index != _lastHeroIndex) {
      _lastHeroIndex = index;
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _jumpToIndex(int index) {
    if (_pageController.hasClients) {
      _pageController.jumpToPage(index);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      _pageController.jumpToPage(index);
    });
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
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<RecommendationViewModel>(
        builder: (context, model, _) {
          return NavigationShell(
            title: '每日推荐',
            selectedRoute: '/recommendation',
            child: _buildBody(context, model),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, RecommendationViewModel model) {
    if (model.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (model.configurationMessage != null) {
      final route = model.configurationRoute;
      return _buildCenteredMessage(
        context,
        icon: Icons.settings_suggest,
        title: model.configurationMessage!,
        actionLabel: route == '/mapping' ? '去映射配置' : '去设置',
        onAction: route == null
            ? null
            : () => Navigator.pushReplacementNamed(context, route),
      );
    }

    if (model.errorMessage != null) {
      return _buildCenteredMessage(
        context,
        icon: Icons.error_outline,
        title: model.errorMessage!,
        actionLabel: '重试',
        onAction: model.isLoading
            ? null
            : () => model.load(context.read<AppSettings>()),
        secondaryLabel: '查看详情',
        onSecondaryAction: (model.error != null && model.stackTrace != null)
            ? () => showDialog(
                  context: context,
                  builder: (context) => ErrorDetailDialog(
                    error: model.error!,
                    stackTrace: model.stackTrace!,
                  ),
                )
            : null,
      );
    }

    if (model.emptyMessage != null) {
      return _buildCenteredMessage(
        context,
        icon: Icons.inbox_outlined,
        title: model.emptyMessage!,
        actionLabel: '换一部',
        onAction: model.isLoading ? null : () => model.reshuffle(),
      );
    }

    if (model.dailyCandidates.isEmpty || model.heroIndices.isEmpty) {
      return _buildCenteredMessage(
        context,
        icon: Icons.inbox_outlined,
        title: '暂无推荐内容',
        actionLabel: '换一部',
        onAction: model.isLoading ? null : () => model.reshuffle(),
      );
    }

    return PageView.builder(
      controller: _pageController,
      itemCount: model.heroIndices.length,
      onPageChanged: (index) {
        _lastHeroIndex = index;
        model.updateHeroIndex(index);
      },
      itemBuilder: (context, index) {
        final recommendation = model.recommendationForHero(index);
        if (recommendation == null) {
          return const SizedBox.shrink();
        }
        return _buildHeroPage(context, model, recommendation);
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
    RecommendationViewModel model,
    DailyRecommendation recommendation,
  ) {
    final showRatings = context.watch<AppSettings>().showRatings;
    final subjectId = model.resolveSubjectId(recommendation);
    if (subjectId != null) {
      model.scheduleBangumiDetailLoad(subjectId);
    }
    if ((recommendation.longReview?.trim().isEmpty ?? true) ||
        (recommendation.cover?.trim().isEmpty ?? true)) {
      model.scheduleNotionContentLoad(recommendation.pageId);
    }

    final detail = model.detailFor(recommendation);
    final notionContent = model.notionContentFor(recommendation);
    final coverUrl = model.resolveCoverUrl(
      recommendation,
      detail,
      notionContent,
    );
    final tags = model.resolveTags(recommendation, detail);
    final longReview = model.resolveLongReview(recommendation, notionContent);

    final bangumiScore = detail != null && detail.score > 0
        ? detail.score
        : recommendation.bangumiScore;
    final yougnRank = model.computeYougnRank(
      recommendation.yougnScore,
      bangumiScore,
    );
    final bangumiRank = detail?.rank;

    final animationProduction = model.pickNotionOrBangumi(
      recommendation.animationProduction,
      detail?.animationProduction,
    );
    final director = model.pickNotionOrBangumi(
      recommendation.director,
      detail?.director,
    );
    final script = model.pickNotionOrBangumi(
      recommendation.script,
      detail?.script,
    );
    final storyboard = model.pickNotionOrBangumi(
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
          model,
          recommendation: recommendation,
          showBoth: isWide,
          longReview: longReview,
        );

        final header = _buildHeader(context, model);
        final searchBar = _buildNotionSearchBar(context);
        final pageIndicator = _buildPageIndicator(model);

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

  Widget _buildHeader(BuildContext context, RecommendationViewModel model) {
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
          onPressed: model.isLoading ? null : () => model.reshuffle(),
          icon: const Icon(Icons.shuffle),
          label: const Text('换一下'),
        ),
      ],
    );
  }

  Widget? _buildPageIndicator(RecommendationViewModel model) {
    if (model.heroIndices.length <= 1) return null;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(model.heroIndices.length, (index) {
        final isActive = index == model.currentHeroIndex;
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
    BuildContext context,
    RecommendationViewModel model, {
    required DailyRecommendation recommendation,
    required bool showBoth,
    required String longReview,
  }) {
    final hint = showBoth
        ? null
        : (model.showLongReview ? '点击查看排名' : '点击查看长评');
    final rankCard = _buildRankCard(
      context,
      model,
      recommendation: recommendation,
      hint: hint,
    );
    final reviewCard = _buildLongReviewCard(
      context,
      model,
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
      onTap: model.toggleLongReview,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: model.showLongReview
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
    BuildContext context,
    RecommendationViewModel model, {
    required DailyRecommendation recommendation,
    String? hint,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final yougnScore = recommendation.yougnScore;
    final yougnScoreText = yougnScore?.toStringAsFixed(1) ?? '-';
    final currentLabel =
        yougnScore != null ? model.scoreToBinLabel(yougnScore) : '-';
    final total = model.scoreTotal;
    final maxCount = model.scoreBins.fold<int>(
      0,
      (current, bin) => bin.count > current ? bin.count : current,
    );

    Widget body;
    if (model.isStatsLoading) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (model.scoreBins.isEmpty || total == 0) {
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
        children: model.scoreBins.map((bin) {
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
    required RecommendationScoreBin bin,
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
    BuildContext context,
    RecommendationViewModel model, {
    required DailyRecommendation recommendation,
    required String longReview,
    String? hint,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final pageId = recommendation.pageId?.trim() ?? '';
    final isLoading =
        pageId.isNotEmpty && model.isNotionContentLoading(pageId);
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
