import 'package:coelo_domain/profile_about.dart';
import 'package:coelo_superadmin/features/principal_profile/presentation/principal_profile_edit_page.dart';
import 'package:coelo_superadmin/features/principal_shared/domain/principal_runtime_context.dart';
import 'package:coelo_superadmin/features/profile_about/domain/profile_about_repository.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the fix of a previously registered defect of `principal.profile-edit`.
///
/// Below 1120 px `ProfileAboutEditor` trades its inline preview panel for a
/// "Pré-visualizar" button whose handler is an optional parameter. This page
/// supplies none, so the button used to render disabled with no explanation:
/// an affordance that exists and does nothing. The audience selector beside it
/// had the same problem, because it only steers a preview that was unreachable.
///
/// Both are now rendered only where a preview is actually reachable. Hiding
/// them is the honest degradation: wiring a preview surface here would compose
/// a visual contract nobody has approved, and a disabled control is not a
/// degraded state, it is a dead one.
///
/// WHEN A PREVIEW SURFACE IS APPROVED AND WIRED: this file inverts. The button
/// must appear enabled and open the projected About; replace the absence
/// assertions rather than relaxing them.
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
  Finder audienceSelector() => find.ancestor(
    of: find.textContaining('Prévia: '),
    matching: find.byType(OutlinedButton),
  );

  testWidgets('below 1120 px no dead preview button reaches the user', (tester) async {
    await pumpEditor(tester, width: 375);

    expect(
      previewButton(),
      findsNothing,
      reason:
          'This page supplies no onPreview. Rendering the button here would '
          'show a disabled, unexplained control instead of degrading honestly.',
    );
  });

  testWidgets('below 1120 px the audience selector is not offered either', (tester) async {
    // It only changes what the preview projects; with no preview reachable it
    // would change nothing the user can see.
    await pumpEditor(tester, width: 375);

    expect(audienceSelector(), findsNothing);
  });

  testWidgets('at 1440 px the inline preview panel keeps the audience selector', (tester) async {
    // Wide layouts show the preview panel, so steering its audience is real
    // and the control stays exactly where the approved composition puts it.
    await pumpEditor(tester, width: 1440);

    expect(previewButton(), findsNothing);
    expect(audienceSelector(), findsOneWidget);
  });

  testWidgets('the save action stays enabled at narrow widths', (tester) async {
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
