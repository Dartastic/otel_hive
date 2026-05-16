# Changelog

## [0.1.0-beta.1-wip]

### Added

- Extension methods on `BoxBase`: `tracedPut`, `tracedPutAll`,
  `tracedDelete`, `tracedDeleteAll`, `tracedClear`,
  `tracedCompact`. Each opens a CLIENT span with
  `db.system=hive`, `db.collection.name=<box>`, `db.operation`,
  and (when applicable) `db.hive.key`.
- `tracedHiveCall<R>({operation, boxName, key, invoke})` —
  generic helper for testing and custom call sites.
- Synchronous reads (`get`, `values`, `length`, `containsKey`)
  are NOT wrapped — they're fast, sync, and would generate a lot
  of low-value spans. File an issue if you need read spans.
- Zone-scoped suppression
  (`runWithoutHiveInstrumentation` / async variant).
- 4 tests via the generic helper (span shape with key, span
  shape without key, exception path, suppression scope).
