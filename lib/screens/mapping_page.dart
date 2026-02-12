import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_services.dart';
import '../app/app_settings.dart';
import '../core/layout/breakpoints.dart';
import '../models/mapping_config.dart';
import '../models/notion_models.dart';
import '../view_models/mapping_view_model.dart';
import '../widgets/error_detail_dialog.dart';
import '../widgets/navigation_shell.dart';
import '../widgets/notion_mapping_panel.dart';

enum _MappingSegment {
  bangumi,
  notion,
}

class MappingPage extends StatefulWidget {
  const MappingPage({super.key});

  @override
  State<MappingPage> createState() => _MappingPageState();
}

class _MappingPageState extends State<MappingPage> {
  _MappingSegment _segment = _MappingSegment.bangumi;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MappingViewModel(
        notionApi: context.read<AppServices>().notionApi,
      )..load(context.read<AppSettings>()),
      child: Consumer<MappingViewModel>(
        builder: (context, model, _) {
          return NavigationShell(
            title: '映射设置',
            selectedRoute: '/mapping',
            actions: [
              IconButton(
                tooltip: '刷新属性',
                onPressed: model.isLoading
                    ? null
                    : () => model.load(
                          context.read<AppSettings>(),
                          forceRefresh: true,
                        ),
                icon: const Icon(Icons.refresh),
              ),
              IconButton(
                tooltip: '保存',
                onPressed: model.isLoading
                    ? null
                    : () => _handleSave(context, model),
                icon: const Icon(Icons.save),
              ),
              const SizedBox(width: 8),
            ],
            child: model.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildContent(context, model),
          );
        },
      ),
    );
  }

  Future<void> _handleSave(BuildContext context, MappingViewModel model) async {
    try {
      if (_segment == _MappingSegment.bangumi) {
        await model.saveConfig();
      } else {
        await model.saveBindings();
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存成功')),
      );
    } catch (error, stackTrace) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('保存失败，请稍后重试'),
          action: SnackBarAction(
            label: '详情',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => ErrorDetailDialog(
                  error: error,
                  stackTrace: stackTrace,
                ),
              );
            },
          ),
        ),
      );
    }
  }

  Widget _buildContent(BuildContext context, MappingViewModel model) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = Breakpoints.isNarrow(constraints.maxWidth);
        final maxWidth = Breakpoints.contentWidth(constraints.maxWidth);
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: isNarrow ? 16 : 24,
                vertical: 16,
              ),
              children: [
                _buildHeader(context, model),
                const SizedBox(height: 16),
                _buildSegmentControl(context),
                const SizedBox(height: 16),
                if (model.error != null) _buildErrorBanner(context, model),
                if (_segment == _MappingSegment.bangumi)
                  _buildBangumiMapping(context, model)
                else
                  _buildNotionMapping(context, model),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, MappingViewModel model) {
    return Row(
      children: [
        Text(
          '映射配置',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const Spacer(),
        if (_segment == _MappingSegment.bangumi)
          OutlinedButton.icon(
            onPressed: model.isConfigured ? model.applyMagicMap : null,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('推荐配置'),
          ),
      ],
    );
  }

  Widget _buildSegmentControl(BuildContext context) {
    return SegmentedButton<_MappingSegment>(
      segments: const [
        ButtonSegment(
          value: _MappingSegment.bangumi,
          label: Text('Bangumi 映射'),
          icon: Icon(Icons.swap_horiz),
        ),
        ButtonSegment(
          value: _MappingSegment.notion,
          label: Text('Notion 映射'),
          icon: Icon(Icons.storage_rounded),
        ),
      ],
      selected: {_segment},
      onSelectionChanged: (values) {
        if (values.isEmpty) return;
        setState(() => _segment = values.first);
      },
    );
  }

  Widget _buildErrorBanner(BuildContext context, MappingViewModel model) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '加载映射配置失败，请稍后重试',
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBangumiMapping(BuildContext context, MappingViewModel model) {
    if (!model.isConfigured) {
      return _buildNoticeCard(
        context,
        '请先在设置页配置 Notion Token 与 Database ID，才能加载映射配置。',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= Breakpoints.wide;
        final table = _buildBangumiMappingTable(context, model);
        final preview = _buildPreviewCard(context, model);

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: table),
              const SizedBox(width: 20),
              Expanded(flex: 2, child: preview),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            table,
            const SizedBox(height: 16),
            preview,
          ],
        );
      },
    );
  }

  Widget _buildBangumiMappingTable(
    BuildContext context,
    MappingViewModel model,
  ) {
    final sections = _buildSections();
    return Column(
      children: [
        for (final section in sections) ...[
          _MappingSectionCard(
            section: section,
            fieldBuilder: (field) => _buildMappingRow(context, model, field),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildMappingRow(
    BuildContext context,
    MappingViewModel model,
    _MappingFieldDefinition field,
  ) {
    final config = model.config;
    final currentValue = field.getValue(config);
    final isEnabled = field.isEnabled?.call(config) ?? true;
    final canToggle = field.toggleable;

    final label = Row(
      children: [
        Text(
          field.label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isEnabled
                ? null
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (field.required)
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text('*', style: TextStyle(color: Colors.redAccent)),
          ),
        if (field.sourceType != null) ...[
          const SizedBox(width: 6),
          _buildTypeBadge(context, field.sourceType!, isSource: true),
        ],
        if (field.helpText != null) ...[
          const SizedBox(width: 6),
          Tooltip(
            message: field.helpText!,
            child: Icon(
              Icons.help_outline,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ],
    );

    Widget inputWidget;
    Widget trailing = const SizedBox.shrink();
    Widget? arrow;

    if (field.input == _MappingFieldInput.text) {
      inputWidget = TextFormField(
        initialValue: currentValue,
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(),
        ),
        onChanged:
            isEnabled ? (value) => model.updateConfig(field.setValue(config, value)) : null,
      );
    } else {
      final properties = model.optionsFor(field.type, currentValue);
      final currentProperty = properties.firstWhere(
        (prop) => prop.name == currentValue,
        orElse: () => NotionProperty(name: currentValue, type: ''),
      );
      final showWarning =
          currentValue.isNotEmpty && currentProperty.type == 'unknown';

      inputWidget = DropdownButtonFormField<String>(
        initialValue: currentValue.isEmpty ? null : currentValue,
        isExpanded: true,
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(),
        ),
        items: properties.map((prop) {
          return DropdownMenuItem(
            value: prop.name,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    prop.name.isEmpty ? '未选择' : prop.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (prop.type.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _buildTypeBadge(context, prop.type),
                ],
              ],
            ),
          );
        }).toList(),
        onChanged: isEnabled
            ? (value) => model.updateConfig(
                  field.setValue(config, value ?? ''),
                )
            : null,
      );

      arrow = Icon(
        Icons.arrow_forward_rounded,
        color: Theme.of(context).colorScheme.primary,
      );

      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showWarning)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(Icons.warning_amber_rounded, color: Colors.orange),
            ),
          if (currentProperty.type.isNotEmpty)
            _buildTypeBadge(context, currentProperty.type),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 720;
        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (canToggle)
                    Checkbox(
                      value: isEnabled,
                      onChanged: field.required
                          ? null
                          : (value) => model.updateConfig(
                                field.setEnabled?.call(config, value ?? true) ??
                                    config,
                              ),
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(child: label),
                ],
              ),
              const SizedBox(height: 8),
              if (field.input == _MappingFieldInput.text)
                inputWidget
              else
                Row(
                  children: [
                    Expanded(child: inputWidget),
                    const SizedBox(width: 8),
                    trailing,
                  ],
                ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (canToggle)
              Checkbox(
                value: isEnabled,
                onChanged: field.required
                    ? null
                    : (value) => model.updateConfig(
                          field.setEnabled?.call(config, value ?? true) ??
                              config,
                        ),
              )
            else
              const SizedBox(width: 48),
            Expanded(flex: 3, child: label),
            const SizedBox(width: 12),
            if (arrow != null) ...[
              arrow,
              const SizedBox(width: 12),
            ],
            Expanded(flex: 4, child: inputWidget),
            if (arrow != null) ...[
              const SizedBox(width: 8),
              trailing,
            ],
          ],
        );
      },
    );
  }

  Widget _buildPreviewCard(BuildContext context, MappingViewModel model) {
    final colorScheme = Theme.of(context).colorScheme;
    final config = model.config;
    final previewItems = <_PreviewItem>[
      _PreviewItem('标题', '葬送的芙莉莲', config.title, config.titleEnabled),
      _PreviewItem('评分', '7.5', config.score, config.scoreEnabled),
      _PreviewItem('放送日期', '2024-02-05', config.airDate, config.airDateEnabled),
      _PreviewItem('放送区间', '2024-02-05 ~ 2024-05-30', config.airDateRange,
          config.airDateRangeEnabled),
      _PreviewItem('标签', '治愈 / 冒险', config.tags, config.tagsEnabled),
      _PreviewItem('封面', 'cover_url', config.imageUrl, config.imageUrlEnabled),
    ];
    final visibleItems = previewItems
        .where((item) => item.targetField.isNotEmpty && item.enabled)
        .take(6)
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '预览示例',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          if (visibleItems.isEmpty)
            Text(
              '请选择映射字段后查看预览。',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            )
          else
            ...visibleItems.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        item.sourceLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text(
                        '${item.targetField} · ${item.sampleValue}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            '数据流向：Bangumi → Notion',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: colorScheme.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildNotionMapping(BuildContext context, MappingViewModel model) {
    return NotionMappingPanel(
      isLoading: model.isLoading,
      isConfigured: model.isConfigured,
      properties: model.notionProperties,
      bindings: model.bindings,
      onBindingsChanged: model.updateBindings,
      embedInScroll: true,
    );
  }

  Widget _buildNoticeCard(BuildContext context, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildTypeBadge(
    BuildContext context,
    String type, {
    bool isSource = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = _typeLabel(type);
    final color = isSource
        ? colorScheme.primary
        : _typeColor(type, colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'title':
        return 'Title';
      case 'rich_text':
        return 'Text';
      case 'number':
        return 'Num';
      case 'date':
        return 'Date';
      case 'multi_select':
        return 'Tag';
      case 'select':
        return 'Select';
      case 'files':
        return 'Files';
      case 'url':
        return 'URL';
      case 'page_content':
        return 'Page';
      case 'status':
        return 'Status';
      case 'formula':
        return 'Formula';
      case 'rollup':
        return 'Rollup';
      default:
        return type.isEmpty ? '-' : type;
    }
  }

  Color _typeColor(String type, ColorScheme scheme) {
    switch (type) {
      case 'title':
        return scheme.primary;
      case 'number':
        return scheme.tertiary;
      case 'date':
        return scheme.secondary;
      case 'multi_select':
        return scheme.secondaryContainer;
      case 'url':
        return scheme.primaryContainer;
      case 'files':
        return scheme.tertiaryContainer;
      case 'page_content':
        return scheme.primary;
      default:
        return scheme.onSurfaceVariant;
    }
  }

  List<_MappingSection> _buildSections() {
    return [
      _MappingSection(
        title: '核心字段',
        initiallyExpanded: true,
        fields: [
          _MappingFieldDefinition.required(
            key: 'title',
            label: '标题',
            sourceType: 'String',
            type: MappingFieldType.title,
            getValue: (config) => config.title,
            setValue: (config, value) => config.copyWith(title: value),
            isEnabled: (config) => config.titleEnabled,
            setEnabled: (config, value) =>
                config.copyWith(titleEnabled: value),
          ),
          _MappingFieldDefinition.dropdown(
            key: 'score',
            label: '评分',
            sourceType: 'Number',
            type: MappingFieldType.number,
            getValue: (config) => config.score,
            setValue: (config, value) => config.copyWith(score: value),
            isEnabled: (config) => config.scoreEnabled,
            setEnabled: (config, value) =>
                config.copyWith(scoreEnabled: value),
          ),
          _MappingFieldDefinition.dropdown(
            key: 'bangumiId',
            label: 'Bangumi ID',
            sourceType: 'Number',
            type: MappingFieldType.number,
            getValue: (config) => config.bangumiId,
            setValue: (config, value) => config.copyWith(bangumiId: value),
            isEnabled: (config) => config.bangumiIdEnabled,
            setEnabled: (config, value) =>
                config.copyWith(bangumiIdEnabled: value),
          ),
          _MappingFieldDefinition.dropdown(
            key: 'imageUrl',
            label: '封面',
            sourceType: 'Files',
            type: MappingFieldType.cover,
            getValue: (config) => config.imageUrl,
            setValue: (config, value) => config.copyWith(imageUrl: value),
            isEnabled: (config) => config.imageUrlEnabled,
            setEnabled: (config, value) =>
                config.copyWith(imageUrlEnabled: value),
          ),
          _MappingFieldDefinition.dropdown(
            key: 'tags',
            label: '标签',
            sourceType: 'Tags',
            type: MappingFieldType.tags,
            getValue: (config) => config.tags,
            setValue: (config, value) => config.copyWith(tags: value),
            isEnabled: (config) => config.tagsEnabled,
            setEnabled: (config, value) => config.copyWith(tagsEnabled: value),
          ),
          _MappingFieldDefinition.dropdown(
            key: 'totalEpisodes',
            label: '总集数',
            sourceType: 'Number',
            type: MappingFieldType.number,
            getValue: (config) => config.totalEpisodes,
            setValue: (config, value) =>
                config.copyWith(totalEpisodes: value),
            isEnabled: (config) => config.totalEpisodesEnabled,
            setEnabled: (config, value) =>
                config.copyWith(totalEpisodesEnabled: value),
          ),
          _MappingFieldDefinition.dropdown(
            key: 'link',
            label: 'Bangumi 链接',
            sourceType: 'URL',
            type: MappingFieldType.url,
            getValue: (config) => config.link,
            setValue: (config, value) => config.copyWith(link: value),
            isEnabled: (config) => config.linkEnabled,
            setEnabled: (config, value) => config.copyWith(linkEnabled: value),
          ),
        ],
      ),
      _MappingSection(
        title: '日期信息',
        initiallyExpanded: true,
        fields: [
          _MappingFieldDefinition.dropdown(
            key: 'airDate',
            label: '放送开始',
            sourceType: 'Date',
            type: MappingFieldType.date,
            getValue: (config) => config.airDate,
            setValue: (config, value) => config.copyWith(airDate: value),
            isEnabled: (config) => config.airDateEnabled,
            setEnabled: (config, value) =>
                config.copyWith(airDateEnabled: value),
          ),
          _MappingFieldDefinition.dropdown(
            key: 'airDateRange',
            label: '放送区间',
            sourceType: 'Date',
            type: MappingFieldType.dateRange,
            getValue: (config) => config.airDateRange,
            setValue: (config, value) =>
                config.copyWith(airDateRange: value),
            isEnabled: (config) => config.airDateRangeEnabled,
            setEnabled: (config, value) =>
                config.copyWith(airDateRangeEnabled: value),
          ),
        ],
      ),
      _MappingSection(
        title: '制作人员',
        initiallyExpanded: false,
        fields: [
          _MappingFieldDefinition.dropdown(
            key: 'animationProduction',
            label: '动画制作',
            sourceType: 'Text',
            type: MappingFieldType.richText,
            getValue: (config) => config.animationProduction,
            setValue: (config, value) =>
                config.copyWith(animationProduction: value),
            isEnabled: (config) => config.animationProductionEnabled,
            setEnabled: (config, value) =>
                config.copyWith(animationProductionEnabled: value),
          ),
          _MappingFieldDefinition.dropdown(
            key: 'director',
            label: '导演',
            sourceType: 'Text',
            type: MappingFieldType.richText,
            getValue: (config) => config.director,
            setValue: (config, value) => config.copyWith(director: value),
            isEnabled: (config) => config.directorEnabled,
            setEnabled: (config, value) =>
                config.copyWith(directorEnabled: value),
          ),
          _MappingFieldDefinition.dropdown(
            key: 'script',
            label: '脚本',
            sourceType: 'Text',
            type: MappingFieldType.richText,
            getValue: (config) => config.script,
            setValue: (config, value) => config.copyWith(script: value),
            isEnabled: (config) => config.scriptEnabled,
            setEnabled: (config, value) => config.copyWith(scriptEnabled: value),
          ),
          _MappingFieldDefinition.dropdown(
            key: 'storyboard',
            label: '分镜',
            sourceType: 'Text',
            type: MappingFieldType.richText,
            getValue: (config) => config.storyboard,
            setValue: (config, value) => config.copyWith(storyboard: value),
            isEnabled: (config) => config.storyboardEnabled,
            setEnabled: (config, value) =>
                config.copyWith(storyboardEnabled: value),
          ),
        ],
      ),
      _MappingSection(
        title: '内容信息',
        initiallyExpanded: false,
        fields: [
          _MappingFieldDefinition.dropdown(
            key: 'description',
            label: '简介/正文',
            sourceType: 'Text',
            type: MappingFieldType.richText,
            getValue: (config) => config.description,
            setValue: (config, value) => config.copyWith(description: value),
            isEnabled: (config) => config.descriptionEnabled,
            setEnabled: (config, value) =>
                config.copyWith(descriptionEnabled: value),
          ),
        ],
      ),
      _MappingSection(
        title: '身份绑定',
        subtitle: '用于防止重复同步，推荐保持默认字段。',
        initiallyExpanded: false,
        fields: [
          _MappingFieldDefinition.text(
            key: 'idPropertyName',
            label: 'Bangumi ID 字段',
            sourceType: 'Number',
            type: MappingFieldType.number,
            helpText: '用于防止重复同步，导入时会写入该字段。',
            getValue: (config) => config.idPropertyName,
            setValue: (config, value) =>
                config.copyWith(idPropertyName: value),
          ),
          _MappingFieldDefinition.text(
            key: 'notionId',
            label: 'Notion ID 字段',
            sourceType: 'Text',
            type: MappingFieldType.richText,
            helpText: '当需要使用 Notion ID 绑定已有页面时使用。',
            getValue: (config) => config.notionId,
            setValue: (config, value) => config.copyWith(notionId: value),
          ),
        ],
      ),
      _MappingSection(
        title: '追番进度',
        initiallyExpanded: false,
        fields: [
          _MappingFieldDefinition.dropdown(
            key: 'watchingStatus',
            label: '追番状态字段',
            sourceType: 'Status',
            type: MappingFieldType.status,
            getValue: (config) => config.watchingStatus,
            setValue: (config, value) =>
                config.copyWith(watchingStatus: value),
            isEnabled: (config) => true,
            setEnabled: (config, value) => config,
            toggleable: false,
          ),
          _MappingFieldDefinition.text(
            key: 'watchingStatusValue',
            label: '追番状态值',
            sourceType: 'Text',
            type: MappingFieldType.statusValue,
            getValue: (config) => config.watchingStatusValue,
            setValue: (config, value) =>
                config.copyWith(watchingStatusValue: value),
          ),
          _MappingFieldDefinition.dropdown(
            key: 'watchedEpisodes',
            label: '已追集数字段',
            sourceType: 'Number',
            type: MappingFieldType.number,
            getValue: (config) => config.watchedEpisodes,
            setValue: (config, value) =>
                config.copyWith(watchedEpisodes: value),
            isEnabled: (config) => true,
            setEnabled: (config, value) => config,
            toggleable: false,
          ),
        ],
      ),
    ];
  }
}

class _PreviewItem {
  final String sourceLabel;
  final String sampleValue;
  final String targetField;
  final bool enabled;

  _PreviewItem(
    this.sourceLabel,
    this.sampleValue,
    this.targetField,
    this.enabled,
  );
}

class _MappingSection {
  final String title;
  final String? subtitle;
  final bool initiallyExpanded;
  final List<_MappingFieldDefinition> fields;

  const _MappingSection({
    required this.title,
    required this.initiallyExpanded,
    required this.fields,
    this.subtitle,
  });
}

class _MappingSectionCard extends StatefulWidget {
  const _MappingSectionCard({
    required this.section,
    required this.fieldBuilder,
  });

  final _MappingSection section;
  final Widget Function(_MappingFieldDefinition) fieldBuilder;

  @override
  State<_MappingSectionCard> createState() => _MappingSectionCardState();
}

class _MappingSectionCardState extends State<_MappingSectionCard>
    with SingleTickerProviderStateMixin {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.section.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final title = Text(
      widget.section.title,
      style: textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
    final subtitle = widget.section.subtitle == null
        ? null
        : Text(
            widget.section.subtitle!,
            style: textTheme.bodySmall,
          );

    final header = InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _expanded = !_expanded),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    subtitle,
                  ],
                ],
              ),
            ),
            AnimatedRotation(
              turns: _expanded ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: const Icon(Icons.expand_more),
            ),
          ],
        ),
      ),
    );

    final body = _expanded
        ? Column(
            children: [
              const SizedBox(height: 8),
              for (final field in widget.section.fields)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: widget.fieldBuilder(field),
                ),
            ],
          )
        : const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: body,
          ),
        ),
      ],
    );
  }
}

