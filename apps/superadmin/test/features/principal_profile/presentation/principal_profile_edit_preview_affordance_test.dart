import 'package:coelo_domain/profile_about.dart';
import 'package:coelo_superadmin/features/principal_profile/presentation/principal_profile_edit_page.dart';
import 'package:coelo_superadmin/features/principal_shared/domain/principal_runtime_context.dart';
import 'package:coelo_superadmin/features/profile_about/domain/profile_about_repository.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins a REGISTERED, DELIBERATELY UNFIXED defect of `principal.profile-edit`.
///
/// Below 1120 px the shared `ProfileAboutEditor` replaces its inline preview
/// panel with a "Pré-visualizar" button whose handler is an optional parameter.
/// This page does not supply one, so the button renders disabled with no
/// explanation: an affordance that exists and does nothing.
///
/// It is not fixed here because the editor is shared with the Activities form
/// and wiring a preview would compose a new surface without an approved visual
/// contract. The test exists so the defect cannot be forgotten and so that
/// whoever wires the handler is told what to change.
///
/// WHEN THE HANDLER IS WIRED: invert this file. The button must become enabled
/// and open the projected About; delete the disabled assertion rather than
/// relaxing it, and drop the narrow-screen exemption below.
void main() {
  const context = PrincipalRuntimeContext(
    membershipId: 'membership-1',
    personId: 'person-1',
    institutionId: 'institution-1',
    institutionName: 'Instituição Autorizada',
    roleCode: 'staff',
    scopeKind: 'institution',
  );

  Future<void> pumpEditor(WidgetTester tester, {required double width}) async {
    await tester.binding.setSurfaceSize(Size(width, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalProfileEditPage(runtimeContext: context, repository: _StubAboutRepository()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder previewButton() => find.widgetWithText(OutlinedButton, 'Pré-visualizar');

  testWidgets('below 1120 px the preview button renders disabled — registered defect', (
    tester,
  ) async {
    await pumpEditor(tester, width: 375);

    expect(previewButton(), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(previewButton()).onPressed,
      isNull,
      reason:
          'Registered defect: PrincipalProfileEditPage supplies no onPreview, so '
          'the shared editor shows a dead button on narrow screens. When the '
          'handler is wired, invert this expectation instead of relaxing it.',
    );
  });

  testWidgets('the dead affordance is confined to narrow screens', (tester) async {
    // At 1120 px and above the editor shows its inline preview panel instead,
    // so no disabled button reaches the user there.
    await pumpEditor(tester, width: 1440);

    expect(previewButton(), findsNothing);
  });

  testWidgets('the save action stays enabled regardless of the preview defect', (tester) async {
    await pumpEditor(tester, width: 375);

    final save = find.byKey(const Key('principal-profile-edit-save'));
    expect(save, findsOneWidget);
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
  });
}

final class _StubAboutRepository implements ProfileAboutRepository {
  @override
  Future<ProfileAboutPage?> load(
    ProfileAboutSubjectRef subject, {
    ProfileAboutAudience? preview,
  }) async => null;

  @override
  Future<ProfileAboutSaveResult> save(
    ProfileAboutPage page, {
    required String requestId,
    Map<ProfileAboutFieldKey, String> officialUpdates = const {},
  }) => Future.error(UnimplementedError());
}
