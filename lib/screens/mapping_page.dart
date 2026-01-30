import 'package:flutter/material.dart';
import '../models/mapping_config.dart';
import '../services/notion_api.dart';
import '../services/settings_storage.dart';
import '../widgets/navigation_shell.dart';

class MappingPage extends StatefulWidget {
  const MappingPage({super.key});

  @override
  State<MappingPage> createState() => _MappingPageState();
}

class _MappingPageState extends State<MappingPage> {
  final NotionApi _notionApi = NotionApi();
  final SettingsStorage _settingsStorage = SettingsStorage();

  bool _isLoading = true;
  List<String> _notionProperties = [];
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return NavigationShell(
      title: '字段映射设置',
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
                    const Text(
                      '字段映射配置',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    _buildMappingItem('标题 (Name)', _currentConfig.title, (val) {
                      setState(() => _currentConfig = _currentConfig.copyWith(title: val));
                    }),
                    _buildMappingItem('放送开始 (Date)', _currentConfig.airDate, (val) {
                      setState(() => _currentConfig = _currentConfig.copyWith(airDate: val));
                    }),
                    _buildMappingItem('标签 (Multi-select)', _currentConfig.tags, (val) {
                      setState(() => _currentConfig = _currentConfig.copyWith(tags: val));
                    }),
                    _buildMappingItem('封面 (Url)', _currentConfig.imageUrl, (val) {
                      setState(() => _currentConfig = _currentConfig.copyWith(imageUrl: val));
                    }),
                    _buildMappingItem('Bangumi ID (Number)', _currentConfig.bangumiId, (val) {
                      setState(() => _currentConfig = _currentConfig.copyWith(bangumiId: val));
                    }),
                    _buildMappingItem('评分 (Number)', _currentConfig.score, (val) {
                      setState(() => _currentConfig = _currentConfig.copyWith(score: val));
                    }),
                    _buildMappingItem('链接 (Url)', _currentConfig.link, (val) {
                      setState(() => _currentConfig = _currentConfig.copyWith(link: val));
                    }),
                    _buildMappingItem('动画制作 (Rich Text)', _currentConfig.animationProduction, (val) {
                      setState(() => _currentConfig = _currentConfig.copyWith(animationProduction: val));
                    }),
                    _buildMappingItem('导演 (Rich Text)', _currentConfig.director, (val) {
                      setState(() => _currentConfig = _currentConfig.copyWith(director: val));
                    }),
                    _buildMappingItem('脚本 (Rich Text)', _currentConfig.script, (val) {
                      setState(() => _currentConfig = _currentConfig.copyWith(script: val));
                    }),
                    _buildMappingItem('分镜 (Rich Text)', _currentConfig.storyboard, (val) {
                      setState(() => _currentConfig = _currentConfig.copyWith(storyboard: val));
                    }),
                    _buildMappingItem('简介 (Page Content)', _currentConfig.content, (val) {
                      setState(() => _currentConfig = _currentConfig.copyWith(content: val));
                    }),
                    _buildMappingItem('描述 (Rich Text)', _currentConfig.description, (val) {
                      setState(() => _currentConfig = _currentConfig.copyWith(description: val));
                    }),
                    _buildMappingItem('Bangumi ID 属性 (Property Name)', _currentConfig.idPropertyName, (val) {
                      setState(() => _currentConfig = _currentConfig.copyWith(idPropertyName: val));
                    }),
                    const SizedBox(height: 24),
                  ],
                ),
    );
  }

  Widget _buildMappingItem(String label, String currentValue, ValueChanged<String?> onChanged) {
    // 确保当前值在选项列表中，如果不在则添加（可能是之前保存的但现在数据库里没了，或者初始默认值）
    // 同时确保包含一个空字符串选项，用于“置空”
    final List<String> items = ['', ..._notionProperties];
    if (currentValue.isNotEmpty && !items.contains(currentValue)) {
      items.add(currentValue);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              initialValue: currentValue,
              items: items.toSet().map((prop) {
                // 如果 prop 为空或 null，显示为空字符串
                final displayText = prop;
                return DropdownMenuItem(
                  value: prop,
                  child: Text(displayText, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: onChanged,
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
