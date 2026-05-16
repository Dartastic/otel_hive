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
- `db.system = hive`, `db.system.name = hive`
- `db.collection.name = users`, `db.operation = put`
- `db.hive.key = alice` (omitted on operations without a key)

Synchronous reads (`get`, `values`, `length`, `containsKey`) are
**not** wrapped — wrapping every sync read would generate a flood
of spans for minimal observability value.

Suppression: `runWithoutHiveInstrumentationAsync`.

## License

Apache 2.0
