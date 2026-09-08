import 'dart:io';

import 'package:coelo_superadmin/features/institutions/data/institution_location_service.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_item.dart';
import 'package:coelo_superadmin/features/institutions/presentation/view_models/institution_form_controller.dart';
import 'package:coelo_superadmin/features/institutions/presentation/widgets/institution_form_sections.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The status control that is shown and cannot act, fenced on both sides.
///
/// `institutions.status` has no path to production and that is on purpose: the
/// transitions have never been defined. The screen keeps the control visible
/// and disabled, with a sentence saying why, which is the honest shape - the
/// operator sees that the concept exists rather than wondering where it went.
///
/// It had no test. Someone flipping `enabled: false` to true would not get a
/// working control and would not get an error either: `status` is not a key
/// `superadmin_institution_edit_core_v2` accepts, and the client never puts it
/// in the payload, so the choice would be collected and dropped in silence -
/// the same shape as the location picker that used to stand in the group form.
///
/// So this test holds the two halves together: the control is disabled and
/// explains itself, and the server-side allow-list has no room for it.
const _migration =
    '../../packages/coelo_database/migrations/'
    '20260828000500_superadmin_internal_institution_edit_core.sql';

Widget _host(Widget child) => MaterialApp(
  theme: CoeloTheme.light,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

Widget _profileStep(InstitutionFormController controller) => InstitutionFormSection(
  controller: controller,
  locationService: InstitutionLocationService(),
  imagePicker: () async => null,
);

void main() {
  testWidgets('the status control is visible, refuses to act, and says why', (tester) async {
    final controller = InstitutionFormController();
    addTearDown(controller.dispose);
    // The wizard opens on branding; the status control lives on the profile
    // step, so the test goes there rather than pretending it is the first.
    controller.currentStep = InstitutionFormStep.profile;

    await tester.pumpWidget(_host(_profileStep(controller)));

    final field = find.byKey(const Key('institution-operational-status'));
    expect(field, findsOneWidget);
    final widget = tester.widget<CoeloAdminSingleSelectField<InstitutionStatus>>(field);
    expect(widget.enabled, isFalse);

    // The behaviour, not just the flag: tapping opens nothing and changes
    // nothing.
    final before = controller.status;
    await tester.tap(field, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(controller.status, before);

    final notice = find.byKey(const Key('institution-status-actions-unavailable'));
    expect(notice, findsOneWidget);
    expect(
      tester.widget<Text>(notice).data,
      'Alteração de status indisponível até a definição das transições permitidas.',
      reason: 'the sentence is the whole affordance; it has to keep saying why',
    );
  });

  test('the server has no key for it either, so enabling the control would lie', () {
    // Read from the migration rather than restated, so widening the allow-list
    // is what makes this fail.
    final sql = File(_migration).readAsStringSync();
    final guard = RegExp(r'where not\(payload_key=any\(array\[([^\]]*)\]').firstMatch(sql);
    if (guard == null) {
      throw StateError('the payload allow-list guard is gone');
    }
    final allowed = RegExp("'([a-z_]+)'")
        .allMatches(guard.group(1)!)
        .map((match) => match.group(1)!)
        .toSet();

    expect(allowed, isNot(contains('status')));
    expect(
      allowed,
      containsAll(<String>['public_name', 'address']),
      reason: 'the guard being read is the institution edit one',
    );
  });
}
