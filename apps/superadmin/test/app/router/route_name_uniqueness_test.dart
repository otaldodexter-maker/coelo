import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards route-name uniqueness in `superadmin_router.dart`.
///
/// go_router asserts on duplicate names while BUILDING the router, so a single
/// repeated `name:` does not break one screen -- `createSuperadminRouter`
/// throws and the whole Superadmin app fails to start. That is what happened
/// when the same Principal chat GoRoute was applied twice during integration:
/// two byte-identical blocks, and every test that builds a router died with an
/// assertion pointing at go_router's internals instead of at the cause.
///
/// This check reads the source rather than building a router, on purpose. It
/// needs no repositories, runs in milliseconds, and -- the point -- names the
/// offending route instead of leaving the next reader to decode a stack trace.
/// It guards against double-applied hunks, which no front can see while
/// testing its own branch alone.
void main() {
  test('no route name is declared twice in the Superadmin router', () {
    final source = File('lib/app/router/superadmin_router.dart').readAsStringSync();
    final counts = <String, int>{};
    for (final match in RegExp(r'name:\s*SuperadminRoutes\.(\w+)').allMatches(source)) {
      final name = match.group(1)!;
      counts[name] = (counts[name] ?? 0) + 1;
    }

    expect(counts, isNotEmpty, reason: 'the router must declare named routes');

    final duplicated = counts.entries.where((entry) => entry.value > 1).toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    expect(
      duplicated.map((entry) => '${entry.key} x${entry.value}').toList(),
      isEmpty,
      reason:
          'Each of these route names is declared more than once in '
          'superadmin_router.dart. go_router asserts on duplicate names while '
          'building, so createSuperadminRouter throws and the app does not '
          'start at all. The usual cause is the same GoRoute block applied '
          'twice during integration: delete the repeated block, keeping one.',
    );
  });
}
