# User guide

Questions is an offline-first Android study app. This guide walks through every screen. The interface is English.

## Home

- **Topics** lists your active topics, ordered by priority and name until you choose another order.
- Long-press a topic card to open its options: **Edit topic**, **Archive topic** and **Delete topic**. Delete asks for confirmation and removes everything inside the topic.
- **Archive topic** hides the topic from Home while keeping its practices, questions, sessions, cards and statistics. Archived topics are not deleted.
- The **sort** icon beside **Topics** orders the list by **Name** or **Recency**, increasing or decreasing. The choice is remembered. The **archived topics** icon to its right lists archived topics; tap one to unarchive, edit or delete it.
- **Session in progress** cards list every paused session with its mode, question count and start time. Each card has **Resume** and **Discard**.
- A topic card shows its practices, its question count (questions left unanswered in completed sessions are excluded), accuracy and progress.
- **Review past errors** opens the 48-hour error queue.
- **Cards** opens concepts, error cards, skipped questions, basic cards and highlights. The tile badge counts error cards that still need bias and vaccine.
- The **Shuffle** floating button opens **Start shuffled practice**. The sheet explains that the session uses questions from every topic, keeps only unsolved and unskipped questions, and shuffles both questions and alternatives. If no question is eligible, it says so instead of starting an empty session.
- **Import** creates topics and practices from a JSON file.
- The help icon opens **How to use it**.
- The settings icon opens Settings.

## Import

1. Tap **Import**.
2. Choose a `.json` file or a `.txt` file containing JSON.
3. Review the file name, counts, topic/practice list and duplicate notes.
4. Tap **Import**.

The whole file is validated first. A broken file shows the JSON path or line/column and imports nothing. **Load sample** loads the bundled `assets/samples/sample_practice.json`. The separate `assets/samples/practice_format_example.json` demonstrates a single-answer question, a multi-answer question, per-alternative explanations, `sourceId` and two topics. A question may include an optional `subtopic`; blank values are imported as uncategorized.

A practice file is limited to 10 MB and 5,000 questions. It is UTF-8 JSON in a `.json` or `.txt` file. The JSON schema and every semantic rule are documented in [Practice JSON format](json-format.md).

## Topic

- Shows description, priority, Anki deck, accuracy, progress, correct answers, active errors and completed sessions.
- **Progress** is answered questions divided by the topic's total questions after removing those left unanswered in completed sessions. It measures coverage; **Accuracy** measures how many answers were correct.
- **Practices** lists each practice with question count and last score. Tap a practice to start.
- The **sort** icon beside **Practices** orders them by **Name** or **Recency**, increasing or decreasing. Each topic remembers its own order across visits and app restarts.
- Long-press a practice to open its options: **Edit practice**, mark it done or active, split it into two slices, or delete it.
- **Edit practice** opens a second menu with **Rename**, **Edit description**, **Download practice JSON** and **Update practice JSON**. It has no deck row: decks are selected per topic. Use **Edit topic → AnkiDroid deck** instead. There is no per-practice deck, and a practice JSON file cannot contain one.
- **Download practice JSON** shares one file with the topic, the practice name and description, and every current question, in the import format. Each question carries `sourceId`, the app's stable identity for that question, so a later update maps back to the stored question. Subtopics are included only when set. The file does not contain a deck.
- **Update practice JSON** reads an edited export and shows a preview before writing anything: how many questions are new, modified, unchanged and deleted, with the affected prompts. The file's topic and practice names must match the stored practice after trimming and ignoring case. Questions are matched by `sourceId` first and then by exact trimmed prompt; files without identities therefore still work. **Apply changes** writes one transaction and refreshes the practice content hash and import time; **Cancel** leaves it untouched. Matched questions keep their answers, error cards, skipped records and statistics. New questions start empty. Deleted questions lose their answers, session links, error cards and skipped records; linked concept cards, basic cards and highlights remain but lose their question link. A file whose topic or practice name does not match is rejected with a clear message.
- **Split into two** replaces the practice with "… Slice A" and "… Slice B", each holding half of its questions in random order. It needs an even number of questions and removes the original practice's sessions and cards. Finish or discard an in-progress session first.
- **Edit topic** is available from the topic's long-press menu on Home and from the archived topics list. It changes name, description, priority and the AnkiDroid deck.
- AnkiDroid decks are selected **per topic only**. There is no practice-level deck, and a practice JSON file cannot contain one.
- **Browse decks** reads live deck names from AnkiDroid when its API and permission are available. You can also type a new deck name; it is created on export.
- Blank deck means the default deck from Settings.

## Statistics

