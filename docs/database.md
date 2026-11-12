# Database reference

Questions stores everything locally in one SQLite database through Drift. The
schema is defined in `lib/core/database/tables.dart`; migrations, custom
indexes and the current version live in `lib/core/database/app_database.dart`.
Domain objects in `lib/core/domain/models.dart` are immutable and repositories
in `lib/core/data/` translate rows into them.

The schema map, migration history and backup coverage below are generated from
that code. Do not edit inside the generated markers by hand.

```bash
dart run tool/docs/update_docs.dart          # rewrite generated sections
dart run tool/docs/update_docs.dart --check  # fail when docs drift
```

`flutter test test/docs` runs the same check. CI and the tracked pre-push hook
also run it, so a table, column, index, migration or backup-table change cannot
land without regenerated documentation.

## Tables, columns and indexes

<!-- BEGIN GENERATED: database -->
Current schema version: **10** (`AppDatabase.schemaVersion`).

Table names below are the SQL names Drift creates. Every column, default, reference, cascade, primary key, unique key and index is read from `lib/core/database/tables.dart` and `app_database.dart`; the feature/model/repository notes come from the documented mapping in `tool/docs/update_docs.dart`.

### Tables

#### `topics`

**Drift class:** `Topics` · **Row class:** `TopicRow`

**Feature use:** Home topic list, topic editor, archive/restore, per-topic Anki deck, priority and natural-name ordering, statistics scope.

**Domain model:** `Topic` · **Repository:** `PracticeRepository` · **DAO:** `SessionDao`, `StatsDao`, `TopicDao`

| Column | Type | Null | Default | Constraints | References |
|---|---|---|---|---|---|
| `id` | INTEGER | NOT NULL | — | AUTOINCREMENT, PRIMARY KEY | — |
| `name` | TEXT | NOT NULL | — | length 1..120 | — |
| `description` | TEXT | NOT NULL | `''` | — | — |
| `priority` | INTEGER | NULL | — | — | — |
| `anki_deck` | TEXT | NULL | — | — | — |
| `created_at` | INTEGER (DateTime) | NOT NULL | — | — | — |
| `archived` | INTEGER (boolean) | NOT NULL | `false` | — | — |

**Keys and indexes**

- Primary key: `id` (auto-increment)
- Explicit table indexes: none

#### `practices`

**Drift class:** `Practices` · **Row class:** `PracticeRow`

**Feature use:** Topic practice list, import and duplicate detection, rename/description edit, mark done/active, split, practice JSON download/update.

**Domain model:** `Practice` · **Repository:** `PracticeRepository` · **DAO:** `SessionDao`, `StatsDao`, `TopicDao`

| Column | Type | Null | Default | Constraints | References |
|---|---|---|---|---|---|
| `id` | INTEGER | NOT NULL | — | AUTOINCREMENT, PRIMARY KEY | — |
| `topic_id` | INTEGER | NOT NULL | — | — | `topics.id` ON DELETE CASCADE |
| `name` | TEXT | NOT NULL | — | length 1..120 | — |
| `description` | TEXT | NOT NULL | `''` | — | — |
| `content_hash` | TEXT | NOT NULL | — | — | — |
| `imported_at` | INTEGER (DateTime) | NOT NULL | — | — | — |
| `is_done` | INTEGER (boolean) | NOT NULL | `false` | — | — |

**Keys and indexes**

- Primary key: `id` (auto-increment)
- Index `practices_topic`: (`topic_id`)

#### `questions`

**Drift class:** `Questions` · **Row class:** `QuestionRow`

**Feature use:** Import, practice sessions, shuffled eligibility, multi-answer scoring, subtopic statistics, practice JSON export/update.

**Domain model:** `Question` · **Repository:** `PracticeRepository` · **DAO:** `SessionDao`, `StatsDao`, `TopicDao`

