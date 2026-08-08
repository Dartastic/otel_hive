// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'dart:async';

const Symbol _suppressKey = #otel_hive_suppress;

/// Whether hive instrumentation is suppressed in the current [Zone].
///
/// True inside [runWithoutHiveInstrumentation] /
/// [runWithoutHiveInstrumentationAsync] scopes; `tracedHiveCall` (and
/// every `traced*` extension method built on it) emits no spans there.
bool hiveInstrumentationSuppressed() {
  return Zone.current[_suppressKey] == true;
}

/// Runs [body] with hive instrumentation suppressed: no `traced*` call
/// inside the scope emits a span. Useful for noisy hot paths.
T runWithoutHiveInstrumentation<T>(T Function() body) {
  return runZoned(body, zoneValues: {_suppressKey: true});
}

/// Async variant of [runWithoutHiveInstrumentation]: the suppression
/// scope covers the whole returned future, including awaited callbacks.
Future<T> runWithoutHiveInstrumentationAsync<T>(
  Future<T> Function() body,
) {
  return runZoned(body, zoneValues: {_suppressKey: true});
}
