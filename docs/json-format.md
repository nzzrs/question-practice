# Practice JSON format

Questions imports and updates practices from a JSON file. The same file format
is used by **Import** on Home and by **Edit practice → Update practice JSON**.
A file can contain many topics, each with many practices, and each practice with
many questions.

- Bundled import sample: [`assets/samples/sample_practice.json`](../assets/samples/sample_practice.json)
- Complete format example: [`assets/samples/practice_format_example.json`](../assets/samples/practice_format_example.json)
- JSON Schema: [`assets/schema/practice_import.schema.json`](../assets/schema/practice_import.schema.json)
- Schema dialect: JSON Schema draft 07

The complete example is importable as-is. Its `sourceId` values are
placeholders that show the field; a normal import ignores them.

## Files and limits

| Item | Rule |
|---|---|
| File extension | `.json`, or `.txt` containing JSON |
| Encoding | UTF-8. A leading UTF-8 BOM is accepted. |
| Maximum file size | 10 MB (10,485,760 bytes) |
| Maximum questions | 5,000 across the whole file |
| Maximum topics | 100 |
| Top-level value | One JSON object, not an array |
| Comments and trailing commas | Not allowed; this is strict JSON |
| Unknown fields | Rejected at every level |

The app validates the entire file before writing anything. A bad file is
rejected as a whole; there is no partial import and no partial update.

## File shape

```
file
└── topics[]
    ├── name, description, priority
    └── practices[]
        ├── name, description
        └── questions[]
            ├── prompt, subtopic, sourceId
            ├── alternatives[]
            ├── correctIndex or correctIndexes
            ├── explanation
            └── alternativeExplanations[]
```

- A file has one required top-level `formatVersion` and one required `topics`
  array.
- A topic has at least one practice.
- A practice has at least one question.
- A question has 2–8 alternatives and exactly one explanation per alternative.
- A topic or practice name identifies the item; a practice name only has to be
  unique inside its own topic.

## Minimal file

One topic, one practice and one single-answer question:

```json
{
  "formatVersion": 1,
  "topics": [
    {
      "name": "Cloud",
      "practices": [
        {
          "name": "Core services",
          "questions": [
            {
              "prompt": "Which service runs containers?",
              "subtopic": "Containers",
              "alternatives": ["Cloud Run", "Cloud SQL"],
              "correctIndex": 0,
              "explanation": "Cloud Run runs container images on managed infrastructure.",
              "alternativeExplanations": [
                "Correct. Cloud Run is the managed container platform.",
                "Cloud SQL is a managed relational database."
              ]
            }
          ]
        }
      ]
    }
  ]
}
```

Fields such as `description`, `priority`, `subtopic` and `sourceId` are
optional. The smallest valid question still needs `prompt`, `alternatives`,
exactly one of `correctIndex` or `correctIndexes`, `explanation`, and
`alternativeExplanations`.

## Complete example

This example has two topics. The first topic has one practice with a
single-answer question and a multi-answer question. The second topic shows the
multi-topic shape. Every question has a `sourceId`, every question has a
`subtopic`, and every alternative has its own explanation.