| Column | Type | Null | Default | Constraints | References |
|---|---|---|---|---|---|
| `id` | INTEGER | NOT NULL | — | AUTOINCREMENT, PRIMARY KEY | — |
| `practice_id` | INTEGER | NOT NULL | — | — | `practices.id` ON DELETE CASCADE |
| `prompt` | TEXT | NOT NULL | — | — | — |
| `alternatives_json` | TEXT | NOT NULL | — | — | — |
| `correct_indexes_json` | TEXT | NOT NULL | `'[0]'` | — | — |
| `explanation` | TEXT | NOT NULL | — | — | — |
| `alternative_explanations_json` | TEXT | NOT NULL | — | — | — |
| `position` | INTEGER | NOT NULL | — | — | — |
| `subtopic` | TEXT | NULL | — | — | — |

**Keys and indexes**

- Primary key: `id` (auto-increment)
- Index `questions_practice`: (`practice_id`)

#### `sessions`

**Drift class:** `Sessions` · **Row class:** `SessionRow`

**Feature use:** Practice, mixed and past-error runs, paused sessions on Home, score and statistics history.

**Domain model:** `PracticeSession` · **Repository:** `SessionRepository` · **DAO:** `SessionDao`, `StatsDao`

| Column | Type | Null | Default | Constraints | References |
|---|---|---|---|---|---|
| `id` | INTEGER | NOT NULL | — | AUTOINCREMENT, PRIMARY KEY | — |
| `practice_id` | INTEGER | NULL | — | — | `practices.id` ON DELETE CASCADE |
| `mode` | TEXT | NOT NULL | — | — | — |
| `status` | TEXT | NOT NULL | — | — | — |
| `started_at` | INTEGER (DateTime) | NOT NULL | — | — | — |
| `finished_at` | INTEGER (DateTime) | NULL | — | — | — |
| `total` | INTEGER | NOT NULL | — | — | — |
| `correct` | INTEGER | NOT NULL | `0` | — | — |
| `skipped` | INTEGER | NOT NULL | `0` | — | — |
| `distracted` | INTEGER | NOT NULL | `0` | — | — |

**Keys and indexes**

- Primary key: `id` (auto-increment)
- Index `sessions_status`: (`status`)

#### `session_questions`

**Drift class:** `SessionQuestions` · **Row class:** `SessionQuestionRow`

**Feature use:** Ordered question set of an in-progress or completed session; enables resume and counts questions left unanswered.

**Domain model:** `—` · **Repository:** `SessionRepository` · **DAO:** `SessionDao`, `StatsDao`

| Column | Type | Null | Default | Constraints | References |
|---|---|---|---|---|---|
| `session_id` | INTEGER | NOT NULL | — | PRIMARY KEY | `sessions.id` ON DELETE CASCADE |
| `question_id` | INTEGER | NOT NULL | — | PRIMARY KEY | `questions.id` ON DELETE CASCADE |
| `position` | INTEGER | NOT NULL | — | — | — |

**Keys and indexes**

- Primary key: `session_id`, `question_id`
- Index `session_questions_question`: (`question_id`)

#### `attempts`

**Drift class:** `Attempts` · **Row class:** `AttemptRow`

**Feature use:** One submitted answer, reasoning, distraction and "I didn't know this" flags, and the done/solved/skipped history.

**Domain model:** `Attempt` · **Repository:** `SessionRepository` · **DAO:** `SessionDao`, `StatsDao`

| Column | Type | Null | Default | Constraints | References |
|---|---|---|---|---|---|
| `id` | INTEGER | NOT NULL | — | AUTOINCREMENT, PRIMARY KEY | — |
| `session_id` | INTEGER | NOT NULL | — | — | `sessions.id` ON DELETE CASCADE |
| `question_id` | INTEGER | NOT NULL | — | — | `questions.id` ON DELETE CASCADE |
| `selected_indexes_json` | TEXT | NOT NULL | `'[]'` | — | — |
| `reasoning` | TEXT | NOT NULL | `''` | — | — |
| `distracted` | INTEGER (boolean) | NOT NULL | `false` | — | — |
| `unknown` | INTEGER (boolean) | NOT NULL | `false` | — | — |
| `is_correct` | INTEGER (boolean) | NOT NULL | — | — | — |
| `answered_at` | INTEGER (DateTime) | NOT NULL | — | — | — |

