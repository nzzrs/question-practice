# User guide

Questions is an offline Android app for practising questions and exporting study cards to AnkiDroid. The interface is English.

## Home

- Active topic cards show their practices, questions, accuracy and progress.
- The **sort** icon beside **Topics** orders the list by **Name** or **Recency**, increasing or decreasing. The choice is remembered.
- The **archive** icon beside it opens archived topics.
- Long-press a topic to **Edit topic**, **Archive topic** or **Delete topic**. Delete asks for confirmation and removes everything inside the topic.
- **Session in progress** cards sit at the top. Each has **Resume** and **Discard**. Several sessions can stay paused at once.
- **Review past errors** opens the 48-hour error queue.
- **Cards** opens concepts, error and skipped cards, basic cards and highlights.
- The **Shuffle** floating button opens **Start shuffled practice**.
- **Import** adds practices from a file. The help icon opens **How to use it**; the settings icon opens **Settings**.

## Import

1. Tap **Import**.
2. Choose a `.json` file or a `.txt` file containing JSON.
3. Check the preview: file name, topic and question counts, contents and duplicate notes.
4. Tap **Import**.

- The whole file is validated first. A broken file shows the JSON path or line and column, and imports nothing.
- **Load sample** opens the bundled `assets/samples/sample_practice.json`.
- A file can contain many topics and practices. It is limited to 10 MB and 5,000 questions.
- Import reuses an existing topic name, skips an identical practice, and adds `(2)`, `(3)` and so on to a different practice with the same name.
- A question may include an optional `subtopic`. Blank values are imported as **Uncategorized**.
- `assets/samples/practice_format_example.json` demonstrates two topics, single- and multi-answer questions, `subtopic`, `sourceId` and per-alternative explanations.
- The full format and validation rules are in [Practice JSON format](json-format.md).

## Topic

- The header shows the description, priority, AnkiDroid deck, accuracy, progress, correct answers, active errors and completed sessions.
- The **insights** icon opens **Statistics**.
- **Practices** lists each practice with its question count and last score. Tap one to start it.
- The **sort** icon beside **Practices** orders them by **Name** or **Recency**, increasing or decreasing. Each topic remembers its own order.
- Long-press a practice to **Edit practice**, mark it done or active, **Split into two**, or delete it.
- A practice marked done keeps a **Done** tag.
- **Edit practice** offers **Rename**, **Edit description**, **Download practice JSON** and **Update practice JSON**.
- **Split into two** needs an even number of questions. It replaces the practice with Slice A and Slice B, and removes the original practice's sessions and cards.
- **Edit topic** is in the topic long-press menu. It changes the name, description, priority and AnkiDroid deck.
- Decks are set per topic. There is no per-practice deck.

## Practice

- Select one alternative, or every correct alternative when the question has several.
- Reasoning is optional. It saves automatically and appears later in the error review.
- Alternative letters stay hidden until feedback. The eye icon shows them early without changing the order.
- **Check** stays on the same screen. Correct and wrong choices are marked, the correct and selected alternatives open with their explanation, and the overall explanation appears below.
- The arrows and question list move between questions without answering. Submitted answers keep their feedback. Answered questions get a **Done** tag.
- **Skip** records a skipped question.
- **Finish practice** asks whether unanswered questions should be left out of the score or marked skipped.
- Close offers **Cancel**, **Discard** and **Save for later**. Saved sessions wait on Home.
- A banner appears after 5, 10, 15… minutes on the same question. It resets when the question changes and pauses in the background.
- Select text to **Define** a term, **Ask** about it or save it as a **Highlight**. http(s) links open in the browser.

## Check and feedback

- A wrong answer creates an error card with the question, your answer, the correct answer, your reasoning and the explanation.
- **I was distracted or read too fast** removes the new error card. Uncheck it to restore the card.
- **I didn't know this** counts as skipped and creates no error card.
- Skipped questions create no error card. The review asks what was missing.
- Feedback stays on screen while you move between questions.

## Results and review

**Results** shows the score, correct and total, wrong and skipped counts, and looked-up words.

- **Start review** opens the review.
- **View cards** opens **Cards**.
- **Done** returns to the previous screen.

Review opens fullscreen.

- **Wrong questions** show your wrong answer, the correct answer, your reasoning and the explanations. Write the flawed assumption and what prevents it next time.
- **Skipped questions** ask **What was missing here?**.
  - **A concept** creates a concept card from a term and definition.
  - **Another question** creates a basic card from a question and answer.
- **Concepts without a definition** get a definition field.
- **Highlights** from the session can be kept or turned into a concept or basic card.
- **Skip** leaves a step for later. Missing card details can be finished from **Cards**.

## Past errors

- Wrong answers wait 48 hours before they are offered again.
- **Review N errors** starts a re-test session.
- A correct answer resolves the card and keeps it in history and statistics.
- A wrong answer keeps the card active and schedules the next attempt 48 hours later.
- Marking a re-test answer as distracted does not resolve the card.
- Resolved cards stay in the history list.

## Cards

