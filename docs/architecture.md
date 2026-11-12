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

One `AppDatabase` with tables for topics, practices, questions, sessions, session questions, attempts, concepts, error cards, manual cards, skipped questions, highlights and settings. The schema is version 8; version 2 added the topic deck and manual-card topic columns, version 3 stores correct/selected/wrong indexes as JSON arrays, version 4 adds the overall explanation and alternative explanations to error-card snapshots, version 5 adds the practice done flag, version 6 adds unknown attempts and acronym extras, version 7 adds skipped-question persistence and manual-card context, and version 8 adds highlights.

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

Per-question history is derived from attempts, never stored as a new column. A question is **done** after an attempt with a non-empty selection that is not marked "I didn't know this" (correct, wrong and distracted answers all count); **solved** after a correct attempt; and **skipped** after an empty-selection or "I didn't know this" attempt. The session navigator tags done questions, and its question list marks them. Shuffled practice keeps only questions that are neither solved nor skipped, so solved questions and questions left unanswered stay out. On a redo, questions answered in an earlier attempt count as done for the end-of-session prompt, so "Leave unanswered" appears only for a question that has never been answered in any attempt.

## UI

- `M3EMaterialApp` owns theming (light/dark from the system, wallpaper colors by default), and `M3ETheme` tokens are used throughout.
- Navigation is Navigator 1.0 with `MaterialPageRoute`, because `M3EMaterialApp` does not expose `routerConfig`.
- Home is a topics list with quick actions for due errors and cards. An info icon opens the help screen.
- The practice screen keeps everything in place after submission: locked reasoning, marked alternatives, per-alternative explanations and the overall explanation. A wrong answer offers the distraction checkbox in the feedback; checking it updates the attempt and removes the new error card, and unchecking restores it.
- Alternatives are shown in a per-session shuffled order. Circular badges hide the original letters until feedback or the eye toggle, which reveals them without reordering the alternatives.
- Questions with several correct answers let you select every correct alternative. Selection is compared as a set, so every correct alternative is required and an extra wrong alternative fails the question.
- Prompt, alternatives and explanations use `SelectableLinkifiedText` for Define and tappable http(s) links.
- AI definitions render in an overlay bubble anchored to the selection and save before display. Web definitions keep the editable bottom sheet.
- The 5-minute reminder is a `Timer.periodic` for the current question, paused while the app is in the background and reset when the question changes.
- Text selection is a `SelectionArea` with custom Define, Highlight and Ask actions. Ask sends the selected passage, its question and the learner message to the configured AI; its answer can become a basic card whose front places the question context above the learner question. Highlights are stored per session/question, painted in place, and reviewed at the end of the session. Cards offers a plain-text download of all highlights; they are never part of an Anki export selection.
- Skipped answers are snapshotted into `skipped_questions`. The review marks a record handled when it creates a card, and the combined **Error and skipped** section lists any records still unhandled so they survive the session. `ErrorCardsReviewPage` walks error cards and skipped questions in one pass; the skipped rows use the same checkbox and pencil row as error cards.
- Settings model selection uses `M3EDropdownMenu` and `LookupService.listModels`; Gemini models are filtered to those that support `generateContent`.

## Platform services

- `AnkiGateway` (Dart) ↔ `AnkiBridge` (Kotlin) over a MethodChannel. Kotlin uses AnkiDroid's AddContentApi, groups notes by target deck, creates missing decks, and broadcasts DO_SYNC. `deckNames()` reads live decks for the topic picker.
- `WebLauncher` wraps Chrome Custom Tabs.
- `SecureKeyStore` wraps Android secure storage.
- `MethodChannelPracticeSoundPlayer` clamps the configured volume to the platform range (0..1). The WAV assets are mastered with 6 dB more gain than before; their peaks stay at least 7 dB below full scale, so doubling the loudness cannot clip.
- `http.Client` is injected so lookup tests use mock responses.
- `LookupService` has two AI transports: OpenAI-compatible `/chat/completions` with a Bearer key, and Gemini native `models/{model}:generateContent` with the key in the query string. `listModels` reads `/models` from either provider shape.

## Testing seams

`databaseProvider`, `clockProvider`, `secureKeyStoreProvider`, `webLauncherProvider` and `ankiGatewayProvider` are overridden in tests. The clock is a fixed/mutable `TestClock`, making the 48-hour rule and reminder deterministic.