**Keys and indexes**

- Primary key: `id` (auto-increment)
- Unique: (`session_id`, `question_id`)
- Index `attempts_session`: (`session_id`)
- Index `attempts_question`: (`question_id`)

#### `concepts`

**Drift class:** `Concepts` · **Row class:** `ConceptRow`

**Feature use:** Define lookups, missing-definition review steps and concept cards for Anki export.

**Domain model:** `Concept` · **Repository:** `CardRepository` · **DAO:** `CardDao`, `SessionDao`, `StatsDao`

| Column | Type | Null | Default | Constraints | References |
|---|---|---|---|---|---|
| `id` | INTEGER | NOT NULL | — | AUTOINCREMENT, PRIMARY KEY | — |
| `session_id` | INTEGER | NULL | — | — | `sessions.id` ON DELETE CASCADE |
| `question_id` | INTEGER | NULL | — | — | `questions.id` ON DELETE SET NULL |
| `term` | TEXT | NOT NULL | — | — | — |
| `definition` | TEXT | NOT NULL | `''` | — | — |
| `extra` | TEXT | NOT NULL | `''` | — | — |
| `context` | TEXT | NOT NULL | `''` | — | — |
| `topic_name` | TEXT | NOT NULL | `''` | — | — |
| `source` | TEXT | NOT NULL | — | — | — |
| `created_at` | INTEGER (DateTime) | NOT NULL | — | — | — |
| `exported_at` | INTEGER (DateTime) | NULL | — | — | — |

**Keys and indexes**

- Primary key: `id` (auto-increment)
- Index `concepts_session`: (`session_id`)
- Index `concepts_exported`: (`exported_at`)

#### `error_cards`

**Drift class:** `ErrorCards` · **Row class:** `ErrorCardRow`

**Feature use:** Wrong-answer error queue, 48-hour retry, bias/vaccine review, shared card review and Anki export.

**Domain model:** `ErrorCard` · **Repository:** `CardRepository` · **DAO:** `CardDao`, `StatsDao`

| Column | Type | Null | Default | Constraints | References |
|---|---|---|---|---|---|
| `id` | INTEGER | NOT NULL | — | AUTOINCREMENT, PRIMARY KEY | — |
| `question_id` | INTEGER | NOT NULL | — | — | `questions.id` ON DELETE CASCADE |
| `session_id` | INTEGER | NULL | — | — | `sessions.id` ON DELETE CASCADE |
| `question` | TEXT | NOT NULL | — | — | — |
| `alternatives_json` | TEXT | NOT NULL | — | — | — |
| `correct_indexes_json` | TEXT | NOT NULL | `'[0]'` | — | — |
| `wrong_indexes_json` | TEXT | NOT NULL | `'[0]'` | — | — |
| `reasoning` | TEXT | NOT NULL | `''` | — | — |
| `explanation` | TEXT | NOT NULL | `''` | — | — |
| `alternative_explanations_json` | TEXT | NOT NULL | `'[]'` | — | — |
| `bias` | TEXT | NOT NULL | `''` | — | — |
| `vaccine` | TEXT | NOT NULL | `''` | — | — |
| `topic_name` | TEXT | NOT NULL | `''` | — | — |
| `practice_name` | TEXT | NOT NULL | `''` | — | — |
| `status` | TEXT | NOT NULL | — | — | — |
| `created_at` | INTEGER (DateTime) | NOT NULL | — | — | — |
| `last_wrong_at` | INTEGER (DateTime) | NOT NULL | — | — | — |
| `due_at` | INTEGER (DateTime) | NOT NULL | — | — | — |
| `details_completed_at` | INTEGER (DateTime) | NULL | — | — | — |
| `resolved_at` | INTEGER (DateTime) | NULL | — | — | — |
| `exported_at` | INTEGER (DateTime) | NULL | — | — | — |

**Keys and indexes**