```json
{
  "formatVersion": 1,
  "topics": [
    {
      "name": "Cloud fundamentals",
      "description": "Core Google Cloud services and how to choose between them.",
      "priority": 1,
      "practices": [
        {
          "name": "Core services",
          "description": "A practice with one single-answer question and one multi-answer question.",
          "questions": [
            {
              "sourceId": "101",
              "prompt": "Which Google Cloud service runs a container image without requiring you to manage a cluster?",
              "subtopic": "Serverless compute",
              "alternatives": [
                "Compute Engine",
                "Cloud Run",
                "Google Kubernetes Engine",
                "Cloud Functions"
              ],
              "correctIndex": 1,
              "explanation": "Cloud Run is a managed container platform. You give it a container image and it handles scaling and the underlying infrastructure.",
              "alternativeExplanations": [
                "Compute Engine gives you virtual machines, so you manage the operating system and runtime yourself.",
                "Correct. Cloud Run runs containers on fully managed infrastructure and scales with requests.",
                "Google Kubernetes Engine runs containers, but you still manage a cluster and its node pools.",
                "Cloud Functions runs event-driven functions, not arbitrary long-running container images."
              ]
            },
            {
              "sourceId": "102",
              "prompt": "Which of these are managed services that run code without requiring you to manage a cluster?",
              "subtopic": "Serverless compute",
              "alternatives": [
                "Cloud Run",
                "Compute Engine",
                "Cloud Functions",
                "Cloud SQL"
              ],
              "correctIndexes": [0, 2],
              "explanation": "Cloud Run and Cloud Functions are managed compute services. You do not provision or maintain a cluster for either one.",
              "alternativeExplanations": [
                "Correct. Cloud Run runs containers on managed infrastructure.",
                "Compute Engine gives you virtual machines, so you manage the operating system and runtime yourself.",
                "Correct. Cloud Functions runs event-driven functions on managed infrastructure.",
                "Cloud SQL is a managed relational database, not a compute service for running your code."
              ]
            }
          ]
        }
      ]
    },
    {
      "name": "Networking basics",
      "description": "IP addressing, DNS, and transport-layer behaviour.",
      "priority": 2,
      "practices": [
        {
          "name": "TCP/IP",
          "description": "Transport and internet-layer fundamentals.",
          "questions": [
            {
              "sourceId": "201",
              "prompt": "Which transport protocol provides reliable, ordered delivery of a byte stream?",
              "subtopic": "Transport layer",
              "alternatives": ["UDP", "TCP", "ICMP", "ARP"],
              "correctIndex": 1,
              "explanation": "TCP establishes a connection, acknowledges segments, and retransmits lost data to preserve order and reliability.",
              "alternativeExplanations": [
                "UDP is connectionless and does not guarantee delivery or ordering.",
                "Correct. TCP provides a reliable, ordered byte stream.",
                "ICMP carries control and error messages, such as ping requests.",
                "ARP resolves IPv4 addresses to link-layer addresses; it does not carry a byte stream."
              ]
            }
          ]
        }
      ]
    }
  ]
}
```

The same content is stored in
[`assets/samples/practice_format_example.json`](../assets/samples/practice_format_example.json).
Import that file to test the importer; import it again to confirm duplicate
detection.

## Field reference

Array indexes in paths and in `correctIndex`/`correctIndexes` are zero-based.
The first alternative is index `0`.

| Field | Required | Type | Constraints and behaviour |
|---|---|---|---|
| `formatVersion` | yes | integer | Must be exactly `1`. |
| `topics` | yes | array | 1–100 topics. |
| `topics[].name` | yes | string | 1–120 characters. Trimmed; must not be blank after trimming. Must be unique in the file, case-insensitive. |
| `topics[].description` | no | string | Up to 2,000 characters. Trimmed. Defaults to an empty string. |
| `topics[].priority` | no | integer or null | `1`–`5`; `1` is highest. Missing or `null` means unprioritised. |
| `topics[].practices` | yes | array | At least one practice. No upper limit in the schema. |
| `practices[].name` | yes | string | 1–120 characters. Trimmed; must not be blank after trimming. Must be unique inside its topic, case-insensitive. |
| `practices[].description` | no | string | Up to 2,000 characters. Trimmed. Defaults to an empty string. |
| `practices[].questions` | yes | array | At least one question. The file total is limited to 5,000. |
| `prompt` | yes | string | 1–5,000 characters. Must not be blank after trimming. |
| `subtopic` | no | string | Up to 120 characters. Trimmed. Blank or missing means **Uncategorized**. |
| `sourceId` | no | string | 1–120 characters. Stable identity written by **Download practice JSON** and used by **Update practice JSON**. A normal import ignores it and does not store it. |
| `alternatives` | yes | array of strings | 2–8 strings. Each string is 1–2,000 characters and must not be blank after trimming. Order defines the indexes. |
| `correctIndex` | one of | integer | Zero-based index of the single correct alternative. Schema range `0`–`7`; it must also be inside `alternatives`. |
| `correctIndexes` | one of | array of integers | 1–8 unique zero-based indexes. Schema range `0`–`7`; every value must also be inside `alternatives`. Use at least two values for a multi-answer question. |
| `explanation` | yes | string | 1–5,000 characters. Must not be blank after trimming. Shown for the question as a whole. |
| `alternativeExplanations` | yes | array of strings | 2–8 strings, each 1–5,000 characters. The count must equal the number of alternatives, exactly one per alternative, in the same order. |

