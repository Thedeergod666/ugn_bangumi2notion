# Copy Title Long Press Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace long-press `+1` behavior with title-copy behavior on the airing-page bound cards and add the same long-press copy behavior to recommendation-page recent cards, while keeping explicit `+1` buttons unchanged.

**Architecture:** Keep both views callback-driven and move clipboard/snackbar side effects into page-level handlers backed by a shared helper. This keeps presentation widgets simple, preserves the existing explicit increment flows, and centralizes the copy feedback message.

**Tech Stack:** Flutter, widget tests, `Clipboard`, `SnackBar`.

---

### Task 1: Lock the new behavior with failing tests

**Files:**
- Modify: `test/features/airing_calendar/calendar_view_layout_test.dart`
- Modify: `test/features/dashboard/recommendation_recent_layout_test.dart`
- Create: `test/core/utils/copy_text_feedback_test.dart`

**Step 1: Write the failing airing-page long-press test**
- Add a callback counter to `CalendarViewCallbacks`.
- Long press the bound card and assert the callback fires once.

**Step 2: Write the failing recommendation-page long-press test**
- Add a callback counter to `RecommendationViewCallbacks`.
- Long press a recent card and assert the callback fires once.

**Step 3: Write the failing shared copy helper test**
- Pump a minimal scaffold.
- Trigger the helper with a sample title.
- Assert clipboard text matches and the snackbar shows `已复制番剧名称。`

**Step 4: Run focused tests to verify they fail**

Run:
- `flutter test test/features/airing_calendar/calendar_view_layout_test.dart`
- `flutter test test/features/dashboard/recommendation_recent_layout_test.dart`
- `flutter test test/core/utils/copy_text_feedback_test.dart`

### Task 2: Add a shared copy helper

**Files:**
- Create: `lib/core/utils/copy_text_feedback.dart`

**Step 1: Add a single helper function**
- Accept `BuildContext`, copied text, and optional message.
- Use `Clipboard.setData`.
- Hide the current snackbar before showing the success snackbar.

**Step 2: Keep the API minimal**
- No extra abstraction or service layer.
- Default message should be `已复制番剧名称。`

### Task 3: Rewire airing-page bound-card long press

**Files:**
- Modify: `lib/features/airing_calendar/presentation/calendar_view.dart`
- Modify: `lib/features/airing_calendar/presentation/calendar_page.dart`

**Step 1: Update the callback contract if needed**
- Ensure the long-press callback carries enough information to copy the displayed title.

**Step 2: Replace the page handler**
- Remove the long-press increment handler from the card interaction path.
- Long press should now copy the displayed anime title.

**Step 3: Preserve explicit increment**
- Leave the visible `+1` button behavior untouched.

### Task 4: Add recent-card long press on recommendation page

**Files:**
- Modify: `lib/features/dashboard/presentation/recommendation_view.dart`
- Modify: `lib/features/dashboard/presentation/recommendation_page.dart`

**Step 1: Extend the recommendation callbacks**
- Add a long-press callback for recent entries.

**Step 2: Wire long press on recent cards**
- Both list and gallery recent cards should forward long press.

**Step 3: Handle copy at the page layer**
- Copy `entry.title`.
- Keep explicit `+1` increment button behavior unchanged.

### Task 5: Verify and format

**Files:**
- Modify: `lib/core/utils/copy_text_feedback.dart`
- Modify: `lib/features/airing_calendar/presentation/calendar_view.dart`
- Modify: `lib/features/airing_calendar/presentation/calendar_page.dart`
- Modify: `lib/features/dashboard/presentation/recommendation_view.dart`
- Modify: `lib/features/dashboard/presentation/recommendation_page.dart`
- Modify tests created above

**Step 1: Run focused tests**

Run:
- `flutter test test/features/airing_calendar/calendar_view_layout_test.dart`
- `flutter test test/features/dashboard/recommendation_recent_layout_test.dart`
- `flutter test test/core/utils/copy_text_feedback_test.dart`

**Step 2: Format changed files**

Run:
- `dart format lib/core/utils/copy_text_feedback.dart`
- `dart format lib/features/airing_calendar/presentation/calendar_view.dart`
- `dart format lib/features/airing_calendar/presentation/calendar_page.dart`
- `dart format lib/features/dashboard/presentation/recommendation_view.dart`
- `dart format lib/features/dashboard/presentation/recommendation_page.dart`
- `dart format test/features/airing_calendar/calendar_view_layout_test.dart`
- `dart format test/features/dashboard/recommendation_recent_layout_test.dart`
- `dart format test/core/utils/copy_text_feedback_test.dart`

**Step 3: Run full regression**

Run:
- `flutter test`
