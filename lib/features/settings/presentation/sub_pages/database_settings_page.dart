import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/app_services.dart';
import '../../../../app/app_settings.dart';
import '../../../../core/widgets/navigation_shell.dart';
import '../../providers/database_settings_view_model.dart';
import 'database_settings_view.dart';

class DatabaseSettingsPage extends StatefulWidget {
  const DatabaseSettingsPage({super.key});

  @override
  State<DatabaseSettingsPage> createState() => _DatabaseSettingsPageState();
}

class _DatabaseSettingsPageState extends State<DatabaseSettingsPage> {
  late final DatabaseSettingsViewModel _viewModel;

  final _notionTokenController = TextEditingController();
  final _notionDbController = TextEditingController();
  final _notionMovieDbController = TextEditingController();
  final _notionGameDbController = TextEditingController();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _viewModel = DatabaseSettingsViewModel(
      notionApi: context.read<AppServices>().notionApi,
      settings: context.read<AppSettings>(),
    );
    _viewModel.addListener(_syncControllers);
    _viewModel.load();
  }

  void _syncControllers() {
    if (_initialized || _viewModel.isLoading) {
      return;
    }
    _initialized = true;
    _notionTokenController.text = _viewModel.notionToken;
    _notionDbController.text = _viewModel.notionDatabaseId;

    final settings = context.read<AppSettings>();
    _notionMovieDbController.text = settings.notionMovieDatabaseId;
    _notionGameDbController.text = settings.notionGameDatabaseId;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<void> _autoSaveNotionSettings() async {
    _viewModel.updateToken(_notionTokenController.text);
    _viewModel.updateDatabaseId(_notionDbController.text);
    await _viewModel.autoSave();
  }

  Future<void> _autoSaveExtraDatabases() async {
    final settings = context.read<AppSettings>();
    await settings.saveAdditionalNotionDatabases(
      movieDatabaseId: _notionMovieDbController.text.trim(),
      gameDatabaseId: _notionGameDbController.text.trim(),
    );
  }

  Future<void> _saveAll() async {
    _viewModel.updateToken(_notionTokenController.text);
    _viewModel.updateDatabaseId(_notionDbController.text);
    await _viewModel.saveAll();
    if (!mounted) return;
    if (_viewModel.errorMessage != null) {
      _showSnackBar(_viewModel.errorMessage!, isError: true);
    } else if (_viewModel.successMessage != null) {
      _showSnackBar(_viewModel.successMessage!);
    }
  }

  Future<void> _testNotionConnection() async {
    _viewModel.updateToken(_notionTokenController.text);
    _viewModel.updateDatabaseId(_notionDbController.text);
    await _viewModel.testConnection();
    if (!mounted) return;
    if (_viewModel.errorMessage != null) {
      _showSnackBar(_viewModel.errorMessage!, isError: true);
    } else if (_viewModel.successMessage != null) {
      _showSnackBar(_viewModel.successMessage!);
    }
  }

  Future<void> _openNotionIntegrations() async {
    await launchUrl(
      Uri.parse('https://www.notion.so/my-integrations'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  void dispose() {
    _viewModel.removeListener(_syncControllers);
    _viewModel.dispose();
    _notionTokenController.dispose();
    _notionDbController.dispose();
    _notionMovieDbController.dispose();
    _notionGameDbController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<DatabaseSettingsViewModel>(
        builder: (context, model, _) {
          final child = model.isLoading
              ? const Center(child: CircularProgressIndicator())
              : DatabaseSettingsView(
                  state: DatabaseSettingsViewState(
                    isSaving: model.isSaving,
                    errorMessage: model.errorMessage,
                    successMessage: model.successMessage,
                  ),
                  callbacks: DatabaseSettingsViewCallbacks(
                    onOpenNotionIntegrations: _openNotionIntegrations,
                    onSaveAll: () => unawaited(_saveAll()),
                    onTestConnection: () => unawaited(_testNotionConnection()),
                    onTokenChanged: (_) =>
                        unawaited(_autoSaveNotionSettings()),
                    onDatabaseIdChanged: (_) =>
                        unawaited(_autoSaveNotionSettings()),
                    onMovieDatabaseIdChanged: (_) =>
                        unawaited(_autoSaveExtraDatabases()),
                    onGameDatabaseIdChanged: (_) =>
                        unawaited(_autoSaveExtraDatabases()),
                  ),
                  notionTokenController: _notionTokenController,
                  notionDatabaseIdController: _notionDbController,
                  notionMovieDatabaseIdController: _notionMovieDbController,
                  notionGameDatabaseIdController: _notionGameDbController,
                );

          return NavigationShell(
            title: '数据绑定',
            selectedRoute: '/settings',
            onBack: () => Navigator.of(context).pop(),
            child: child,
          );
        },
      ),
    );
  }
}

