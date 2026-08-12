import 'package:coelo_superadmin/features/invites/domain/platform_invite.dart';
import 'package:coelo_superadmin/features/invites/presentation/invite_form_page.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_frame.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'invite_test_repository.dart';

void main() {
  testWidgets('uses the canonical frame and only email plus copyable link', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = TestInviteRepository();
    await tester.pumpWidget(_app(InviteFormPage(repository: repository, onCancel: () {})));
    await tester.pumpAndSettle();

    expect(find.byType(SuperadminFormFrame), findsOneWidget);
    expect(find.byKey(const Key('invite-form-desktop-panel')), findsNothing);
    expect(InviteChannel.values.map((value) => value.label), ['E-mail', 'Link copiável']);
    expect(find.textContaining('SMS'), findsNothing);
    expect(find.textContaining('Celular'), findsNothing);
  });

  testWidgets('selects hierarchical data and issues a person target with both channels', (
    tester,
  ) async {
    final repository = TestInviteRepository();
    PlatformInvite? sent;
    await tester.pumpWidget(
      _app(
        InviteFormPage(repository: repository, onCancel: () {}, onSent: (value) => sent = value),
      ),
    );
    await tester.pumpAndSettle();

    _change<InviteScopeOption?>(
      tester,
      const Key('invite-scope-field'),
      repository.options.scopes.single,
    );
    await tester.pumpAndSettle();
    _change<InviteProfileOption?>(
      tester,
      const Key('invite-profile-field'),
      repository.options.profiles.single,
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('invite-form-continue')));
    await tester.pumpAndSettle();

    _change<InviteRecipientOption?>(
      tester,
      const Key('invite-recipient-field'),
      repository.options.recipients.single,
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('invite-form-continue')));
    await tester.pumpAndSettle();

    final delivery = tester.widget<CoeloAdminMultiSelectField<InviteChannel>>(
      find.byKey(const Key('invite-channels-field')),
    );
    delivery.onChanged({InviteChannel.email, InviteChannel.link});
    await tester.pump();
    await tester.tap(find.byKey(const Key('invite-form-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('invite-form-send')));
    await tester.pumpAndSettle();

    expect(repository.lastIssue?.recipient.personId, repository.options.recipients.single.personId);
    expect(repository.lastIssue?.recipient.email, isNull);
    expect(repository.lastIssue?.channels, {InviteChannel.email, InviteChannel.link});
    expect(find.byKey(const Key('invite-result-link')), findsOneWidget);

    await tester.tap(find.byKey(const Key('invite-form-done')));
    expect(sent, isNotNull);
  });

  testWidgets('searches options through the backend query', (tester) async {
    final repository = TestInviteRepository();
    await tester.pumpWidget(_app(InviteFormPage(repository: repository, onCancel: () {})));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('invite-options-search')), 'girassol');
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pumpAndSettle();

    expect(repository.lastOptionsQuery?.search, 'girassol');
  });

  for (final width in [768.0, 1024.0]) {
    testWidgets('keeps the 248 rail and max-880 body at ${width.toInt()}', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(InviteFormPage(repository: TestInviteRepository(), onCancel: () {})),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SuperadminFormFrame), findsOneWidget);
      final rail = find.byKey(const Key('superadmin-form-steps-scroll'));
      expect(rail, findsOneWidget);
      expect(tester.getSize(rail).width, 248);
    });
  }

  testWidgets('remains usable at 375 and 200 percent text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(375, 900), textScaler: TextScaler.linear(2)),
        child: _app(InviteFormPage(repository: TestInviteRepository(), onCancel: () {})),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('superadmin-form-step-summary')), findsOneWidget);
  });
}

void _change<T>(WidgetTester tester, Key key, T value) {
  final field = tester.widget<CoeloAdminSingleSelectField<T>>(find.byKey(key));
  field.onChanged(value);
}

Widget _app(Widget child) => MaterialApp(
  theme: CoeloTheme.light,
  home: Scaffold(body: child),
);
