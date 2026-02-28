part of 'detail_page.dart';

mixin _DetailPageSections {
  Widget _buildOverviewTab(
    BuildContext context,
    DetailViewModel model,
    BangumiSubjectDetail detail,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(context, '简介'),
          const SizedBox(height: 12),
          InkWell(
            onTap: model.toggleSummaryExpanded,
            borderRadius: BorderRadius.circular(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.summary.isEmpty ? '暂无简介' : detail.summary,
                  maxLines: model.isSummaryExpanded ? null : 6,
                  overflow: model.isSummaryExpanded
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    height: 1.7,
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0.3,
                  ),
                ),
                if (detail.summary.length > 100)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      model.isSummaryExpanded ? '收起' : '展开全部',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildSectionTitle(context, '制作人员'),
          const SizedBox(height: 12),
          _buildSimplifiedInfoGrid(context, detail),
          const SizedBox(height: 32),
          _buildSectionTitle(context, '标签'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: detail.tags.isEmpty
                ? [const Chip(label: Text('暂无标签'))]
                : detail.tags
                    .map((tag) => InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: tag));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('已复制标签: $tag'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildStaffTab(BuildContext context, BangumiSubjectDetail detail) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(context, '全制作人员'),
          const SizedBox(height: 12),
          _buildInfoGrid(context, detail),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildCommentsTab(BuildContext context, DetailViewModel model) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final showRatings = context.watch<AppSettings>().showRatings;
    if (model.isCommentsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (model.comments.isEmpty) {
      return RefreshIndicator(
        onRefresh: model.loadComments,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: 300,
            child: Center(
              child: Text('暂无吐槽',
                  style: TextStyle(color: colorScheme.onSurfaceVariant)),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: model.loadComments,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: model.comments.length,
        separatorBuilder: (context, index) =>
            Divider(height: 32, color: colorScheme.outlineVariant),
        itemBuilder: (context, index) {
          final comment = model.comments[index];
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: comment.user.avatar.isNotEmpty
                    ? NetworkImage(comment.user.avatar)
                    : null,
                child: comment.user.avatar.isEmpty
                    ? const Icon(Icons.person, size: 18)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          comment.user.nickname,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _formatTime(comment.updatedAt),
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (showRatings && comment.rate > 0)
                      Row(
                        children: List.generate(5, (i) {
                          return Icon(
                            i < (comment.rate / 2).ceil()
                                ? Icons.star
                                : Icons.star_border,
                            color: colorScheme.tertiary,
                            size: 10,
                          );
                        }),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      comment.comment,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatTime(String time) {
    try {
      final dt = DateTime.parse(time);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.year}-${dt.month}-${dt.day}';
    } catch (_) {
      return time;
    }
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoGrid(BuildContext context, BangumiSubjectDetail detail) {
    final skipKeys = {
      '中文名',
      '别名',
      '话数',
      '放送开始',
      '放送星期',
      '官方网站',
      '播放电视台',
      '其他电视台',
      'Copyright',
    };

    final items = detail.infoboxMap.entries
        .where((e) => !skipKeys.contains(e.key))
        .map((e) => MapEntry(e.key, e.value))
        .toList();

    items.add(MapEntry('Bangumi ID', detail.id.toString()));

    return _buildInfoListContainer(context, items);
  }

  Widget _buildSimplifiedInfoGrid(
    BuildContext context,
    BangumiSubjectDetail detail,
  ) {
    final items = <MapEntry<String, String>>[];

    items.add(MapEntry('Bangumi ID', detail.id.toString()));

    if (detail.animationProduction.isNotEmpty) {
      items.add(MapEntry('动画制作', detail.animationProduction));
    }
    if (detail.director.isNotEmpty) {
      items.add(MapEntry('导演', detail.director));
    }
    if (detail.script.isNotEmpty) {
      items.add(MapEntry('脚本', detail.script));
    }
    if (detail.storyboard.isNotEmpty) {
      items.add(MapEntry('分镜', detail.storyboard));
    }

    return _buildInfoListContainer(context, items);
  }

  Widget _buildInfoListContainer(
    BuildContext context,
    List<MapEntry<String, String>> items,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (context, index) =>
            Divider(height: 1, color: colorScheme.outlineVariant),
        itemBuilder: (context, index) {
          final item = items[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: item.value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('已复制${item.key}: ${item.value}'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    width: 80,
                    child: Text(
                      item.key,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    item.value,
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: 13,
                      color: colorScheme.onSurface,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