- Open **Statistics** from the insights icon on a topic.
- The hero shows the latest score, best and average, and the number of completed sessions.
- **Progress over time** plots one point per completed session. The solid line joins the sessions; the dashed **Trend** line is a least-squares fit through the same points, so it shows the overall direction rather than a single jump. The legend names both series.
- **Learning rate** appears below the metrics once the history spans at least one week. It reports the average change in percentage points per week from the fitted trend, for example `+8 pp/week`. Short histories and single sessions do not show a figure.
- **By subtopic** groups questions by their optional `subtopic` and shows accuracy and progress for each group, counted from completed sessions. Questions without a subtopic appear under **Uncategorized**. The section is hidden when no question in the topic has a subtopic. Spelling and capitalisation define the group, so `Networking` and `networking` are shown separately. The same per-subtopic figures are included in the shared statistics JSON.
- **Sessions** lists every completed session with its score and date.
- The share icon exports the visible statistics as a JSON file through the system share sheet. The file contains the topic summary, progress points, per-subtopic figures and the trend data.

## Practice session

- Each question shows the topic and practice, the prompt and 2–8 alternatives.
- Alternatives are shuffled for every session and keep that order while the question is open. Before answering, badges are plain circles and hide the original letters. Tap the eye beside the flag to reveal each alternative's original letter without changing the order. After **Check**, the original letters appear automatically so explanations that refer to “A”, “B” or “C” stay unambiguous.
- Select one alternative, or every correct alternative when the question has more than one. The reasoning field is optional. Write what led you to the answer, before or after **Check**; it saves automatically and appears later in the error review.
- The arrows beside **Question X of Y** move to the previous or next question without answering. Answers already submitted keep their feedback when you return.
- **Check** stays on the same screen. The correct answer is marked, the wrong choice is marked, and the correct alternatives plus your selection open with their explanation. Every other alternative stays collapsed until you tap its expand icon. The overall explanation appears below.
- Prompt, alternatives, alternative explanations and the overall explanation are selectable, including before you answer. Select a word or phrase and tap **Define**. http(s) links are tappable.
- While a practice is open, the app hides the status and navigation bars for fewer distractions. Leaving the session restores them.
- After a wrong answer, check **I was distracted or read too fast** in the feedback to remove the new error card. Uncheck it to restore the card.
- **Skip** records a skipped question. No error card is created; the end-of-session review asks what was missing.
- Closing the session offers **Cancel**, **Discard** and **Save for later**. Save keeps the session on Home; several sessions can stay paused at once.
- A small banner appears after 5, 10, 15… minutes of foreground practice. There is no countdown and no time score.
- Long-press a word or phrase and tap **Define** to save it as a missing concept.
- The progress bar and “Question X of Y” show position. Score is correct answers / total questions.

## Results

- Shows the overall percentage, correct/total, wrong and skipped counts, and the number of distinct terms looked up.
- **Start review** creates error details and cards for this session.
- **View cards** opens the export screen.
- **Done** returns to the previous screen.

## End-of-session review

- **Wrong questions**: shows the question, your wrong answer, the correct answer and your reasoning, then asks:
  - “What was the flawed assumption in your reasoning?”
  - “What do you need to know to prevent that error in the future?”
- **Skipped questions**: asks “What was missing here?” with two choices:
  - **A concept** → term + definition, saved as a cloze concept card.
  - **Another question** → question + answer, saved as a basic card.
- **Concepts without a definition** (for example after a web lookup) get a definition field.
- **Skip** leaves the step unfinished. Use the same review view from Cards → **Complete**, **Review all**, or **Review selected**.
- The completion screen offers **Done** and **View cards**.
- Review is idempotent: completed error cards disappear from a later review. Skipped questions are shown again if you reopen review before finishing.
- Cards created here and in the session review share one view: question, your answer, the correct answer, your reasoning, bias and vaccine.

## Past errors

- Wrong answers enter the queue with a 48-hour delay from the last mistake.
- The screen lists due cards and the resolved history.
- **Review N errors** starts a re-test session.
- Correct answer → the card is resolved, removed from the active queue, and kept in history/statistics.
- Wrong answer → the card stays active and its next attempt is scheduled 48 hours later.
- Marking a re-test answer as distracted in the feedback does not resolve the card; it stays in the error queue.
- Resolved cards are never deleted automatically.

## Cards and export

- Filter chips: **All**, **Concepts**, **Errors & skipped**, **Basic** and **Highlights**, plus **Show exported** / **Hide exported**. Exported cards stay in the list but are not selectable.
- Checkboxes choose what is included. By default all unexported, complete concepts, error cards and basic cards are selected. Incomplete error cards can also be checked so they can be reviewed first.
- **Review all** sits above the **Error and skipped** section. **Review selected** appears for checked error cards or skipped questions.
- If a checked error card is incomplete, export and share stay disabled; finish it with **Complete** or **Review selected** first. Export becomes available when every checked error card is complete.
- Each exportable row shows its target deck. The deck comes from the card's topic, or the default deck from Settings.
- **Complete** on a concept opens its definition editor. On an error card it opens the same card review view used after a session, including the question/options editor and **Check with AI**.
- **Export to AnkiDroid** creates the deck and note types if needed, bulk-adds notes, marks cards exported and broadcasts `com.ichi2.anki.DO_SYNC`.
- **Share as files** creates Anki-compatible text files. File export does not encode a deck and never includes highlights.
- **Delete selected** permanently removes the selected cards; deleting an active error card also removes it from the error queue.
- Missing bias/vaccine or definitions block export until completed.
- **Highlights** are plain text only. **Download all** saves them as a text file through the share sheet. A highlight can be turned into a concept or basic card, or deleted individually; highlights are never sent to AnkiDroid.

