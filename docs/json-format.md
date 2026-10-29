# Practice JSON format

The importer accepts `.json` files, or `.txt` files whose contents are UTF-8 JSON. A UTF-8 BOM is ignored. The whole file is validated before anything is written.

The schema is [assets/schema/practice_import.schema.json](../assets/schema/practice_import.schema.json). It uses JSON Schema draft-07, the latest draft supported by the Dart validator used by the app. The app adds semantic checks that JSON Schema cannot express.

## Example

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
              "prompt": "Which service runs a container image without a cluster?",
              "alternatives": ["Compute Engine", "Cloud Run", "GKE", "Cloud Functions"],
              "correctIndex": 1,
              "explanation": "Cloud Run is a managed container platform.",
              "alternativeExplanations": [
                "Compute Engine is an IaaS virtual machine.",
                "Correct. Cloud Run runs containers on managed infrastructure.",
                "GKE runs containers but you manage a cluster.",
                "Cloud Functions runs event-driven functions."
              ]
            }
          ]
        }
      ]
    }
  ]
}
```

## Rules

| Field | Rule |
|---|---|
| `formatVersion` | Must be `1`. |
| `topics` | 1–100 topics. |
| `topics[].name` | 1–120 characters, unique within the file (case-insensitive). |
| `topics[].description` | Optional, up to 2000 characters. |
| `topics[].priority` | Optional integer 1–5. `1` is highest. |
| `topics[].practices` | At least one practice. |
| `practices[].name` | 1–120 characters, unique within the topic. |
| `practices[].questions` | At least one question. |
| `prompt` | 1–5000 characters. |
| `alternatives` | 2–8 non-empty strings. |
| `correctIndex` | Zero-based index inside `alternatives`. |
| `explanation` | Non-empty. |
| `alternativeExplanations` | Exactly one non-empty explanation per alternative. |

Additional properties are rejected, so typos fail loudly instead of being ignored. Files over 10 MB or more than 5,000 questions are rejected.

## Duplicates

- A topic with the same name (case-insensitive) is reused. Its description and priority are kept; the file does not overwrite them.
- A practice with the same content hash is skipped.
- A practice with the same name but different content is imported as `Name (2)`, `Name (3)`, and so on.
- The preview lists every duplicate decision before import.

## Files with multiple practices

Add more practices to a topic's `practices` array, or more topics to `topics`. Every practice produces its own card on the topic screen.

## Validation errors

Errors include a JSON path such as:

```
/topics/0/practices/1/questions/3/correctIndex: maximum exceeded (99 > 7)
```

JSON syntax errors include a line and column. Validation failures never partially import a file.
