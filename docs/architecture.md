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

One `AppDatabase` with tables for topics, practices, questions, sessions, session questions, attempts, concepts, error cards, manual cards and settings. The schema is version 4; version 2 added the topic deck and manual-card topic columns, version 3 stores correct/selected/wrong indexes as JSON arrays, and version 4 adds the overall explanation and alternative explanations to error-card snapshots.

- Timestamps are UTC; rows are converted back to UTC in mappers.
- Questions store alternatives, per-alternative explanations, and correct indexes as JSON arrays.
- A partial unique index enforces one active error card per question.
- Error cards snapshot the question, alternatives, reasoning, overall explanation and per-alternative explanations.
- Topics store an optional AnkiDroid deck name. Cards snapshot the topic name; export resolves a deck per card, falling back to the Settings default.
- Sessions are created on start and can be resumed if the app is killed.
- Deleting a topic/practice cascades through its content; deleting a session removes its attempts and cards created by it.

## Error lifecycle

1. A wrong, non-distracted answer creates an active error card with snapshots and `dueAt = lastWrongAt + 48 h`.
2. The end-of-session review fills bias, vaccine and `detailsCompletedAt`. Cards screen **Complete**, **Review all** and **Review selected** use the same `ErrorCardReviewView`.
3. After 48 h the card appears in Past errors.
4. A correct past-error answer sets `resolved` and `resolvedAt`; the row remains for history.
5. A wrong past-error answer updates `lastWrongAt` and pushes `dueAt` another 48 h. Marking the answer as distracted does not resolve the card; it stays active.

Distraction is chosen after feedback. Checking it updates the attempt, removes an error card created by that same session, and refreshes completed session counts. Unchecking it recreates or retouches the card. A card from an earlier session is not deleted.

Skipped answers never create error cards. They are handled by the skipped branch of the review (concept or basic card).

## Sessions and navigation

A session is created at start and remains `inProgress` until every question has an attempt. The session screen keeps its own question index: the top arrows move without answering, and previously submitted attempts reload their selected alternatives, reasoning and feedback. Closing offers save, discard or cancel. Save leaves the session `inProgress`; Home watches a list of all in-progress sessions, not only the newest.

## UI

- `M3EMaterialApp` owns theming (light/dark from the system, wallpaper colors by default), and `M3ETheme` tokens are used throughout.
- Navigation is Navigator 1.0 with `MaterialPageRoute`, because `M3EMaterialApp` does not expose `routerConfig`.
- Home is a topics list with quick actions for due errors and cards. An info icon opens the help screen.
- The practice screen keeps everything in place after submission: locked reasoning, marked alternatives, per-alternative explanations and the overall explanation. A wrong answer offers the distraction checkbox in the feedback; checking it updates the attempt and removes the new error card, and unchecking restores it.
- Questions with several correct answers use checkboxes. Selection is compared as a set, so every correct alternative is required and an extra wrong alternative fails the question.
- Prompt, alternatives and explanations use `SelectableLinkifiedText` for Define and tappable http(s) links.
- AI definitions render in an overlay bubble anchored to the selection and save before display. Web definitions keep the editable bottom sheet.
- The 5-minute reminder is a `Timer.periodic` paused while the app is in the background.
- Text selection is a `SelectionArea` with a custom “Define” action.
- Settings model selection uses `M3EDropdownMenu` and `LookupService.listModels`; Gemini models are filtered to those that support `generateContent`.

## Platform services

- `AnkiGateway` (Dart) ↔ `AnkiBridge` (Kotlin) over a MethodChannel. Kotlin uses AnkiDroid's AddContentApi, groups notes by target deck, creates missing decks, and broadcasts DO_SYNC. `deckNames()` reads live decks for the topic picker.
- `WebLauncher` wraps Chrome Custom Tabs.
- `SecureKeyStore` wraps Android secure storage.
- `http.Client` is injected so lookup tests use mock responses.
- `LookupService` has two AI transports: OpenAI-compatible `/chat/completions` with a Bearer key, and Gemini native `models/{model}:generateContent` with the key in the query string. `listModels` reads `/models` from either provider shape.

## Testing seams

`databaseProvider`, `clockProvider`, `secureKeyStoreProvider`, `webLauncherProvider` and `ankiGatewayProvider` are overridden in tests. The clock is a fixed/mutable `TestClock`, making the 48-hour rule and reminder deterministic.