- Filters: **All**, **Concepts**, **Errors & skipped**, **Basic**, **Highlights**, and **Show exported** or **Hide exported**.
- Check the cards to include. **Review all** sits above the error and skipped section; **Review selected** appears for checked cards.
- **Complete** finishes a missing concept definition or a checked error card's details.
- Tap a card to preview it. In the error review, the pencil opens the full-page editor for the card's question, alternatives and explanations.
- **Export to AnkiDroid** sends the selected cards to AnkiDroid.
- **Share as files** creates Anki-compatible text files.
- **Delete selected** removes the chosen cards. Deleting an active error card also removes it from the error queue.
- Incomplete error cards and concepts without a definition block export until they are completed.

## Highlights

- Select text during practice and choose **Highlight**. The phrase is painted in place.
- Highlights stay in **Cards** and can become a concept or basic card.
- **Download all** saves highlights as plain text.
- Highlights are never sent to AnkiDroid.

## AnkiDroid export

- **Export to AnkiDroid** needs AnkiDroid installed, its API enabled and storage permission granted.
- Concepts use the **Cloze** note type. Error cards use their own note type with six fields. Basic cards use the **Basic** note type, created automatically if missing.
- Each topic can use its own deck. A topic without a deck uses the default deck from **Settings**.
- Set a topic's deck with **Edit topic → AnkiDroid deck**. **Browse decks** lists live deck names; a typed name is created on export.
- **Share as files** writes Anki-compatible text files. File export cannot encode a deck and never includes highlights.

## Practice JSON

- Long-press a practice and choose **Edit practice → Download practice JSON** to share the practice in the import format.
- The file contains the topic and practice names, descriptions and every question, with `sourceId` on each question and `subtopic` only when set. It never contains a deck.
- **Update practice JSON** reads an edited file and shows a preview: new, modified, unchanged and deleted questions, with the affected prompts.
- Questions match by `sourceId` first, then by exact trimmed prompt. Matched questions keep their answers, error cards, skipped records and statistics. New questions start empty. Deleted questions lose their answers and linked records.
- The file's topic and practice names must match the stored practice after trimming and ignoring case.
- **Apply changes** writes in one step. **Cancel** leaves the practice untouched.

## Subtopics and statistics

- A subtopic is an optional group inside a practice. Questions without one appear under **Uncategorized**.
- Spelling and capitalisation define a group, so `Networking` and `networking` are separate.
- **Statistics** is opened from the **insights** icon on a topic. It shows the latest, best and average score and the number of completed sessions.
- **Progress over time** plots one point per completed session. The dashed **Trend** line shows the overall direction.
- **By subtopic** shows accuracy and progress for each group. It is hidden when no question has a subtopic.
- **Learning rate** appears once the history spans at least one week and reports the average change per week.
- The **share** icon exports the visible statistics as a JSON file. It includes the summary, progress points, per-subtopic figures and trend data.

## Lookup

- Select text in a question, alternative or explanation, then choose **Define**.
- With **Web search**, DuckDuckGo or Wikipedia opens in a browser tab and the editable definition sheet stays open.
- With **AI**, a short definition appears in a read-only bubble and is saved automatically. Configure the provider, model and key in **Settings**.
- **Ask** sends the selected passage to AI. Its answer can become a concept or basic card.
- Only the selected text, question and topic are sent, and only when you use **Define** or **Ask**.

## Settings

- **Appearance**: wallpaper colors, practice sounds and sound volume.
- **Looking up terms**: web engine or AI provider, model and API key. **Test connection** checks the AI setup.
- **AnkiDroid**: install, API and permission status, default deck, and **Browse decks**.
- **Data**: **Export backup**, **Restore backup** and **Erase all data**.
- **About**: app version and build type.

## Backup and restore

- **Export backup** shares one JSON file with topics, practices, questions, subtopics, sessions, answers, cards, skipped questions, highlights and settings.
- **Restore backup** validates the file before replacing all local data in one step. An empty, damaged or incompatible file leaves the current data untouched.
- A restore does not merge: the backup becomes the complete state.
- A backup is not a practice JSON file. Use **Import** or **Update practice JSON** for practice content.
- The AI API key is never part of a backup. See [Backup coverage](database.md#backup-coverage).

## Data and privacy

- Practices, answers, cards, statistics and settings are stored locally on the device.
- The AI API key is stored in Android secure storage and is never exported.
- The app works offline and sends no analytics.
- **Erase all data** removes practices, sessions, cards, settings and the saved key. Restore and erase cannot be undone.
- For the developer data map, see [Database reference](database.md).

## Archived topics

- **Archive topic** hides a topic from Home and keeps its practices, questions, sessions, cards, statistics and deck.
- The **archive** icon beside **Topics** opens the archived list.
- Tap an archived topic to **Unarchive topic**, **Edit topic** or **Delete topic**.
- Unarchive returns it to Home with its data intact. Deleting an archived topic is permanent, like deleting an active topic.

## Shuffled practice

- The **Shuffle** floating button opens **Start shuffled practice**.
- The session uses questions from every topic, keeps only questions that are neither solved nor skipped, and shuffles questions and alternatives.
- If no question is eligible, the app says so instead of starting an empty session.
- A shuffled session can be saved for later like any other session.
