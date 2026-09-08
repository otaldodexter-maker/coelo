import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Fence around the deferred import and export of Instituições and Turmas.
///
/// The Owner deferred these operations to after the MVP: the buttons stay
/// visible and say they are unavailable, and nothing behind them opens a file,
/// parses one, starts a job or calls an RPC. Reading the source keeps that
/// promise about what production composes, which a widget test cannot state as
/// directly.
///
/// The counterpart for Unidades lives beside the units suite, next to the
/// orphan implementation it fences.
void main() {
  const surfaces = <String, ({List<String> keys, String handler})>{
    'lib/features/institutions/presentation/widgets/institution_file_actions.dart': (
      keys: [
        'institution-files-import',
        'institution-files-export-csv',
        'institution-files-export-xlsx',
      ],
      handler: '_showUnavailable',
    ),
    'lib/features/groups/presentation/group_directory_page.dart': (
      keys: ['group-files-import', 'group-files-export-csv', 'group-files-export-xlsx'],
      handler: '_showUnavailable',
    ),
  };

  for (final entry in surfaces.entries) {
    test('${entry.key} keeps its deferred actions visible and inert', () {
      final source = File(entry.key).readAsStringSync();
      for (final key in entry.value.keys) {
        expect(source.contains(key), isTrue, reason: 'the button for $key must stay visible');
      }
      expect(
        source.contains(entry.value.handler),
        isTrue,
        reason: 'the buttons must route to the unavailability notice',
      );
      for (final forbidden in const ['FilePicker', 'openDownloadUrl', 'generateExport']) {
        expect(
          source.contains(forbidden),
          isFalse,
          reason: '$forbidden would make a deferred operation real',
        );
      }
    });
  }
}
