# Review Findings Fixes Design

**Date:** 2026-03-15

**Goal:** Fix the concrete issues discovered in the project review without expanding scope into new product behavior.

## Scope

This change set addresses five user-visible or correctness-impacting issues:

1. Remove the unused movie/game Notion database settings from the UI because they are not wired into runtime behavior.
2. Fix the Bangumi OAuth local callback race that can drop the authorization code.
3. Scope daily recommendation cache by active Notion database to prevent cross-database data bleed.
4. Scope batch import in-memory cache by active Notion database to prevent cross-database candidate bleed.
5. Make the batch import UI accurately describe the current `limit: 30` behavior instead of implying whole-library coverage.

This pass also cleans the existing analyzer findings and updates the web bootstrap template to remove deprecation warnings discovered during the review.

## Product Decisions

### Unused multi-database settings

The movie/game database inputs will be removed from settings surfaces for now. We are intentionally not implementing multi-database routing in this fix because:

- the current behavior always uses the main Notion database;
- leaving the extra inputs visible is misleading;
- routing by media type would require broader product decisions and additional tests.

Existing storage keys can stay in place for backward compatibility. The fix is limited to removing dead UI and dead callback plumbing from the current settings flow.

### Batch import scope messaging

The current batch import logic fetches up to 30 unbound Notion pages. That behavior stays unchanged in this pass, but the entry text and page helper text will explicitly describe the limited scan so users are not told it is a full bulk import.

## Architecture

### OAuth race fix

The root cause is that the callback server can receive the browser redirect before `waitForCode()` creates `_codeCompleter`. The callback handler therefore has nowhere to store the code.

The fix is to make the local OAuth server own a single completer for the full authorization session and initialize it before the browser is launched. `waitForCode()` will reuse that completer instead of creating it late.

This keeps the public `BangumiOAuth.authorize()` shape intact while making the callback handling deterministic.

### Scoped caches

Recommendation daily cache currently uses global keys, unlike stats/recent caches that already use scoped payloads. The fix will move daily cache onto the same scoped payload mechanism with a database-aware scope derived from the active Notion database ID.

Batch import currently keeps a static in-memory list with no scope check. The fix will change that cache to a map keyed by database scope so switching databases in the same process cannot reuse stale candidates from another library.

## Testing Strategy

Tests will be added before implementation for:

- settings UI no longer exposing the unused movie/game database fields;
- settings navigation text reflecting the limited batch import scan;
- daily recommendation cache ignoring data saved under another database scope;
- batch import in-memory cache only restoring candidates for the active database;
- OAuth callback server successfully returning a code even if the callback arrives immediately after the server starts.

Existing analyzer cleanup and web bootstrap updates will be verified through `flutter analyze` and `flutter build web`.

## Risks And Mitigations

- Changing daily cache storage format could invalidate old same-day cache. This is acceptable because recommendation data is disposable and can be rebuilt on next load.
- OAuth changes touch live authorization flow. A regression test will cover the fast-callback path that caused the race.
- Removing settings fields could confuse users if they previously entered values. We mitigate this by keeping storage compatibility and only removing the unused controls.
