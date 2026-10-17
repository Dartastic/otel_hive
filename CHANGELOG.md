# Changelog

## [0.3.1] - 2026-10-17

### Changed

- README: standard header naming the instrumented library, its supported platforms and project links; pubspec description to match.

## [0.3.0] - 2026-10-11

### Changed

- Requires `dartastic_opentelemetry_api >=1.0.0-rc.4 <1.0.0-rc.5`.
- **Breaking:** depends on `dartastic_opentelemetry_api` only, no
  longer on the SDK. The application chooses and initializes the
  OpenTelemetry SDK. Parameters and fields typed with SDK classes
  now use the API types (`APITracer`, `APISpan`, `APILogger`, ...);
  SDK instances are still accepted wherever an API type is expected.

## [0.2.0] - 2026-08-10

### Changed

- Semantic conventions updated to the current OTel registry: deprecated
  attribute keys are no longer emitted (`db.system` -> `db.system.name`,
  `db.operation` -> `db.operation.name`, `rpc.system` -> `rpc.system.name`,
  with `rpc.service` folded into a fully-qualified `rpc.method`).
- Dependency floors raised to `dartastic_opentelemetry ^1.1.0-beta.12` and
  `dartastic_opentelemetry_api ^1.0.0-rc.1`. The previous floors declared
  compatibility with API versions that predate the semconv enums this
  package uses and could not actually resolve-and-compile.
- `repository` URL corrected to the canonical `Dartastic` org casing so
  pub.dev repository verification succeeds.

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
  shape without key, exception path, suppression scope), plus
  real-box tests exercising the `Box` extension end to end.
- `tracedPutAll` records `db.operation.batch.size` (available on
  `tracedHiveCall` via the optional `batchSize` parameter).

### Fixed

- `OTelHiveBox` is now generic over the box element type
  (`BoxBase<E>`). It was declared on `BoxBase<dynamic>` with
  `dynamic`/`Map<dynamic, dynamic>` parameters, which threw a runtime
  type error on any typed box (e.g. `Box<String>.tracedPutAll`).
- `example/otel_hive_example.dart`.
