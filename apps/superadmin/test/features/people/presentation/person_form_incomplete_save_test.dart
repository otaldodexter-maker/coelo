import 'package:coelo_superadmin/features/people/domain/person_directory.dart';
import 'package:coelo_superadmin/features/people/presentation/person_form_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/people/fake_person_directory_repository.dart';

/// Saving an incomplete identity used to produce nothing at all.
///
/// The view model refused with `ArgumentError`, which is an `Error`; the screen
/// caught `on Exception`. So the refusal fell through every catch: no snackbar,
/// no error state, and an unhandled async failure. The operator pressed save and
/// the screen simply did not react - which reads as a frozen product, and is the
/// same shape as the silent hang fixed in the tracking view model tonight.
///
/// An empty field is an ordinary thing for a person to do. It gets an Exception.
///
/// Reported by C07 through C06, with the honest caveat that the step navigation
/// validates before advancing, so the reachable path is clearing a field after
/// advancing and then saving. That is precisely what these tests do.
void main() {
  PersonFormViewModel model() => PersonFormViewModel(FakePersonDirectoryRepository());

  void fill(PersonFormViewModel viewModel) {
    viewModel
      ..firstName = 'Ana'
      ..lastName = 'Lima'
      ..displayName = 'Ana Lima'
      ..legalName = 'Ana Lima';
  }

  test('a complete identity saves', () async {
    final viewModel = model();
    addTearDown(viewModel.dispose);
    fill(viewModel);
    await expectLater(viewModel.save(), completes);
  });

  test('legal name is optional under spec019', () async {
    final viewModel = model();
    addTearDown(viewModel.dispose);
    fill(viewModel);
    viewModel.legalName = '';
    await expectLater(viewModel.save(), completes);
  });

  for (final field in const ['first', 'last', 'display']) {
    test('clearing the $field name after filling it refuses with an Exception', () async {
      // The reachable path: the form was complete enough to advance, and the
      // field was emptied afterwards.
      final viewModel = model();
      addTearDown(viewModel.dispose);
      fill(viewModel);
      switch (field) {
        case 'first':
          viewModel.firstName = '   ';
        case 'last':
          viewModel.lastName = '';
        case 'display':
          viewModel.displayName = '  ';
      }

      await expectLater(
        viewModel.save(),
        throwsA(isA<PersonFormIncompleteException>()),
        reason: 'an Error here is invisible to every `on Exception` above it',
      );
    });
  }

  test('the refusal is an Exception, so an `on Exception` catch sees it', () async {
    final viewModel = model();
    addTearDown(viewModel.dispose);
    viewModel.firstName = 'Ana';

    var caught = false;
    try {
      await viewModel.save();
    } on Exception {
      caught = true;
    }
    expect(
      caught,
      isTrue,
      reason: 'this is the exact catch the screen uses; an Error would slip past it',
    );
  });

  test('an incomplete save leaves nothing behind to retry against', () async {
    final viewModel = model();
    addTearDown(viewModel.dispose);
    viewModel.firstName = 'Ana';
    await expectLater(viewModel.save(), throwsA(isA<PersonFormIncompleteException>()));

    // Completing the identity afterwards must still save: the refusal is not a
    // terminal state, it is a "not yet".
    fill(viewModel);
    await expectLater(viewModel.save(), completes);
  });
}
