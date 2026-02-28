import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/view_mode_toggle.dart';
import '../../../models/bangumi_models.dart';
import '../../../models/notion_models.dart';
import '../providers/search_view_model.dart';

class SearchViewState {
  const SearchViewState({
    required this.source,
    required this.sort,
    required this.searchViewMode,
    required this.isLoading,
    required this.errorMessage,
    required this.showHints,
    required this.suggestions,
    required this.history,
    required this.items,
    required this.notionItems,
    required this.controller,
    required this.searchFocusNode,
  });

  final SearchSource source;
  final SearchSort sort;
  final String searchViewMode;
  final bool isLoading;
  final String? errorMessage;
  final bool showHints;
  final List<String> suggestions;
  final List<String> history;
  final List<BangumiSearchItem> items;
  final List<NotionSearchItem> notionItems;
  final TextEditingController controller;
  final FocusNode searchFocusNode;
}

class SearchViewCallbacks {
  const SearchViewCallbacks({
    required this.onSourceChanged,
    required this.onSortChanged,
    required this.onSearchViewModeChanged,
    required this.onQueryChanged,
    required this.onSubmit,
    required this.onClearHistory,
    required this.onRemoveHistory,
    required this.onPickSuggestion,
    required this.onPickHistory,
    required this.onTapBangumiItem,
    required this.onOpenNotionPage,
  });

  final ValueChanged<SearchSource> onSourceChanged;
  final ValueChanged<SearchSort> onSortChanged;
  final ValueChanged<String> onSearchViewModeChanged;
  final VoidCallback onQueryChanged;
  final ValueChanged<String> onSubmit;
  final VoidCallback onClearHistory;
  final ValueChanged<String> onRemoveHistory;
  final ValueChanged<String> onPickSuggestion;
  final ValueChanged<String> onPickHistory;
  final ValueChanged<int> onTapBangumiItem;
  final ValueChanged<String> onOpenNotionPage;
}

class SearchView extends StatelessWidget {
  const SearchView({
    super.key,
    required this.state,
    required this.callbacks,
  });

  final SearchViewState state;
  final SearchViewCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '搜索条目',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          SegmentedButton<SearchSource>(
            segments: const [
              ButtonSegment(
                value: SearchSource.bangumi,
                label: Text('Bangumi'),
                icon: Icon(Icons.search),
              ),
              ButtonSegment(
                value: SearchSource.notion,
                label: Text('Notion'),
                icon: Icon(Icons.storage_rounded),
              ),
            ],
            selected: {state.source},
            onSelectionChanged: (values) {
              if (values.isEmpty) return;
              callbacks.onSourceChanged(values.first);
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: state.controller,
                  focusNode: state.searchFocusNode,
                  decoration: const InputDecoration(
                    hintText: '输入番剧名称或关键词（最多 50 字）',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => callbacks.onQueryChanged(),
                  onSubmitted: callbacks.onSubmit,
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: state.isLoading
                    ? null
                    : () => callbacks.onSubmit(state.controller.text),
                icon: const Icon(Icons.search),
                label: const Text('搜索'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (state.source == SearchSource.bangumi)
            _buildSearchControls(context),
          const SizedBox(height: 12),
          if (state.showHints) ...[
            _buildSuggestionList(context),
            const SizedBox(height: 12),
            _buildHistorySection(context),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 4),
          const Text(
            '搜索结果',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildResults(context)),
        ],
      ),
    );
  }

  Widget _buildSearchControls(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<SearchSort>(
          segments: const [
            ButtonSegment(value: SearchSort.match, label: Text('最佳适配')),
            ButtonSegment(value: SearchSort.heat, label: Text('最佳热度')),
            ButtonSegment(value: SearchSort.collect, label: Text('最多收藏')),
          ],
          selected: {state.sort},
          onSelectionChanged: (values) {
            if (values.isEmpty) return;
            callbacks.onSortChanged(values.first);
          },
        ),
        ViewModeToggle(
          mode: state.searchViewMode,
          compact: true,
          onChanged: callbacks.onSearchViewModeChanged,
        ),
      ],
    );
  }

  Widget _buildSuggestionList(BuildContext context) {
    if (state.suggestions.isEmpty) {
      return const SizedBox.shrink();
    }
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '搜索建议',
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: state.suggestions
              .map(
                (item) => ActionChip(
                  label: Text(item),
                  onPressed: () => callbacks.onPickSuggestion(item),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildHistorySection(BuildContext context) {
    if (state.history.isEmpty) {
      return const SizedBox.shrink();
    }
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '搜索历史',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: callbacks.onClearHistory,
              child: const Text('清空'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: state.history.map((item) {
            return GestureDetector(
              onLongPress: () => callbacks.onRemoveHistory(item),
              child: ActionChip(
                label: Text(item),
                onPressed: () => callbacks.onPickHistory(item),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildResults(BuildContext context) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorMessage != null) {
      return Center(
        child: Text(
          state.errorMessage!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final gridCount = width >= 1200 ? 3 : (width >= 900 ? 2 : 1);
        final isGallery = state.searchViewMode == 'gallery';

        if (state.source == SearchSource.bangumi) {
          final useGrid = gridCount > 1;
          if (isGallery) {
            if (!useGrid) {
              return ListView.separated(
                itemCount: state.items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = state.items[index];
                  return _ResultGalleryCard(
                    item: item,
                    onTap: () => callbacks.onTapBangumiItem(item.id),
                  );
                },
              );
            }
            return GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: gridCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              itemCount: state.items.length,
              itemBuilder: (context, index) {
                final item = state.items[index];
                return _ResultGalleryCard(
                  item: item,
                  onTap: () => callbacks.onTapBangumiItem(item.id),
                );
              },
            );
          }

          if (!useGrid) {
            return ListView.separated(
              itemCount: state.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = state.items[index];
                return _ResultCard(
                  item: item,
                  onTap: () => callbacks.onTapBangumiItem(item.id),
                );
              },
            );
          }

          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: gridCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 3.2,
            ),
            itemCount: state.items.length,
            itemBuilder: (context, index) {
              final item = state.items[index];
              return _ResultCard(
                item: item,
                onTap: () => callbacks.onTapBangumiItem(item.id),
              );
            },
          );
        }

        return ListView.separated(
          itemCount: state.notionItems.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = state.notionItems[index];
            return _NotionResultCard(
              item: item,
              onTap: () => callbacks.onOpenNotionPage(item.url),
            );
          },
        );
      },
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.item, required this.onTap});

  final BangumiSearchItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = item.nameCn.isNotEmpty ? item.nameCn : item.name;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 96,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  image: item.imageUrl.isNotEmpty
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(item.imageUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: item.imageUrl.isEmpty
                    ? const Icon(Icons.image, size: 32)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('放送开始：${item.airDate.isEmpty ? '-' : item.airDate}'),
                    const SizedBox(height: 8),
                    Text(
                      item.summary.isEmpty ? '暂无简介' : item.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultGalleryCard extends StatelessWidget {
  const _ResultGalleryCard({required this.item, required this.onTap});

  final BangumiSearchItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = item.nameCn.isNotEmpty ? item.nameCn : item.name;
    final hasCover = item.imageUrl.isNotEmpty;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 0.72,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  image: hasCover
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(item.imageUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: hasCover ? null : const Icon(Icons.image, size: 48),
              ),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black54],
                  ),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotionResultCard extends StatelessWidget {
  const _NotionResultCard({required this.item, required this.onTap});

  final NotionSearchItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.description, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.url.isEmpty ? 'Notion 条目' : item.url,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.open_in_new,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
