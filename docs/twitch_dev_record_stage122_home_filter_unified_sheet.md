# Stage 122 - Home Filter Unified Sheet

## Summary
- Converted home game category picker from custom Dialog to the shared `showTwitchUnifiedSheet` template.
- Converted Browse language picker from AlertDialog to shared sheet template.
- Converted Following language picker from AlertDialog to shared sheet template.
- Removed direct `showDialog` / `AlertDialog` usage from the home filter entry points.

## Reason
Android hardware/software back navigation could close the old dialog while internal controllers were still attached to the route transition, causing a Flutter framework assertion:

```text
'_dependents.isEmpty': is not true
```

Using the shared sheet route aligns the home filters with the rest of the Twitch interaction sheets and improves mobile behavior.

## Changed Files
- `lib/features/twitch/presentation/pages/twitch_browse_page.dart`
- `lib/features/twitch/presentation/pages/twitch_following_page.dart`