## Lookup

- Long-press text in a question → **Define**.
- **AI mode**: sends the term, question and topic to the configured provider and saves a short definition. The definition appears in a read-only bubble and is saved automatically; there is no save button. OpenAI, Groq and OpenRouter use their chat-completions endpoint; Gemini uses its native `generateContent` API. Configure the provider, model and API key in Settings; the base URL appears only for a custom provider. Opening the model dropdown loads the models the provider makes available, and the field is searchable. If a list cannot be loaded, the saved model stays selected.
- **Web mode**: opens DuckDuckGo or Wikipedia in a Custom Tab and keeps the editable definition sheet with **Save**, so you can fill the definition after reading.
- Every lookup is saved automatically for the session and counted in Results.

## Settings

- **Appearance**: wallpaper colors (Material You) are on by default. Turn them off to use the app seed color. The app follows system light/dark. **Practice sounds** has a volume slider and a play icon to hear the sample; the slider saves when you release it.
- **Looking up terms**: Web search or AI. Web engine: DuckDuckGo or Wikipedia. AI: provider (OpenAI, Groq, OpenRouter, Gemini or custom), model, API key and **Test connection**. The base URL is shown only for a custom provider. Opening the model dropdown loads the provider list. Provider, model, base URL and API key save automatically; clear the key field to remove the saved key. The key is stored in Android secure storage and never shown after saving.
- **AnkiDroid**: status of install/API/permission/Cloze type, permission request, open AnkiDroid, default deck name, and **Browse decks** to pick a live deck name.
- **Data**: **Export backup** shares one JSON file with every topic (including archived topics and Anki decks), practice, question and subtopic, session, answer, card, skipped question, highlight and setting. The file records its format version, app version/build, database schema version, export time and row counts, plus a checksum. **Restore backup** validates all of that before replacing anything, then replaces all local data in one step; a damaged or inconsistent file is rejected and leaves the current data untouched. Backups made by older app versions, including the first backup format, still restore. The AI API key is never part of a backup and is left untouched on the device. **Erase all data** removes practices, sessions, cards, settings and the API key. Restore and erase cannot be undone.
- **About**: the app version (`Questions 0.9.9`). Backup files record the same version and build number.

## Backup and restore

- **Export backup** writes a UTF-8 JSON file through the system share sheet. It contains the complete local database, including archived topics, subtopics, practice done flags, session history, error history, skipped questions, highlights and settings.
- **Restore backup** checks the file before writing anything. It must be UTF-8 JSON, no larger than 50 MB, with the expected app id, format version and checksum. An empty, malformed or incompatible file leaves the current data untouched.
- A valid restore replaces every local table in one transaction. It does not merge with existing data, so the backup becomes the complete state of the app.
- The AI API key lives in Android secure storage, not in the database. It is never exported, and a restore does not overwrite the key already on the device.
- A backup is not a practice JSON file. A backup preserves history and settings; a practice JSON file contains only importable practice content and is used by **Import** or **Update practice JSON**.
- The exact table-level coverage and backup format are listed in [Database reference](database.md#backup-coverage).

## Archived topics

- Long-press a topic on Home and choose **Archive topic**. It disappears from the active list but keeps its practices, questions, sessions, cards, statistics and deck.
- The archive icon beside **Topics** opens the archived list. When at least one topic is archived, the icon shows a badge with the count.
- Tap an archived topic to open the same actions as an active topic: **Unarchive**, **Edit topic** or **Delete topic**. Unarchive returns it to Home with its data intact.
- Deleting an archived topic is permanent and removes everything inside it, exactly like deleting an active topic.

## Shuffled practice

- The **Shuffle** floating button opens **Start shuffled practice**, not a separate practice.
- The session uses questions from every topic, keeps only questions that are neither solved nor skipped, and shuffles questions and alternatives.
- The sheet lists these rules before **Start practice**. If no question is eligible, the app reports that no unsolved questions are left.
- A shuffled session is saved as a paused session like any other and appears on Home if you close it with **Save for later**.

## Deck routing details

- Topics with a deck set go to that deck.
- Topics without a deck use the default deck from Settings.
- Cards snapshot the topic name at creation. Renaming a topic affects only new cards; old cards fall back to the default deck.
- AnkiDroid's API supports arbitrary decks; a missing deck is created on export.
- File export cannot encode a deck; choose one during Anki import.
