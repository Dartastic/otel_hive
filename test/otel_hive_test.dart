// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
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
  group('tracedHiveCall', () {
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
      expect(attrs['db.system'], equals('hive'));
      expect(attrs['db.operation'], equals('put'));
      expect(attrs['db.collection.name'], equals('users'));
      expect(attrs['db.hive.key'], equals('alice'));
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
}
