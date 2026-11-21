# User guide

Questions is an offline Android app for practising questions and exporting study cards to AnkiDroid. The interface is English.

## Home

- Active topic cards show their practices, questions, accuracy and progress.
- The **sort** icon beside **Topics** orders the list by **Name** or **Recency**, increasing or decreasing. The choice is remembered.
- The **archive** icon beside it opens archived topics.
- Long-press a topic to **Edit topic**, **Archive topic** or **Delete topic**. Delete asks for confirmation and removes everything inside the topic.
- **Session in progress** cards sit at the top. Each has **Resume** and **Discard**. Several sessions can stay paused at once.
- **Review past errors** opens the 48-hour error queue.
- **Cards** opens concepts, error and skipped cards, basic cards and notes.
- The **Shuffle** floating button opens **Start shuffled practice**.
- **Import** adds practices from a file. The help icon opens **How to use it**; the settings icon opens **Settings**.

## Import

1. Tap **Import**.
2. Choose a `.json` file or a `.txt` file containing JSON.
3. Check the preview: file name, topic and question counts, contents and duplicate warnings.
4. Tap **Import**.

- The whole file is validated first. A broken file shows the JSON path or line and column, and imports nothing.
- **Load sample** opens the bundled `assets/samples/sample_practice.json`.
- A file can contain many topics and practices. It is limited to 10 MB and 5,000 questions.
- Import reuses an existing topic name, skips an identical practice, and adds `(2)`, `(3)` and so on to a different practice with the same name.
- A question may include an optional `subtopic`. Blank values are imported as **Uncategorized**.
- `assets/samples/practice_format_example.json` demonstrates two topics, single- and multi-answer questions, `subtopic`, `sourceId` and per-alternative explanations.
- The full format and validation rules are in [Practice JSON format](json-format.md).

## Topic

