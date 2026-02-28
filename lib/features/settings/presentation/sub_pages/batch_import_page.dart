import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_services.dart';
import '../app/app_settings.dart';
import '../models/bangumi_models.dart';
import '../view_models/batch_import_view_model.dart';
import '../widgets/navigation_shell.dart';

class BatchImportPage extends StatefulWidget {
  const BatchImportPage({super.key});

  @override
  State<BatchImportPage> createState() => _BatchImportPageState();
}

class _BatchImportPageState extends State<BatchImportPage> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => BatchImportViewModel(
        notionApi: context.read<AppServices>().notionApi,
        bangumiApi: context.read<AppServices>().bangumiApi,
        settings: context.read<AppSettings>(),
      )..load(),
      child: Consumer<BatchImportViewModel>(
        builder: (context, model, _) {
          return NavigationShell(
            title: '批量导入/更新',
            selectedRoute: '/settings',
            onBack: () => Navigator.of(context).pop(),
            actions: [
              IconButton(
                tooltip: '刷新',
                onPressed: model.isLoading ? null : model.load,
                icon: const Icon(Icons.refresh),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: model.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildContent(context, model),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, BatchImportViewModel model) {
    if (model.errorMessage != null) {
      return Center(
        child: Text(
          model.errorMessage!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }
    if (model.candidates.isEmpty) {
      return const Center(child: Text('暂无待绑定条目'));
    }

    return ListView.separated(
      itemCount: model.candidates.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final candidate = model.candidates[index];
        return _BatchImportCard(
          candidate: candidate,
          onBind: (id) => _bindCandidate(context, model, candidate, id),
        );
      },
    );
  }

  Future<void> _bindCandidate(
    BuildContext context,
    BatchImportViewModel model,
    BatchImportCandidate candidate,
    int bangumiId,
  ) async {
    try {
      await model.bindCandidate(candidate: candidate, bangumiId: bangumiId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('绑定成功')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('绑定失败: $e')),
      );
    }
  }
}

class _BatchImportCard extends StatefulWidget {
  const _BatchImportCard({
    required this.candidate,
    required this.onBind,
  });

  final BatchImportCandidate candidate;
  final ValueChanged<int> onBind;

  @override
  State<_BatchImportCard> createState() => _BatchImportCardState();
}

class _BatchImportCardState extends State<_BatchImportCard> {
  final TextEditingController _manualController = TextEditingController();

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final candidate = widget.candidate;
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _NotionSide(title: candidate.notionItem.title),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BangumiSide(
                    matches: candidate.matches,
                    onBind: widget.onBind,
                    bound: candidate.bound,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!candidate.bound)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _manualController,
                      decoration: const InputDecoration(
                        labelText: '手动输入 Bangumi ID',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      final id = int.tryParse(_manualController.text.trim());
                      if (id == null || id <= 0) return;
                      widget.onBind(id);
                    },
                    child: const Text('绑定'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _NotionSide extends StatelessWidget {
  const _NotionSide({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.description_outlined),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BangumiSide extends StatelessWidget {
  const _BangumiSide({
    required this.matches,
    required this.onBind,
    required this.bound,
  });

  final List<BangumiSearchItem> matches;
  final ValueChanged<int> onBind;
  final bool bound;

  @override
  Widget build(BuildContext context) {
    if (bound) {
      return const Text('已绑定');
    }
    if (matches.isEmpty) {
      return const Text('未找到匹配项');
    }
    return Column(
      children: matches.map((item) {
        final title = item.nameCn.isNotEmpty ? item.nameCn : item.name;
        return ListTile(
          dense: true,
          leading: _CoverThumb(url: item.imageUrl),
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text('ID ${item.id}'),
          trailing: TextButton(
            onPressed: () => onBind(item.id),
            child: const Text('绑定'),
          ),
        );
      }).toList(),
    );
  }
}

class _CoverThumb extends StatelessWidget {
  const _CoverThumb({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return const SizedBox(width: 36, height: 48, child: Icon(Icons.image));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: CachedNetworkImage(
        imageUrl: url,
        width: 36,
        height: 48,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) =>
            const SizedBox(width: 36, height: 48, child: Icon(Icons.broken_image)),
      ),
    );
  }
}

