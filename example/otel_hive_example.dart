// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:hive/hive.dart';
import 'package:otel_hive/otel_hive.dart';

Future<void> main() async {
  await OTel.initialize(serviceName: 'otel-hive-example');

  final dir = await Directory.systemTemp.createTemp('otel_hive_example');
  Hive.init(dir.path);
  final box = await Hive.openBox<String>('users');

  // Extension methods on Box: each call opens a CLIENT span named
  // `hive <op> <box>[/<key>]` with `db.system.name=hive`,
  // `db.operation.name`, `db.collection.name`, and `db.hive.key`.
  await box.tracedPut('alice', 'Alice');

  // Batch writes also record `db.operation.batch.size`.
  await box.tracedPutAll({'bob': 'Bob', 'carol': 'Carol'});

  // Reads are synchronous in hive 2.x and intentionally not wrapped.
  assert(box.get('alice') == 'Alice');

  await box.tracedDelete('bob');
  await box.tracedClear();

  // Generic helper for custom call sites (or other key-value stores).
  await tracedHiveCall<void>(
    operation: 'put',
    boxName: 'users',
    key: 'dave',
    invoke: () => box.put('dave', 'Dave'),
  );

  // Suppress instrumentation for a scope (e.g. noisy polling).
  await runWithoutHiveInstrumentationAsync(() async {
    await box.tracedPut('eve', 'Eve'); // Emits no span.
  });

  await Hive.close();
  await dir.delete(recursive: true);
  await OTel.shutdown();
}
