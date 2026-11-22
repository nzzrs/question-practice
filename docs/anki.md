# AnkiDroid export

Question Practice writes to AnkiDroid through its supported Instant-Add API (`com.github.ankidroid:Anki-Android:api-v1.1.0`). The API uses AnkiDroid's `com.ichi2.anki.flashcards` ContentProvider and packs note fields with the official `\u001f` separator.

## One-time setup

1. Install AnkiDroid on the same device.
2. In AnkiDroid, open Settings → Advanced → enable the AnkiDroid API.
3. In Questions → Settings → AnkiDroid, tap **Grant permission**. Android asks for `com.ichi2.anki.permission.READ_WRITE_DATABASE`.
4. Make sure AnkiDroid has a **Cloze** note type. AnkiDroid ships with one; if it was deleted, create it again in AnkiDroid's note type manager. Questions uses that type for concept cards.

The manifest declares the database permission and a `<queries>` entry for `com.ichi2.anki`, required for package visibility on Android 11+.

## Decks: selected at topic level

Decks are selected **per topic only**. There is no per-practice deck: every card made from a topic routes to that topic's deck, or to the default deck when the topic has none.

1. Open **Settings → AnkiDroid → Deck name** and set the default deck, for example `Question Practice`.
2. Long-press a topic on Home and choose **Edit topic**, then **AnkiDroid deck** → **Browse decks**.
3. Pick an existing deck from AnkiDroid, or type a new name. A missing deck is created on export.
4. Leave the field blank to use the default deck.

The **Edit practice** sheet has no deck row. Deck selection is topic-level only: it does not create a practice-specific deck, and practice JSON files never contain a deck.

The picker reads the live deck list through AnkiDroid's API (`AddContentApi.deckList`). If the AnkiDroid API or database permission is unavailable, the picker explains the problem and still allows typing a deck name.

Routing uses the topic name captured on each card: concept cards use the topic captured when the term was looked up, atomic cards use the topic captured when they were created, and skipped-question basic cards use the topic captured in the review. If a topic is renamed, cards created before the rename keep the old captured topic name and fall back to the default deck. File exports do not encode a deck; choose the deck when importing the file into Anki.

## Note types: Basic and Cloze only

| Model | Fields | Used for |
|---|---|---|
| AnkiDroid's Cloze type | existing `Text` and `Back Extra` fields | Concept cards and definitions |
| `Basic` | `Front`, `Back` | Contrast, Cause and effect, Scenario and rule and Steps cards, skipped-question cards and Ask answers |

The app no longer creates or writes a custom error note type. An error is a review record that is turned into atomic Basic cards with **Create cards** before export. The old `Question Practice: Error v2` model is no longer required, created or written.

Basic cards use the note type named exactly **`Basic`**, with the two fields `Front` and `Back`. If that note type is missing, the app creates it through AnkiDroid's `addNewBasicModel` before adding notes; it does not use `Basic (and reversed card)` or another variant.

### Concept cards

Concept note text is:

```
Definition of {{c1::GCP}}: {{c2::A managed cloud computing platform.}}
```

The topic and subtopic are never written into the note text, even when the term
is defined inside a question. They travel as tags (`question-practice`,
`topic::<topic>`, `subtopic::<subtopic>`) and, in file exports, in the third
`Tags` column.

When the selected term is an acronym, the AI returns a dictionary-style meaning
for the cloze and puts only the full form in the note's `Back Extra` field:

```
Back Extra: Google Cloud Platform
```

The definition never spells the acronym out. The same expansion appears under
the definition bubble in the app.

### Atomic error cards

The end-of-session review and the Cards screen show the same feedback as practice: the question, every alternative with its correct/wrong state and explanation, the status, and your read-only wrong-answer bullets. Each saved note has a three-dot menu for Copy, Create card, Define, Ask when AI is configured, and Delete; each wrong-answer bullet has a menu for Copy and Create card with AI. A distracted re-test keeps the card due and adds a warning. The review no longer edits the question or options. There are no free-text bias or vaccine fields and no "Check with AI" button.

An error step is one full-width reading surface with a shared bottom dock. The floating card button above the dock opens **Create cards** as a bottom sheet, so the feedback stays readable above it; there is no split view. Create card with AI in a bullet's three-dot menu seeds the sheet from it; with AI it drafts the front and back and picks the template, and without a key it prefills the bullet as the front with a Settings hint. Manual entry adds cards one at a time and works offline without AI. Five templates write the front and back: **Definition**, **Contrast**, **Cause and effect**, **Scenario and rule** and **Steps**. A Definition card becomes a Cloze concept; the other four become Basic cards. Definition uses one raw cloze field with the term in `{{c1::…}}` and the definition in `{{c2::…}}`; both are required.