- Primary key: `id` (auto-increment)
- Index `error_cards_due`: (`status`, `due_at`)
- Index `error_cards_question`: (`question_id`)
- Index `error_cards_session`: (`session_id`)
- Partial unique index `error_cards_active_question`: (`question_id`) WHERE `status = 'active'`
- The partial unique index above enforces at most one `active` error card per question; resolved history rows are unrestricted.

#### `manual_cards`

**Drift class:** `ManualCards` · **Row class:** `ManualCardRow`

**Feature use:** Basic question/answer cards from skipped questions, Ask or a highlight.

**Domain model:** `ManualCard` · **Repository:** `CardRepository` · **DAO:** `CardDao`, `StatsDao`

| Column | Type | Null | Default | Constraints | References |
|---|---|---|---|---|---|
| `id` | INTEGER | NOT NULL | — | AUTOINCREMENT, PRIMARY KEY | — |
| `session_id` | INTEGER | NULL | — | — | `sessions.id` ON DELETE CASCADE |
| `question_id` | INTEGER | NULL | — | — | `questions.id` ON DELETE SET NULL |
| `question` | TEXT | NOT NULL | — | — | — |
| `answer` | TEXT | NOT NULL | — | — | — |
| `context` | TEXT | NOT NULL | `''` | — | — |
| `topic_name` | TEXT | NOT NULL | `''` | — | — |
| `created_at` | INTEGER (DateTime) | NOT NULL | — | — | — |
| `exported_at` | INTEGER (DateTime) | NULL | — | — | — |

**Keys and indexes**

- Primary key: `id` (auto-increment)
- Index `manual_cards_exported`: (`exported_at`)

#### `skipped_questions`

**Drift class:** `SkippedQuestions` · **Row class:** `SkippedQuestionRow`

**Feature use:** Persistent skipped-question queue that stays in Cards until a concept or basic card is made.

**Domain model:** `SkippedQuestion` · **Repository:** `CardRepository` · **DAO:** `CardDao`

| Column | Type | Null | Default | Constraints | References |
|---|---|---|---|---|---|
| `id` | INTEGER | NOT NULL | — | AUTOINCREMENT, PRIMARY KEY | — |
| `session_id` | INTEGER | NULL | — | — | `sessions.id` ON DELETE CASCADE |
| `question_id` | INTEGER | NOT NULL | — | — | `questions.id` ON DELETE CASCADE |
| `question` | TEXT | NOT NULL | — | — | — |
| `alternatives_json` | TEXT | NOT NULL | — | — | — |
| `correct_indexes_json` | TEXT | NOT NULL | `'[0]'` | — | — |
| `explanation` | TEXT | NOT NULL | `''` | — | — |
| `alternative_explanations_json` | TEXT | NOT NULL | `'[]'` | — | — |
| `reasoning` | TEXT | NOT NULL | `''` | — | — |
| `topic_name` | TEXT | NOT NULL | `''` | — | — |
| `practice_name` | TEXT | NOT NULL | `''` | — | — |
| `unknown` | INTEGER (boolean) | NOT NULL | `false` | — | — |
| `created_at` | INTEGER (DateTime) | NOT NULL | — | — | — |
| `handled_at` | INTEGER (DateTime) | NULL | — | — | — |
| `handled_kind` | TEXT | NULL | — | — | — |

**Keys and indexes**

- Primary key: `id` (auto-increment)
- Index `skipped_questions_handled`: (`handled_at`)
- Index `skipped_questions_session`: (`session_id`)

#### `highlights`

**Drift class:** `Highlights` · **Row class:** `HighlightRow`

**Feature use:** Selected passages painted during practice, kept or converted into a concept/basic card, downloaded as plain text.

**Domain model:** `StudyHighlight` · **Repository:** `CardRepository` · **DAO:** `CardDao`

