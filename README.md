# Question Practice

A quiet, local-first Android app for practising multiple-choice questions, analysing mistakes, and turning them into Anki cards.

Built with Flutter and Material 3 Expressive. No account, no analytics, no countdowns.

## What it does

- Import practices from JSON or a `.txt` file containing JSON. One file can contain many topics and practices.
- Answer with an optional written reasoning. Feedback appears in place, with an explanation under every alternative.
- Get a score and the number of terms looked up at the end of a session.
- Review wrong and skipped questions immediately and create:
  - error cards with question, wrong answer, correct answer, bias and vaccine;
  - concept cards such as `Definition of {{c1::GCP}}: {{c2::Google Cloud Platform}}`;
  - basic question/answer cards for skipped questions.
- Re-test errors after 48 hours. A correct answer resolves the card but keeps the history.
- Look up a selected term with an optional OpenAI-compatible endpoint, or in DuckDuckGo/Wikipedia through a Custom Tab.
- Export selected cards directly to AnkiDroid or share Anki-compatible files.
- See per-topic accuracy and progress, and a mixed shuffled session across all topics.
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

## Import

The importer validates the whole file before writing anything. A broken file is rejected with the JSON path of the problem. See [docs/json-format.md](docs/json-format.md).

A sample with two topics and eight questions lives at [assets/samples/sample_practice.json](assets/samples/sample_practice.json). The Import screen can load it directly.

## Anki export

See [docs/anki.md](docs/anki.md). Concept cards use AnkiDroid's existing **Cloze** note type. Error and basic note types are created automatically the first time.

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

The suite covers the importer and JSON schema, scoring and the 48-hour rule, review cards, lookup parsing, Anki note formatting and export, Drift statistics, and the main widget flows. See [docs/testing.md](docs/testing.md) for the manual on-device checklist.

## Project layout

```
lib/app/                  app shell, providers, theme
lib/core/                 domain models, Drift database, repositories, platform bridges
lib/features/import/      schema validation, preview and import
lib/features/practice/    session flow, reminders, results
lib/features/review/      end-of-session error and concept cards
lib/features/errors/      due queue and resolved history
lib/features/lookup/      AI and web term lookup
lib/features/export/      Anki note/file builders and cards screen
lib/features/topics/      topics, practices and progress
lib/features/home/        home screen
lib/features/settings/    appearance, lookup, Anki and data settings
lib/features/help/        in-app instructions
```

## License

Private project.
