# Questions documentation

All documentation is in English.

| Document | Contents |
|---|---|
| [User guide](user-guide.md) | Every screen and workflow, multi-answer practice, navigation and paused sessions, statistics and subtopics, AI definition bubble, error-card review, AI providers and per-topic Anki decks |
| [Practice JSON format](json-format.md) | Complete field reference, schema constraints, single and multiple correct answers, subtopics, `sourceId`, download/update matching, validation paths, duplicates, common mistakes and a full example |
| [AnkiDroid export](anki.md) | API setup, per-topic decks, the six-field error note type, field formats, multi-answer fields, file fallback |
| [Architecture and feature map](architecture.md) | Layers, every feature mapped to code and tables, done/solved/skipped, error lifecycle, sessions, review, statistics, backup, platform bridges |
| [Database reference](database.md) | Generated table/column/index map, references and cascades, subtopics end to end, settings keys, migration history 1→10, backup coverage |
| [Testing](testing.md) | Automated coverage and manual device checklist |
| [README](../README.md) | Overview, setup, build and test commands |

The database, migration and backup sections are generated. After changing
`lib/core/database/tables.dart` or `app_database.dart`, run
`dart run tool/docs/update_docs.dart`; `--check` fails when the docs drift.
