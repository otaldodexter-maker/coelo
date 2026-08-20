import 'dart:async';

import 'package:coelo_superadmin/features/forms/application/form_autosave_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('debounces edits and preserves the newest draft while an older save completes', () async {
    final firstSave = Completer<String>();
    final saved = <String>[];
    final controller = FormAutosaveController<String>(
      initialValue: 'initial',
      debounce: Duration.zero,
      save: (draft) async {
        saved.add(draft);
        if (draft == 'first') return firstSave.future;
        return draft;
      },
    );

    controller.update('first');
    await Future<void>.delayed(Duration.zero);
    controller.update('second');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    firstSave.complete('first');
    await Future<void>.delayed(Duration.zero);

    expect(saved, ['first', 'second']);
    expect(controller.state.status, FormAutosaveStatus.saved);
    expect(controller.state.draft, 'second');
    await controller.dispose();
  });

  test('surfaces failure without discarding the draft and allows a retry', () async {
    var fail = true;
    final controller = FormAutosaveController<String>(
      initialValue: 'draft',
      save: (draft) async {
        if (fail) throw StateError('offline');
        return draft;
      },
    );

    await controller.flush();
    expect(controller.state.status, FormAutosaveStatus.failure);
    expect(controller.state.draft, 'draft');

    fail = false;
    await controller.flush();
    expect(controller.state.status, FormAutosaveStatus.saved);
    await controller.dispose();
  });
}
