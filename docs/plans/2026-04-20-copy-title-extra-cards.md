# Extra Card Long Press Copy Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add long-press title copy to the airing-page schedule cards and the recommendation-page hero card.

**Architecture:** Reuse the existing copy helper and snackbar feedback. Add one new callback for airing schedule cards and one new callback for the recommendation hero card, keeping all side effects in the page layer.

**Tech Stack:** Flutter, `InkWell`, clipboard helper.

---

### Task 1: Extend callback contracts

**Files:**
- Modify: `lib/features/airing_calendar/presentation/calendar_view.dart`
- Modify: `lib/features/dashboard/presentation/recommendation_view.dart`

### Task 2: Wire long press at the page layer

**Files:**
- Modify: `lib/features/airing_calendar/presentation/calendar_page.dart`
- Modify: `lib/features/dashboard/presentation/recommendation_page.dart`

### Task 3: Keep test factories compiling

**Files:**
- Modify: `test/features/airing_calendar/calendar_view_layout_test.dart`
- Modify: `test/features/airing_calendar/calendar_bound_card_score_chip_test.dart`
- Modify: `test/features/dashboard/recommendation_recent_layout_test.dart`
- Modify: `test/features/dashboard/recommendation_cover_resolution_test.dart`