| Column | Type | Null | Default | Constraints | References |
|---|---|---|---|---|---|
| `id` | INTEGER | NOT NULL | — | AUTOINCREMENT, PRIMARY KEY | — |
| `session_id` | INTEGER | NULL | — | — | `sessions.id` ON DELETE CASCADE |
| `question_id` | INTEGER | NULL | — | — | `questions.id` ON DELETE SET NULL |
| `phrase` | TEXT | NOT NULL | — | — | — |
| `context` | TEXT | NOT NULL | `''` | — | — |
| `topic_name` | TEXT | NOT NULL | `''` | — | — |
| `practice_name` | TEXT | NOT NULL | `''` | — | — |
| `created_at` | INTEGER (DateTime) | NOT NULL | — | — | — |
| `kept_at` | INTEGER (DateTime) | NULL | — | — | — |
| `card_created_at` | INTEGER (DateTime) | NULL | — | — | — |
| `manual_card_id` | INTEGER | NULL | — | — | `manual_cards.id` ON DELETE SET NULL |

**Keys and indexes**

- Primary key: `id` (auto-increment)
- Index `highlights_session`: (`session_id`)
- Index `highlights_question`: (`question_id`)

#### `settings`

**Drift class:** `Settings` · **Row class:** `SettingRow`

**Feature use:** Lookup mode, AI provider/model/base URL, dynamic color, sounds and volume, default Anki deck, Home topic sort and each topic's practice sort.

**Domain model:** `AppSettings` · **Repository:** `SettingsRepository` · **DAO:** `SettingsDao`

| Column | Type | Null | Default | Constraints | References |
|---|---|---|---|---|---|
| `key` | TEXT | NOT NULL | — | PRIMARY KEY | — |
| `value` | TEXT | NOT NULL | — | — | — |

**Keys and indexes**

- Primary key: `key`
- Explicit table indexes: none

### Index summary

| Index | Table | Columns | Kind | Condition |
|---|---|---|---|---|
| `practices_topic` | `practices` | `topic_id` | INDEX | — |
| `questions_practice` | `questions` | `practice_id` | INDEX | — |
| `sessions_status` | `sessions` | `status` | INDEX | — |
| `session_questions_question` | `session_questions` | `question_id` | INDEX | — |
| `attempts_session` | `attempts` | `session_id` | INDEX | — |
| `attempts_question` | `attempts` | `question_id` | INDEX | — |
| `concepts_session` | `concepts` | `session_id` | INDEX | — |
| `concepts_exported` | `concepts` | `exported_at` | INDEX | — |
| `error_cards_due` | `error_cards` | `status`, `due_at` | INDEX | — |
| `error_cards_question` | `error_cards` | `question_id` | INDEX | — |
| `error_cards_session` | `error_cards` | `session_id` | INDEX | — |
| `manual_cards_exported` | `manual_cards` | `exported_at` | INDEX | — |
| `skipped_questions_handled` | `skipped_questions` | `handled_at` | INDEX | — |
| `skipped_questions_session` | `skipped_questions` | `session_id` | INDEX | — |
| `highlights_session` | `highlights` | `session_id` | INDEX | — |
| `highlights_question` | `highlights` | `question_id` | INDEX | — |
| `error_cards_active_question` | `error_cards` | `question_id` | UNIQUE | `status = 'active'` |
<!-- END GENERATED: database -->

## Relationships and deletion behaviour

- `topics` own `practices`; deleting a topic deletes its practices and
  questions, and every session belonging to those practices. Session-linked
  cards, skipped questions and highlights go with the session; question-only
  snapshots lose their question link as described below. There is no soft
  delete for content.
- `practices` own `questions`. Deleting a practice or topic removes its
  questions, attempts, session links, error cards and skipped records.
- `sessions` own `session_questions` and `attempts`. Deleting a session removes
  those rows, plus cards, concepts, skipped questions and highlights that
  captured that session. Resolved error history tied to the session is removed
  too; error cards are history for a question, not an independent archive.
- `concepts`, `manual_cards`, `skipped_questions` and `highlights` reference a
  question only while it exists. When a question is deleted, concepts, basic
  cards and highlights keep their snapshot and their `question_id` becomes
  `NULL` (`ON DELETE SET NULL`). Skipped-question and error-card rows are
  deleted with the question (`ON DELETE CASCADE`).
