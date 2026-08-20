import 'package:coelo_superadmin/features/invites/data/fake_invite_repository.dart';
import 'package:coelo_superadmin/features/invites/domain/platform_invite.dart';
import 'package:coelo_superadmin/features/invites/presentation/invite_form_page.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_action_footer.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_step_navigation.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses canonical controls, navigation and footer', (tester) async {
    await _pumpForm(tester, size: const Size(1024, 900));

    expect(find.byType(SuperadminFormStepNavigation), findsOneWidget);
    expect(find.byType(SuperadminFormActionFooter), findsOneWidget);
    expect(find.byType(CoeloAdminSingleSelectField<InviteAudience>), findsOneWidget);
    expect(find.byType(RadioListTile), findsNothing);
    expect(find.byType(DropdownButton), findsNothing);
    expect(find.byType(DropdownButtonFormField), findsNothing);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact footer puts primary action first and cancels', (tester) async {
    var cancellations = 0;
    await _pumpForm(tester, size: const Size(375, 900), onCancel: () => cancellations++);

    final continueButton = find.byKey(const Key('invite-form-continue'));
    final cancelButton = find.byKey(const Key('invite-form-cancel'));
    expect(tester.getTopLeft(continueButton).dy, lessThan(tester.getTopLeft(cancelButton).dy));

    await tester.tap(cancelButton);
    await tester.pump();
    expect(cancellations, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses a simple surface base on mobile and tablet', (tester) async {
    for (final width in const [375.0, 768.0, 1024.0]) {
      await _pumpForm(tester, size: Size(width, 900));

      final pageSurface = tester.widget<ColoredBox>(
        find.byKey(const Key('invite-form-page-surface')),
      );
      expect(pageSurface.color, CoeloTheme.light.colorScheme.surface);
      expect(find.byKey(const Key('invite-form-desktop-panel')), findsNothing);
    }
  });
  testWidgets('keeps every reached step enabled after returning to an earlier step', (
    tester,
  ) async {
    await _pumpForm(tester);

    await _continue(tester);
    await _continue(tester);
    await _continue(tester);
    await tester.enterText(find.byKey(const Key('invite-recipient-field')), 'owner@aurora.test');
    await _continue(tester);
    await _continue(tester);

    var navigation = tester.widget<SuperadminFormStepNavigation>(
      find.byType(SuperadminFormStepNavigation),
    );
    navigation.onStepSelected(3);
    await tester.pump();

    navigation = tester.widget<SuperadminFormStepNavigation>(
      find.byType(SuperadminFormStepNavigation),
    );
    expect(navigation.steps[5].enabled, isTrue);

    navigation.onStepSelected(5);
    await tester.pump();
    expect(find.byKey(const Key('invite-expiry-field')), findsOneWidget);
  });

  testWidgets('marks the recipient step as error when its value is invalid', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpForm(tester, size: const Size(375, 900));

    await _continue(tester);
    await _continue(tester);
    await _continue(tester);
    await tester.enterText(find.byKey(const Key('invite-recipient-field')), 'email-invalido');
    await _continue(tester);

    final navigation = tester.widget<SuperadminFormStepNavigation>(
      find.byType(SuperadminFormStepNavigation),
    );
    expect(navigation.steps[3].status, SuperadminFormStepStatus.error);
    final summary = tester.getSemantics(find.byKey(const Key('superadmin-form-step-summary')));
    expect(summary.label, contains('com erro'));
    semantics.dispose();
  });

  testWidgets('validates email, reviews masked recipient and sends', (tester) async {
    PlatformInvite? sent;
    await _pumpForm(tester, onSent: (invite) => sent = invite);

    await _continue(tester);
    expect(find.byType(CoeloFormTextField), findsOneWidget);
    await _continue(tester);
    await _continue(tester);

    await tester.enterText(find.byKey(const Key('invite-recipient-field')), 'email-invalido');
    await _continue(tester);
    expect(find.text('Informe um e-mail válido.'), findsOneWidget);
    expect(find.text('Destinatário'), findsWidgets);

    await tester.enterText(find.byKey(const Key('invite-recipient-field')), 'owner@aurora.test');
    await _continue(tester);
    expect(find.byType(CoeloAdminSingleSelectField<InviteChannel>), findsOneWidget);

    await _continue(tester);
    expect(find.byKey(const Key('invite-expiry-field')), findsOneWidget);
    await _continue(tester);

    expect(find.text('o***@aurora.test'), findsOneWidget);
    expect(find.text('owner@aurora.test'), findsNothing);

    await tester.tap(find.byKey(const Key('invite-form-send')));
    await tester.pumpAndSettle();

    expect(sent, isNotNull);
    expect(sent!.recipient, 'owner@aurora.test');
    expect(sent!.status, InviteStatus.pending);
  });

  testWidgets('redirects review to the first invalid reached text step', (tester) async {
    PlatformInvite? sent;
    await _pumpForm(tester, onSent: (invite) => sent = invite);
    await _reachReview(tester);

    var navigation = tester.widget<SuperadminFormStepNavigation>(
      find.byType(SuperadminFormStepNavigation),
    );
    navigation.onStepSelected(2);
    await tester.pump();
    await tester.enterText(find.byKey(const Key('invite-role-field')), '');

    navigation = tester.widget<SuperadminFormStepNavigation>(
      find.byType(SuperadminFormStepNavigation),
    );
    navigation.onStepSelected(1);
    await tester.pump();
    await tester.enterText(find.byKey(const Key('invite-scope-field')), '');

    navigation = tester.widget<SuperadminFormStepNavigation>(
      find.byType(SuperadminFormStepNavigation),
    );
    navigation.onStepSelected(6);
    await tester.pump();

    navigation = tester.widget<SuperadminFormStepNavigation>(
      find.byType(SuperadminFormStepNavigation),
    );
    expect(navigation.currentIndex, 1);
    expect(navigation.steps[1].status, SuperadminFormStepStatus.error);
    expect(navigation.steps[2].status, SuperadminFormStepStatus.error);
    expect(find.byKey(const Key('invite-form-send')), findsNothing);
    expect(sent, isNull);
  });

  testWidgets('redirects review to recipient when a channel change invalidates it', (tester) async {
    PlatformInvite? sent;
    await _pumpForm(tester, onSent: (invite) => sent = invite);
    await _reachReview(tester);

    var navigation = tester.widget<SuperadminFormStepNavigation>(
      find.byType(SuperadminFormStepNavigation),
    );
    navigation.onStepSelected(3);
    await tester.pump();
    await tester.enterText(find.byKey(const Key('invite-recipient-field')), '1234@a.co');

    navigation = tester.widget<SuperadminFormStepNavigation>(
      find.byType(SuperadminFormStepNavigation),
    );
    navigation.onStepSelected(4);
    await tester.pump();
    final channel = tester.widget<CoeloAdminSingleSelectField<InviteChannel>>(
      find.byType(CoeloAdminSingleSelectField<InviteChannel>),
    );
    channel.onChanged(InviteChannel.mobile);
    await tester.pump();

    navigation = tester.widget<SuperadminFormStepNavigation>(
      find.byType(SuperadminFormStepNavigation),
    );
    navigation.onStepSelected(5);
    await tester.pump();

    navigation = tester.widget<SuperadminFormStepNavigation>(
      find.byType(SuperadminFormStepNavigation),
    );
    expect(navigation.currentIndex, 3);
    expect(navigation.steps[3].status, SuperadminFormStepStatus.error);
    expect(find.byKey(const Key('invite-recipient-field')), findsOneWidget);
    expect(sent, isNull);
  });
}

Future<void> _continue(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('invite-form-continue')));
  await tester.pumpAndSettle();
}

Future<void> _reachReview(WidgetTester tester) async {
  await _continue(tester);
  await _continue(tester);
  await _continue(tester);
  await tester.enterText(find.byKey(const Key('invite-recipient-field')), 'owner@aurora.test');
  await _continue(tester);
  await _continue(tester);
  await _continue(tester);
}

Future<void> _pumpForm(
  WidgetTester tester, {
  Size size = const Size(1024, 900),
  VoidCallback? onCancel,
  ValueChanged<PlatformInvite>? onSent,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: InviteFormPage(
          repository: FakeInviteRepository(now: () => DateTime(2026, 8, 4, 12)),
          onCancel: onCancel ?? () {},
          onSent: onSent,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
