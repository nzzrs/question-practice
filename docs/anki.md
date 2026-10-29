# AnkiDroid export

Question Practice writes to AnkiDroid through its supported Instant-Add API (`com.github.ankidroid:Anki-Android:api-v1.1.0`). The API uses AnkiDroid's `com.ichi2.anki.flashcards` ContentProvider and packs note fields with the official `\u001f` separator.

## One-time setup

1. Install AnkiDroid on the same device.
2. Open AnkiDroid → Settings → Advanced → enable the AnkiDroid API.
3. In Question Practice → Settings → AnkiDroid, tap **Grant permission**. Android asks for `com.ichi2.anki.permission.READ_WRITE_DATABASE`.
4. Make sure AnkiDroid has a **Cloze** note type. AnkiDroid ships with one; if it was deleted, create it again in AnkiDroid's note type manager. Question Practice uses that type for concept cards.

The manifest declares the database permission and a `<queries>` entry for `com.ichi2.anki`, required for package visibility on Android 11+.

## Decks: default and per topic

Every topic can target its own AnkiDroid deck:

1. Open **Settings → AnkiDroid → Deck name** and set the default deck, for example `Question Practice`.
2. Open a topic → **Edit** → **AnkiDroid deck** → **Browse decks**.
3. Pick an existing deck from AnkiDroid, or type a new name. A missing deck is created on export.
4. Leave the field blank to use the default deck.

The picker reads the live deck list through AnkiDroid's API (`AddContentApi.deckList`). If the AnkiDroid API or database permission is unavailable, the picker explains the problem and still allows typing a deck name.

Routing uses the topic name captured on each card:

- concept cards use the topic name captured when the term was looked up;
- error cards use the topic name captured when the wrong answer was recorded;
- skipped-question basic cards use the topic name captured in the review.

If a topic is renamed, cards created before the rename keep the old captured topic name and fall back to the default deck. Cards created after the rename use the new topic name and its deck. File exports do not encode a deck; choose the deck when importing the file into Anki.

## Created note types

| Model | Fields | Used for |
|---|---|---|
| AnkiDroid's Cloze type | existing `Text` field | Concept cards |
| `Question Practice: Error` | Problem, Wrong Solution, Correct Solution, Mental Trap, Vaccine, Explanation | Error cards |
| `Question Practice Basic` | Front, Back | Skipped-question “another question” cards |

Question Practice checks for `Question Practice: Error` before inserting notes. If the model is missing, it creates it with the six fields, front/back templates and CSS defined in `AnkiBridge.kt`.

The error front shows the problem, the wrong answer chosen and the flawed-assumption prompt. The back shows the mental trap first, then the vaccine, correct solution and explanation in a secondary reference box.

When a question has several correct answers, **Wrong Solution** lists every alternative the user selected and **Correct Solution** lists every correct alternative, separated by `<br>`. **Explanation** contains the overall question explanation followed by the alternative explanation for each failed selected distractor.

Concept note text is exactly:

```
Definition of {{c1::GCP}}: {{c2::Google Cloud Platform}}
```

The error and basic note types are created automatically the first time they are needed. AnkiDroid's API cannot create a cloze note type, so the app uses the existing one.

## What is sent

Only selected, completed cards are sent. Error cards must have both bias and vaccine; concepts must have a definition. The Cards screen previews every card and lets you deselect or delete items first.

After a successful import the app broadcasts `com.ichi2.anki.DO_SYNC` so AnkiDroid can sync in the background.

## Failure handling

- AnkiDroid missing → the app offers the file fallback.
- API disabled or permission denied → an explanatory dialog and a button to open AnkiDroid.
- No Cloze note type → the app explains what to create.
- Partial failure → the successfully added note count is reported, but the selected cards stay unexported so nothing is silently lost.

## File fallback

**Share files** creates UTF-8, Anki-compatible files:

- `question-practice-concepts-YYYYMMDD-HHmm.txt` — one cloze note per line;
- `question-practice-errors-YYYYMMDD-HHmm.tsv` — six tab-separated fields in the model order;
- `question-practice-basic-YYYYMMDD-HHmm.tsv` — two tab-separated fields.

Import them into Anki desktop or AnkiDroid with the matching note types. Tabs become spaces and newlines become `<br>`; user content is HTML-escaped.

## Manual verification

On a connected Android device with AnkiDroid installed:

1. Import the sample practice and create one concept, one error card and one basic card.
2. In Cards, confirm the preview and selection.
3. Export to AnkiDroid and accept the permission prompt.
4. Open AnkiDroid, open the Question Practice deck and confirm:
   - concept notes render as cloze cards;
   - error notes use `Question Practice: Error` with all six fields;
   - basic notes show front and back.
5. Set the Cloud topic to a separate deck (for example `QP Cloud`) and export again. Confirm the cards land in `QP Cloud`, not the default deck.
6. Import a multi-answer question and export its error card. Confirm both selected and correct alternatives appear in the respective fields.
7. Delete `Question Practice: Error` in AnkiDroid, export again, and confirm the app creates it before adding notes.
8. Rename the topic and confirm old cards still use their captured topic name (and therefore the default deck), while new cards use the renamed topic.
9. Trigger AnkiDroid sync and confirm the DO_SYNC broadcast does not crash.
10. Disable the AnkiDroid API and confirm the app reports the problem without losing cards.
