# Question Practice

A quiet, local-first Android app for practising multiple-choice questions, analysing mistakes, and turning them into Anki cards.

Built with Flutter and Material 3 Expressive. No account, no analytics, no countdowns.

## What it does

- Import practices from JSON or a `.txt` file containing JSON. One file can contain many topics and practices.
- Answer with an optional written reasoning. Questions can have one correct alternative or several; feedback appears in place, with an explanation under every alternative. Answers and explanations are selectable, and http(s) links open in the browser.
- Move between questions with the arrows beside the question number. Closing a session offers **Save for later**, and Home lists every paused session.
- Check **I was distracted or read too fast** in the feedback to remove a new error card; uncheck it to restore the card.
- Get a score and the number of terms looked up at the end of a session.
- Review wrong and skipped questions immediately and create:
  - error cards with question, wrong answer, correct answer, bias and vaccine;
  - concept cards such as `Definition of {{c1::GCP}}: {{c2::Google Cloud Platform}}`;
  - basic question/answer cards for skipped questions.
- Re-test errors after 48 hours. A correct answer resolves the card but keeps the history.
- Look up a selected term with an optional AI provider: OpenAI-compatible endpoints (OpenAI, Groq, OpenRouter, custom) or Gemini's native API, with a model list loaded from the provider. AI definitions appear in a read-only bubble and save automatically; web lookup keeps the editable sheet. Or use DuckDuckGo/Wikipedia through a Custom Tab.
- Export selected cards directly to AnkiDroid or share Anki-compatible files. Error cards can be reviewed all at once or by selection from Cards. Incomplete error cards can be selected to review them before export.
- Give each topic its own AnkiDroid deck; topics without one use the default deck.
- See per-topic accuracy and progress, and a mixed shuffled session across all topics.
- Material You wallpaper colors are on by default; they can be turned off in Settings.
- A subtle reminder every five minutes. There is no timer.

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

Install it on a connected device:

```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

## Documentation

All documentation is in English. Start at [docs/README.md](docs/README.md).

- [User guide](docs/user-guide.md)
- [Import format](docs/json-format.md)
- [AnkiDroid export and per-topic decks](docs/anki.md)
- [Architecture](docs/architecture.md)
- [Testing](docs/testing.md)

## Import

The importer validates the whole file before writing anything. A broken file is rejected with the JSON path of the problem. See [docs/json-format.md](docs/json-format.md).

A question uses `correctIndex` for one correct alternative, or `correctIndexes` for several. A multi-answer question is correct only when every correct alternative is selected and no wrong one is selected.

A sample with two topics and eight questions lives at [assets/samples/sample_practice.json](assets/samples/sample_practice.json). The Import screen can load it directly.

## Anki export

See [docs/anki.md](docs/anki.md). Concept cards use AnkiDroid's existing **Cloze** note type. Error cards use the six-field **Question Practice: Error** model, created automatically with its HTML and CSS when missing. Basic note types are created automatically the first time. Each topic can target its own deck; the topic editor and Settings load deck names from AnkiDroid. Blank topics use the default deck from Settings.

## Data and privacy

- Practices, answers, cards and statistics are stored in local SQLite through Drift.
- The AI API key is stored with Android secure storage, never in SQLite and never logged.
- The app has no analytics and does not record time spent.
- A term lookup sends only the selected term, its question and the topic name to the configured endpoint, and only when Define is invoked.
- All data can be erased from Settings.

## Tests

```bash
flutter analyze
flutter test
```

The suite covers the importer and JSON schema (including `correctIndexes`), scoring and the 48-hour rule, multi-answer scoring, distraction checked and unchecked after feedback, session arrows and paused sessions, review cards, the shared error-card review view, Gemini and OpenAI-compatible lookup, provider model lists, six-field Anki error notes, Drift statistics, and the main widget flows. See [docs/testing.md](docs/testing.md) for the manual on-device checklist.

## Project layout

```
lib/app/                  app shell, providers, theme
lib/core/                 domain models, Drift database, repositories, platform bridges
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
