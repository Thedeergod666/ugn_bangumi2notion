# Review Findings Fixes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove misleading unused settings, fix cache scoping bugs and the OAuth callback race, and leave the project passing tests, analysis, and key builds.

**Architecture:** Keep the product scope narrow. Remove only the dead UI for extra Notion databases, make OAuth callback capture deterministic by preparing the completer before launch, and align recommendation and batch-import caches with the already scoped database-aware cache pattern used elsewhere.

**Tech Stack:** Flutter, Dart, provider, flutter_test, shared_preferences, local loopback HTTP server for desktop OAuth.

---

### Task 1: Add failing tests for settings UI copy and hidden unused database fields

**Files:**
- Modify: `test/features/settings/batch_import_page_layout_test.dart`
- Modify: `test/widget_test.dart` or add a focused settings UI/widget test file
- Test: `test/features/settings/...`

**Step 1: Write the failing test**

Add widget assertions that:

- the database settings screen does not render movie/game database ID inputs;
- the settings entry copy for batch import no longer implies full-library coverage;
- the batch import screen includes helper text describing the limited scan.

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/settings/batch_import_page_layout_test.dart`
Expected: FAIL because the old helper text and extra fields are still present.

**Step 3: Write minimal implementation**

Update the relevant settings widgets to remove the unused text fields and adjust copy only where needed.

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/settings/batch_import_page_layout_test.dart`
Expected: PASS

### Task 2: Add failing tests for scoped recommendation daily cache

**Files:**
- Modify: `test/features/dashboard/recommendation_view_model_cache_test.dart`
- Modify: `lib/core/database/settings_storage.dart`
- Modify: `lib/features/dashboard/providers/recommendation_view_model.dart`

**Step 1: Write the failing test**

Add a test that saves a daily recommendation cache payload under one database scope, then loads the view model under another database scope and asserts the old daily payload is ignored.

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/dashboard/recommendation_view_model_cache_test.dart`
Expected: FAIL because daily cache is currently global.

**Step 3: Write minimal implementation**

Move daily recommendation cache storage onto scoped payload helpers and make the view model read/write with `_cacheScope()`.

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/dashboard/recommendation_view_model_cache_test.dart`
Expected: PASS

### Task 3: Add failing tests for scoped batch import in-memory cache

**Files:**
- Add or modify: `test/features/settings/batch_import_view_model_cache_test.dart`
- Modify: `lib/features/settings/providers/batch_import_view_model.dart`

**Step 1: Write the failing test**

Add a test that:

- primes batch import cache for database A;
- constructs a new view model for database B in the same process;
- asserts it does not restore candidates from database A.

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/settings/batch_import_view_model_cache_test.dart`
Expected: FAIL because `_candidateCache` is currently global and unsafely reused.

**Step 3: Write minimal implementation**

Replace the single static list cache with a scope-keyed cache map and make restore/save paths respect the active scope.

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/settings/batch_import_view_model_cache_test.dart`
Expected: PASS

### Task 4: Add failing test for OAuth callback race

**Files:**
- Add: `test/core/network/bangumi_oauth_test.dart`
- Modify: `lib/core/network/bangumi_oauth.dart`

**Step 1: Write the failing test**

Add a test that starts the local OAuth server, delivers a valid callback before `waitForCode()` attaches late, and asserts the code is still returned successfully.

**Step 2: Run test to verify it fails**

Run: `flutter test test/core/network/bangumi_oauth_test.dart`
Expected: FAIL or timeout because the callback code is currently dropped.

**Step 3: Write minimal implementation**

Initialize the authorization completer for the full server lifetime before the browser callback can arrive, and let `waitForCode()` await that existing completer.

**Step 4: Run test to verify it passes**

Run: `flutter test test/core/network/bangumi_oauth_test.dart`
Expected: PASS

### Task 5: Clean analyzer warnings and web bootstrap deprecations

**Files:**
- Modify: `lib/core/theme/kazumi_theme.dart`
- Modify: `lib/features/airing_calendar/presentation/calendar_view.dart`
- Modify: `test/features/dashboard/recommendation_recent_layout_test.dart`
- Modify: `web/index.html`

**Step 1: Write or update focused assertions if needed**

Only add tests if copy or behavior changes require them. Analyzer-only cleanups can proceed directly after the earlier failing tests are in place.

**Step 2: Run analyzer to capture current failures**

Run: `flutter analyze`
Expected: existing warnings for unused field, unused import, interpolation style, and deprecated web bootstrap template warnings during web build.

**Step 3: Write minimal implementation**

- remove the dead `_cardRadius` field;
- simplify the string interpolation;
- remove the unused test import;
- update `web/index.html` to current Flutter loader template.

**Step 4: Verify the cleanup**

Run: `flutter analyze`
Expected: PASS with no issues

### Task 6: Full regression verification

**Files:**
- Verify entire worktree

**Step 1: Run targeted tests**

Run:
- `flutter test test/features/dashboard/recommendation_view_model_cache_test.dart`
- `flutter test test/features/settings/batch_import_page_layout_test.dart`
- `flutter test test/features/settings/batch_import_view_model_cache_test.dart`
- `flutter test test/core/network/bangumi_oauth_test.dart`

Expected: PASS

**Step 2: Run full suite**

Run: `flutter test`
Expected: PASS

**Step 3: Run static analysis**

Run: `flutter analyze`
Expected: PASS

**Step 4: Run key builds**

Run:
- `flutter build web`
- `flutter build windows`

Expected: both succeed

**Step 5: Review diff**

Run: `git status --short`

Expected: only intended source, test, web, and docs changes plus the local worktree `.env` placeholder.
