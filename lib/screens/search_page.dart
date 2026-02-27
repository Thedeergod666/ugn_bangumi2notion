import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_services.dart';
import '../app/app_settings.dart';
import '../models/bangumi_models.dart';
import '../models/notion_models.dart';
import '../view_models/search_view_model.dart';
import '../widgets/navigation_shell.dart';
import '../widgets/view_mode_toggle.dart';
import 'detail_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final TextEditingController _controller;
  late final SearchViewModel _viewModel;
  bool _initializedFromArgs = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _viewModel = SearchViewModel(
      bangumiApi: context.read<AppServices>().bangumiApi,
      notionApi: context.read<AppServices>().notionApi,
      settings: context.read<AppSettings>(),
    );
    _viewModel.initialize();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initializedFromArgs) return;
    _initializedFromArgs = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final source = args['source']?.toString();
      if (source == 'notion') {
        _viewModel.setSource(SearchSource.notion);
      } else if (source == 'bangumi') {
        _viewModel.setSource(SearchSource.bangumi);
      }
      final keyword = args['keyword']?.toString().trim() ?? '';
      if (keyword.isNotEmpty) {
        _controller.text = keyword;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _viewModel.search(_controller.text);
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _openNotionPage(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _buildSearchControls(
    BuildContext context,
    SearchViewModel model,
    AppSettings settings,
  ) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<SearchSort>(
          segments: const [
            ButtonSegment(
              value: SearchSort.match,
              label: Text('最佳适配'),
            ),
            ButtonSegment(
              value: SearchSort.heat,
              label: Text('最佳热度'),
            ),
            ButtonSegment(
              value: SearchSort.collect,
              label: Text('最多收藏'),
            ),
          ],
          selected: {model.sort},
          onSelectionChanged: (values) {
            if (values.isEmpty) return;
            model.setSort(values.first);
          },
        ),
        ViewModeToggle(
          mode: settings.searchViewMode,
          compact: true,
          onChanged: (mode) => settings.setSearchViewMode(mode),
        ),
      ],
    );
  }

  Widget _buildSuggestionList(SearchViewModel model) {
    final input = _controller.text.trim();
    if (input.isEmpty) {
      return const SizedBox.shrink();
    }
    final suggestions = model.suggestionsFor(input);
    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '搜索建议',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: suggestions.map((item) {
            return ActionChip(
              label: Text(item),
              onPressed: () {
                _controller.text = item;
                _viewModel.search(item);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildHistorySection(SearchViewModel model) {
    if (model.history.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '搜索历史',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => model.clearHistory(),
              child: const Text('清空'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: model.history.map((item) {
            return GestureDetector(
              onLongPress: () => _confirmRemoveHistory(model, item),
              child: ActionChip(
                label: Text(item),
                onPressed: () {
                  _controller.text = item;
                  _viewModel.search(item);
                },
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _confirmRemoveHistory(
    SearchViewModel model,
    String keyword,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除搜索记录'),
        content: Text('是否删除“$keyword”？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (result == true) {
      await model.removeHistory(keyword);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<SearchViewModel>(
        builder: (context, model, _) {
          final settings = context.watch<AppSettings>();
          return NavigationShell(
            title: '搜索',
            selectedRoute: '/search',
            child: Padding(
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
                    selected: {model.source},
                    onSelectionChanged: (values) {
                      if (values.isEmpty) return;
                      model.setSource(values.first);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(
                            hintText: '输入番剧名称或关键词（最多 50 字）',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => model.search(_controller.text),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed:
                            model.isLoading ? null : () => model.search(_controller.text),
                        icon: const Icon(Icons.search),
                        label: const Text('搜索'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (model.source == SearchSource.bangumi)
                    _buildSearchControls(context, model, settings),
                  const SizedBox(height: 12),
                  _buildSuggestionList(model),
                  const SizedBox(height: 12),
                  _buildHistorySection(model),
                  const SizedBox(height: 16),
                  const Text(
                    '搜索结果',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  if (model.isLoading)
                    const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (model.errorMessage != null)
                    Expanded(
                      child: Center(
                        child: Text(
                          model.errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final gridCount =
                              width >= 1200 ? 3 : (width >= 900 ? 2 : 1);
                          final isGallery = settings.searchViewMode == 'gallery';

                          if (model.source == SearchSource.bangumi) {
                            final useGrid = gridCount > 1;
                            if (isGallery) {
                              if (!useGrid) {
                                return ListView.separated(
                                  itemCount: model.items.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final item = model.items[index];
                                    return _ResultGalleryCard(
                                      item: item,
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                DetailPage(subjectId: item.id),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                );
                              }
                              return GridView.builder(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: gridCount,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.72,
                                ),
                                itemCount: model.items.length,
                                itemBuilder: (context, index) {
                                  final item = model.items[index];
                                  return _ResultGalleryCard(
                                    item: item,
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              DetailPage(subjectId: item.id),
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            }

                            if (!useGrid) {
                              return ListView.separated(
                                itemCount: model.items.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final item = model.items[index];
                                  return _ResultCard(
                                    item: item,
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              DetailPage(subjectId: item.id),
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            }

                            return GridView.builder(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: gridCount,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 3.2,
                              ),
                              itemCount: model.items.length,
                              itemBuilder: (context, index) {
                                final item = model.items[index];
                                return _ResultCard(
                                  item: item,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            DetailPage(subjectId: item.id),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          }

                          return ListView.separated(
                            itemCount: model.notionItems.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = model.notionItems[index];
                              return _NotionResultCard(
                                item: item,
                                onTap: () => _openNotionPage(item.url),
                              );
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
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
                child: hasCover
                    ? null
                    : const Icon(Icons.image, size: 48),
              ),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black54,
                    ],
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