- The header shows the description, priority, AnkiDroid deck, readiness over the last 100 answered questions, progress, correct answers, active errors and completed sessions.
- The **insights** icon opens **Statistics**.
- **Practices** lists each practice with its question count and last score. Tap one to start it.
- The **sort** icon beside **Practices** orders them by **Name** or **Recency**, increasing or decreasing. Each topic remembers its own order.
- Long-press a practice to **Edit practice**, mark it done or active, **Split into two**, or delete it.
- A practice marked done keeps a **Done** tag.
- **Edit practice** offers **Rename**, **Edit description**, **Download practice JSON** and **Update practice JSON**.
- **Split into two** needs an even number of questions. It replaces the practice with Slice A and Slice B, and removes the original practice's sessions and cards.
- **Edit topic** is in the topic long-press menu. Its options are grouped into **Details** (name and description), **Study targets** (priority, minimum approval score and target score), **AnkiDroid** (deck) and **Topic file** (**Download topic JSON** and **Update topic JSON**).
- The topic long-press menu groups **Edit topic**, **Archive topic**/**Unarchive topic** and **Delete topic**, like the practice menu.
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
- Select text to **Define** a term, **Ask** about it or **Save as note**. Questions, answers and explanations all support notes. http(s) links open in the browser.

## Check and feedback

- A wrong answer creates an error record with the question, your answer, the correct answer and the explanation.
- After a wrong answer, one-tap chips classify the mistake: **Forgotten fact**, **Confusion between 2 options**, **Misinterpretation** or **Distraction**. You can pick more than one; the choice feeds the card creator.
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

- **Wrong questions** show your wrong answer, the correct answer and the explanations.
- **Create cards** sits inside the error review and opens the card creator as a draggable half-height sheet, so the error stays visible above it; drag it up for more room. Manual entry adds cards one at a time and works offline without AI. Five templates write the front and back: Definition / term, Contrast / difference, Mechanism / cause-effect, Exam heuristic and Phase transition / procedure. AI suggestions are optional: each idea offers up to three wording variants, and the error breakdown proposes a contrast between your choice and the correct option and/or an exam heuristic.
- Every builder card, draft and AI variant carries an advisory quality badge. It warns about yes/no questions, fronts over 30 words, cards over 15 seconds to read, answer clues, template mismatches, empty fronts or backs, a missing definition, and a definition that repeats its term. It never blocks saving. Choose the cards to add; the error is then marked reviewed. There are no bias or vaccine text boxes and no Check with AI button.
- **Skipped questions** ask **What was missing here?**.
  - **A concept** creates a concept card from a term and definition.
  - **Another question** creates a basic card from a question and answer.
- **Create cards** also sits inside the skipped review and opens the same creator with the question and correct answer prefilled as a custom card. Manual entry adds one card at a time; AI is not required.
- **Concepts without a definition** get a definition field.
- **Notes** from the session can be kept or turned into cards with **Create cards**. The creator's manual entry adds cards one by one and needs no AI provider. AI suggestions are optional and offer up to three wording variants per idea; check the ones to add.
- **Skip** leaves a step for later. Missing card details can be finished from **Cards**.

## Past errors

- Wrong answers wait 48 hours before they are offered again.
- **Review N errors** starts a re-test session.
- A correct answer resolves the card and keeps it in history and statistics.
- A wrong answer keeps the card active and schedules the next attempt 48 hours later.
- Marking a re-test answer as distracted does not resolve the card.
- Resolved cards stay in the history list.

## Cards

- Cognitive filters: **All**, **Facts**, **Heuristics**, **Contrasts** and **Concepts**. Separate entries show **Errors & skipped** and **Notes**. **Show exported** or **Hide exported** controls finished cards.
- Cards has no checkboxes. Long-press a card to start selecting it, then tap more cards. While selection is active, a tap toggles that card; the close icon in the app bar clears the selection. The subtitle counts the selection and rows keep their positions.
- **Review all** sits above the error and skipped section; **Review selected** appears while cards are selected.
- **Complete** finishes a missing concept definition; an error is completed by adding cards with **Create cards** or skipping it.
- Tap a card to preview it. Tapping a note opens the note review at that note. In the error review, the pencil opens the full-page editor for the card's question, alternatives and explanations, and **Create cards** creates the cards to export. An error preview is titled **Error preview**.
- **Export to AnkiDroid** sends the selected cards to AnkiDroid.
- **Share as files** creates Anki-compatible text files.
- **Delete selected** removes the chosen cards, skipped questions and notes. Deleting an active error card also removes it from the error queue; a deleted skipped question leaves the queue but stays in its practice. Deleting a note removes only the saved phrase; cards already made from it stay.
- Errors are never exported directly: review them into atomic cards with **Create cards** first. Concepts without a definition block export until completed. Skipped questions and notes cannot be exported, but they can still be selected and deleted.
- Concept cards in the creator need only a term. The meaning is looked up from your saved concepts first, then from AI when a provider is configured. There is no definition field to type in the creator. Without a provider the concept is saved as **Definition pending** and is not exported until a definition is added.
- Topic and subtopic are never written inside card text. They travel as `question-practice`, `topic::<slug>` and `subtopic::<slug>` Anki tags. File exports put them in a third `Tags` column with `#tags column:3`.

## Notes

- Select any question, answer or explanation text during practice and choose **Save as note**. The phrase is shown in place and belongs to the question, so it appears whenever that question is practised again.
- Tap a note to **Define**, **Ask** or **Delete note**. Deleting is immediate and asks no confirmation.
- Notes stay in **Cards** and can be reviewed one at a time from **Review notes** or by tapping one.
- **Create cards** sits inside the note review and opens the card creator. Manual entry adds cards one at a time and works without AI. AI suggestions are optional and offer up to three wording variants per idea; check the ones to add.
- A note with a card hides the card-making actions. **Keep for later** marks it as kept, and **Delete note** removes only the saved phrase.
- **Download all** saves notes as plain text.
- Notes are never sent to AnkiDroid.

## AnkiDroid export

- **Export to AnkiDroid** needs AnkiDroid installed, its API enabled and storage permission granted.
- Concepts use the **Cloze** note type. Facts, heuristics and contrasts use the standard **Basic** note type, created automatically if missing. There is no custom error note type.
- Exported Anki notes carry hierarchical `topic::<topic>` and `subtopic::<subtopic>` tags. Concept fronts also show `[Topic / Subtopic]`.
- Each topic can use its own deck. A topic without a deck uses the default deck from **Settings**.
- Set a topic's deck with **Edit topic → AnkiDroid deck**. **Browse decks** lists live deck names; a typed name is created on export.
- **Share as files** writes Anki-compatible text files. File export cannot encode a deck and never includes notes.

## Topic and practice JSON

- **Download topic JSON** and **Update topic JSON** live inside **Edit topic** and cover the whole topic, separate from the per-practice options. The topic menu itself groups **Edit topic**, **Archive**/**Unarchive** and **Delete** only.
- A topic file contains every practice in the topic. Updating creates new practices and questions, modifies matched ones and deletes questions missing from the file; practices absent from the file are left untouched.
- Long-press a practice and choose **Edit practice → Download practice JSON** to share one practice in the import format.
- The file contains the topic and practice names, descriptions and every question, with `sourceId` on each question and `subtopic` only when set. It never contains a deck.
- **Update practice JSON** reads an edited file and shows a preview: new, modified, unchanged and deleted questions, with the affected prompts.
- Questions match by `sourceId` first, then by exact trimmed prompt. Matched questions keep their answers, error cards, skipped records and statistics. New questions start empty. Deleted questions lose their answers and linked records.
- The file's topic and practice names must match the stored practice after trimming and ignoring case.
- **Apply changes** writes in one step. **Cancel** leaves the practice untouched.

