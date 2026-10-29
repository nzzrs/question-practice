# Testing

## Automated

```bash
flutter analyze
flutter test
```

The suite runs on the Dart VM. Drift uses an in-memory SQLite database; HTTP and browser calls use fakes.

| Area | Coverage |
|---|---|
| Import | Schema rejection, JSON syntax paths, BOM/text files, semantic validation, duplicate handling, size limit |
| Practice | Scoring, skipped answers, distracted answers, resume/discard, mixed sessions, summary counts |
| Error queue | Exact 48-hour boundary, due query, resolution, history, wrong retry scheduling |
| Review | Error steps, skipped concept/basic branches, missing definitions |
| Lookup | AI JSON parsing, fenced JSON, 401 fallback, missing key/model, web URL selection, auto-saved concepts |
| Export | Cloze format, HTML/cloze escaping, exactly five error fields, TSV content, per-topic deck routing, default deck fallback, permission/status failures, partial failures |
| Data | Topic/practice summaries, accuracy/progress, due counts, unfinished sessions excluded |
| Widgets | Empty home, help, topic list, topic details, question feedback/explanation, five-minute reminder, sample import |

## Manual Android checklist

Use the connected Pixel 9 Pro XL (Android 17) and AnkiDroid 2.25.3.

1. Fresh install; open Help from the `i` icon.
2. Import the sample; confirm two topics and eight questions.
3. Start a practice; answer one correctly, one wrongly and skip one.
4. Confirm feedback stays on the same screen and every alternative expands.
5. Toggle “I was distracted” on a wrong answer; confirm no error card appears.
6. Finish; confirm the score and looked-up count.
7. Complete the error review: bias, vaccine, concept card and basic card.
8. Open Cards; preview, deselect and delete a card.
9. Set a topic's deck from the live AnkiDroid list (or type a new deck), export, and verify cards land in that deck while a blank topic uses the default.
10. Export to AnkiDroid; verify the deck and all three note types.
11. Use Define with web mode; confirm the Custom Tab opens and a concept is saved.
12. Configure an AI endpoint, save the key, and test one definition.
13. Seed an old error (or use a clock override in development), confirm it is hidden until 48 hours and resolves after a correct answer.
14. Toggle wallpaper colors and dark mode; check contrast.
15. Set the font scale to 2.0; confirm no overflow on home, session, review and cards.
16. Erase all data; confirm topics, cards, settings and key are gone.

## Notes

- Widget tests use `TestHarness` with an in-memory database and an `UncontrolledProviderScope` that is disposed before the test ends. This flushes Drift stream-cancellation timers.
- `pumpAndSettle` is avoided where a page contains a continuous M3E animation; bounded frame pumps are used instead.
- No golden tests: font and engine changes make them noisy. Semantics and layout assertions cover the important UI contracts.