enum _MappingFieldInput {
  dropdown,
  text,
}

class _MappingFieldDefinition {
  final String key;
  final String label;
  final String? sourceType;
  final String? helpText;
  final MappingFieldType type;
  final _MappingFieldInput input;
  final bool required;
  final bool toggleable;
  final String Function(MappingConfig) getValue;
  final MappingConfig Function(MappingConfig, String) setValue;
  final bool Function(MappingConfig)? isEnabled;
  final MappingConfig Function(MappingConfig, bool)? setEnabled;

  const _MappingFieldDefinition({
    required this.key,
    required this.label,
    required this.sourceType,
    required this.helpText,
    required this.type,
    required this.input,
    required this.required,
    required this.toggleable,
    required this.getValue,
    required this.setValue,
    this.isEnabled,
    this.setEnabled,
  });

  factory _MappingFieldDefinition.required({
    required String key,
    required String label,
    required String sourceType,
    required MappingFieldType type,
    required String Function(MappingConfig) getValue,
    required MappingConfig Function(MappingConfig, String) setValue,
    required bool Function(MappingConfig) isEnabled,
    required MappingConfig Function(MappingConfig, bool) setEnabled,
    String? helpText,
  }) {
    return _MappingFieldDefinition(
      key: key,
      label: label,
      sourceType: sourceType,
      helpText: helpText,
      type: type,
      input: _MappingFieldInput.dropdown,
      required: true,
      toggleable: true,
      getValue: getValue,
      setValue: setValue,
      isEnabled: isEnabled,
      setEnabled: setEnabled,
    );
  }