- `highlights.manual_card_id` becomes `NULL` if the basic card made from the
  highlight is deleted; the highlight itself remains.
- The partial unique index `error_cards_active_question` allows at most one
  `active` error card per question while leaving any number of resolved rows.
- `PRAGMA foreign_keys = ON` is executed in `beforeOpen`, so SQLite enforces all
  of the above at runtime rather than only documenting it.
- Statistics are computed from `sessions`, `session_questions`, `attempts`,
  `questions` and `error_cards` at query time. No aggregate table is stored, so
  deleting content immediately removes its statistics.
- Timestamps are stored as UTC DateTime values. Mappers convert rows back to
  UTC, including dates read from a backup.

## Subtopics end to end

A subtopic is an optional grouping string on each question. It is not a table;
the whole feature follows one nullable column so a practice can be grouped
without changing its topic.

1. **Import.** A question in a practice JSON file may contain an optional
   `subtopic` string. `ImportService` trims it into `QuestionDraft.subtopic`.
   The JSON schema and import limits are documented in
   [Practice JSON format](json-format.md).
2. **Store.** `PracticeRepository` normalises blank text to `NULL` through
   `_normalizeSubtopic`, and `Questions.subtopic` stores the trimmed value.
   `Question.subtopic` maps `NULL` back to an empty string and exposes
   `hasSubtopic` for the UI.
3. **Export and update.** Download practice JSON emits `subtopic` only when it
   is non-empty. An update compares the stored and file values (trimmed),
   previews the question as modified when the grouping changed, and rewrites
   `questions.subtopic` for matched questions. New questions insert the value;
   deleted questions remove it with the row.
4. **Statistics.** `StatsDao.watchSubtopicStats` groups a topic's questions by
   `COALESCE(NULLIF(TRIM(q.subtopic), ''), '')`. Attempts are counted only when
   their session is `completed` and the answer had a non-empty selection.
   Groups are sorted by name with the uncategorised group last.
5. **Display.** The Statistics screen shows **By subtopic** only when at least
   one question has a non-empty subtopic. Empty strings appear as
   **Uncategorized**. Grouping is exact after trimming, so `Networking` and
   `networking` remain separate groups.
