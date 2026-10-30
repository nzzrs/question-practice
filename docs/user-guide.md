# User guide

Question Practice is an offline-first Android study app. This guide walks through every screen. The interface is English.

## Home

- **Topics** lists your topics, ordered by priority and name.
- **Session in progress** cards list every paused session with its mode, question count and start time. Each card has **Resume** and **Discard**.
- A topic card shows its practices, its question count (questions left unanswered in completed sessions are excluded), accuracy and progress.
- Long-press a topic card to delete the topic and everything inside it. The confirmation asks first.
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

- Shows description, priority, Anki deck, accuracy, progress, correct answers, active errors and completed sessions.
- **Progress** is answered questions divided by the topic's total questions after removing those left unanswered in completed sessions. It measures coverage; **Accuracy** measures how many answers were correct.
- **Practices** lists each practice with question count and last score. Tap a practice to start.
- Long-press a practice to rename it, delete it, or mark it done or active.
- **Edit** changes name, description, priority and the Anki deck for that topic.
- **Browse decks** reads live deck names from AnkiDroid when its API and permission are available. You can also type a new deck name; it is created on export.
- Blank deck means the default deck from Settings.

## Practice session

- Each question shows the topic and practice, the prompt and 2–8 alternatives.
- Alternatives are shuffled for every session and keep that order while the question is open. Before answering, badges are plain circles and hide the original letters. Tap the eye beside the flag to reveal each alternative's original letter without changing the order. After **Check**, the original letters appear automatically so explanations that refer to “A”, “B” or “C” stay unambiguous.
- Select one alternative, or every correct alternative when the question has more than one. The reasoning field is optional. Write what led you to the answer; it appears later in the error review.
- The arrows beside **Question X of Y** move to the previous or next question without answering. Answers already submitted keep their feedback when you return.
- **Check** stays on the same screen. The reasoning locks, the correct answer is marked, the wrong choice is marked, and every alternative expands with its explanation. The overall explanation appears below.
- Prompt, alternatives, alternative explanations and the overall explanation are selectable. Select a word or phrase and tap **Define**. http(s) links are tappable.
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

- Tabs: **All**, **Concepts**, **Errors**, **Basic**.
- **Show exported cards** is a filter chip below the description. It includes exported cards in the list; exported cards stay unselectable.
- Checkboxes choose what is included. By default all unexported, complete cards are selected. Incomplete error cards can also be checked.
- **Review all** sits at the top of the Error cards section. **Review selected** appears for checked error cards.
- If a checked error card is incomplete, the bottom bar hides export and share and offers **Review selected** instead. Export returns when every checked error card is complete.
- Each row shows the target deck. Deck comes from the card's topic, or the default deck.
- **Complete** opens the same error-card review view used after a session.
- **Export to AnkiDroid** creates the deck and note types if needed, bulk-adds notes, marks cards exported and broadcasts `com.ichi2.anki.DO_SYNC`.
- **Share as files** creates Anki-compatible text files. File export does not encode a deck.
- **Delete selected** permanently removes cards; deleting an active error card also removes it from the error queue.
- Use **Show exported cards** to include exported cards in the list (they are not selectable).
- Missing bias/vaccine or definitions block export until completed.

## Lookup

- Long-press text in a question → **Define**.
- **AI mode**: sends the term, question and topic to the configured provider and saves a short definition. The definition appears in a read-only bubble and is saved automatically; there is no save button. OpenAI, Groq and OpenRouter use their chat-completions endpoint; Gemini uses its native `generateContent` API. Configure the provider, base URL, model and API key in Settings. **Load models** lists the models the provider makes available, and the model field is a searchable dropdown. If a list cannot be loaded, the saved model stays selected.
- **Web mode**: opens DuckDuckGo or Wikipedia in a Custom Tab and keeps the editable definition sheet with **Save**, so you can fill the definition after reading.
- Every lookup is saved automatically for the session and counted in Results.

## Settings

- **Appearance**: wallpaper colors (Material You) are on by default. Turn them off to use the app seed color. The app follows system light/dark.
- **Looking up terms**: Web search or AI. Web engine: DuckDuckGo or Wikipedia. AI: provider (OpenAI, Groq, OpenRouter, Gemini or custom), base URL, model, API key, test connection. **Load models** fills the model dropdown from the provider. The key is stored in Android secure storage and never shown after saving.
- **AnkiDroid**: status of install/API/permission/Cloze type, permission request, open AnkiDroid, default deck name, and **Browse decks** to pick a live deck name.
- **Data**: erase all practices, sessions, cards, settings and API key. Cannot be undone.
- **About**: version.

## Deck routing details

- Topics with a deck set go to that deck.
- Topics without a deck use the default deck from Settings.
- Cards snapshot the topic name at creation. Renaming a topic affects only new cards; old cards fall back to the default deck.
- AnkiDroid's API supports arbitrary decks; a missing deck is created on export.
- File export cannot encode a deck; choose one during Anki import.
