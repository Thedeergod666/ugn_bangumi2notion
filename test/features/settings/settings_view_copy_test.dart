import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_utools/features/settings/presentation/settings_view.dart';
import 'package:flutter_utools/features/settings/presentation/sub_pages/database_settings_view.dart';

SettingsView _buildSettingsView() {
  return SettingsView(
    oauthCallbackUrl: 'http://localhost:8080/auth/callback',
    state: const SettingsViewState(
      isLoading: false,
      isSaving: false,
      isBangumiLoading: false,
      bangumiHasToken: false,
      bangumiTokenValid: false,
      bangumiUserLabel: 'Guest',
      errorMessage: null,
      successMessage: null,
    ),
    callbacks: SettingsViewCallbacks(
      onAuthorize: () {},
      onLogout: () {},
      onRefreshBangumiStatus: () {},
      onOpenDatabaseSettings: () {},
      onOpenMapping: () {},
      onOpenBatchImport: () {},
      onOpenAppearance: () {},
      onOpenErrorLog: () {},
      onCopyOAuthCallbackUrl: () {},
    ),
  );
}

DatabaseSettingsView _buildDatabaseSettingsView() {
  return DatabaseSettingsView(
    state: const DatabaseSettingsViewState(
      isSaving: false,
      errorMessage: null,
      successMessage: null,
    ),
    callbacks: DatabaseSettingsViewCallbacks(
      onOpenNotionIntegrations: () {},
      onSaveAll: () {},
      onTestConnection: () {},
      onTokenChanged: (_) {},
      onDatabaseIdChanged: (_) {},
      onMovieDatabaseIdChanged: (_) {},
      onGameDatabaseIdChanged: (_) {},
    ),
    notionTokenController: TextEditingController(),
    notionDatabaseIdController: TextEditingController(),
    notionMovieDatabaseIdController: TextEditingController(),
    notionGameDatabaseIdController: TextEditingController(),
  );
}

void main() {
  testWidgets('settings view labels batch import as limited recent scan',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _buildSettingsView(),
        ),
      ),
    );

    expect(find.textContaining('30'), findsOneWidget);
  });

  testWidgets('database settings view only shows primary database inputs',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _buildDatabaseSettingsView(),
        ),
      ),
    );

    expect(find.byType(TextField), findsNWidgets(2));
  });
}
