import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Which of the calls Estruturas makes have a function to land on.
///
/// OQ-032 records that the remote materialised a set of unit RPCs that the
/// canonical HEAD never reproduced. That was prose, and I repeated a number
/// from it - "seven" - without measuring. My first measurement said five and
/// was also wrong: it only knew one call shape, and the unit gateway names its
/// functions through a `_request(...)` helper that the pattern walked straight
/// past. The answer is fifteen.
///
/// Hence the completeness test below, which is the one that matters. A file
/// that reaches for `.rpc` and yields no name means the reader has gone blind
/// again, and a blind reader makes every other assertion here pass.
///
/// It cannot say what the deployed database contains. It says what this
/// repository can account for, which is the thing that rots quietly.
///
/// When a migration lands for one of the fifteen, this test goes red and the
/// list loses a line. That is deliberate: closing OQ-032 should be something
/// somebody writes down, not something that stops being true on its own.
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
/// Every one of them is Unidades. Turmas reaches two - `list_units_for_superadmin`
/// and `unit_directory_filter_options` - to build its own filter context, which
/// is why the group directory is blocked by a unit gap rather than a group one.
///
/// `20260825180500:55` goes further and `perform`s `create_unit_for_superadmin`
/// from inside a migration that does not define it either.
const _knownAbsent = {
  'change_unit_handle_for_superadmin',
  'create_unit_for_superadmin',
  'get_unit_form_for_superadmin',
  'list_units_for_superadmin',
  'preview_unit_institution_transfer_for_superadmin',
  'request_unit_type_for_superadmin',
  'superadmin_confirm_unit_identity_delete',
  'superadmin_finalize_unit_identity_upload',
  'superadmin_prepare_unit_identity_upload',
  'superadmin_request_unit_identity_delete',
  'superadmin_unit_identity_download_descriptor',
  'superadmin_unit_import_template',
  'transfer_unit_institution_for_superadmin',
  'unit_directory_filter_options',
  'update_unit_for_superadmin',
};

/// The three shapes a call takes here: `rpc('name')` on the client, and the two
/// helpers that wrap it, `_rpc('name')` and `_request('name')`. A generic
/// argument can nest, so the name is found by scanning past the parenthesis.
final _call = RegExp(
  r"(?:rpc|_rpc|_request)(?:<[^;{}]*?>)?\(\s*'([a-z][a-z0-9_]{6,})'",
  dotAll: true,
);
final _definition = RegExp(
  r'create (?:or replace )?function\s+(?:public|app_private)\.([a-z0-9_]+)\s*\(',
);

Iterable<File> _sources(String path, String extension) {
  final root = Directory(path);
  if (!root.existsSync()) {
    throw StateError('$path is not where this test expects it');
  }
  return root
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith(extension));
}

Set<String> _names(String path, RegExp pattern, String extension) => {
  for (final file in _sources(path, extension))
    for (final match in pattern.allMatches(file.readAsStringSync())) match.group(1)!,
};

void main() {
  final called = <String>{};
  for (final family in _families) {
    called.addAll(_names('lib/features/$family', _call, '.dart'));
  }
  final defined = _names('../../packages/coelo_database/migrations', _definition, '.sql');

  test('no file reaches for rpc without the reader seeing a name', () {
    // The test that would have caught the five. A helper the pattern does not
    // know hides its names, and hidden names cannot be missing from anything.
    final blind = <String>[];
    for (final family in _families) {
      for (final file in _sources('lib/features/$family', '.dart')) {
        final source = file.readAsStringSync();
        if (source.contains('.rpc') && !_call.hasMatch(source)) {
          blind.add(file.path);
        }
      }
    }
    expect(
      blind,
      isEmpty,
      reason: 'a new call shape is invisible to this measurement; teach the '
          'pattern before trusting the counts below',
    );
  });

  test('the measurement is not empty, or it proves nothing', () {
    expect(called.length, greaterThan(30));
    expect(defined.length, greaterThan(100));
  });

  test('fifteen calls have no function behind them, and all of them are Unidades', () {
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
      expect(
        _names('lib/features/$family', _call, '.dart').difference(defined),
        isEmpty,
        reason: '$family now calls something the repository cannot account for',
      );
    }
    expect(
      _names('lib/features/groups', _call, '.dart').difference(defined),
      equals({'list_units_for_superadmin', 'unit_directory_filter_options'}),
    );
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