6. **JSON export.** The topic statistics payload includes a `subtopics` array
   with `subtopic`, question/attempted/answered/correct counts, accuracy and
   progress when at least one group is named. See
   [Architecture](architecture.md#statistics-and-statistics-export).
7. **Backup.** Backup v2 serialises `questions` as database rows, so
   `subtopic` travels with every question. A v1 backup without that column
   restores it as `NULL`; the question then appears under Uncategorized.

## Settings keys

`settings` is a key/value table. `SettingsRepository` owns the keys and their
defaults; the sort values use the `field:direction` form from `ListSort`.

| Key | Value | Used by |
|---|---|---|
| `lookup_mode` | `web` or `ai` | Define lookup mode; Ask always uses AI |
| `web_engine` | `duckDuckGo` or `wikipedia` | Web lookup engine |
| `ai_provider` | `openai`, `groq`, `openRouter`, `gemini`, `custom` | AI lookup and review checks |
| `ai_base_url` | URL string | Custom/OpenAI-compatible endpoint |
| `ai_model` | model id | AI lookup and review checks |
| `dynamic_color` | `true` or `false` | Material You wallpaper colors |
| `sounds_enabled` | `true` or `false` | Practice correct/wrong/finished cues |
| `sound_volume` | `0.05`–`1` | Practice sound volume |
| `anki_deck` | deck name | Default deck for topics without their own |
| `home_topic_sort` | `name:increasing`, `name:decreasing`, `recency:increasing`, `recency:decreasing` | Home topic order |
| `topic_practice_sort_<topicId>` | same `field:direction` values | Each topic's practice order |

The AI API key is not in this table. It lives in Android secure storage through
`SecureKeyStore`, is never exported, and is not overwritten by a restore.

## Migration history

<!-- BEGIN GENERATED: migrations -->
Current schema version: **10**. Migration steps are read from `AppDatabase.migration.onUpgrade`; `onCreate` creates every table and the custom partial indexes listed above.

| Version | Changes |
|---|---|
| 1 | Initial schema with `topics`, `practices`, `questions`, `sessions`, `session_questions`, `attempts`, `concepts`, `error_cards`, `manual_cards`, `settings`. |
| 2 | Added `anki_deck` to `topics`. Added `topic_name` to `manual_cards`. |
| 3 | Added `correct_indexes_json` to `questions`. Added `selected_indexes_json` to `attempts`. Added `correct_indexes_json` to `error_cards`. Added `wrong_indexes_json` to `error_cards`. Custom SQL backfilled `questions`, `attempts`, `error_cards`. |
| 4 | Added `explanation` to `error_cards`. Added `alternative_explanations_json` to `error_cards`. |
| 5 | Added `is_done` to `practices`. |
| 6 | Added `unknown` to `attempts`. Added `extra` to `concepts`. |
| 7 | Added `question_id` to `manual_cards`. Added `context` to `manual_cards`. Created table `skipped_questions`. |
| 8 | Created table `highlights`. |
| 9 | Added `archived` to `topics`. |
| 10 | Added `subtopic` to `questions`. |

The database opens with `PRAGMA foreign_keys = ON`, so every reference and cascade in the table map is enforced. Versions are cumulative: a database at version 1 runs every step from 2 through 10.
<!-- END GENERATED: migrations -->

## Backup coverage

<!-- BEGIN GENERATED: backup -->
Backup format **v2**; minimum readable format **v1**. Files record app version **0.9.10** build **11**, the database schema version, export time and per-table row counts.

| Coverage | Backup keys |
|---|---|
| Required in every backup | `topics`, `practices`, `questions`, `sessions`, `sessionQuestions`, `attempts`, `concepts`, `errorCards`, `manualCards`, `settings` |
| Optional for older files | `skippedQuestions`, `highlights` |

The required and optional sets together cover every database table exactly once. `settings` stores preferences as key/value rows; the AI API key is in Android secure storage and is never exported.
<!-- END GENERATED: backup -->

## Backup format and restore rules

- `BackupService` writes format **v2**. The `tables` object contains every
  database table; the canonical SHA-256 checksum is computed over that object
  with sorted keys, so formatting changes do not alter it.
- The `metadata` block records format version, app version and build, database
  schema version, export time and per-table row counts. The app rejects a file
  whose recorded counts do not match the rows it contains.
- Required tables must exist. `skippedQuestions` and `highlights` are optional
  so a file from an older install still restores; unknown tables are ignored.
- Rows are read leniently for v1: missing columns use database defaults, and a
  topic deck may arrive as `ankiDeck`, `anki_deck` or `deck`.
- Validation runs before any write: UTF-8 and 50 MB limit, JSON shape, enum
  values, JSON-array columns, duplicate identities, the one-active-error-card
  rule, and referential integrity for practices, questions, session questions,
  attempts, concepts, error cards, basic cards, skipped questions and
  highlights. Each failure reports the table, row and field.
- Restore replaces all local tables inside one transaction and then refreshes
  every data provider. A failure leaves the previous database untouched.
  **Erase all data** uses the same replacement path and also deletes the
  secure-storage API key.

## Changing the schema

1. Edit `lib/core/database/tables.dart` and add a migration step in
   `AppDatabase.migration.onUpgrade`; bump `schemaVersion`.
2. If a table is new, add an entry to `_tableDocs` in
   `tool/docs/update_docs.dart` with its feature, domain model and repository.
   The generator fails instead of silently omitting it.
3. If backup coverage changes, update `requiredTables` or `optionalTables` in
   `BackupService`; the generator checks that both sets cover every table
   exactly once.
4. Run `dart run tool/docs/update_docs.dart`, then
   `dart run tool/docs/update_docs.dart --check` and
   `flutter test test/docs`.
