import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const productionFakePath =
      'features/people/data/'
      'fake_person_directory_repository.dart';

  test('RED: People production graph contains no fake or demonstrative fallback', () {
    final fakeRepository = File('lib/$productionFakePath');
    final router = File('lib/app/router/superadmin_router.dart').readAsStringSync();
    final form = File('lib/features/people/presentation/person_form_page.dart').readAsStringSync();
    final fileActions = File(
      'lib/features/people/presentation/person_file_actions.dart',
    ).readAsStringSync();

    expect(
      fakeRepository.existsSync(),
      isFalse,
      reason: 'Fixtures belong under test/support only.',
    );
    expect(router, isNot(contains('fake_person_directory_repository.dart')));
    expect(router, isNot(contains('FakePersonDirectoryRepository')));
    expect(form, isNot(contains('_Demo')));
    expect(form.toLowerCase(), isNot(contains('demonstrativ')));
    expect(form.toLowerCase(), isNot(contains('não será persistido')));
    expect(fileActions.toLowerCase(), isNot(contains('demonstrativ')));
    expect(fileActions, isNot(contains('people-demo-file-picker')));
  });

  test('RED: no invented person is compiled into the People form', () {
    // The guard above scans for _Demo, "demonstrativ" and "não será persistido".
    // None of those words appeared in the four invented people that shipped
    // inside this form - Ana Souza, Caio Lima, Lia Coelo, Noah Coelo, each with
    // a masked-looking document, e-mail and phone - so it passed green while
    // they were a few lines away. Selecting one reached no view model and no
    // RPC, which meant a silent loss for whoever tried to link somebody.
    //
    // A fixture does not have to call itself a fixture. This names the shape
    // instead of the label.
    final form = File('lib/features/people/presentation/person_form_page.dart').readAsStringSync();
    for (final forbidden in const [
      '_LinkCandidate',
      '_adultLinkCandidates',
      '_childLinkCandidates',
      'searchableData',
      'Ana Souza',
      'Caio Lima',
      'Lia Coelo',
      'Noah Coelo',
      '@ana.coelo',
      'Turma Girassol',
    ]) {
      expect(form, isNot(contains(forbidden)), reason: forbidden);
    }
    // A masked document is still a document-shaped string in the source.
    expect(
      RegExp(r'\*{3}\.\d{3}\.\*{3}-\*{2}').hasMatch(form),
      isFalse,
      reason: 'a masked CPF pattern must not be written into the form',
    );
  });

  test('RED: People tests do not import the production fake repository', () {
    final peopleTests = Directory(
      'test/features/people',
    ).listSync(recursive: true).whereType<File>().where((file) => file.path.endsWith('_test.dart'));
    final routerTest = File('test/app/router/people_routes_test.dart');
    final offenders = <String>[
      for (final file in [...peopleTests, routerTest])
        if (file.readAsStringSync().contains(productionFakePath)) file.path,
    ];

    expect(offenders, isEmpty, reason: 'Use test/support/people fixtures instead: $offenders');
  });
}
