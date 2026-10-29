# Import format

Question Practice imports a practice file from **Import** on the home screen. Accepted files:

- `.json`
- `.txt` containing UTF-8 JSON

The file may contain one or many topics and practices. Everything is validated before anything is written. A bad file is rejected as a whole; no partial import.

- Canonical sample: [`assets/samples/sample_practice.json`](../assets/samples/sample_practice.json)
- JSON Schema: [`assets/schema/practice_import.schema.json`](../assets/schema/practice_import.schema.json)
- Schema draft: **07** (the latest draft supported by the Dart validator used by the app)
- File size limit: 10 MB
- Question limit: 5,000 per file

## Minimal file

One topic, one practice, one question.

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

## Several correct answers

A question can have more than one correct alternative. Replace `correctIndex` with `correctIndexes`; the app then shows checkboxes and requires every correct alternative to be selected.

```json
{
  "prompt": "Which of these are managed container services?",
  "alternatives": ["Cloud Run", "Compute Engine", "Cloud Functions", "Cloud SQL"],
  "correctIndexes": [0, 2],
  "explanation": "Cloud Run and Cloud Functions run code without a cluster.",
  "alternativeExplanations": [
    "Correct. Cloud Run runs container images on managed infrastructure.",
    "Compute Engine gives you a virtual machine, not a managed container service.",
    "Correct. Cloud Functions is a managed event-driven compute service.",
    "Cloud SQL is a managed relational database."
  ]
}
```

Use either `correctIndex` or `correctIndexes` for a question, never both.

The app compares the selected set with the correct set. With `correctIndexes: [0, 2]`, selecting only `0` is wrong, and selecting `0, 2, 3` is also wrong. Alternative explanations remain one per alternative; mark which ones are correct in the explanation text.

## File shape

```json
{
  "formatVersion": 1,
  "topics": [
    {
      "name": "Topic name",
      "description": "Optional topic description",
      "priority": 1,
      "practices": [
        {
          "name": "Practice name",
          "description": "Optional practice description",
          "questions": [
            {
              "prompt": "Question text?",
              "alternatives": ["A", "B", "C", "D"],
              "correctIndex": 2,
              "explanation": "Why the correct alternative is correct.",
              "alternativeExplanations": [
                "Why A is wrong.",
                "Why B is wrong.",
                "Why C is correct.",
                "Why D is wrong."
              ]
            }
          ]
        }
      ]
    }
  ]
}
```

## Field reference

| Path | Required | Type | Rules |
|---|---|---|---|
| `formatVersion` | yes | integer | Must be `1`. |
| `topics` | yes | array | 1–100 topics. |
| `topics[].name` | yes | string | 1–120 chars, unique in the file, case-insensitive. |
| `topics[].description` | no | string | Up to 2,000 chars. Defaults to empty. |
| `topics[].priority` | no | integer or null | 1–5. `1` is highest. Null/missing means unprioritised. |
| `topics[].practices` | yes | array | At least one practice. |
| `practices[].name` | yes | string | 1–120 chars, unique inside its topic. |
| `practices[].description` | no | string | Up to 2,000 chars. Defaults to empty. |
| `practices[].questions` | yes | array | At least one question. |
| `question.prompt` | yes | string | 1–5,000 chars. |
| `question.alternatives` | yes | string array | 2–8 non-empty alternatives, 2,000 chars each. |
| `question.correctIndex` | one of | integer | Zero-based index of the single correct alternative. Must be inside `alternatives`. |
| `question.correctIndexes` | one of | integer array | 1–8 unique zero-based indexes for a question with several correct answers. |
| `question.explanation` | yes | string | Non-empty. Overall explanation shown after answering. |
| `question.alternativeExplanations` | yes | string array | Exactly one non-empty explanation per alternative, in the same order. |

A question needs exactly one of `correctIndex` or `correctIndexes`. Unknown fields are rejected. This catches typos such as `right_answer` or `correct_index` instead of silently importing a broken question.

## Multiple practices and topics

A topic's `practices` array holds any number of practices. Add more topics to `topics`. Each practice appears as its own card on the topic screen and produces its own session.

