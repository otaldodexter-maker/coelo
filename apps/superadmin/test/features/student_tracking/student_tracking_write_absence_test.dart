import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Four inventory actions that do not exist, held down at the contract.
///
/// `students.link`, `students.transfer`, `students.edit` and `students.revoke`
/// have no surface. I had recorded that as "there is a test asserting the
/// absence"; there is one, and it asserts that two Portuguese labels are not on
/// screen. That is a fence around two words, not around four actions - a fifth
/// affordance under a different label would walk straight past it.
///
/// The durable half is the interface. `StudentTrackingRepository` declares two
/// reads and nothing else, so there is no method a link, a transfer, an edit or
/// a revocation could travel through. A write appearing here is the moment the
/// inventory changes, and it should be a moment somebody notices.
///
/// The widget-level test stays where it is, in
/// `presentation/student_tracking_page_test.dart`. This one is about the shape
/// underneath it.
const _contract = 'lib/features/student_tracking/domain/student_tracking.dart';

void main() {
  final source = File(_contract).readAsStringSync();
  final start = source.indexOf('abstract interface class StudentTrackingRepository {');
  final body = start == -1 ? '' : source.substring(start, source.indexOf('\n}', start));

  test('the repository was found, or the rest of this proves nothing', () {
    expect(start, isNot(-1), reason: 'the contract moved; point this test at it');
    expect(body, contains('fetchChildren'));
  });

  test('it declares two reads and no writes at all', () {
    final methods = RegExp(
      r'Future<[^>]*>\s+([a-zA-Z]+)\(',
    ).allMatches(body).map((match) => match.group(1)!).toSet();
    expect(
      methods,
      equals({'fetchChildren', 'fetchSnapshot'}),
      reason: 'a method arrived on the student tracking contract; if it writes, '
          'students.link / .transfer / .edit / .revoke are no longer absent and '
          'the inventory has to say so',
    );
  });

  test('none of the four verbs appears anywhere in the contract', () {
    // Names first, in case a write ever arrives shaped like a read.
    for (final verb in ['link', 'transfer', 'revoke', 'unlink', 'assign', 'update', 'save']) {
      expect(
        RegExp('Future<[^>]*>\\s+[a-zA-Z]*$verb[a-zA-Z]*\\(', caseSensitive: false).hasMatch(body),
        isFalse,
        reason: 'the contract now offers something shaped like $verb',
      );
    }
  });
}
