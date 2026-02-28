import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../models/bangumi_models.dart';

part 'detail_page_sections.dart';
part 'detail_page_widgets.dart';

class DetailViewState {
  const DetailViewState({
    required this.isLoading,
    required this.isCommentsLoading,
    required this.isImporting,
    required this.isSummaryExpanded,
    required this.showRatings,
    required this.errorMessage,
    required this.detail,
    required this.comments,
  });

  final bool isLoading;
  final bool isCommentsLoading;
  final bool isImporting;
  final bool isSummaryExpanded;
  final bool showRatings;
  final String? errorMessage;
  final BangumiSubjectDetail? detail;
  final List<BangumiComment> comments;
}

class DetailViewCallbacks {
  const DetailViewCallbacks({
    required this.onBack,
    required this.onRetryLoad,
    required this.onImportToNotion,
    required this.onOpenBangumi,
    required this.onToggleSummaryExpanded,
    required this.onRefreshComments,
    required this.onCopyText,
  });

  final VoidCallback onBack;
  final VoidCallback onRetryLoad;
  final VoidCallback onImportToNotion;
  final VoidCallback onOpenBangumi;
  final VoidCallback onToggleSummaryExpanded;
  final Future<void> Function() onRefreshComments;
  final void Function(String text, String message) onCopyText;
}

class DetailView extends StatelessWidget with _DetailPageSections {
  const DetailView({
    super.key,
    required this.state,
    required this.callbacks,
  });

  @override
  final DetailViewState state;

  @override
  final DetailViewCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.errorMessage != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  state.errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: callbacks.onRetryLoad,
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final detail = state.detail;
    if (detail == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('暂无详情数据')),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              _buildSliverAppBar(context, detail),
            ];
          },
          body: TabBarView(
            children: [
              _buildOverviewTab(context, detail),
              _buildStaffTab(context, detail),
              _buildCommentsTab(context),
            ],
          ),
        ),
        floatingActionButton: state.isImporting
            ? null
            : FloatingActionButton.extended(
                onPressed: callbacks.onImportToNotion,
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(
                  '导入到 Notion',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, BangumiSubjectDetail detail) {
    final title = detail.nameCn.isNotEmpty ? detail.nameCn : detail.name;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ratingColor = colorScheme.tertiary;
    final showRatings = state.showRatings;

    return SliverAppBar(
      expandedHeight: 380,
      pinned: true,
      stretch: true,
      backgroundColor: colorScheme.surface,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
        onPressed: callbacks.onBack,
      ),
      actions: const [],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (detail.imageUrl.isNotEmpty)
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Opacity(
                  opacity: 0.5,
                  child: Image.network(detail.imageUrl, fit: BoxFit.cover),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.surface.withValues(alpha: 0.2),
                    colorScheme.surface,
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 100, 16, 60),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(
                    tag: 'subject-${detail.id}',
                    child: Container(
                      width: 120,
                      height: 180,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                        image: detail.imageUrl.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(detail.imageUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: detail.imageUrl.isEmpty
                          ? const Icon(
                              Icons.image,
                              size: 48,
                              color: Colors.white24,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: textTheme.titleLarge?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          detail.airDate,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (showRatings) ...[
                          Row(
                            children: [
                              Text(
                                detail.score.toStringAsFixed(1),
                                style: TextStyle(
                                  color: ratingColor,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: List.generate(5, (index) {
                                      final rating = detail.score / 2;
                                      if (index < rating.floor()) {
                                        return Icon(
                                          Icons.star,
                                          color: ratingColor,
                                          size: 12,
                                        );
                                      } else if (index < rating) {
                                        return Icon(
                                          Icons.star_half,
                                          color: ratingColor,
                                          size: 12,
                                        );
                                      } else {
                                        return Icon(
                                          Icons.star_border,
                                          color: ratingColor,
                                          size: 12,
                                        );
                                      }
                                    }),
                                  ),
                                  Text(
                                    'Rank #${detail.rank ?? "N/A"}',
                                    style: textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ] else
                          const SizedBox(height: 16),
                        InkWell(
                          onTap: callbacks.onOpenBangumi,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color:
                                    colorScheme.primary.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.open_in_new,
                                  color: colorScheme.primary,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Bangumi',
                                  style: TextStyle(
                                    color: colorScheme.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showRatings)
                    Expanded(
                      child: RatingChart(
                        ratingCount: detail.ratingCount,
                        total: detail.ratingTotal,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottom: const TabBar(
        tabs: [
          Tab(text: '概述'),
          Tab(text: '制作'),
          Tab(text: '吐槽'),
        ],
      ),
    );
  }
}

