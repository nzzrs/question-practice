# Architecture

## Layers

```
UI (features/*/pages, widgets)
  -> Riverpod providers
  -> services (import, session, review, lookup, export)
  -> repositories (practice, session, card, settings)
  -> Drift DAOs / tables
```

Domain models in `lib/core/domain/models.dart` are immutable plain Dart. Repositories return domain models, not Drift rows. Services hold the business rules that need more than one repository or the clock.

## Database

One `AppDatabase` with tables for topics, practices, questions, sessions, session questions, attempts, concepts, error cards, manual cards and settings. The schema is version 2; the upgrade from version 1 adds the topic deck and manual-card topic columns.

- Timestamps are UTC; rows are converted back to UTC in mappers.
- Questions store alternatives and per-alternative explanations as JSON arrays.
- A partial unique index enforces one active error card per question.
- Error cards snapshot the question, alternatives and reasoning so history survives edits.
- Topics store an optional AnkiDroid deck name. Cards snapshot the topic name; export resolves a deck per card, falling back to the Settings default.
- Sessions are created on start and can be resumed if the app is killed.
- Deleting a topic/practice cascades through its content; deleting a session removes its attempts and cards created by it.

## Error lifecycle

1. A wrong, non-distracted answer creates an active error card with snapshots and `dueAt = lastWrongAt + 48 h`.
2. The end-of-session review fills bias, vaccine and `detailsCompletedAt`.
3. After 48 h the card appears in Past errors.
4. A correct past-error answer sets `resolved` and `resolvedAt`; the row remains for history.
5. A wrong past-error answer updates `lastWrongAt` and pushes `dueAt` another 48 h. A distracted wrong answer leaves the due date untouched.

Skipped answers never create error cards. They are handled by the skipped branch of the review (concept or basic card).

## UI

- `M3EMaterialApp` owns theming (light/dark from the system, optional dynamic color), and `M3ETheme` tokens are used throughout.
- Navigation is Navigator 1.0 with `MaterialPageRoute`, because `M3EMaterialApp` does not expose `routerConfig`.
- Home is a topics list with quick actions for due errors and cards. An info icon opens the help screen.
- The practice screen keeps everything in place after submission: locked reasoning, marked alternatives, per-alternative explanations and the overall explanation.
- The 5-minute reminder is a `Timer.periodic` paused while the app is in the background.
- Text selection is a `SelectionArea` with a custom “Define” action.

## Platform services

- `AnkiGateway` (Dart) ↔ `AnkiBridge` (Kotlin) over a MethodChannel. Kotlin uses AnkiDroid's AddContentApi, groups notes by target deck, creates missing decks, and broadcasts DO_SYNC. `deckNames()` reads live decks for the topic picker.
- `WebLauncher` wraps Chrome Custom Tabs.
- `SecureKeyStore` wraps Android secure storage.
- `http.Client` is injected so lookup tests use mock responses.

## Testing seams

`databaseProvider`, `clockProvider`, `secureKeyStoreProvider`, `webLauncherProvider` and `ankiGatewayProvider` are overridden in tests. The clock is a fixed/mutable `TestClock`, making the 48-hour rule and reminder deterministic.
