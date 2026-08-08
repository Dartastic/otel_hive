// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:hive/hive.dart';
import 'package:otel_hive/otel_hive.dart';
import 'package:test/test.dart';

class _MemorySpanExporter implements SpanExporter {
  final List<Span> spans = [];
  bool _shutdown = false;

  @override
  Future<void> export(List<Span> s) async {
    if (_shutdown) return;
    spans.addAll(s);
  }

  @override
  Future<void> forceFlush() async {}

  @override
  Future<void> shutdown() async {
    _shutdown = true;
  }
}

Map<String, Object> _attrs(Span span) =>
    {for (final a in span.attributes.toList()) a.key: a.value};

void main() {
  late _MemorySpanExporter exporter;

  setUp(() async {
    await OTel.reset();
    exporter = _MemorySpanExporter();
    await OTel.initialize(
      serviceName: 'hive-otel-test',
      detectPlatformResources: false,
      spanProcessor: SimpleSpanProcessor(exporter),
    );
  });

  tearDown(() async {
    await OTel.shutdown();
    await OTel.reset();
  });

  group('tracedHiveCall', () {
    test('emits CLIENT span with db.* attrs + key', () async {
      await tracedHiveCall<void>(
        operation: 'put',
        boxName: 'users',
        key: 'alice',
        invoke: () async {},
      );

      final span = exporter.spans.single;
      expect(span.kind, equals(SpanKind.client));
      expect(span.name, equals('hive put users/alice'));
      final attrs = _attrs(span);
      expect(attrs['db.system.name'], equals('hive'));
      expect(attrs['db.operation.name'], equals('put'));
      expect(attrs['db.collection.name'], equals('users'));
      expect(attrs['db.hive.key'], equals('alice'));
    });

    test('batchSize records db.operation.batch.size', () async {
      await tracedHiveCall<void>(
        operation: 'putAll',
        boxName: 'users',
        batchSize: 3,
        invoke: () async {},
      );
      final span = exporter.spans.single;
      expect(span.name, equals('hive putAll users'));
      expect(_attrs(span)['db.operation.batch.size'], equals(3));
    });

    test('operation without key (clear) omits db.hive.key', () async {
      await tracedHiveCall<int>(
        operation: 'clear',
        boxName: 'users',
        invoke: () async => 0,
      );
      final span = exporter.spans.single;
      expect(span.name, equals('hive clear users'));
      expect(_attrs(span).containsKey('db.hive.key'), isFalse);
    });

    test('exception flips span to Error', () async {
      await expectLater(
        tracedHiveCall<void>(
          operation: 'put',
          boxName: 'b',
          invoke: () async => throw StateError('locked'),
        ),
        throwsStateError,
      );
      final span = exporter.spans.single;
      expect(span.status, equals(SpanStatusCode.Error));
      expect(_attrs(span)['error.type'], equals('StateError'));
    });

    test('runWithoutHiveInstrumentationAsync bypasses spans', () async {
      await runWithoutHiveInstrumentationAsync(() async {
        await tracedHiveCall<void>(
          operation: 'put',
          boxName: 'b',
          invoke: () async {},
        );
      });
      expect(exporter.spans, isEmpty);
    });
  });

  group('OTelHiveBox extension (real box)', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('otel_hive_test');
      Hive.init(dir.path);
    });

    tearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });

    test('tracedPut/tracedPutAll wrap real writes and emit spans', () async {
      final box = await Hive.openBox<String>('people');

      await box.tracedPut('alice', 'Alice');
      await box.tracedPutAll({'bob': 'Bob', 'carol': 'Carol'});

      // The writes really happened.
      expect(box.get('alice'), equals('Alice'));
      expect(box.length, equals(3));

      // And each emitted a span with current semconv keys.
      expect(exporter.spans, hasLength(2));
      final put = exporter.spans.first;
      expect(put.name, equals('hive put people/alice'));
      expect(put.kind, equals(SpanKind.client));
      final putAll = exporter.spans.last;
      expect(putAll.name, equals('hive putAll people'));
      final attrs = _attrs(putAll);
      expect(attrs['db.system.name'], equals('hive'));
      expect(attrs['db.operation.name'], equals('putAll'));
      expect(attrs['db.collection.name'], equals('people'));
      expect(attrs['db.operation.batch.size'], equals(2));
    });

    test('tracedDelete and tracedClear wrap real mutations', () async {
      final box = await Hive.openBox<String>('people');
      await box.put('alice', 'Alice');
      await box.put('bob', 'Bob');

      await box.tracedDelete('alice');
      expect(box.containsKey('alice'), isFalse);

      final cleared = await box.tracedClear();
      expect(cleared, equals(1));
      expect(box.isEmpty, isTrue);

      expect(
        exporter.spans.map((s) => s.name),
        equals(['hive delete people/alice', 'hive clear people']),
      );
    });
  });
}
