# Questions

A quiet, local-first Android app for practising multiple-choice questions, analysing mistakes, and turning them into Anki cards.

Built with Flutter and Material 3 Expressive. No account, no analytics, no countdowns.

## What it does

- Import practices from JSON or a `.txt` file containing JSON. One file can contain many topics and practices, and each question may name an optional subtopic for grouped statistics.
- Questions can have one correct alternative or several; feedback appears in place, with the correct and selected alternatives expanded to their explanation and the rest collapsed. Alternatives are shuffled per session, original letters stay hidden until feedback or the eye toggle, and questions, answers and explanations are selectable with http(s) links opening in the browser. Explanations can be highlighted too.
- Select any text to **Define** a term, **Highlight** it for later, or **Ask** the AI about it using the passage, its question and your own message. An answer can be turned into a basic card with the question context above the front.
- Highlights belong to the question, so they paint in place whenever that question is practised again. Tap a highlight for Define, Ask or **Delete highlight** (no confirmation). Highlights wait in the end review, where each one can become a concept card or simply be kept. **Suggest cards with AI** classifies up to six proposals as procedures/rules or atomic facts, so you can pick which ones to add. Kept highlights remain in Cards, where **Review highlights** walks them one at a time with the same actions, and **Download all** saves every highlight as a plain-text file. Highlights are never sent to AnkiDroid.
- Move between questions with the arrows beside the question number. Closing a session offers **Save for later**, and Home lists every paused session.
- After a wrong answer, tap quick chips (**Forgotten fact**, **Confusion between 2 options**, **Misinterpretation**, **Distraction**) to classify the error for the card generator. Check **I was distracted or read too fast** to remove a new error card; uncheck it to restore the card. Check **I didn't know this** instead to count the answer as skipped and have the review ask for the missing concept.
- Get a score and the number of terms looked up at the end of a session.
- Review wrong and skipped questions immediately and create:
  - atomic cards from a mistake: **Break into atomic cards (AI)** proposes a direct contrast (wrong vs. correct option) and/or a condition-action heuristic, each with a Litmus quality badge for binary questions, fronts over 30 words or syntactic clues; errors are never exported directly;
  - concept cards such as `[Topic / Subtopic] Definition of {{c1::GCP}}: {{c2::A managed cloud computing platform.}}`, with an acronym's full form in the Anki extra field;
  - basic question/answer cards for skipped questions.
- Review cards show the skipped or unknown question in a structured panel with the correct answer in green and a collapsible list of the other alternatives and their explanations.
- Skipped questions stay in the combined **Error and skipped** section of Cards after the session ends, so they can become cards later. They leave the section when converted into a card.
- Re-test errors after 48 hours. A correct answer resolves the card but keeps the history.
- Look up a selected term with an optional AI provider: OpenAI-compatible endpoints (OpenAI, Groq, OpenRouter, custom) or Gemini's native API, with a model list loaded from the provider. AI definitions appear in a read-only bubble and save automatically; acronyms also show what they stand for. Web lookup keeps the editable sheet. Or use DuckDuckGo/Wikipedia through a Custom Tab.
- Export selected cards directly to AnkiDroid or share Anki-compatible files using only Anki's standard **Cloze** and **Basic** note types. Errors can be reviewed all at once or by selection from Cards and broken into atomic Basic cards; skipped questions can be reviewed until converted. Notes carry `topic::<topic>` and `subtopic::<subtopic>` tags.
- Cards filters by cognitive type (**Facts**, **Heuristics**, **Contrasts**, **Concepts**), with separate entries for errors/skipped questions and highlights. It has no checkboxes. Long-press any row to start selecting, then tap more rows; the subtitle counts the selection and the app-bar close clears it. The list does not shift when selection starts or grows.
- **Delete selected** also removes selected skipped questions and highlights, even though they cannot be exported; their questions and any cards already made from a highlight stay.
- Set a **minimum approval score** (70% by default) and a **target score** (80% by default) per topic. Practices, readiness, statistics cards and chart dots are red below the minimum, normal between minimum and target, and green at or above the target. Statistics also estimate when your current pace reaches the target.
- Download or update a whole topic as JSON, separate from the per-practice JSON options. A topic file contains every practice in the topic; updating leaves practices absent from the file untouched.
- Open topic statistics for a per-subtopic accuracy and progress breakdown, a weighted least-squares trend line over cumulative questions answered, and learning rates per 100 questions and per week. The topic header shows **Readiness**, the correct share of its last 100 answered questions. Long-press a subtopic to rename, merge or delete it, or long-press a completed session to delete a selection of sessions with their captured records. Share the whole statistics payload as JSON.
- Give each topic its own AnkiDroid deck; topics without one use the default deck.
- Export a complete JSON backup of practices, sessions, answers, cards and settings, and restore it on another install. The backup never contains the AI API key.
- Sort topics and each topic's practices by name or recency, with the order remembered; archive topics without deleting their data. Start a mixed shuffled session from the **Shuffle** floating button and choose how many questions to include (15 by default).
- Material You wallpaper colors are on by default; they can be turned off in Settings.
- A floating reminder after five minutes on the same question, then every five minutes. It resets when you move on.

