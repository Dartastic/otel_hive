// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:hive/hive.dart';

import 'hive_suppression.dart';

const _tracerName = 'otel_hive';
const _dbSystem = 'hive';

/// The semconv registry has no attribute for a key-value store key, so
/// this package uses a neutral, package-namespaced key for it.
const _dbHiveKey = 'db.hive.key';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

Attributes _attrs({
  required String operation,
  required String boxName,
  Object? key,
  int? batchSize,
}) =>
    OTel.attributesFromMap(<String, Object>{
      Db.dbSystemName.key: _dbSystem,
      Db.dbOperationName.key: operation,
      Db.dbCollectionName.key: boxName,
      if (key != null) _dbHiveKey: key.toString(),
      if (batchSize != null) Db.dbOperationBatchSize.key: batchSize,
    });

/// Generic helper. Opens a `CLIENT` span named
/// `hive <op> <box>[/<key>]` carrying `db.system.name=hive`,
/// `db.collection.name=<box>`, `db.hive.key=<key>` (when supplied),
/// and `db.operation.batch.size=<batchSize>` (when supplied).
/// Runs [invoke] and ends the span on completion.
Future<R> tracedHiveCall<R>({
  required String operation,
  required String boxName,
  Object? key,
  int? batchSize,
  required Future<R> Function() invoke,
}) async {
  if (hiveInstrumentationSuppressed()) return invoke();
  final span = _tracer().startSpan(
    key == null ? 'hive $operation $boxName' : 'hive $operation $boxName/$key',
    kind: SpanKind.client,
    attributes: _attrs(
      operation: operation,
      boxName: boxName,
      key: key,
      batchSize: batchSize,
    ),
  );
  try {
    return await invoke();
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorAttributes.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}

/// Traced operations on a [BoxBase].
///
/// Read operations (`get`, `values`, `length`, `containsKey`) are
/// synchronous in hive 2.x and are *not* wrapped here — wrapping
/// every read would generate an excessive number of spans for
/// minimal benefit. The async write/delete path is wrapped.
extension OTelHiveBox<E> on BoxBase<E> {
  /// Traced `put`.
  Future<void> tracedPut(dynamic key, E value) {
    return tracedHiveCall<void>(
      operation: 'put',
      boxName: name,
      key: key,
      invoke: () => put(key, value),
    );
  }

  /// Traced `putAll`. Records the size as `db.operation.batch.size`.
  Future<void> tracedPutAll(Map<dynamic, E> entries) {
    return tracedHiveCall<void>(
      operation: 'putAll',
      boxName: name,
      batchSize: entries.length,
      invoke: () => putAll(entries),
    );
  }

  /// Traced `delete`.
  Future<void> tracedDelete(dynamic key) {
    return tracedHiveCall<void>(
      operation: 'delete',
      boxName: name,
      key: key,
      invoke: () => delete(key),
    );
  }

  /// Traced `deleteAll`.
  Future<void> tracedDeleteAll(Iterable<dynamic> keys) {
    return tracedHiveCall<void>(
      operation: 'deleteAll',
      boxName: name,
      invoke: () => deleteAll(keys),
    );
  }

  /// Traced `clear`.
  Future<int> tracedClear() {
    return tracedHiveCall<int>(
      operation: 'clear',
      boxName: name,
      invoke: clear,
    );
  }

  /// Traced `compact`.
  Future<void> tracedCompact() {
    return tracedHiveCall<void>(
      operation: 'compact',
      boxName: name,
      invoke: compact,
    );
  }
}
