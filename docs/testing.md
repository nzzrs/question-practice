# Testing

## Automated

```bash
flutter analyze
flutter test
dart run tool/docs/update_docs.dart --check
```

The suite runs on the Dart VM. Drift uses an in-memory SQLite database; HTTP and browser calls use fakes.

| Area | Coverage |
|---|---|
| Import | Schema rejection, JSON syntax paths, BOM/text files, semantic validation, `correctIndex`, `correctIndexes`, optional subtopics, duplicate handling, size limit |
| Practice | Scoring, multi-answer set matching, skipped answers, distraction checked and unchecked after feedback, resume/discard, mixed sessions, summary counts, session arrows, done/solved/skipped history, shuffled inclusion, redo prompt, done tag |
| Practice edit | JSON export with stable question identities, diff counts for unchanged/modified/new/deleted, prompt fallback without identities, reworded questions with identities, wrong practice rejection, answers and cards preserved across apply, deleted-question cascade, edit menu and update preview Apply/Cancel |
| Error queue | Exact 48-hour boundary, due query, resolution, history, wrong retry scheduling |
| Review | Error steps, shared error-card review view, skipped concept/basic branches, missing definitions, AI bias/vaccine suggestions, structured skipped/unknown review with reasoning and other alternatives |
| Highlights | Highlight persistence, painted phrases, keep/convert review steps, highlights in Cards, plain-text download |
| Ask | AI request carries passage/context/message, plain-text answer, ask sheet and card action |
| Cards browser | Combined error and skipped section with checkboxes and pencils, unified review all/selected, formatted previews, filters, editor switches between concept and basic fields |
| Past errors | Due queue and resolved history collapsed by default, review action above the list |
| Settings | AI key handling, data actions keep visible labels |
| Skipped queue | Persistence across the session, unknown toggle, early finish, late reasoning, combined Cards section and conversion |
| Lookup | OpenAI-compatible and Gemini requests, AI JSON parsing, fenced JSON, 401 fallback, missing key/model, provider model lists, web URL selection, auto-saved concepts |
| Export | Cloze format, HTML/cloze escaping, six error fields, distractor explanation, multi-answer fields, TSV content, per-topic deck routing, default deck fallback, permission/status failures, partial failures |
| Data | Topic/practice summaries, accuracy/progress, due counts, unfinished sessions excluded, archive filtering, per-topic sort settings, subtopic grouping, deletion cascades through statistics |
| Statistics | Regression line math (flat, upward, downward, fewer than two points), weekly learning rate and its one-week threshold, per-subtopic stats with Uncategorized, JSON statistics payload and share action |
| Widgets | Empty home, multiple paused sessions, help, topic list, topic details, topic long-press edit/archive/delete, archived-topics sheet, topic and practice sort persistence, shuffle FAB start sheet, question feedback/explanation, question arrows, distraction checkbox in feedback, five-minute reminder, sample import, subtopic statistics section and its hidden state, statistics export button |
| Documentation | `test/docs/docs_sync_test.dart` runs `tool/docs/update_docs.dart --check`, so the generated table, column, index, migration and backup sections must match the Drift code |

## Manual Android checklist

Use a connected Samsung Android device and AnkiDroid 2.25.3.

