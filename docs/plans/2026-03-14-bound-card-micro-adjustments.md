# Bound Card Micro Adjustments Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Update the airing-page bound bangumi card to show weekly update cadence, move `+1` into the metadata row, shrink the unread indicator into a numeric red dot, and reduce card height.

**Architecture:** Keep the current update-summary data model and only tighten the bound-card presentation layer. Reuse the existing long-press increment callback for the new `+1` button, derive `周X更新` from the next-airing time or weekday metadata, and verify the new hierarchy with widget tests before implementation.

**Tech Stack:** Flutter, widget tests, existing Bangumi episode summary formatting helpers.

---

### Task 1: Lock the new bound-card behavior with tests

**Files:**
- Modify: `test/features/airing_calendar/calendar_view_layout_test.dart`

**Step 1: Write the failing test**
- Extend the bound-card test case to expect `周四更新`.
- Expect a visible `+1` control.
- Expect the old long-press helper copy to be absent.
- Expect the old `未看 1 集` pill copy to be absent.

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/airing_calendar/calendar_view_layout_test.dart`

**Step 3: Implement minimal code**
- No production code in this task.

**Step 4: Re-run to confirm the test still fails for the intended reason**

Run: `flutter test test/features/airing_calendar/calendar_view_layout_test.dart`

### Task 2: Rework the bound card layout

**Files:**
- Modify: `lib/features/airing_calendar/presentation/calendar_view.dart`

**Step 1: Add weekday update helper**
- Derive `周X更新` from `releaseSummary.nextAiredAt`, falling back to `item.airWeekday` when needed.

**Step 2: Update the first metadata row**
- Keep the `悠gn` chip.
- Add a compact `+1` button to its right that triggers the existing increment callback.

**Step 3: Update the status rows**
- Keep `最近更新` and `下次更新`.
- Combine cadence + watched progress into one line: `周X更新 · 看到 EPn`.
- Keep `最近观看`.

**Step 4: Replace the unread pill**
- Remove the inline `未看 n 集` chip.
- Render a compact numeric red dot at the card’s top-right corner when there are unread episodes.

**Step 5: Remove the old helper copy and tighten card height**
- Delete the old long-press instruction text.
- Reduce spacing and card heights so the new layout stays compact without overflow.

### Task 3: Verify and format

**Files:**
- Modify: `lib/features/airing_calendar/presentation/calendar_view.dart`
- Modify: `test/features/airing_calendar/calendar_view_layout_test.dart`

**Step 1: Run the focused test**

Run: `flutter test test/features/airing_calendar/calendar_view_layout_test.dart`

**Step 2: Format changed files**

Run: `dart format lib/features/airing_calendar/presentation/calendar_view.dart test/features/airing_calendar/calendar_view_layout_test.dart`

**Step 3: Run full regression**

Run: `flutter test`
