# Long Press Copy Title Design

**Goal:** Change long-press behavior on the airing-page bound card and recommendation-page recent cards so they copy the anime title to the clipboard, while keeping the existing explicit `+1` buttons unchanged.

**Context:**
- The airing page currently binds bound-card long press to watched-episode increment.
- The recommendation page currently has an explicit `+1` button for watching entries but no long-press behavior on the card itself.
- The new requirement is to standardize long press as a copy-title action on both pages and show the same success feedback message.

## Recommended Approach

Use a shared copy helper at the page layer and keep the view layer callback-driven.

- `CalendarView` keeps exposing a bound-card long-press callback, but the page changes its handler from incrementing episodes to copying the title.
- `RecommendationView` adds a recent-card long-press callback for both watching and watched entries.
- Both pages reuse a shared helper that:
  - writes the anime title to the clipboard
  - hides the current snackbar
  - shows `已复制番剧名称。`

## Why This Approach

### Option 1: Shared helper + page-owned long-press handlers

**Pros**
- Preserves current data flow and keeps views presentation-only.
- Avoids duplicating clipboard/snackbar logic across pages.
- Leaves the explicit `+1` actions untouched, reducing regression risk.

**Cons**
- Requires touching both page and view callback contracts.

### Option 2: Copy directly inside each card widget

**Pros**
- Smaller local edits inside widgets.

**Cons**
- Duplicates clipboard/snackbar logic.
- Makes the view layer responsible for side effects.
- Harder to keep feedback text and behavior consistent.

### Option 3: Replace both long press and explicit `+1` with copy

**Pros**
- Simplifies interaction model.

**Cons**
- Conflicts with the approved requirement to keep explicit `+1` buttons unchanged.

## Interaction Contract

### Airing Page
- Tap card: unchanged, still opens detail.
- Explicit `+1` button: unchanged, still increments watched episodes.
- Long press card: copy the Bangumi title and show `已复制番剧名称。`

### Recommendation Page
- Tap card: unchanged, still opens detail.
- Explicit `+1` button on watching entries: unchanged.
- Long press recent card: copy the entry title and show `已复制番剧名称。`

## Data Flow

1. Card detects `onLongPress`.
2. View forwards the relevant subject title or entry title through callbacks.
3. Page calls a shared copy helper.
4. Helper writes clipboard data and shows the unified snackbar.

## Testing Strategy

- Widget test the airing-page view wiring: bound-card long press triggers the supplied callback.
- Widget test the recommendation-page view wiring: recent-card long press triggers the supplied callback.
- Widget test the shared copy helper: clipboard receives the title and snackbar shows `已复制番剧名称。`