1. Fresh install; open **How to use it** from the help icon.
2. Import `assets/samples/sample_practice.json`; confirm two topics, three practices and eight questions.
3. Import `assets/samples/practice_format_example.json`; confirm the preview notes the existing Cloud fundamentals topic and that the Networking basics practice becomes `TCP/IP (2)` because its name exists with different content. Open **Cloud fundamentals → Core services** and confirm its second question uses checkboxes: a partial selection fails and the complete set (`Cloud Run` and `Cloud Functions`) passes. Confirm the `sourceId` values in the file are accepted and ignored by a normal import.
4. Start the sample practice `Compute choices`; answer one question correctly, one wrongly and skip one.
5. Confirm feedback stays on the same screen and every alternative expands. Use the top arrows to move forward and back.
6. Submit a wrong answer; check “I was distracted or read too fast” in the feedback; confirm the new error card disappears. Uncheck it; confirm the card returns. Then check “I didn’t know this”; confirm the card disappears, the answer counts as skipped and the review asks for a concept.
7. Close another session and choose **Save for later**; confirm Home lists each paused session.
8. Finish; confirm the score and looked-up count.
9. Complete the error review: bias, vaccine, concept card and basic card.
10. Open Cards; confirm the Show exported filter chip, select an incomplete error card and confirm export is replaced by Review selected. Complete it and confirm export returns.
11. Complete one error card with **Complete**, then try **Review all** at the top of the error section and **Review selected**.
12. Preview, deselect and delete a card.
13. Set a topic's deck with **Edit topic → AnkiDroid deck** from the live list (or type a new deck), export, and verify cards land in that deck while a blank topic uses the default. Confirm **Edit practice** has no deck row and that decks are topic-level only. Use **Browse decks** in Settings for the default deck.
14. Export to AnkiDroid; verify the deck, Cloze model, six-field `Question Practice: Error v2` model and the `Basic` note type with `Front` and `Back`.
15. Delete `Question Practice: Error v2` in AnkiDroid and export again; confirm it is recreated.
16. Use Define with web mode; confirm the Custom Tab opens and the editable definition sheet still appears.
17. Configure OpenAI or Groq, load models, save the key, and test one definition. Confirm it appears in a read-only bubble and is saved without a Save button. Define an acronym such as SRE and confirm the bubble shows the full form under “Stands for”.
18. In an error card review, write bias and vaccine and use “Check with AI”; confirm feedback appears without leaving the review.
19. Configure Gemini, load models, and test one definition.
20. Seed an old error (or use a clock override in development), confirm it is hidden until 48 hours and resolves after a correct answer.
21. Try selecting text in a prompt, alternative and explanation; confirm Define appears. Confirm an http(s) link opens.
22. On a fresh install, confirm wallpaper colors are on; toggle them off and back on. Check dark mode.
23. Set the font scale to 2.0; confirm no overflow on home, session, review and cards.
24. Erase all data; confirm topics, cards, settings and key are gone.
25. On Home, use the sort icon for name/recency and both directions; restart the app and confirm the order is kept.
26. Long-press a topic and open **Edit topic**; save a change. Long-press it again and choose **Archive topic**; confirm it leaves Home and the archive icon shows a count. Open the archived list, confirm its practices, questions, sessions and cards still exist, then unarchive it and confirm it returns with its data intact. Edit it from the archived list once, and delete an archived throwaway topic to confirm the confirmation dialog.
27. Open two topics, choose a different practice sort in each (for example Name decreasing and Recency increasing), leave and reopen them, then restart the app; confirm each topic keeps its own order.
28. Tap the **Shuffle** floating button; confirm the **Start shuffled practice** sheet lists the options and starts a mixed session. Solve or skip every question, then tap Shuffle again and confirm the no-questions message appears.
29. Long-press a practice and open **Edit practice**; rename it and change its description. Confirm the menu has no per-practice deck and no deck row. Download the practice JSON and inspect it: confirm the topic/practice names, `sourceId` on every question, `subtopic` only where set, `correctIndex` or `correctIndexes`, and no deck field. Change one question, add one, remove one, then update from that file. Confirm the preview counts (new, modified, deleted, unchanged), apply, and verify answers/cards/skipped records for matched questions survive while the removed question's linked records are gone. Confirm the practice name and description are unchanged by the update, and repeat with a file whose topic or practice name does not match to see the rejection message.
30. Export a backup, erase all data, then restore the backup. Confirm active and archived topics, subtopics, done flags, sessions, answers, error history, skipped questions, highlights and settings all return in one step. Confirm the AI API key is still the one already stored on the device, not one from the file. Try an empty or malformed backup and confirm the current data is untouched.
31. Complete sessions that include two different subtopics and at least one Uncategorized question, then open **Statistics → By subtopic**. Confirm each group shows accuracy and progress, Uncategorized contains the ungrouped question, and the section is hidden in a topic where no question has a subtopic. Share the statistics JSON and confirm the per-subtopic figures are present.

## Notes

- Widget tests use `TestHarness` with an in-memory database and an `UncontrolledProviderScope` that is disposed before the test ends. This flushes Drift stream-cancellation timers.
- `pumpAndSettle` is avoided where a page contains a continuous M3E animation; bounded frame pumps are used instead.
- No golden tests: font and engine changes make them noisy. Semantics and layout assertions cover the important UI contracts.