## Requirements

- Flutter 3.47.7 stable (Dart 3.13.5). The repository pins the version in `.tool-versions`.
- Android SDK 37 and a device running Android 7.0+ (the app is Android-only).
- For direct Anki export: AnkiDroid installed with its API enabled and database permission granted.

The app uses `material_3_expressive` 1.2 and `material_ui`; UI code must not import `package:flutter/material.dart`.

## Run

```bash
flutter pub get
dart run build_runner build
flutter run
```

Build a debug APK:

```bash
flutter build apk --debug
```

The debug build uses the `link.nzrs.questionpractice.dev` application ID, so it can be installed next to a release build.

A tracked pre-push hook checks that generated documentation is current and builds the debug APK on this laptop before every push. Install it once:

```bash
./tool/install_hooks.sh
```

The APK is written to `build/app/outputs/flutter-apk/app-debug.apk`.

Install it on a connected device:

```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

## Documentation

All documentation is in English. Start at [docs/README.md](docs/README.md).

- [User guide](docs/user-guide.md)
- [Practice JSON format](docs/json-format.md)
- [AnkiDroid export and per-topic decks](docs/anki.md)
- [Architecture and feature map](docs/architecture.md)
- [Database reference](docs/database.md)
- [Testing](docs/testing.md)

The database map, migration history and backup coverage in
[docs/database.md](docs/database.md) are generated from the Drift code. After a
schema change, run `dart run tool/docs/update_docs.dart`; verify with
`dart run tool/docs/update_docs.dart --check`.

## Import

The importer validates the whole file before writing anything. A broken file is rejected with the JSON path of the problem. See [docs/json-format.md](docs/json-format.md).

A question uses `correctIndex` for one correct alternative, or `correctIndexes` for several. A multi-answer question is correct only when every correct alternative is selected and no wrong one is selected.

A sample with two topics and eight questions lives at [assets/samples/sample_practice.json](assets/samples/sample_practice.json). The Import screen can load it directly. A second importable file, [assets/samples/practice_format_example.json](assets/samples/practice_format_example.json), demonstrates a single-answer question with a subtopic, a multi-answer question, per-alternative explanations, `sourceId` and two topics.

## Anki export

See [docs/anki.md](docs/anki.md). Concept cards use AnkiDroid's existing **Cloze** note type. Facts, heuristics, contrasts and other question/answer cards use the standard `Basic` note type, created automatically the first time it is needed. The custom six-field error model was removed; errors become atomic Basic cards during review. Each topic can target its own deck; there is no per-practice deck. The topic editor and Settings load deck names from AnkiDroid. Blank topics use the default deck from Settings.

## Data and privacy

- Practices, answers, cards and statistics are stored in local SQLite through Drift.
- Settings offers a complete JSON backup and restore. The backup covers practices, sessions, answers, cards and settings; the AI API key stays in Android secure storage and is never included.
- The AI API key is stored with Android secure storage, never in SQLite and never logged.
- The app has no analytics and does not record time spent.
- A term lookup sends only the selected term, its question and the topic name to the configured endpoint, and only when Define is invoked.
- All data can be erased from Settings.

## Tests

```bash
flutter analyze
flutter test
dart run tool/docs/update_docs.dart --check
```

The suite covers the importer and JSON schema (including `correctIndexes` and subtopics), scoring and the 48-hour rule, multi-answer scoring, distraction checked and unchecked after feedback, session arrows and paused sessions, review cards, the shared error-card review view, Gemini and OpenAI-compatible lookup, provider model lists, acronym expansion, atomic card breakdown and Litmus checks, standard Basic/Cloze export and hierarchical tags, Drift statistics and deletion cascades, per-subtopic stats and category management, readiness over the last 100 answered questions, session deletion cascades, weighted regression and learning-rate math, statistics export, generated database documentation, and the main widget flows. See [docs/testing.md](docs/testing.md) for the manual on-device checklist.

## Project layout

```
lib/app/                  app shell, providers, theme
lib/core/                 domain models, Drift database, repositories, platform bridges
lib/features/backup/      complete JSON backup and restore
lib/features/import/      schema validation, preview and import
lib/features/practice/    session flow, reminders, results
lib/features/review/      end-of-session error and concept cards
lib/features/errors/      due queue, resolved history, shared error-card review view
lib/features/lookup/      AI and web term lookup
lib/features/export/      Anki note/file builders and cards screen
lib/features/topics/      topics, practices and progress
lib/features/home/        home screen
lib/features/settings/    appearance, lookup, Anki and data settings
lib/features/help/        in-app instructions
```

## License

Private project.
