import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../models/bangumi_models.dart';
import '../../providers/batch_import_view_model.dart';

class BatchImportViewState {
  const BatchImportViewState({
    required this.isLoading,
    required this.errorMessage,
    required this.candidates,
  });

  final bool isLoading;
  final String? errorMessage;
  final List<BatchImportCandidate> candidates;
}

class BatchImportViewCallbacks {
  const BatchImportViewCallbacks({
    required this.onBind,
  });

  final void Function(BatchImportCandidate candidate, int bangumiId) onBind;
}

class BatchImportView extends StatelessWidget {
  const BatchImportView({
    super.key,
    required this.state,
    required this.callbacks,
  });

  final BatchImportViewState state;
  final BatchImportViewCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
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

    if (state.candidates.isEmpty) {
      return const Center(child: Text('暂无待绑定条目'));
    }

    return ListView.separated(
      itemCount: state.candidates.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final candidate = state.candidates[index];
        return _BatchImportCard(
          candidate: candidate,
          onBind: (id) => callbacks.onBind(candidate, id),
        );
      },
    );
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
                Expanded(child: _NotionSide(title: candidate.notionItem.title)),
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
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
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
        errorWidget: (_, __, ___) => const SizedBox(
          width: 36,
          height: 48,
          child: Icon(Icons.broken_image),
        ),
      ),
    );
  }
}

