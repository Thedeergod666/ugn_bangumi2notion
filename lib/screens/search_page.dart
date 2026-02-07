import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_services.dart';
import '../app/app_settings.dart';
import '../models/bangumi_models.dart';
import '../models/notion_models.dart';
import '../services/bangumi_api.dart';
import '../services/notion_api.dart';
import '../services/settings_storage.dart';
import '../widgets/navigation_shell.dart';
import 'detail_page.dart';

enum _SearchSource {
  bangumi,
  notion,
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const int _maxKeywordLength = 50;

  final _controller = TextEditingController();
  late final BangumiApi _api;
  late final NotionApi _notionApi;
  final SettingsStorage _settingsStorage = SettingsStorage();
  _SearchSource _source = _SearchSource.bangumi;

  List<BangumiSearchItem> _items = [];
  List<NotionSearchItem> _notionItems = [];
  bool _loading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _api = context.read<AppServices>().bangumiApi;
    _notionApi = context.read<AppServices>().notionApi;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _sanitizeKeyword({required bool allowDefault}) {
    final keyword = _controller.text.trim();
    final resolvedKeyword =
        keyword.isEmpty && allowDefault ? '进击的巨人' : keyword;
    if (keyword.isEmpty && allowDefault) {
      _controller.text = resolvedKeyword;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: resolvedKeyword.length),
      );
    }
    final normalizedKeyword = resolvedKeyword.trim();
    final limitedKeyword = normalizedKeyword.length > _maxKeywordLength
        ? normalizedKeyword.substring(0, _maxKeywordLength)
        : normalizedKeyword;
    if (limitedKeyword != normalizedKeyword) {
      _controller.text = limitedKeyword;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: limitedKeyword.length),
      );
    }
    if (limitedKeyword.isEmpty) {
      throw Exception('请输入搜索关键词');
    }
    return limitedKeyword;
  }

  Future<void> _searchBangumi() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final limitedKeyword = _sanitizeKeyword(allowDefault: true);
      final token = context.read<AppSettings>().bangumiAccessToken;

      final items = await _api.search(
        keyword: limitedKeyword,
        accessToken: token.isEmpty ? null : token,
      );
      if (mounted) {
        setState(() {
          _items = items;
          _notionItems = [];
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = '搜索失败，请稍后重试';
          _items = [];
          _notionItems = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _searchNotion() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final limitedKeyword = _sanitizeKeyword(allowDefault: false);
      final settings = context.read<AppSettings>();
      final token = settings.notionToken;
      final databaseId = settings.notionDatabaseId;
      if (token.isEmpty || databaseId.isEmpty) {
        throw Exception('请先在设置页配置 Notion Token 和 Database ID');
      }

      final mappingConfig = await _settingsStorage.getMappingConfig();
      final titleProperty = mappingConfig.title.trim();
      if (titleProperty.isEmpty) {
        throw Exception('请先在映射配置中绑定 Notion 标题字段');
      }

      final items = await _notionApi.searchDatabase(
        token: token,
        databaseId: databaseId,
        titlePropertyName: titleProperty,
        keyword: limitedKeyword,
      );
      if (mounted) {
        setState(() {
          _notionItems = items;
          _items = [];
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.toString().replaceAll('Exception: ', '');
          _notionItems = [];
          _items = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _search() async {
    if (_source == _SearchSource.bangumi) {
      return _searchBangumi();
    }
    return _searchNotion();
  }


  Future<void> _openNotionPage(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return NavigationShell(
      title: '悠gn助手',
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
            SegmentedButton<_SearchSource>(
              segments: const [
                ButtonSegment(
                  value: _SearchSource.bangumi,
                  label: Text('Bangumi'),
                  icon: Icon(Icons.search),
                ),
                ButtonSegment(
                  value: _SearchSource.notion,
                  label: Text('Notion'),
                  icon: Icon(Icons.storage_rounded),
                ),
              ],
              selected: {_source},
              onSelectionChanged: (values) {
                if (values.isEmpty) return;
                setState(() {
                  _source = values.first;
                  _items = [];
                  _notionItems = [];
                  _errorMessage = null;
                });
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: '输入番剧名称或关键字（最多 50 字）',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _loading ? null : _search,
                  icon: const Icon(Icons.search),
                  label: const Text('搜索'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              '搜索结果',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              Expanded(
                child: Center(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: _source == _SearchSource.bangumi
                    ? ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = _items[index];
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
                      )
                    : ListView.separated(
                        itemCount: _notionItems.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = _notionItems[index];
                          return _NotionResultCard(
                            item: item,
                            onTap: () => _openNotionPage(item.url),
                          );
                        },
                      ),
              ),
          ],
        ),
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
