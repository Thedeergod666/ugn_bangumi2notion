# Extra Card Long Press Copy Design

**Goal:** Extend the existing long-press copy interaction to the airing-page schedule cards and the recommendation-page hero card.

## Scope

- Airing page:
  - Add long-press copy to the schedule cards shown below the bound-card section.
- Recommendation page:
  - Add long-press copy to the hero recommendation card ("今日安利").

## Approach

- Keep the existing shared copy helper and unified snackbar message.
- Keep side effects at the page layer and only pass copy callbacks through the view layer.
- Do not change any tap behavior or explicit `+1` behavior.

## Interaction Rules

- Airing schedule card:
  - Tap: unchanged, still opens detail.
  - Long press: copies the displayed Bangumi title.
- Recommendation hero card:
  - Tap: unchanged, still opens Notion detail.
  - Long press: copies the recommendation title.

