import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_services.dart';
import '../app/app_settings.dart';
import '../models/bangumi_models.dart';
import '../view_models/detail_view_model.dart';
import '../widgets/error_detail_dialog.dart';

part 'detail_page_sections.dart';
part 'detail_page_widgets.dart';

class DetailPage extends StatelessWidget {
  const DetailPage({super.key, required this.subjectId});

  final int subjectId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => DetailViewModel(
        subjectId: subjectId,
        bangumiApi: context.read<AppServices>().bangumiApi,
        notionApi: context.read<AppServices>().notionApi,
        settings: context.read<AppSettings>(),
      )..load(),
      child: const _DetailView(),
    );
  }
}

class _DetailView extends StatelessWidget with _DetailPageSections {
  const _DetailView();

  @override
  Widget build(BuildContext context) {
    final model = context.watch<DetailViewModel>();

    if (model.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (model.errorMessage != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline,
                    size: 64, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  model.errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: model.load,
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final detail = model.detail;
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
              _buildOverviewTab(context, model, detail),
              _buildStaffTab(context, detail),
              _buildCommentsTab(context, model),
            ],
          ),
        ),
        floatingActionButton: model.isImporting
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _showImportConfirmDialog(context, model),
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

  Future<void> _showImportConfirmDialog(
    BuildContext context,
    DetailViewModel model,
  ) async {
    final detail = model.detail;
    if (detail == null) return;

    final preparation = await model.prepareImport();
    if (!context.mounted) return;

    final mappingConfig = preparation.mappingConfig;
    final existingPageId = preparation.existingPageId;

    String formatLabel(String bangumiLabel, String? notionLabel) {
      if (notionLabel == null || notionLabel.trim().isEmpty) return '';
      final cleanBangumi =
          bangumiLabel.split('(').first.split('?').first.trim();
      return '$cleanBangumi?$notionLabel?';
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

    if (selectedFields.isEmpty) {
      if (existingPageId == null) {
        selectedFields.addAll(fieldLabels.keys);
      } else {
        selectedFields.addAll(['score', 'link', 'bangumiId']);
      }
    }

    final List<String> topTags = detail.tags.take(30).toList();
    final Set<String> selectedTags = {};

    final TextEditingController bangumiIdController = TextEditingController();
    final TextEditingController notionIdController = TextEditingController();
    bool isBindMode = false;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final bool isUpdateMode = existingPageId != null;

            return AlertDialog(
              title: Text(isUpdateMode ? '更新 Notion 页面' : '导入到 Notion'),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDialogSectionTitle('目标定位'),
                      if (isUpdateMode)
                        ListTile(
                          leading: const Icon(Icons.check_circle,
                              color: Colors.green),
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
                                      final bool allSelected =
                                          selectedFields.length ==
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
                            onPressed:
                                selectedFields.contains('tags') &&
                                        topTags.isNotEmpty
                                    ? () {
                                        setDialogState(() {
                                          final bool allSelected =
                                              selectedTags.length ==
                                                  topTags.length;
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
                        const Text('暂无标签',
                            style:
                                TextStyle(fontSize: 12, color: Colors.grey))
                      else
                        AbsorbPointer(
                          absorbing: !selectedFields.contains('tags'),
                          child: Opacity(
                            opacity:
                                selectedFields.contains('tags') ? 1.0 : 0.5,
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

    if (!context.mounted || result == null) {
      return;
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
        if (!context.mounted) return;
        if (targetPageId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未找到对应的 Notion 页面，请检查输入。')),
          );
          return;
        }
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('查找页面失败: $e')),
        );
        return;
      }
    }

    final importResult = await model.importToNotion(
      enabledFields: fields,
      mappingConfig: mappingConfig,
      selectedTags: tags.toList(),
      targetPageId: targetPageId,
    );

    if (!context.mounted) return;

    if (importResult.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(importResult.message)),
      );
      return;
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

  Widget _buildSliverAppBar(BuildContext context, BangumiSubjectDetail detail) {
    final title = detail.nameCn.isNotEmpty ? detail.nameCn : detail.name;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ratingColor = colorScheme.tertiary;
    final showRatings = context.watch<AppSettings>().showRatings;
    return SliverAppBar(
      expandedHeight: 380,
      pinned: true,
      stretch: true,
      backgroundColor: colorScheme.surface,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
        onPressed: () => Navigator.pop(context),
      ),
      actions: const [],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground
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
                          ? const Icon(Icons.image,
                              size: 48, color: Colors.white24)
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
                          onTap: () async {
                            final url = Uri.parse(
                                'https://bgm.tv/subject/${detail.id}');
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color:
                                  colorScheme.primary.withValues(alpha: 0.12),
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
                                      fontWeight: FontWeight.bold),
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