Additional rules:

- Every object rejects unknown fields. A typo such as `right_answer` or
  `correct_index` is an error, not silently ignored.
- `correctIndex` and `correctIndexes` are mutually exclusive. A question needs
  exactly one of them, never both and never neither.
- `correctIndexes` is a JSON array, even when it contains one value. A single
  value behaves like a single-answer question; use `correctIndex` for clarity.
- `alternativeExplanations` must describe every alternative, including the
  correct one. The app does not infer or generate missing explanations.
- Duplicate alternatives are not rejected by validation, but they make a
  question ambiguous and should be avoided.
- Duplicate prompts inside one practice are not rejected, but they make
  source-less updates ambiguous. See [Common mistakes](#common-mistakes).

## Single-answer and multi-answer questions

Use `correctIndex` when exactly one alternative is correct:

```json
{
  "prompt": "Which service runs containers?",
  "alternatives": ["Cloud Run", "Cloud SQL"],
  "correctIndex": 0
}
```

The app shows radio-style selection and accepts exactly that one alternative.

Use `correctIndexes` when more than one alternative is correct:

```json
{
  "prompt": "Which of these are managed container services?",
  "alternatives": ["Cloud Run", "Compute Engine", "Cloud Functions", "Cloud SQL"],
  "correctIndexes": [0, 2]
}
```

The app shows checkboxes. The selected set must equal the correct set: every
correct index must be selected, and no wrong index may be selected. With
`correctIndexes: [0, 2]`, selecting only `0` is wrong, and selecting `0, 2, 3`
is also wrong.

Do not put `correctIndex` and `correctIndexes` in the same question. Do not put
`correctIndexes` inside a string or use one-based positions.

## Subtopics

`subtopic` is an optional free-form group inside a practice. It does not create
a separate practice or session. The value is trimmed, and a missing or blank
value is stored as **Uncategorized**.

Topic statistics group questions and answers by this value. Questions that
belong together must use the same spelling and capitalisation; `Networking` and
`networking` are separate groups. The **By subtopic** section appears only when
at least one question in the topic has a non-blank subtopic.

## Question identity and practice updates

### Downloading a practice

Long-press a practice and choose **Edit practice → Download practice JSON**.
The shared file contains one topic and one practice in exactly the format
above:

- the topic's current name, description and, when set, `priority`;
- the practice's current name and description;
- every current question, in stored order;
- `sourceId` on every question, containing the app's stable identity for that
  question;
- `subtopic` only when the stored value is not blank;
- `correctIndex` when the question has one correct alternative, otherwise
  `correctIndexes`.

The file name is
`question-practice-practice-<practiceId>-<yyyyMMdd-HHmm>.json`.

`sourceId` is an update hint. It is not stored in the database and is not part
of a practice's content hash. Importing a file that contains `sourceId` is safe:
the identity is ignored outside an update.

### Updating a practice

Long-press the same practice and choose **Edit practice → Update practice JSON**.
The target practice must already exist. The file must contain a topic and
practice whose names match the stored practice after trimming and ignoring
case. Extra topics or practices in the file are ignored when the update is
matched, but the whole file is still validated first.

For each question in the file, the app maps it to a stored question in this
order:

1. If `sourceId` parses as an integer and matches the id of a stored question
   that has not already been matched, use that stored question.
2. Otherwise, find the first not-yet-matched stored question whose prompt is
   exactly equal after trimming.
3. Otherwise, treat the question as new.

Each stored question can be matched at most once. A missing, non-numeric,
unknown or repeated `sourceId` falls back to the prompt rule. This keeps files
exported before identities existed updatable.

Content comparison for a matched question uses:

- trimmed prompt;
- the alternatives, in order;
- the set of correct indexes;
- trimmed explanation;
- the alternative explanations, in order;
- trimmed subtopic.

`sourceId` itself is not content. A matched question appears as **modified**
when any of those fields differ, and as **unchanged** otherwise. The practice
name, description and `priority` in the file are not applied to the stored
practice; only the topic and practice names are used to find the target.

Before anything is written, the preview shows the counts for new, modified,
deleted and unchanged questions, plus the affected prompts. **Apply changes**
writes one transaction. **Cancel** leaves the practice untouched.

| File contains | Result |
|---|---|
| A question with a known `sourceId` | Updated in place. The stored question keeps its id. |
| A question with an unknown or absent `sourceId`, with a matching prompt | Updated in place by prompt. |
| A question with no match | Inserted as a new question. |
| A stored question missing from the file | Deleted from the practice. |

What is preserved on update:

- A matched question keeps its database id, so its attempts, reasoning, error
  cards, skipped-question records and statistics remain linked.
- A new question starts with no history.
- A deleted question loses its attempts, session-question links, error cards and
  skipped-question records through the database cascade. Concept cards, basic
  cards and highlights that referenced it remain, but their question link is
  cleared. Statistics for its attempts disappear with them.
- The practice stays in the same topic and keeps its done flag, while the
  practice content hash and import time are refreshed.
- Topic properties such as deck, archived state, priority and description are
  not changed by a practice update. Rename the practice, or edit the topic, in
  the app rather than in the file.

If the file's topic or practice name does not match the selected practice, the
update is rejected. Download the practice again and edit that file if the names
have changed.

## Import behaviour

**Import** creates new content. It is not an update command.

1. The file is read as UTF-8. A leading BOM is removed.
2. Syntax is parsed as strict JSON.
3. The JSON Schema validates structure, types, lengths and unknown fields.
4. Semantic checks validate trimmed text, unique topic names, unique practice
   names per topic, correct-index ranges, duplicate indexes, the one-of rule for
   correct indexes, and explanation/alternative alignment.
5. A preview shows the file name, topic/practice/question counts and duplicate
   notes.
6. **Import** writes all new topics, practices and questions in one database
   transaction. **Cancel** writes nothing.

Duplicate handling against existing data:

| Situation | Result |
|---|---|
| Topic name already exists, case-insensitive | Reuse the topic and keep its existing description and priority. |
| Practice content hash already exists in that topic | Skip the practice. |
| Practice name exists with different content | Import as `Name (2)`, then `Name (3)`, and so on. |
| The same file is imported twice | The second import skips every practice. |

Before importing a practice that already exists, use **Update practice JSON**
instead. Re-importing changed content with **Import** creates a numbered copy;
it does not edit the original.

## Validation errors and JSON paths

Two layers report problems before any write:

1. **JSON Schema** errors for the shape, required fields, types, lengths,
   numeric ranges, item counts, unique indexes and unknown fields.
2. **Semantic** errors for trimmed empty text, duplicate topic or practice
   names, indexes outside the actual alternatives, index duplication, the
   one-of rule, and explanation count alignment.

Paths use JSON Pointer syntax with zero-based array indexes. The root is `/`.
Syntax errors from the JSON parser use `line N, column N` instead.

Representative rejection messages:

```
line 7, column 18: Unexpected character
/topics/0/practices/0/questions/0/correctIndex: maximum exceeded (99 > 7)
/topics/0/practices/0/questions/0/correctIndexes: Correct index 5 is outside 0..3.
/topics/0/practices/0/questions/0/correctIndexes: uniqueItems violated: [0, 0] [0]==[1]
/topics/0/practices/0/questions/0/alternativeExplanations: Expected 4 explanations, found 3.
/topics/0/practices/0/questions/0: unallowed additional property right_answer
/topics/0/practices/0/questions/0: #/definitions/question/oneOf: violated Too many elements
/topics/2/name: Topic names must be unique; "Cloud fundamentals" appears more than once.
```

Notes on these messages:

- A missing required field is reported at the parent object and at the missing
  property path, for example `/topics/0/practices/0/questions/0` and
  `/topics/0/practices/0/questions/0/prompt`, with a message beginning
  `required prop missing: prompt`.
- Sending both `correctIndex` and `correctIndexes` fails the schema `oneOf`
  check before the semantic layer, so the message is the generic `oneOf`
  violation at the question path.
- A range error found by the semantic layer is reported under
  `/correctIndexes` even when the question used the singular `correctIndex`.
- Whitespace-only strings pass the schema's `minLength` but are rejected by the
  semantic layer with messages such as `Prompt cannot be empty.`,
  `Alternative cannot be empty.` or `Explanation cannot be empty.`
- The preview lists every issue found. Fix all of them; the file is not
  partially imported.

## Common mistakes

| Mistake | What happens | Fix |
|---|---|---|
| Counting alternatives from `1` | The wrong alternative is marked correct. | `0` is the first alternative. |
| Using `correctIndex: [1]` or `correctIndexes: 1` | Schema type error. | Use an integer for `correctIndex` and an array for `correctIndexes`. |
| Including both answer fields | Schema `oneOf` error; the question is rejected. | Keep exactly one field. |
| Duplicating an index in `correctIndexes` | `uniqueItems` error. | List each correct index once. |
| `correctIndexes` outside the alternatives | Semantic range error. | Keep every index between `0` and `alternatives.length - 1`. |
| Mismatched explanation count | Semantic error; nothing is imported. | Write exactly one explanation per alternative, in the same order. |
| Explanation order differs from alternatives | Validation passes, but feedback describes the wrong choices. | Keep the arrays aligned; include an explanation for the correct alternative too. |
| Duplicate prompts in one practice | Import passes, but a source-less update can match the first prompt and leave another question unmatched. | Keep prompts unique, or keep and preserve the exported `sourceId`. |
| Editing a practice by importing it again | A numbered copy such as `Name (2)` is created. | Use **Update practice JSON**. |
| Renaming the practice only inside the update file | Update is rejected because the target name no longer matches. | Rename in the app, then download again. |
| Typing `right_answer` or another custom field | Unknown-field error at the question. | Use the exact field names in the table above. |
| Adding JSON comments or trailing commas | JSON syntax error with a line and column. | Use strict JSON; remove comments and trailing commas. |
| Saving as ANSI/Latin-1 | UTF-8 error before parsing. | Save the file as UTF-8. |
| Mixing subtopic spellings | Statistics split into separate groups. | Use one spelling consistently. |
| More than 5,000 questions | File rejected at `/topics`. | Split the content into smaller files. |

## Text and encoding rules

- All text is plain text. The app displays prompt, alternatives, explanations
  and subtopics as written.
- JSON strings use normal JSON escaping for quotes, backslashes and control
  characters. Non-ASCII characters are fine.
- Newlines inside JSON strings are allowed with `\n`.
- For Anki export, `<`, `>`, and `&` are HTML-escaped, newlines become `<br>`,
  and tabs become spaces.
- Cloze syntax (`::`, `{{`, `}}`) inside a term or definition is neutralised so
  it cannot break a generated card. See [anki.md](anki.md).

## Anki decks are not part of practice JSON

The practice file cannot select or change an AnkiDroid deck. Decks are stored
per topic:

- set the default deck in **Settings → AnkiDroid**;
- set a topic's deck in **Edit topic → AnkiDroid deck** (or in the topic
  long-press menu).

There is no per-practice deck. The **AnkiDroid deck** entry in the **Edit
practice** sheet edits the practice's topic deck, not a separate practice deck.
A downloaded practice JSON file never contains a deck. See [anki.md](anki.md).

## Versioning

`formatVersion` is `1`. `subtopic`, `sourceId` and `correctIndexes` are additive
fields: files written without them remain valid. A file with another
`formatVersion` is rejected instead of guessed. Future incompatible changes
must introduce a new version.