```json
{
  "formatVersion": 1,
  "topics": [
    {
      "name": "Cloud fundamentals",
      "description": "Core Google Cloud services.",
      "priority": 1,
      "practices": [
        {
          "name": "Compute choices",
          "description": "Pick the right compute service.",
          "questions": [
            {
              "prompt": "Which service runs containers without a cluster?",
              "alternatives": ["Compute Engine", "Cloud Run", "GKE", "Cloud Functions"],
              "correctIndex": 1,
              "explanation": "Cloud Run is a managed container platform.",
              "alternativeExplanations": [
                "Compute Engine is an IaaS virtual machine.",
                "Correct. Cloud Run runs containers on managed infrastructure.",
                "GKE runs containers, but you manage the cluster.",
                "Cloud Functions runs event-driven functions."
              ]
            },
            {
              "prompt": "Which storage class is cheapest for long-term archives?",
              "alternatives": ["Standard", "Nearline", "Coldline", "Archive"],
              "correctIndex": 3,
              "explanation": "Archive has the lowest storage price and the highest retrieval cost.",
              "alternativeExplanations": [
                "Standard is for frequently accessed data.",
                "Nearline is for monthly access.",
                "Coldline is cheaper, but Archive is cheaper for long-term retention.",
                "Correct. Archive is the lowest-cost long-term class."
              ]
            }
          ]
        },
        {
          "name": "Messaging",
          "questions": [
            {
              "prompt": "What is Pub/Sub for?",
              "alternatives": ["Asynchronous messaging", "Serving websites"],
              "correctIndex": 0,
              "explanation": "Pub/Sub decouples producers and consumers with topics and subscriptions.",
              "alternativeExplanations": [
                "Correct. It delivers messages asynchronously.",
                "Static websites are served by Cloud Storage or Firebase Hosting."
              ]
            }
          ]
        }
      ]
    },
    {
      "name": "Networking basics",
      "description": "IP, DNS and transport fundamentals.",
      "priority": 2,
      "practices": [
        {
          "name": "TCP/IP",
          "questions": [
            {
              "prompt": "Which transport protocol provides reliable, ordered delivery?",
              "alternatives": ["UDP", "TCP", "ICMP", "ARP"],
              "correctIndex": 1,
              "explanation": "TCP acknowledges segments and retransmits lost data.",
              "alternativeExplanations": [
                "UDP is connectionless and unreliable.",
                "Correct. TCP provides a reliable, ordered byte stream.",
                "ICMP carries control messages.",
                "ARP resolves IPv4 addresses to link-layer addresses."
              ]
            }
          ]
        }
      ]
    }
  ]
}
```

## Validation

Two layers run before import:

1. **JSON Schema**: structure, required fields, types, lengths, limits, unknown fields.
2. **Semantic checks**: unique topic names, unique practice names per topic, `correctIndex` or `correctIndexes` within range, no duplicate indexes, explanation count equal to alternative count, non-empty text after trimming, total question limit.

Examples of rejection messages:

```
line 7, column 18: Unexpected character
/topics/0/practices/0/questions/0/correctIndex: maximum exceeded (99 > 7)
/topics/0/practices/0/questions/0/correctIndexes: correctIndexes cannot contain the same index twice.
/topics/0/practices/0/questions/0/alternativeExplanations: Expected 4 explanations, found 3.
```

The preview screen shows the file name, topic/practice/question counts and duplicate notes. **Import** writes everything in one database transaction. **Cancel** leaves the database unchanged.

## Duplicate handling

| Situation | Result |
|---|---|
| Topic name already exists (case-insensitive) | Reuse the topic. Keep its existing description and priority. |
| Practice content hash already exists in the topic | Skip it. |
| Practice name exists with different content | Import as `Name (2)`, then `Name (3)`, etc. |
| Same file imported twice | Second import skips all practices. |

The preview lists these decisions before import.

## Text rules

- The app displays prompt, alternatives and explanations as plain text.
- For Anki export, `<`, `>`, `&` are HTML-escaped, newlines become `<br>`, and tabs become spaces.
- Cloze syntax (`::`, `{{`, `}}`) inside a term or definition is neutralised so it cannot break the generated card.
- JSON strings must escape quotes and backslashes normally. Unicode is fine.

## Import format does not contain Anki decks

Deck selection is app configuration, not file data. Set the default deck in **Settings → AnkiDroid**. Override it per topic in **Topic → Edit → AnkiDroid deck**. See [anki.md](anki.md).

## Versioning

`formatVersion` is `1`. `correctIndexes` is an additive field: files written for the original version with `correctIndex` keep working. Future incompatible changes must use a new version; the app rejects unknown versions rather than guessing.
