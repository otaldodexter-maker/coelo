import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Fence around the deferred import and export debt of Unidades.
///
/// `unit_file_actions.dart` still contains a real implementation: a file
/// picker, a signed download and a demo export that reports success. The Owner
/// deferred those operations, and the production toolbar shows an honest
/// unavailability instead. The file is preserved for after the MVP, so the risk
/// is not that it exists but that someone wires it back by accident.
///
/// This test is the fence. It reads the source tree rather than the widget
/// tree, because the guarantee is about what production composes, not about
/// what a screen renders.
void main() {
  test('no production file composes the deferred unit file actions', () {
    final offenders = <String>[];
    final lib = Directory('lib');
    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      // The declaration itself lives in the debt file; everything else is a use.
      if (path.endsWith('features/units/presentation/widgets/unit_file_actions.dart')) continue;
      if (entity.readAsStringSync().contains('UnitFileActions(')) offenders.add(path);
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'The deferred unit import and export must stay without a consumer. '
          'Reactivating it needs an explicit Owner decision, not an import.',
    );
  });

  test('the deferred toolbar keeps showing an honest unavailability', () {
    final toolbar = File(
      'lib/features/units/presentation/widgets/unit_directory_toolbar.dart',
    ).readAsStringSync();
    for (final key in const [
      'unit-files-import',
      'unit-files-export-csv',
      'unit-files-export-xlsx',
    ]) {
      expect(toolbar.contains(key), isTrue, reason: 'the button for $key must stay visible');
    }
    expect(
      toolbar.contains('_showDeferredFileNotice'),
      isTrue,
      reason: 'the buttons must route to the unavailability notice',
    );
    expect(
      toolbar.contains('FilePicker'),
      isFalse,
      reason: 'the visible toolbar must not open a file picker while the operation is deferred',
    );
  });
}