## Subtopics and statistics

- A subtopic is an optional group inside a practice. Questions without one appear under **Uncategorized**.
- Spelling and capitalisation define a group, so `Networking` and `networking` are separate.
- Set a topic's **minimum approval score** (70% by default) and **target score** (80% by default) in **Edit topic**. Scores below the minimum are red, scores from the minimum to the target use the normal color, and scores at or above the target are green. This applies to practice score pills, the readiness ring, the latest/average/best statistics and chart dots.
- **Statistics** is opened from the **insights** icon on a topic. It shows the latest, best and average score and the number of completed sessions. The average is weighted by the number of questions in each session, so a long session counts more than a short one.
- **Progress over time** plots one point per completed session. The dashed **Trend (questions)** line is a weighted fit of score against the total questions answered so far; sessions with more questions have more influence.
- **Learning rate** reports the fit as percentage points per 100 answered questions and as percentage points per week. It appears as soon as two sessions give a usable fit, without waiting for a week of history.
- Below it, a projection says when the current pace would bring the weighted average to the target score: **At this rate, you will average the target score by <date>.** It also reports when the target is already reached or not in reach at this rate.
- **By subtopic** shows accuracy and progress for each group. It is hidden when no question has a subtopic.
- Long-press a subtopic to select it. With one selected, the pencil renames it and the trash deletes it. With two or more, the merge icon combines them under one name.
- **Rename** changes the name on every question in this topic in that category. Renaming **Uncategorized** gives those questions a name.
- **Delete** removes the category but keeps every question; its questions move to **Uncategorized**. Deleting **Uncategorized** does nothing.
- **Merge** asks for the name to keep, either one of the selected categories or a new name, and applies it to all of them. Other topics are not changed.
- The **share** icon exports the visible statistics as a JSON file. It includes the summary, progress points, per-subtopic figures and trend data, with the weighted regression slope and intercept plus learning rates per 100 questions and per week.
- A topic's header **Readiness** is the correct share of the last 100 answered questions in that topic, across completed sessions. Every attempt counts, including wrong, skipped and **I didn't know this** answers; questions left unanswered have no attempt and stay out. Shorter histories use every answer they have, and only the tail of the oldest session needed joins the window.
- The **Sessions** list keeps one row per completed session. Long-press a row to start selecting sessions, then tap others to toggle them. The trash icon asks for confirmation and deletes the selected completed sessions together with their answers, cards, notes and skipped records. Selection tints the row and uses the app bar, so the page does not move; category and session selection are separate modes.

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

- **Export backup** shares one JSON file with topics (including score bands), practices, questions, subtopics, sessions, answers, mistake classifications, cards, skipped questions, notes and settings.
- **Restore backup** validates the file before replacing all local data in one step. An empty, damaged or incompatible file leaves the current data untouched.
- A restore does not merge: the backup becomes the complete state.
- A backup is not a practice JSON file. Use **Import** or **Update practice JSON** for practice content.
- The AI API key is never part of a backup. See [Backup coverage](database.md#backup-coverage).

## Data and privacy

- Practices, answers, cards, notes, statistics and settings are stored locally on the device.
- The AI API key is stored in Android secure storage and is never exported.
- The app works offline and sends no analytics.
- **Erase all data** removes practices, sessions, cards, notes, settings and the saved key. Restore and erase cannot be undone.
- For the developer data map, see [Database reference](database.md).

## Archived topics

- **Archive topic** hides a topic from Home and keeps its practices, questions, sessions, cards, notes, statistics and deck.
- The **archive** icon beside **Topics** opens the archived list.
- Tap an archived topic to **Unarchive topic**, **Edit topic** or **Delete topic**.
- Unarchive returns it to Home with its data intact. Deleting an archived topic is permanent, like deleting an active topic.

## Shuffled practice

- The **Shuffle** floating button opens **Start shuffled practice**.
- Choose how many questions to include in the **Questions** field; the default is 15.
- The session uses questions from every topic, keeps only questions that are neither solved nor skipped, and shuffles questions and alternatives.
- If you ask for more questions than are available, the session includes all eligible ones.
- If no question is eligible, the app says so instead of starting an empty session.
- A shuffled session can be saved for later like any other session.
