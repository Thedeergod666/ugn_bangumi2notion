import 'package:flutter/material.dart';
import '../models/mapping_config.dart';
import '../services/notion_api.dart';
import '../services/settings_storage.dart';
import '../widgets/navigation_shell.dart';
import '../models/notion_models.dart';
import '../widgets/error_detail_dialog.dart';

class MappingPage extends StatefulWidget {
  const MappingPage({super.key});

  @override
  State<MappingPage> createState() => _MappingPageState();
}

class _MappingPageState extends State<MappingPage> {
  final NotionApi _notionApi = NotionApi();
  final SettingsStorage _settingsStorage = SettingsStorage();

  bool _isLoading = true;
  List<NotionProperty> _notionProperties = [];
  MappingConfig _currentConfig = MappingConfig();
  String _notionToken = '';
  String _notionDatabaseId = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    try {
      final settings = await _settingsStorage.loadAll();
      _notionToken = settings[SettingsKeys.notionToken] ?? '';
      _notionDatabaseId = settings[SettingsKeys.notionDatabaseId] ?? '';
      _currentConfig = await _settingsStorage.getMappingConfig();

      if (_notionToken.isNotEmpty && _notionDatabaseId.isNotEmpty) {
        if (!forceRefresh) {
          _notionProperties = await _settingsStorage.getNotionProperties();
        }

        if (forceRefresh || _notionProperties.isEmpty) {
          _notionProperties = await _notionApi.getDatabaseProperties(
            token: _notionToken,
            databaseId: _notionDatabaseId,
          );
          await _settingsStorage.saveNotionProperties(_notionProperties);
        }
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('加载失败，请稍后重试'),
            action: SnackBarAction(
              label: '详情',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => ErrorDetailDialog(
                    error: e,
                    stackTrace: stackTrace,
                  ),
                );
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveConfig() async {
    try {
      await _settingsStorage.saveMappingConfig(_currentConfig);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存成功')),
        );
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('保存失败，请稍后重试'),
            action: SnackBarAction(
              label: '详情',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => ErrorDetailDialog(
                    error: e,
                    stackTrace: stackTrace,
                  ),
                );
              },
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return NavigationShell(
      title: '映射配置',
      selectedRoute: '/mapping',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: '刷新属性',
          onPressed: _isLoading ? null : () => _loadData(forceRefresh: true),
        ),
        IconButton(
          icon: const Icon(Icons.save),
          tooltip: '保存配置',
          onPressed: _isLoading ? null : _saveConfig,
        ),
        const SizedBox(width: 8),
      ],
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notionToken.isEmpty || _notionDatabaseId.isEmpty
              ? const Center(child: Text('请先在设置页面配置 Notion Token 和 Database ID'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Row 1: Column Headers (Bangumi Property / Notion Property)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8.0, horizontal: 4.0),
                      child: Row(
                        children: [
                          const SizedBox(width: 48), // 对齐带有复选框的字段
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Bangumi属性',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Notion属性',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Row 2: Divider
                    const Divider(),
                    // Row 3: Section Title "数据导入配置 (Data Import Config)"
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8.0, horizontal: 4.0),
                      child: Text(
                        '数据导入配置 (Data Import Config)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    // Row 4: The list of mapping fields
                    _buildMappingItem(
                      '标题 (Name)',
                      _currentConfig.title,
                      _currentConfig.titleEnabled,
                      (val) {
                        setState(() =>
                            _currentConfig = _currentConfig.copyWith(title: val));
                      },
                      (enabled) {
                        setState(() => _currentConfig =
                            _currentConfig.copyWith(titleEnabled: enabled));
                      },
                    ),
                    _buildMappingItem(
                      '放送开始 (Date)',
                      _currentConfig.airDate,
                      _currentConfig.airDateEnabled,
                      (val) {
                        setState(() => _currentConfig =
                            _currentConfig.copyWith(airDate: val));
                      },
                      (enabled) {
                        setState(() => _currentConfig =
                            _currentConfig.copyWith(airDateEnabled: enabled));
                      },
                    ),
                    _buildMappingItem(
                      '标签 (Multi-select)',
                      _currentConfig.tags,
                      _currentConfig.tagsEnabled,
                      (val) {
                        setState(() =>
                            _currentConfig = _currentConfig.copyWith(tags: val));
                      },
                      (enabled) {
                        setState(() => _currentConfig =
                            _currentConfig.copyWith(tagsEnabled: enabled));
                      },
                    ),
                    _buildMappingItem(
                      '封面 (Files & media)',
                      _currentConfig.imageUrl,
                      _currentConfig.imageUrlEnabled,
                      (val) {
                        setState(() => _currentConfig =
                            _currentConfig.copyWith(imageUrl: val));
                      },
                      (enabled) {
                        setState(() => _currentConfig =
                            _currentConfig.copyWith(imageUrlEnabled: enabled));
                      },
                    ),
                    _buildMappingItem(
                      'Bangumi ID (Number)',
                      _currentConfig.bangumiId,
                      _currentConfig.bangumiIdEnabled,
                      (val) {
                        setState(() => _currentConfig =
                            _currentConfig.copyWith(bangumiId: val));
                      },
                      (enabled) {
                        setState(() => _currentConfig =
                            _currentConfig.copyWith(bangumiIdEnabled: enabled));
                      },
                    ),
                    _buildMappingItem(
                      '评分 (Number)',
                      _currentConfig.score,
                      _currentConfig.scoreEnabled,
                      (val) {
                        setState(() =>
                            _currentConfig = _currentConfig.copyWith(score: val));
                      },
                      (enabled) {
                        setState(() => _currentConfig =
                            _currentConfig.copyWith(scoreEnabled: enabled));
                      },
                    ),
                    _buildMappingItem(
                      '链接 (Url)',
                      _currentConfig.link,
                      _currentConfig.linkEnabled,
                      (val) {
                        setState(() =>
                            _currentConfig = _currentConfig.copyWith(link: val));
                      },
                      (enabled) {
                        setState(() => _currentConfig =
                            _currentConfig.copyWith(linkEnabled: enabled));
                      },
                    ),
                    _buildMappingItem(
                      '动画制作 (Rich Text)',
                      _currentConfig.animationProduction,
                      _currentConfig.animationProductionEnabled,
                      (val) {
                        setState(() => _currentConfig =
                            _currentConfig.copyWith(animationProduction: val));
                      },
                      (enabled) {
                        setState(() => _currentConfig = _currentConfig.copyWith(
                            animationProductionEnabled: enabled));
                      },
                    ),
                    _buildMappingItem(
                      '导演 (Rich Text)',
                      _currentConfig.director,
                      _currentConfig.directorEnabled,
                      (val) {
                        setState(() => _currentConfig =
                            _currentConfig.copyWith(director: val));
                      },
                      (enabled) {
                        setState(() => _currentConfig =
                            _currentConfig.copyWith(directorEnabled: enabled));
                      },
                    ),
                    _buildMappingItem(
                      '脚本 (Rich Text)',
                      _currentConfig.script,
                      _currentConfig.scriptEnabled,
                      (val) {
                        setState(() =>
                            _currentConfig = _currentConfig.copyWith(script: val));
                      },
                      (enabled) {
                        setState(() => _currentConfig =
                            _currentConfig.copyWith(scriptEnabled: enabled));
                      },
                    ),
                    _buildMappingItem(
                      '分镜 (Rich Text)',
                      _currentConfig.storyboard,
                      _currentConfig.storyboardEnabled,
                      (val) {
                        setState(() => _currentConfig =
                            _currentConfig.copyWith(storyboard: val));
                      },
                      (enabled) {
                        setState(() => _currentConfig =
                            _currentConfig.copyWith(storyboardEnabled: enabled));
                      },
                    ),
                    _buildMappingItem(
                      '简介 (Rich Text)',
                      _currentConfig.content,
                      _currentConfig.contentEnabled,
                      (val) {
                        setState(() => _currentConfig =
                            _currentConfig.copyWith(content: val));
                      },
                      (enabled) {
                        setState(() => _currentConfig =
                            _currentConfig.copyWith(contentEnabled: enabled));
                      },
                    ),
                    _buildMappingItem(
                      '描述 (Rich Text)',
                      _currentConfig.description,
                      _currentConfig.descriptionEnabled,
                      (val) {
                        setState(() => _currentConfig =
                            _currentConfig.copyWith(description: val));
                      },
                      (enabled) {
                        setState(() => _currentConfig =
                            _currentConfig.copyWith(descriptionEnabled: enabled));
                      },
                    ),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8.0, horizontal: 4.0),
                      child: Text(
                        '身份绑定配置 (Identity Binding Config)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    _buildMappingItem(
                      'Bangumi ID 属性 (For Page Binding)',
                      _currentConfig.idPropertyName,
                      true,
                      (val) {
                        setState(() => _currentConfig =
                            _currentConfig.copyWith(idPropertyName: val));
                      },
                      null,
                    ),
                    _buildMappingItem(
                      'Notion ID 属性 (For Page Binding)',
                      _currentConfig.notionId,
                      true,
                      (val) {
                        setState(() =>
                            _currentConfig = _currentConfig.copyWith(notionId: val));
                      },
                      null,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
    );
  }

  Widget _buildMappingItem(
    String label,
    String currentValue,
    bool isEnabled,
    ValueChanged<String?> onChanged,
    ValueChanged<bool?>? onEnabledChanged,
  ) {
    final List<NotionProperty> items = [
      NotionProperty(name: '', type: ''),
      NotionProperty(name: '正文', type: 'page_content'),
      ..._notionProperties
    ];

    final bool exists = items.any((p) => p.name == currentValue);
    if (currentValue.isNotEmpty && !exists) {
      items.add(NotionProperty(name: currentValue, type: 'unknown'));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          if (onEnabledChanged != null)
            Checkbox(
              value: isEnabled,
              onChanged: onEnabledChanged,
            )
          else
            const SizedBox(width: 48), // 对齐没有 Checkbox 的项
          Expanded(
            flex: 3,
            child: Text(label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isEnabled ? null : Theme.of(context).disabledColor,
                )),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              value: currentValue,
              items: items.map((prop) {
                return DropdownMenuItem(
                  value: prop.name,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          prop.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (prop.type.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          '(${prop.type})',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).disabledColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
              onChanged: isEnabled ? onChanged : null,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
