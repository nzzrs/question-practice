# User guide

Question Practice is an offline-first Android study app. This guide walks through every screen. The interface is English.

## Home

- **Topics** lists your topics, ordered by priority and name.
- A topic card shows its practices, question count, accuracy and progress.
- **Review past errors** opens the 48-hour error queue.
- **Cards** opens concepts, error cards and basic cards waiting for export.
- The **shuffle** button turns on **Start shuffled practice**. That session mixes questions from every topic in random order. The setting is remembered.
- **Import** creates topics and practices from a JSON file.
- The **i** icon opens Help.
- The settings icon opens Settings.

## Import

1. Tap **Import**.
2. Choose a `.json` file or a `.txt` file containing JSON.
3. Review the file name, counts, topic/practice list and duplicate notes.
4. Tap **Import**.

The whole file is validated first. A broken file shows the JSON path or line/column and imports nothing. **Load sample** loads the bundled practice. See [Import format](json-format.md).

## Topic

- Shows description, priority, Anki deck, accuracy, progress, active errors and completed sessions.
- **Practices** lists each practice with question count and last score. Tap a practice to start.
- **Edit** changes name, description, priority and the Anki deck for that topic.
- **Choose AnkiDroid deck** reads live deck names from AnkiDroid when its API and permission are available. You can also type a new deck name; it is created on export.
- Blank deck means the default deck from Settings.

## Practice session

- Each question shows the topic and practice, the prompt and 2–8 alternatives.
- Select an alternative. The reasoning field is optional. Write what led you to the answer; it appears later in the error review.
- **I was distracted or read too fast** prevents an error card from being created if the answer is wrong.
- **Submit answer** stays on the same screen. The reasoning locks, the correct answer is marked, the wrong choice is marked, and every alternative expands with its explanation. The overall explanation appears below.
- **Skip** records a skipped question. No error card is created; the end-of-session review asks what was missing.
- A small banner appears after 5, 10, 15… minutes of foreground practice. There is no countdown and no time score.
- Long-press a word or phrase in the prompt and tap **Define** to save it as a missing concept.
- Leaving an unfinished session asks for confirmation. An unfinished session can be resumed from Home if the app was closed.
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
- **Skip** leaves the step unfinished. Unfinished error cards can be completed later from Cards.
- The completion screen offers **Done** and **View cards**.
- Review is idempotent: completed error cards disappear from a later review. Skipped questions are shown again if you reopen review before finishing.

## Past errors

- Wrong answers enter the queue with a 48-hour delay from the last mistake.
- The screen lists due cards and the resolved history.
- **Review N errors** starts a re-test session.
- Correct answer → the card is resolved, removed from the active queue, and kept in history/statistics.
- Wrong answer → the card stays active and its next attempt is scheduled 48 hours later.
- A distracted wrong answer in this session does not move the due date; the card remains due.
- Resolved cards are never deleted automatically.

## Cards and export

- Tabs: **All**, **Concepts**, **Errors**, **Basic**.
- Checkboxes choose what is included. By default all unexported, complete cards are selected.
- Each row shows the target deck. Deck comes from the card's topic, or the default deck.
- **Complete** adds a missing concept definition or error bias/vaccine.
- **Export to AnkiDroid** creates the deck if needed, ensures note types, bulk-adds notes, marks cards exported and broadcasts `com.ichi2.anki.DO_SYNC`.
- **Share as files** creates Anki-compatible text files. File export does not encode a deck.
- **Delete selected** permanently removes cards; deleting an active error card also removes it from the error queue.
- Use the visibility icon to include exported cards in the list (they are not selectable).
- Missing bias/vaccine or definitions block export until completed.

## Lookup

- Long-press text in a question → **Define**.
- **AI mode**: sends the term, question and topic to an OpenAI-compatible endpoint and saves a short definition. Configure base URL, model and API key in Settings.
- **Web mode**: opens DuckDuckGo or Wikipedia in a Custom Tab and saves the term with an empty definition. Fill the definition in the sheet, in review, or in Cards.
- Every lookup is saved automatically for the session and counted in Results.

## Settings

- **Appearance**: use wallpaper colors (Material You). The app follows system light/dark.
- **Looking up terms**: Web search or AI. Web engine: DuckDuckGo or Wikipedia. AI: provider preset, base URL, model, API key, test connection. The key is stored in Android secure storage and never shown after saving.
- **AnkiDroid**: status of install/API/permission/Cloze type, permission request, open AnkiDroid, default deck name.
- **Data**: erase all practices, sessions, cards, settings and API key. Cannot be undone.
- **About**: version.

## Deck routing details

- Topics with a deck set go to that deck.
- Topics without a deck use the default deck from Settings.
- Cards snapshot the topic name at creation. Renaming a topic affects only new cards; old cards fall back to the default deck.
- AnkiDroid's API supports arbitrary decks; a missing deck is created on export.
- File export cannot encode a deck; choose one during Anki import.
