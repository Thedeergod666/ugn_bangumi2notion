import 'package:flutter/material.dart';

import '../../../core/widgets/error_detail_dialog.dart';
import '../providers/detail_view_model.dart';

Future<bool> showNotionImportDialog({
  required BuildContext context,
  required DetailViewModel model,
  bool initialBindMode = false,
  String? initialBangumiId,
  String? initialNotionId,
}) async {
  final detail = model.detail;
  if (detail == null) return false;

  final preparation = await model.prepareImport();
  if (!context.mounted) return false;

  final mappingConfig = preparation.mappingConfig;
  final existingPageId = preparation.existingPageId;
  final subjectTitle = detail.nameCn.trim().isNotEmpty
      ? detail.nameCn.trim()
      : detail.name.trim().isNotEmpty
          ? detail.name.trim()
          : 'Untitled';

  String formatLabel(String bangumiLabel, String? notionLabel) {
    if (notionLabel == null || notionLabel.trim().isEmpty) return '';
    final cleanBangumi = bangumiLabel.split('(').first.split('（').first.trim();
    final cleanNotion = notionLabel.split('(').first.split('（').first.trim();
    return '$cleanBangumi → $cleanNotion';
  }

  final Map<String, String> fieldLabels = {
    'title': formatLabel('标题', mappingConfig.title),
    'airDate': formatLabel('放送开始', mappingConfig.airDate),
    'airDateRange': formatLabel('放送开始-含结束', mappingConfig.airDateRange),
    'tags': formatLabel('标签', mappingConfig.tags),
    'imageUrl': formatLabel('封面', mappingConfig.imageUrl),
    'bangumiId': formatLabel('Bangumi ID', mappingConfig.bangumiId),
    'score': formatLabel('评分', mappingConfig.score),
    'totalEpisodes': formatLabel('总集数', mappingConfig.totalEpisodes),
    'link': formatLabel('链接', mappingConfig.link),
    'bangumiUpdatedAt':
        formatLabel('Bangumi 更新日期', mappingConfig.bangumiUpdatedAt),
    'animationProduction':
        formatLabel('动画制作', mappingConfig.animationProduction),
    'director': formatLabel('导演', mappingConfig.director),
    'script': formatLabel('脚本', mappingConfig.script),
    'storyboard': formatLabel('分镜', mappingConfig.storyboard),
    'description': formatLabel('简介/描述', mappingConfig.description),
  };
  fieldLabels.removeWhere((key, value) => value.trim().isEmpty);

  final Set<String> selectedFields = {};
  if (mappingConfig.titleEnabled) selectedFields.add('title');
  if (mappingConfig.airDateEnabled) selectedFields.add('airDate');
  if (mappingConfig.airDateRangeEnabled) selectedFields.add('airDateRange');
  if (mappingConfig.tagsEnabled) selectedFields.add('tags');
  if (mappingConfig.imageUrlEnabled) selectedFields.add('imageUrl');
  if (mappingConfig.bangumiIdEnabled) selectedFields.add('bangumiId');
  if (mappingConfig.scoreEnabled) selectedFields.add('score');
  if (mappingConfig.totalEpisodesEnabled) selectedFields.add('totalEpisodes');
  if (mappingConfig.linkEnabled) selectedFields.add('link');
  if (mappingConfig.animationProductionEnabled) {
    selectedFields.add('animationProduction');
  }
  if (mappingConfig.directorEnabled) selectedFields.add('director');
  if (mappingConfig.scriptEnabled) selectedFields.add('script');
  if (mappingConfig.storyboardEnabled) selectedFields.add('storyboard');
  if (mappingConfig.descriptionEnabled) selectedFields.add('description');
  if (mappingConfig.bangumiUpdatedAt.isNotEmpty) {
    selectedFields.add('bangumiUpdatedAt');
  }
  if (selectedFields.isEmpty) {
    selectedFields.addAll(fieldLabels.keys);
    selectedFields.remove('tags');
  }

  final List<String> topTags = detail.tags.take(30).toList();
  final Set<String> selectedTags = {};

  final TextEditingController bangumiIdController = TextEditingController(
    text: initialBangumiId?.trim() ?? '',
  );
  final TextEditingController notionIdController = TextEditingController(
    text: initialNotionId?.trim() ?? '',
  );
  bool isBindMode = initialBindMode ||
      bangumiIdController.text.trim().isNotEmpty ||
      notionIdController.text.trim().isNotEmpty;

  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final isUpdateMode = existingPageId != null;
          return AlertDialog(
            title: Text(isUpdateMode ? '更新 Notion 页面' : '导入到 Notion'),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSubjectHeader(context, subjectTitle),
                    const SizedBox(height: 8),
                    _buildDialogSectionTitle('目标定位'),
                    if (isUpdateMode)
                      ListTile(
                        leading:
                            const Icon(Icons.check_circle, color: Colors.green),
                        title: const Text('已关联 Notion 页面'),
                        subtitle:
                            Text('ID: ${existingPageId.substring(0, 8)}...'),
                        dense: true,
                      )
                    else ...[
                      RadioGroup<bool>(
                        groupValue: isBindMode,
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => isBindMode = val);
                          }
                        },
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RadioListTile<bool>(
                              title: Text('新建页面'),
                              value: false,
                              dense: true,
                            ),
                            RadioListTile<bool>(
                              title: Text('绑定到已有页面'),
                              value: true,
                              dense: true,
                            ),
                          ],
                        ),
                      ),
                      if (isBindMode)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: bangumiIdController,
                                  enabled: notionIdController.text.isEmpty,
                                  onChanged: (_) => setDialogState(() {}),
                                  decoration: const InputDecoration(
                                    labelText: 'Bangumi ID',
                                    hintText: 'Bangumi ID',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: notionIdController,
                                  enabled: bangumiIdController.text.isEmpty,
                                  onChanged: (_) => setDialogState(() {}),
                                  decoration: const InputDecoration(
                                    labelText: 'Notion ID',
                                    hintText: 'Notion ID',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    const Divider(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildDialogSectionTitle('字段更新选择'),
                        const SizedBox(width: 8),
                        const Text(
                          'Bangumi 字段名对应 Notion 字段名',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: fieldLabels.isEmpty
                              ? null
                              : () {
                                  setDialogState(() {
                                    final allSelected = selectedFields.length ==
                                        fieldLabels.length;
                                    if (allSelected) {
                                      selectedFields.clear();
                                    } else {
                                      selectedFields.addAll(fieldLabels.keys);
                                    }
                                  });
                                },
                          child: Text(
                            selectedFields.length == fieldLabels.length &&
                                    fieldLabels.isNotEmpty
                                ? '取消全选'
                                : '全选',
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: fieldLabels.entries.map((entry) {
                        return FilterChip(
                          label: Text(entry.value),
                          selected: selectedFields.contains(entry.key),
                          onSelected: (val) {
                            setDialogState(() {
                              if (val) {
                                selectedFields.add(entry.key);
                              } else {
                                selectedFields.remove(entry.key);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const Divider(),
                    Row(
                      children: [
                        _buildDialogSectionTitle('标签选择 (Top 30)'),
                        const Spacer(),
                        TextButton(
                          onPressed: selectedFields.contains('tags') &&
                                  topTags.isNotEmpty
                              ? () {
                                  setDialogState(() {
                                    final allSelected =
                                        selectedTags.length == topTags.length;
                                    if (allSelected) {
                                      selectedTags.clear();
                                    } else {
                                      selectedTags.addAll(topTags);
                                    }
                                  });
                                }
                              : null,
                          child: Text(
                            selectedTags.length == topTags.length &&
                                    topTags.isNotEmpty
                                ? '取消全选'
                                : '全选',
                          ),
                        ),
                      ],
                    ),
                    if (topTags.isEmpty)
                      const Text(
                        '暂无标签',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      )
                    else
                      AbsorbPointer(
                        absorbing: !selectedFields.contains('tags'),
                        child: Opacity(
                          opacity: selectedFields.contains('tags') ? 1.0 : 0.5,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: topTags.map((tag) {
                              return FilterChip(
                                label: Text(tag),
                                selected: selectedTags.contains(tag),
                                onSelected: (val) {
                                  setDialogState(() {
                                    if (val) {
                                      selectedTags.add(tag);
                                    } else {
                                      selectedTags.remove(tag);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context, {
                    'fields': selectedFields,
                    'tags': selectedTags,
                    'bangumiId': bangumiIdController.text.trim(),
                    'notionId': notionIdController.text.trim(),
                    'existingPageId': existingPageId,
                    'isBind': isBindMode,
                  });
                },
                child: Text(isUpdateMode ? '确认更新' : '确认导入'),
              ),
            ],
          );
        },
      );
    },
  );

  bangumiIdController.dispose();
  notionIdController.dispose();

  if (!context.mounted || result == null) {
    return false;
  }

  final Set<String> fields = result['fields'];
  final Set<String> tags = result['tags'];
  final String? bangumiIdStr = result['bangumiId'];
  final String? notionIdStr = result['notionId'];
  final String? existingPageIdResult = result['existingPageId'];

  String? targetPageId = existingPageIdResult;
  if (result['isBind'] == true) {
    try {
      targetPageId = await model.resolveBindingTargetPageId(
        mappingConfig: mappingConfig,
        bangumiId: bangumiIdStr,
        notionId: notionIdStr,
      );
      if (!context.mounted) return false;
      if (targetPageId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未找到对应的 Notion 页面，请检查输入。')),
        );
        return false;
      }
    } catch (e) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('查找页面失败: $e')),
      );
      return false;
    }
  }

  final importResult = await model.importToNotion(
    enabledFields: fields,
    mappingConfig: mappingConfig,
    selectedTags: tags.toList(),
    targetPageId: targetPageId,
  );

  if (!context.mounted) return false;

  if (importResult.success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(importResult.message)),
    );
    return true;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(importResult.message),
      backgroundColor: Theme.of(context).colorScheme.error,
      duration: const Duration(seconds: 5),
      action: importResult.error == null
          ? null
          : SnackBarAction(
              label: '查看详情',
              textColor: Colors.white,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => ErrorDetailDialog(
                    error: importResult.error!,
                    stackTrace: importResult.stackTrace,
                  ),
                );
              },
            ),
    ),
  );
  return false;
}

Widget _buildDialogSectionTitle(String title) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
    ),
  );
}

Widget _buildSubjectHeader(BuildContext context, String title) {
  final colorScheme = Theme.of(context).colorScheme;
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: colorScheme.outlineVariant),
    ),
    child: Row(
      children: [
        const Icon(Icons.movie_outlined, size: 18),
        const SizedBox(width: 8),
        Text(
          '番剧：',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    ),
  );
}
