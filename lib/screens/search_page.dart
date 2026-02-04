import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_services.dart';
import '../app/app_settings.dart';
import '../models/bangumi_models.dart';
import '../services/bangumi_api.dart';
import '../widgets/navigation_shell.dart';
import 'detail_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const int _maxKeywordLength = 50;

  final _controller = TextEditingController();
  late final BangumiApi _api;

  List<BangumiSearchItem> _items = [];
  bool _loading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _api = context.read<AppServices>().bangumiApi;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final keyword = _controller.text.trim();
      final resolvedKeyword = keyword.isEmpty ? '魔法少女小圆' : keyword;
      if (keyword.isEmpty) {
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
        throw Exception('请输入有效关键词');
      }
      final token = context.read<AppSettings>().bangumiAccessToken;

      final items = await _api.search(
        keyword: limitedKeyword,
        accessToken: token.isEmpty ? null : token,
      );
      if (mounted) {
        setState(() {
          _items = items;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = '搜索失败，请稍后重试';
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
                child: ListView.separated(
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
                            builder: (_) => DetailPage(subjectId: item.id),
                          ),
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