  factory _MappingFieldDefinition.dropdown({
    required String key,
    required String label,
    required String sourceType,
    required MappingFieldType type,
    required String Function(MappingConfig) getValue,
    required MappingConfig Function(MappingConfig, String) setValue,
    required bool Function(MappingConfig) isEnabled,
    required MappingConfig Function(MappingConfig, bool) setEnabled,
    bool toggleable = true,
    String? helpText,
  }) {
    return _MappingFieldDefinition(
      key: key,
      label: label,
      sourceType: sourceType,
      helpText: helpText,
      type: type,
      input: _MappingFieldInput.dropdown,
      required: false,
      toggleable: toggleable,
      getValue: getValue,
      setValue: setValue,
      isEnabled: isEnabled,
      setEnabled: setEnabled,
    );
  }

  factory _MappingFieldDefinition.text({
    required String key,
    required String label,
    required String sourceType,
    required MappingFieldType type,
    required String Function(MappingConfig) getValue,
    required MappingConfig Function(MappingConfig, String) setValue,
    String? helpText,
  }) {
    return _MappingFieldDefinition(
      key: key,
      label: label,
      sourceType: sourceType,
      helpText: helpText,
      type: type,
      input: _MappingFieldInput.text,
      required: false,
      toggleable: false,
      getValue: getValue,
      setValue: setValue,
    );
  }
}
