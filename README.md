# otel_hive

OpenTelemetry instrumentation for
[`package:hive`](https://pub.dev/packages/hive).

```dart
final box = await Hive.openBox<dynamic>('users');

await box.tracedPut('alice', {'name': 'Alice'});
await box.tracedDelete('bob');
await box.tracedPutAll({'k1': 'v1', 'k2': 'v2'});
await box.tracedClear();
```

Each call emits a CLIENT span:
- name: `hive put users/alice`
- `db.system.name = hive`
- `db.collection.name = users`, `db.operation.name = put`
- `db.hive.key = alice` (omitted on operations without a key)
- `db.operation.batch.size` on `tracedPutAll`

Synchronous reads (`get`, `values`, `length`, `containsKey`) are
**not** wrapped — wrapping every sync read would generate a flood
of spans for minimal observability value.

Using `hive_ce`? The `Box` extension targets `package:hive`, but the
generic `tracedHiveCall` helper wraps any call site.

Suppression: `runWithoutHiveInstrumentationAsync`.

## License

Apache 2.0
