import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Which of the calls Estruturas makes have a function to land on.
///
/// OQ-032 records that the remote materialised a set of unit RPCs that the
/// canonical HEAD never reproduced. Until now that was prose, and I repeated a
/// number from it - "seven" - without measuring. It is five, and this test is
/// what measures it.
///
/// The test reads every `rpc('name')` in the seven Estruturas features and every
/// `create function` in the migrations, and compares the two sets. It cannot say
/// what the deployed database contains; it says what this repository can
/// account for, which is the thing that silently rots.
///
/// When a migration lands for one of the five, this test goes red and the list
/// below loses a line. That is the point: closing OQ-032 should be something
/// somebody writes down, not something that quietly stops being true.
const _families = [
  'institutions',
  'units',
  'groups',
  'people',
  'children',
  'student_tracking',
  'locations',
];

/// Called by Estruturas, defined nowhere in `packages/coelo_database`.
///
/// All five are Unidades, and Turmas reaches two of them for its own filter
/// context - which is why the group directory is blocked by a unit gap.
/// `20260825180500:55` goes further and `perform`s the first one from inside a
/// migration that does not define it either.
const _knownAbsent = {
  'create_unit_for_superadmin',
  'get_unit_form_for_superadmin',
  'list_units_for_superadmin',
  'unit_directory_filter_options',
  'update_unit_for_superadmin',
};

/// A generic argument can nest, so the name is found by scanning past the
/// opening parenthesis rather than by matching the type.
final _call = RegExp(r"rpc[^(]{0,60}\(\s*'([a-z0-9_]+)'", dotAll: true);
final _definition = RegExp(
  r'create (?:or replace )?function\s+(?:public|app_private)\.([a-z0-9_]+)\s*\(',
);

Set<String> _matches(Directory root, RegExp pattern, String extension) {
  if (!root.existsSync()) {
    throw StateError('${root.path} is not where this test expects it');
  }
  final names = <String>{};
  for (final entity in root.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith(extension)) continue;
    for (final match in pattern.allMatches(entity.readAsStringSync())) {
      names.add(match.group(1)!);
    }
  }
  return names;
}

void main() {
  final called = <String>{};
  for (final family in _families) {
    called.addAll(_matches(Directory('lib/features/$family'), _call, '.dart'));
  }
  final defined = _matches(
    Directory('../../packages/coelo_database/migrations'),
    _definition,
    '.sql',
  );

  test('the measurement is not empty, or it proves nothing', () {
    // A regex that stopped matching would make every assertion below pass.
    expect(called.length, greaterThan(20));
    expect(defined.length, greaterThan(100));
  });

  test('exactly five calls have no function behind them', () {
    final absent = called.difference(defined);
    expect(
      absent,
      equals(_knownAbsent),
      reason: absent.length > _knownAbsent.length
          ? 'a new call was added with no migration behind it: '
                '${absent.difference(_knownAbsent).join(', ')}'
          : 'a migration landed, or a call was removed; update the list and say '
                'so in the handoff: ${_knownAbsent.difference(absent).join(', ')}',
    );
  });

  test('every family except Unidades can account for its calls', () {
    // Turmas is the exception that is not an exception: the two names it misses
    // are unit names, reached for filter context.
    for (final family in ['institutions', 'people', 'children', 'student_tracking', 'locations']) {
      final familyCalls = _matches(Directory('lib/features/$family'), _call, '.dart');
      expect(
        familyCalls.difference(defined),
        isEmpty,
        reason: '$family now calls something the repository cannot account for',
      );
    }
  });

  test('the Locais writes that are queued but unapplied are still declared', () {
    // My three unapplied packages are candidates, not deployments. They belong
    // to the defined set because the migration text exists; what is missing is a
    // replay window, which is C00's to open.
    expect(
      defined,
      containsAll(<String>[
        'superadmin_location_update_v2',
        'superadmin_location_set_status_v2',
        'superadmin_location_copy_v2',
        'superadmin_location_schedule_v2',
        'superadmin_location_schedule_set_v2',
      ]),
    );
  });
}
