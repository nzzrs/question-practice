# Architecture and feature map

Questions is an offline-first Flutter app. It keeps practice content, session
history, cards and settings in one local Drift database, and has no account or
server component. This document maps every current feature to the code that
implements it and to the tables it reads or writes. The exhaustive column,
constraint and index reference is in [Database reference](database.md).

## Layers

```
UI (lib/features/*, lib/core/ui)
  -> Riverpod providers (lib/app/providers.dart)
  -> services (import, practice edit, session, review, lookup, export, backup)
  -> repositories (practice, session, card, settings)
  -> Drift DAOs (topic, session, card, stats, settings)
  -> SQLite schema (lib/core/database)
```

Domain models in `lib/core/domain/models.dart` are immutable plain Dart.
Repositories return models, not Drift rows; mappers in
`lib/core/data/mappers.dart` decode JSON-array columns and normalise timestamps
to UTC. Services hold rules that need more than one repository or a clock.
`clockProvider` is injected so the 48-hour rule, reminders and statistics are
testable.

## Feature map

### Library, topics and practices

| Feature | Behaviour | Code | Tables |
|---|---|---|---|
| Home library | Active topics with practice count, question count, accuracy, progress, active/due errors, completed sessions and last practised date. Empty states distinguish no topics from all topics archived. | `lib/features/home/home_page.dart`, `StatsDao.watchTopicSummaries` | `topics`, `practices`, `questions`, `sessions`, `attempts`, `error_cards` |
| Topic editing | **Edit topic** is one compact form of option-style tiles in this order: name, description, optional priority 1–5, minimum score and target score (percentages defaulting to 70 and 80), optional deck, JSON download and JSON update. It has no section headings or helper paragraphs. Valid edits autosave after 600 ms and flush on focus loss and close. Invalid drafts are never written; a blocked close reveals the first invalid field and offers **Discard changes**, which restores the last saved values without writing. Deck names can be typed or browsed from live AnkiDroid data. The topic long-press menu groups **Edit topic**, **Archive**/**Unarchive** and **Delete**, like the practice menu. | `lib/features/topics/topic_actions.dart`, `topic_editor_sheet.dart`, `anki_deck_picker.dart` | `topics` |
| Topic JSON download and update | Offered from **Edit topic**, not the top-level topic menu. Shares one file with the topic and every practice it contains. Updating validates the file, matches the topic by name, updates metadata, diffs each practice by practice name and question `sourceId`/prompt, creates new practices/questions and deletes missing questions. Practices absent from the file are left untouched. Separate from the per-practice JSON options. | `lib/features/topics/domain/topic_edit_service.dart`, `ImportService`, `PracticeRepository` | `topics`, `practices`, `questions`; existing history |
| Archive and restore | Archiving sets `topics.archived`; the active Home query excludes archived rows, while the archived sheet includes them. Data, deck, sessions and statistics remain. | `topic_actions.dart`, `archived_topics_sheet.dart`, `PracticeRepository.watchArchivedTopicSummaries` | `topics` |
| Delete topic | Confirmation, then cascading deletion of its practices, questions, sessions and attempts. Error cards and skipped records go with their question; concepts, basic cards and notes are removed with their session and otherwise keep only their snapshot with a `NULL` question link. | `PracticeRepository.deleteTopic` | `topics` and dependants |
| Practice list | Each topic lists its practices with question count, last score and an in-progress badge. | `lib/features/topics/topic_page.dart`, `StatsDao.watchPracticeSummaries` | `practices`, `questions`, `sessions` |
| Practice actions | Long-press offers **Edit practice**, mark done/active, split and delete. Done practices stay in the topic but are labelled; they are not archived. | `lib/features/topics/practice_actions.dart` | `practices` |
| Edit practice | Rename and edit description. There is no per-practice deck: decks are topic-level only. | `PracticeRepository.renamePractice/updatePracticeDescription` | `practices` |
| Split practice | Requires at least two questions and a part count from two to the question count. Questions are shuffled and dealt into parts whose sizes differ by at most one, then the original is deleted. New practices are named `<name> Slice A`, `B`, and so on through `Z`, then `<name> Slice 27` and up, with numeric suffixes when a name is taken. Its sessions, answers and cards go with it. | `PracticeRepository.splitPractice` | `practices`, `questions`; cascades |
| Per-topic sort | Home stores `home_topic_sort`; each topic stores `topic_practice_sort_<id>`. Both use name/recency plus increasing/decreasing and survive restarts. | `lib/core/domain/list_sort.dart`, `SettingsRepository`, `lib/core/ui/sort_dialog.dart` | `settings` |

### Import, update and question content

| Feature | Behaviour | Code | Tables |
|---|---|---|---|
| JSON import | Accepts `.json` or `.txt` containing JSON, max 10 MB and 5,000 questions. Validates with the schema asset and semantic checks before opening a transaction. Shows BOM/text handling and JSON line/column errors. | `lib/features/import/domain/import_service.dart`, `import_page.dart` | `topics`, `practices`, `questions` |
| Duplicate handling | A topic name is reused case-insensitively. A practice with the same content hash is skipped. A different practice with the same name gets ` (2)`, ` (3)` and so on. Import preview names both cases. | `ImportService._duplicateNotes`, `PracticeRepository.findTopicByName/findPracticeByHash/findPracticeByName` | `topics`, `practices` |
| Question shape | 2–8 alternatives, `correctIndex` or `correctIndexes`, overall explanation, one alternative explanation per alternative, optional subtopic and optional `sourceId`. | `assets/schema/practice_import.schema.json`, `ImportService._readTopics` | `questions` |
| Practice JSON download | Shares one topic/practice file in import format with `sourceId` on every question, `subtopic` only when set, and `correctIndex`/`correctIndexes`. Never includes a deck. | `lib/features/practice_edit/domain/practice_edit_service.dart` | `topics`, `practices`, `questions` |
| Practice JSON update | Requires the stored topic and practice names after trimming/case-folding. Matches questions by `sourceId` first, then exact trimmed prompt. Previews new/modified/unchanged/deleted counts, then applies one transaction. Matched ids keep attempts, error cards, skipped records and statistics; deleted questions cascade; linked concepts, basic cards and notes lose only their question link. | `PracticeEditService.previewUpdate/apply`, `PracticeRepository.applyPracticeUpdate` | `practices`, `questions`; existing history |
| Subtopics | Stored per question in `questions.subtopic`, trimmed; blank is stored as `NULL`. Used by practice JSON export/update, statistics grouping, category management and backup. Rename, delete and merge update only this column for one topic; no separate table or migration. | `QuestionDraft.subtopic`, `Question.subtopic`, `_normalizeSubtopic`, `StatsDao.watchSubtopicStats`, `PracticeRepository.renameSubtopic/deleteSubtopics/mergeSubtopics`, `TopicDao.setSubtopicForTopic` | `questions` |
| Multi-answer scoring | Correctness is set equality: every correct index is selected and no extra index is selected. Partial selections fail. | `Question.isCorrectSelection`, `SessionService.submitAnswer` | `questions`, `attempts` |

### Sessions, answers and progress

| Feature | Behaviour | Code | Tables |
|---|---|---|---|
| Session modes | `practice` (one practice, all its questions), `mixed` (shuffled practice across topics) and `pastErrors` (due error cards). | `SessionMode`, `SessionService.startPractice/startMixed/startPastErrors` | `sessions`, `session_questions`, `questions` |
| Session lifecycle | A row is created as `inProgress` with its ordered question list. Completing writes scores and `finishedAt`; abandoning marks `abandoned`; discarding deletes the session and its dependent rows. | `SessionRepository.startSession/completeSession/abandonSession/discardSession` | `sessions`, `session_questions` |
| Paused sessions | Home watches every `inProgress` session, not only the newest. Each card offers **Resume** and **Discard**. Save for later keeps the session; discard deletes it and the error cards it created. | `SessionDao.watchInProgressSessions`, Home | `sessions`, `attempts`, `error_cards` |
| Question navigation | The question index lives in the session page. Arrow controls move without answering; submitted attempts reload their selection and feedback. | `session_page.dart`, `SessionStart.attempts` | `session_questions`, `attempts` |
| Alternatives | Each session shuffles alternative order and keeps it per question. Original letters stay hidden until feedback or the eye toggle; the toggle reveals letters without reordering. | `SessionQuestionItem.alternativeOrder` | none (session state) |
| What went wrong | After a wrong, non-skipped answer, a Logseq-style bullet editor collects one atomic note per line. Enter splits at the caret, a pasted outline becomes one bullet per line with its marker stripped, empty bullets are dropped on blur, and the list caps at 30 bullets of 500 characters. Edits autosave after 600 ms and flush on blur, navigation, finish, exit and app pause. | `WrongNotes`, `WrongNotesController`, `SessionService.setWrongNotes`, `session_page.dart` | `attempts.reasoning`, `error_cards.reasoning` |
| Skip and unknown | **Skip** records an empty selection. No current feedback control marks an answer unknown; the stored `unknown` flag remains for older attempts and still counts as skipped. Both count as skipped and create/mark a skipped-question record, not an error card. | `Attempt.isSkipped`, `SessionService.setUnknown`, `_trackSkipped` | `attempts`, `skipped_questions` |
| Distraction | After a wrong answer, checking **I was distracted or read too fast** updates the attempt, removes an error card created by this session and refreshes completed counts. A card from an earlier session stays due and is marked `distracted`, so the review can warn. Unchecking clears the flag and restores or updates the card. | `SessionService.setDistracted`, `CardRepository.setErrorCardDistracted` | `attempts`, `error_cards` |
| Finish early | **Finish practice** offers **Leave unanswered** or **Mark skipped**. Left-out questions are excluded from score and statistics; marked ones get an empty attempt and skipped record. A question answered in an earlier attempt is never treated as unanswered again. | `SessionService.finishEarly`, `SessionStart.pendingUnanswered`, `SessionDao.questionsLeftUnanswered` | `sessions`, `attempts`, `session_questions` |
| Results | Percentage, correct/total, wrong, skipped, distinct looked-up terms, review prompt and Cards shortcut. | `lib/features/practice/summary_page.dart` | `sessions`, `attempts`, `concepts`, `error_cards` |
| Practice sounds | Correct, wrong and finished cues, with a settings toggle and volume; failures never block practice. | `lib/core/platform/practice_sound_player.dart` | `settings` |
| Reminder | A five-minute foreground timer on the current question, repeated every five minutes and reset when the question changes or the app goes to the background. | `session_page.dart`, `Timer.periodic` | none |

### Done, solved and skipped

Per-question history is derived from attempts at query time; there is no state
column on `questions`.

- **Done** — at least one attempt with a non-empty selection that is not marked
  `unknown`. Correct, wrong and distracted answers all count.
- **Solved** — at least one attempt with `is_correct = 1`.
- **Skipped** — an attempt with an empty selection or a legacy `unknown = 1`, or a
  completed session that left the question unanswered through **Leave
  unanswered**.

`SessionRepository.questionProgress()` combines `attempts` with the
`questionsLeftUnanswered` query. The session navigator uses it to tag done
questions; the end-of-session prompt uses it to keep earlier answers out of
"leave unanswered". Shuffled practice includes only questions that are neither
solved nor skipped, so solved questions and questions left unanswered stay out
of the random queue.

### Error cards and past errors

1. A wrong answer with a non-empty selection, not distracted and not unknown,
   creates an `active` error card. The card snapshots the prompt, alternatives,
   correct and wrong indexes, the newline-joined wrong-answer bullets, overall
   explanation, per-alternative explanations, topic and practice names.
2. `dueAt` is the last wrong time plus 48 hours. One active card per question is
   enforced by the partial unique index `error_cards_active_question`.
3. The end-of-session review and Cards put every error, skipped, concept and
   note step in one full-width reading surface with a shared `ReviewShell`.
   The floating create FAB opens `CardCreatorSheet` as a modal bottom sheet over
   the feedback, so there is no split view. The sheet has no save action: the
   dock owns the single Save, which writes the cached drafts through
   `saveCardCreatorDrafts`. Every item keeps a `CardCreatorSnapshot` on the
   page's `CardCreatorController`; closing or hiding the sheet stores typed
   text, template, drafts, AI ideas and seed state, and reopening the same item
   restores them. Snapshots clear only after a successful save or reviewed
   exit. The dock order is back, Save and forward side by side; the back arrow
   is disabled on the first item, the forward arrow on the last, and the last
   item labels Save as Save and finish on every surface. Leaving with pending
   work asks first, including when Save finishes the last item and another item
   still has cached work. Manual entry
   adds cards one at a time and needs no AI. Five templates (Definition,
   Contrast, Cause and effect, Scenario and rule, Steps) write the front and back;
   Definition uses a raw cloze and becomes a Cloze concept, the other four
   become Basic `manual_cards` with the matching cognitive type. Every builder
   card, draft and AI variant carries an advisory quality badge and the
   estimated reading time. The badge covers yes/no questions, long fronts and
   cards, answer clues, template mismatches, missing fields, a missing
   definition and a definition that repeats its term. The sparkle icon beside
   the template opens an optional AI panel: each idea offers up to three wording
   variants, and an error breakdown offers at most two ideas (contrast and exam
   tip). Saved cards keep the topic and subtopic as Anki tags, never in the
   text; the error then gets `detailsCompletedAt`. Errors are not exported
   directly.
   Bias/vaccine text boxes and the old AI check were removed.

   The Create cards UI is split into `CardCreatorBody`, which holds the compact
   template dropdown, fields, quality, drafts, AI panel and save loop, and the
   review host `CardCreatorSheet`. Review pages pass `showSaveButton: false`,
   `showContextRecap: false` and `showSeedSource: false` so the dock owns the
   only Save. Each reviewed item gets a `CardCreatorSnapshot` keyed by its page
   and id; `_storeSnapshot` runs before the controllers are disposed, so a
   drag-down, system back or close keeps typed text, template, drafts, AI ideas
   and seed state for that item. Moving to another step clears only the live
   seed. The dock Save writes cached drafts through
   `saveCardCreatorDrafts`, which also marks the note converted, the error
   details complete or the skipped question handled. `CardCreatorPane` remains
   the non-modal host for embedded/tests and reports draft counts.
   `CardCreatorController` seeds from a bullet (`seedFromBullet`) or a note
   (`seedFromNote`), and the sheet applies a seed only when `seedRevision`
   changes. `LookupService.suggestCardFromWrongNote` drafts one front/back pair
   and chooses its template; without an AI key the front is the bullet and the
   back stays empty with a Settings hint. AI loading, inline failure,
   **Use AI draft**, added-bullet state and draft removal all flow through the
   same controller.
4. After the delay, the card appears in Past errors. A correct re-test sets
   `status = resolved` and `resolvedAt`, keeping the row for history. A wrong
   re-test updates `lastWrongAt` and pushes `dueAt` another 48 hours.
5. Distraction on a re-test does not resolve the card; it stays active and is
   flagged `distracted = 1`. A later non-distracted wrong answer clears the flag.
   Skipped answers never create error cards.
6. The review no longer edits the card's question or alternatives. It shows the
   same read-only feedback surface as practice, so the original question stays a
   stable history link.

Deleting an active error card removes it from the queue. Deleting a question
cascades to its error cards. Deleting a session cascades to cards captured by
that session.

### Review surfaces and card creation

`ReviewService.load(sessionId)` builds an ordered step list:

- For each attempt in id order: skipped answers become a skipped-question step
  (unless the persistent record is already handled), and wrong, non-distracted
  answers become an error-card step when the card still needs details and is
  not exported.
- Concepts from the session that still have no definition become definition
  steps.
- Notes from the session that are neither kept nor converted become note
  steps.

The skipped branch asks what was missing. The contextual **Create cards** action
opens the shared Create cards sheet in the same draggable sheet with a custom
front/back prefilled from the question and correct answer. Manual entry adds one
card at a time and needs no AI; the template sparkle opens optional AI
suggestions. Saving marks the persistent skipped record handled.
Skipped questions stay in the combined **Error and skipped** section of Cards
until handled, where their previews open the same review surface.

Note steps use the shared `NoteReviewView`, the same view Cards opens from a
note preview's **Review** action. **Create cards** opens the sheet for manual
entry, with optional AI suggestions behind the template sparkle. The provider
receives the note, its question context and the topic, and must return one JSON
object with at most three ideas and three variants per idea. The parser
tolerates fenced JSON, trims values, drops
empty or duplicate variants, skips unknown templates and caps ideas and
variants. Accepted variants become Basic cards (or a Cloze concept for a
Definition idea) through `ReviewService`; the note is then marked converted
once, with the first created basic card id.

Review pages run inside `ImmersiveReview`, which hides the system bars while the
review is visible, restores them while another page covers it, and re-enters on
resume or when the learner returns. The end-of-session review, the Cards review
and practice all render `QuestionFeedbackView`: topic and subtopic, question,
alternatives with correct/wrong state and expandable explanations, the status
banner, **Why this answer**, and Define / Ask / Save as note / URL actions. The
review passes read-only bullets and the notes for the question; practice passes
the editable bullet editor and the distraction checks. A distracted card adds
**You were distracted or misread. This card stays due.** In the review each
bullet and note has a three-dot overflow menu. A bullet menu offers Copy and
Create card with AI; a note menu offers Copy, Create card, Define, Ask when an
AI key is configured, and Delete with confirmation. The card action seeds the
bottom-sheet Create cards. Both menus keep the feedback readable and open no
split pane. The feedback stays inside one
selection area, so Define, Ask, Save as note and Copy work across the question,
bullets and notes. The old card-content editor has no entry point. Skipped,
concept and session-note steps share the same dock and sheet.

### Concepts, basic cards, skipped questions and notes

| Feature | Behaviour | Code | Tables |
|---|---|---|---|
| Define (AI) | Sends the selected term, question, topic and subtopic to the configured provider, saves the definition and shows it in a read-only bubble. Acronyms get their full form in `extra`. Concept cards carry topic and subtopic as tags only. | `LookupService.define`, `lookup_sheet.dart` | `concepts`, `settings` |
| Define (web) | Opens DuckDuckGo or Wikipedia in a Custom Tab and keeps an editable definition sheet with Save. A missing concept is saved immediately. | `LookupService.openWeb`, `WebLauncher` | `concepts`, `settings` |
| Ask | Sends the selected passage, its question and the learner message to AI. The answer can become a concept card or a basic card; the basic front places the question context above the learner question. | `ask_sheet.dart`, `LookupService.ask`, `ReviewService.createConcept/createBasicCard` | `concepts` or `manual_cards` when saved |
| Concept cards | Cloze text `Definition of {{c1::term}}: {{c2::definition}}`; `extra` becomes the Anki extra field. Topic and subtopic travel as tags only. Missing definitions block export. | `AnkiNoteBuilder.conceptCloze/conceptFields` | `concepts` |
| Basic cards | Question/answer cards from skipped questions, Ask, a note or a review bullet, with optional context above the front and a cognitive type (Cause and effect, Scenario and rule, Contrast or Steps). | `CardRepository.createManualCard`, `card_creator_sheet.dart`, `review_service.dart` | `manual_cards` |
| Skipped queue | Every skipped answer, including older unknown attempts, is saved per session and question. Re-skipping reopens the same row instead of duplicating it. Unhandled rows survive session completion. | `CardRepository.saveSkippedQuestion`, `SessionService._trackSkipped` | `skipped_questions` |
| Notes (`notes` table) | Selecting question, answer or explanation text offers **Save as note**. The phrase is stored with context, topic, subtopic, practice, session and question and belongs to the question, so it is shown again whenever that question is practised. In practice, tapping a note offers Define, Ask and **Delete note**; that deletion is immediate with no confirmation. In review a note's three-dot menu offers Copy, Create card, Define, and Ask when an AI key is configured; reviews offer no note delete, and notes are deleted from Cards. A note can be kept with Save or turned into cards with the create FAB above the dock. Manual entry adds cards one at a time and works without AI; the template sparkle opens optional AI suggestions with up to three variants per idea, and the learner keeps any combination. Each saved variant becomes a Basic card (or a Cloze concept for a Definition idea) with its cognitive type and subtopic, and the note is marked converted once. Kept notes remain in Cards, where tapping one opens a selectable **Note preview** with its question context; **Review** walks them one at a time through the shared view, which offers **See context** for a read-only question and attempt. The download and select-all icons in the Notes header save them as plain text or select them. They are never sent to Anki. | `selectable_linkified_text.dart`, `session_page.dart`, `CardRepository.createNote/notesForQuestion/keepNote/markNoteConverted/deleteNotes`, `LookupService.suggestArchetypeCards`, `cards_page.dart`, `note_review_page.dart`, `note_review_view.dart`, `card_creator_sheet.dart` | `notes`, `manual_cards` |
| Note download | The download action in the Notes header writes a plain-text file through the system share sheet. | `CardsPage._downloadNotes`, `ExportService.shareNotes` | `notes` |

### Statistics and statistics export

- Topic statistics are derived from completed sessions at query time; no
  aggregate table is stored.
- Topic scores are compared with the topic's minimum and target scores: below the minimum is red, from the minimum up to the target is the normal theme color, and at or above the target is green. The same bands color the practice score pills, readiness ring, latest/average/best cards, subtopic and session pills, and chart dots.
- The hero shows the latest score, best session, completed-session count and a
  question-weighted average: `sum(correct) / sum(total)` over completed
  sessions, not the mean of session percentages.
- **Progress over time** plots one point per completed session. The solid line
  joins sessions; the dashed **Trend (questions)** line is a weighted least
  squares fit of session score against cumulative questions answered, with each
  session weighted by its own question count. The slope is the score change per
  answered question.
- A small projection under the trend uses the weekly learning rate to state the date on which the weighted average would reach the target: **At this rate, you will average the target score by <date>.** It reports that the target is already reached or that the current pace does not reach it.
- **Learning rate** shows two figures from that fit: percentage points per 100
  answered questions (`slope × 10,000`) and percentage points per week
  (`slope × questionsPerDay × 7 × 100`). Questions per day are answered
  questions divided by active study days, the distinct local calendar dates in
  the completed session history. Both appear as soon as a fit exists; there is
  no minimum span.
- **By subtopic** groups questions with `COALESCE(NULLIF(TRIM(subtopic), ''), '')`
  and reports question count, attempted count, answered count, correct count,
  accuracy and progress. Questions without a subtopic appear last as
  **Uncategorized**. The section is hidden when no question has a named
  subtopic. Long-press a row to select a category; in selection mode, tapping
  another row toggles it. One selected row offers rename and delete, two or more
  offer merge and delete. Rename assigns the new name to the topic's matching
  questions. Delete keeps every question and clears the subtopic, so those
  questions become Uncategorized; deleting Uncategorized is a no-op. Merge
  applies one chosen name to every selected category, including Uncategorized
  when selected. Only `questions.subtopic` changes; other topics, questions,
  attempts, sessions and cards stay untouched.
- The share action writes format v1 statistics JSON with `app`,
  `kind: statistics`, topic scope, summary, progress points, `subtopics` (when
  named groups exist) and `trend` with `sessionCount`, `regression`
  (`slope`/`intercept`), `learningRatePercentagePointsPer100Questions` and
  `learningRatePercentagePointsPerWeek`. Rate keys are null without a fit.
- The **Sessions** list allows independent long-press selection. Selected rows
  use a background tint and the app bar shows a clear action plus a trash
  action; category and session selection clear each other. Deleting selected
  sessions runs in one transaction and keeps in-progress sessions because the
  list and delete query are limited to completed rows. Attempts, session
  questions, error cards, skipped records, concepts, notes and basic cards
  cascade with a deleted session.
- A topic's header **Readiness** is the correct share of its last 100 answered
  attempts across completed sessions. The `watchTopicReadiness` inner query
  orders attempts by `answered_at DESC, id DESC`, limits the window and joins
  through sessions, questions and practices. Wrong and skipped attempts count,
  including older attempts stored with the legacy unknown flag, because each
  recorded attempt is in the window; questions left unanswered have no attempt. A short history uses all attempts.
  When the window crosses a session boundary it keeps only the tail of the
  oldest session needed. With no attempts the ring shows **—** and value zero.
- See [Database reference](database.md#subtopics-end-to-end) for the full
  subtopic path from import to backup.

Code: `lib/features/topics/topic_stats_page.dart`,
`lib/features/topics/domain/statistics_export_service.dart`,
`lib/core/domain/progress_math.dart`, `StatsDao.watchSubtopicStats`,
`StatsDao.watchTopicReadiness`,
`PracticeRepository.renameSubtopic/deleteSubtopics/mergeSubtopics/watchTopicReadiness`,
`SessionRepository.deleteSessions`, `SessionDao.deleteSessions`,
`TopicDao.setSubtopicForTopic`.

### Cards, Anki export and deck routing

- Cards filters with one compact, horizontally scrolling row: **All**,
  **Cards**, **Errors** and **Notes**, plus a discrete visibility action for
  exported rows. **Cards** groups concepts and manual basic cards; **Errors**
  also includes skipped questions.
- Selection uses long-press, not checkboxes. Long-press any row to enter
  selection mode and select it; while selection mode is active a tap toggles
  that row, and a normal tap otherwise previews it. A note preview offers
  **Review** to open the note review. The subtitle counts the selection;
  deselecting the selected rows clears it, and no banner or extra row is
  inserted, so rows keep their positions as the selection grows. **Select all**
  and **Review all pending** sit in a right-aligned row directly below the
  filters. Select all covers the rows the current filter shows and ignores
  rows that cannot be selected. An error row preview is titled **Error
  preview** and offers **Review** beside **Close**.
- Selection is global across families and persists in settings as versioned
  JSON keyed by family. It starts empty, is pruned against currently selectable
  rows on load and on list changes, and is removed when it becomes empty or
  corrupt. Exported and deleted ids therefore cannot come back.
- Selection defaults to unexported, complete cards. Error rows are selectable
  only for review/delete and never count toward export or share; review them
  into atomic cards from their preview or with the global pending-review
  action. Concepts need a definition; an incomplete concept is completed from
  its preview. Manual cards of every cognitive type export as Basic. Skipped
  questions and notes can be selected too: they count toward the subtitle,
  **Delete selected** and skip/review flows, but never toward export or share.
- The main action exports a ready selection. When the selection contains a
  pending error or skipped question it becomes **Review pending** and opens the
  combined error/skipped review. A separate **Review all pending** action
  below the filters opens every pending error and skipped question.
- Tapping a note opens a selectable **Note preview** with the saved text and its
  question context, with **Close** and **Review**. **Review** walks the notes one
  at a time with the shared dock: the **Create cards** FAB opens the sheet,
  **Save and finish** keeps the note, and reviews offer no note delete. The
  shared `NoteReviewView` shows the phrase,
  its topic and practice pills, and **See context** for a read-only question and
  attempt; the end-of-session note step uses the same view.
- **Export to AnkiDroid** creates missing decks and note types, bulk-adds notes,
  marks cards exported and broadcasts `com.ichi2.anki.DO_SYNC`.
- **Share as files** writes Anki-compatible cloze `.txt` and basic `.tsv` files. File export does not encode a deck and never includes notes; tags go in the third `Tags` column with `#tags column:3`. Exported Anki notes carry hierarchical `topic::` and `subtopic::` tags in the direct AnkiDroid path.
- **Delete selected** removes the selected concepts, error cards, basic cards,
  skipped questions and notes. Deleting an active error card also removes it
  from the error queue; deleting a skipped row removes only the queue record,
  not its question. Deleting notes removes only the saved phrases; cards
  already made from them stay. Delete stays enabled for any selection even when
  export and share are disabled.
- Decks are selected **per topic only**. A card snapshots its topic name;
  export looks up the current deck by that name and falls back to the Settings
  default. Renaming a topic affects new cards only. There is no per-practice
  deck and practice JSON never contains one.

Code: `lib/features/export/cards_page.dart`,
`lib/features/review/note_review_page.dart`,
`lib/features/review/note_review_view.dart`,
`lib/features/export/domain/export_service.dart`,
`lib/features/export/domain/anki_note_builder.dart`,
`lib/core/platform/anki_gateway.dart`, Android `AnkiBridge.kt`.
See [AnkiDroid export](anki.md).

### Backup, restore and erase

`BackupService` writes one checksummed JSON document with every local table:
topics (including archived topics, decks and score bands), practices, questions
(including subtopics), sessions, session questions, attempts (including legacy
mistake classifications and wrong-answer bullets), concepts (including
subtopic), error cards (including cognitive type, subtopic, legacy mistake
classifications, distracted flag and bullets), basic cards (including cognitive
type and subtopic), skipped
questions, notes (the `notes` table) and settings.

- Format **v3** keeps the canonical checksum over the `tables` object and
  writes notes under the `notes` key. `metadata` records format version, app
  version/build, database schema version, export time and per-table row
  counts. Required and optional table sets are listed in
  [Database reference](database.md#backup-coverage).
- The app imports v1, v2 and v3 files and accepts a missing `skippedQuestions`
  or `notes` table. v1 and v2 files that stored notes under `highlights`,
  with a `phrase` column, are read as notes without losing rows. Unknown
  tables are ignored.
- v1 rows are lenient: missing columns use defaults, and a topic deck is
  accepted from `ankiDeck` or legacy `anki_deck`.
- Validation runs before writing: UTF-8/50 MB, table presence, metadata row
  counts, row shape, JSON arrays, enum values, duplicate primary keys (including
  composite session/question keys), one active error card per question, and
  referential integrity. Failures identify table, row and field.
- Restore replaces every table in one transaction. `refreshDataProviders`
  invalidates every data provider; the topic editor re-reads its row before
  saving so a stale deck snapshot cannot overwrite the restored value.
- **Erase all data** replaces the database and deletes the secure-storage API
  key. The key is never part of a backup and restore does not touch the key
  already on the device.

Code: `lib/features/backup/domain/backup_service.dart`,
`lib/app/data_refresh.dart`, Settings Data section.
See [User guide: Backup and restore](user-guide.md#backup-and-restore).

### Settings and build information

- **Appearance:** wallpaper (Material You) colors on by default, otherwise the
  seed color; system light/dark; practice sounds on/off with volume and a test
  cue.
- **Looking up terms:** web (DuckDuckGo or Wikipedia) or AI. AI provider
  (OpenAI, Groq, OpenRouter, Gemini or custom) chosen from a single-choice
  picker, model chosen from a searchable list loaded from the provider, and
  API key saved automatically to Android secure storage, with **Test
  connection**. Custom shows the base URL. OpenAI-compatible providers use
  `/chat/completions` with a Bearer key; Gemini uses native
  `models/{model}:generateContent`.
- **AnkiDroid:** install/API/permission/Cloze status, a refresh action, the
  permission request, default deck name and live deck browsing.
- **Data:** export backup, restore backup and erase all data.
- **About:** app version `0.9.11`. Backup metadata records the same app version
  and build number (`BackupService.appVersion/buildNumber`).

Code: `lib/features/settings/settings_page.dart`,
`lib/app/providers.dart`, `lib/core/data/settings_repository.dart`,
`lib/features/lookup/domain/lookup_service.dart`.

### Home dashboard, archive and shuffle

- Home shows paused sessions first, then quick tiles for due errors and
  unexported cards, then the active topic list. The app bar opens Help and
  Settings. The section header sorts topics and opens archived topics (with a
  count badge when non-empty).
- The Shuffle floating button opens **Start shuffled practice**, which asks how
  many questions to include (15 by default), explains that the run uses every
  topic, keeps only questions that are neither solved nor skipped, and shuffles
  questions and alternatives. A request larger than the eligible pool includes
  every available question. If no question is eligible it reports so instead of
  creating an empty session. The resulting session is `mixed` and can be saved
  like any other.
- A topic/practice long-press opens the options sheets; actions are destructive
  only after confirmation.

### UI and navigation

- `M3EMaterialApp` owns theming and `M3ETheme` tokens are used throughout.
  `package:flutter/material.dart` is not imported in `lib`.
- Navigation is Navigator 1.0 with `MaterialPageRoute`, because
  `M3EMaterialApp` does not expose `routerConfig`.
- Practice and review pages are immersive. Session close offers Cancel, Discard
  and Save for later. Paused sessions are listed on Home.
- Narrow layouts stack actions; wide layouts keep them in a row. `AppPage`,
  `AppGroup`, `AppActionDock` and the shared widgets in `lib/core/ui` keep the
  surfaces consistent.

### Platform services

- `AnkiGateway` (Dart) ↔ `AnkiBridge` (Kotlin) over a MethodChannel. Kotlin uses
  AnkiDroid's AddContentApi, groups notes by target deck, creates missing decks
  and broadcasts `DO_SYNC`; `deckNames()` reads live decks for the picker.
- `WebLauncher` wraps Chrome Custom Tabs.
- `SecureKeyStore` wraps Android secure storage; the key never enters SQLite.
- `MethodChannelPracticeSoundPlayer` plays native cues and clamps volume to
  0..1; other platforms and tests use silence.
- `http.Client` is injected so lookup tests use mock responses.

### Testing seams

`databaseProvider`, `clockProvider`, `secureKeyStoreProvider`,
`webLauncherProvider` and `ankiGatewayProvider` are overridden in tests. The
clock is a fixed/mutable `TestClock`, making the 48-hour rule and reminders
deterministic. `test/docs/docs_sync_test.dart` runs the documentation generator
in check mode so schema changes cannot silently drift from
[Database reference](database.md).