The sparkle icon beside the template opens optional AI suggestions. Each idea
offers up to three wording variants, and an error breakdown proposes at most
two ideas:

- a **contrast** idea that asks you to distinguish the chosen wrong option from the correct one;
- a **heuristic** idea whose front follows the mandatory template
  `If a scenario asks X but restricts with Y, which option is always discarded?` and whose back starts with `Discard Z because ...`.

Every builder card, draft and AI variant carries an advisory quality badge and
the estimated reading time. The badge flags a binary front (one answerable with
yes/no), a front longer than 30 words, a card over 15 seconds to read,
syntactic clues that give the answer away, template mismatches, missing fronts
or backs, and a missing or term-repeating definition. It never blocks saving. You choose which cards to save; the error is
marked reviewed. Errors are never sent to Anki directly.

## Tags

Every exported note carries hierarchical tags derived from the simulator
structure:

```
question-practice
topic::networking-basics
subtopic::layer-4
```

Topic and subtopic names are lower-cased and slugged (non-alphanumeric runs
become `-`). The `subtopic::` tag is omitted when the card has no subtopic. Tags
are the only carrier of topic and subtopic: no front or back ever contains a
bracketed `[Topic / Subtopic]` prefix.

## What is sent

Only selected, complete cards are sent. Concepts need a definition. Manual
cards built from any Basic template are always exportable Basic cards.
Error records and skipped questions are not exported directly: turn an error
into atomic cards with **Create cards** first and convert a skipped question
into a concept or basic card. The Cards screen previews every card and lets you
deselect or delete items first.

After a successful import the app broadcasts `com.ichi2.anki.DO_SYNC` so AnkiDroid can sync in the background.

## Failure handling

- AnkiDroid missing → the app offers the file fallback.
- API disabled or permission denied → an explanatory dialog and a shortcut that opens the AnkiDroid app.
- No Cloze note type → the app explains what to create.
- Partial failure → the successfully added note count is reported, but the selected cards stay unexported so nothing is silently lost.

## File fallback

**Share files** creates UTF-8, Anki-compatible files:

- `question-practice-concepts-YYYYMMDD-HHmm.txt` — a Cloze file with `#separator`, `#html`, `#notetype`, `#columns` and `#tags column:3` headers, then three tab-separated fields: front, extra, tags;
- `question-practice-basic-YYYYMMDD-HHmm.tsv` — the same header block for the Basic note type, then front, back, tags.

Import them into Anki desktop or AnkiDroid with the matching note types and map
the third column to Tags. Tabs become spaces and newlines become `<br>`; user
content is HTML-escaped. If an app ignores the header or cannot map a tags
column, the tags are dropped there; they are never moved into the card text.
File exports carry no deck, so choose one when importing.

## Manual verification

On a connected Android device with AnkiDroid installed:

1. Import the sample practice and create one concept, one atomic card and one skipped-question basic card.
2. In Cards, use **Cards** to see concepts and basic cards, and **Errors** to see error and skipped rows.
3. Export to AnkiDroid and accept the permission prompt.
4. In AnkiDroid, open the Question Practice deck and confirm:
   - concept notes render as cloze cards with no topic prefix in the text;
   - Contrast, Cause and effect, Scenario and rule and Steps cards use the `Basic` note type;
   - `question-practice`, `topic::` and `subtopic::` tags are present.
5. Set the Cloud topic to a separate deck with **Edit topic → AnkiDroid deck** (for example `QP Cloud`) and export again. Confirm the cards land in `QP Cloud`, not the default deck. Open **Edit practice** and confirm it has no deck row; deck selection is topic-level only.
6. Import a multi-answer question, answer it wrong, open the review and confirm **Create cards** adds two cards manually without AI, while the sparkle icon opens AI suggestions with contrast and scenario-and-rule ideas, variants, advisory quality badges and reading times. Retry with the refresh icon and confirm drafts stay.
7. Confirm no `Question Practice: Error v2` model is created in AnkiDroid.
8. Rename the topic and confirm old cards still use their captured topic name (and therefore the default deck), while new cards use the renamed topic.
9. Trigger AnkiDroid sync and confirm the DO_SYNC broadcast does not crash.
10. Disable the AnkiDroid API and confirm the app reports the problem without losing cards.
