# AnkiDroid export

Question Practice writes to AnkiDroid through its supported Instant-Add API (`com.github.ankidroid:Anki-Android:api-v1.1.0`). The API uses AnkiDroid's `com.ichi2.anki.flashcards` ContentProvider and packs note fields with the official `\u001f` separator.

## One-time setup

1. Install AnkiDroid on the same device.
2. Open AnkiDroid → Settings → Advanced → enable the AnkiDroid API.
3. In Question Practice → Settings → AnkiDroid, tap **Grant permission**. Android asks for `com.ichi2.anki.permission.READ_WRITE_DATABASE`.
4. Make sure AnkiDroid has a **Cloze** note type. AnkiDroid ships with one; if it was deleted, create it again in AnkiDroid's note type manager. Question Practice uses that type for concept cards.

The manifest declares the database permission and a `<queries>` entry for `com.ichi2.anki`, required for package visibility on Android 11+.

## Created deck and note types

Deck: **Question Practice** (editable in Settings; created if missing).

| Model | Fields | Used for |
|---|---|---|
| AnkiDroid's Cloze type | existing `Text` field | Concept cards |
| `Question Practice Error` | Question, Wrong answer, Correct answer, Bias, Vaccine | Error cards |
| `Question Practice Basic` | Front, Back | Skipped-question “another question” cards |

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
- `question-practice-errors-YYYYMMDD-HHmm.tsv` — five tab-separated fields;
- `question-practice-basic-YYYYMMDD-HHmm.tsv` — two tab-separated fields.

Import them into Anki desktop or AnkiDroid with the matching note types. Tabs become spaces and newlines become `<br>`; user content is HTML-escaped.

## Manual verification

On a connected Android device with AnkiDroid installed:

1. Import the sample practice and create one concept, one error card and one basic card.
2. In Cards, confirm the preview and selection.
3. Export to AnkiDroid and accept the permission prompt.
4. Open AnkiDroid, open the Question Practice deck and confirm:
   - concept notes render as cloze cards;
   - error notes show all five fields;
   - basic notes show front and back.
5. Trigger AnkiDroid sync and confirm the DO_SYNC broadcast does not crash.
6. Disable the AnkiDroid API and confirm the app reports the problem without losing cards.
