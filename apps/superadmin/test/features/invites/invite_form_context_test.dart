import 'dart:async';

import 'package:coelo_superadmin/features/invites/domain/platform_invite.dart';
import 'package:coelo_superadmin/features/invites/presentation/invite_form_page.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_step_navigation.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'invite_test_repository.dart';

void main() {
  testWidgets('new option search invalidates an older response before debounce completes', (
    tester,
  ) async {
    final repository = _Repository();
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();
    tester
        .widget<CoeloAdminSingleSelectField<InviteScopeOption?>>(
          find.byKey(const Key('invite-scope-field')),
        )
        .onChanged(repository.delegate.options.scopes.single);
    await tester.pumpAndSettle();
    final oldOptions = Completer<InviteFormOptions>();
    repository.optionsGate = oldOptions.future;
    await tester.enterText(find.byKey(const Key('invite-options-search')), 'first');
    await tester.pump(const Duration(milliseconds: 301));
    await tester.enterText(find.byKey(const Key('invite-options-search')), 'second');
    oldOptions.complete(repository.delegate.options);
    await tester.pump();
    expect(
      tester
          .widget<CoeloAdminSingleSelectField<InviteProfileOption?>>(
            find.byKey(const Key('invite-profile-field')),
          )
          .isLoading,
      isTrue,
    );
    repository.optionsGate = null;
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pumpAndSettle();
    expect(repository.delegate.lastOptionsQuery?.search, 'second');
  });

  testWidgets('profile search stays available inside the selected context', (tester) async {
    final repository = _Repository();
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();
    tester
        .widget<CoeloAdminSingleSelectField<InviteScopeOption?>>(
          find.byKey(const Key('invite-scope-field')),
        )
        .onChanged(repository.delegate.options.scopes.single);
    await tester.pumpAndSettle();
    repository.delegate.options = InviteFormOptions(
      scopes: const [],
      profiles: repository.delegate.options.profiles,
      recipients: const [],
    );
    await tester.enterText(find.byKey(const Key('invite-options-search')), 'Profissional');
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invite-profile-field')), findsOneWidget);
    expect(find.text('Nenhum contexto encontrado'), findsNothing);
  });

  testWidgets('recipient search preserves the selected profile when profile results are filtered', (
    tester,
  ) async {
    final repository = _Repository();
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();
    await _prepare(tester, repository.delegate.options);
    tester
        .widget<SuperadminFormStepNavigation>(find.byType(SuperadminFormStepNavigation))
        .onStepSelected(1);
    await tester.pumpAndSettle();
    repository.delegate.options = InviteFormOptions(
      scopes: const [],
      profiles: const [],
      recipients: repository.delegate.options.recipients,
    );
    await tester.enterText(find.byKey(const Key('invite-recipient-search')), 'Ana');
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pumpAndSettle();
    tester
        .widget<SuperadminFormStepNavigation>(find.byType(SuperadminFormStepNavigation))
        .onStepSelected(3);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('invite-form-send')), findsOneWidget);
    await tester.tap(find.byKey(const Key('invite-form-send')));
    await tester.pumpAndSettle();
    expect(repository.delegate.lastIssue?.profileId, testInviteOptions().profiles.single.id);
    expect(repository.issues, 1);
  });

  testWidgets('review cannot skip a profile cleared after returning to context', (tester) async {
    final repository = _Repository();
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();
    await _prepare(tester, repository.delegate.options);
    tester
        .widget<SuperadminFormStepNavigation>(find.byType(SuperadminFormStepNavigation))
        .onStepSelected(0);
    await tester.pumpAndSettle();
    tester
        .widget<CoeloAdminSingleSelectField<InviteScopeOption?>>(
          find.byKey(const Key('invite-scope-field')),
        )
        .onChanged(repository.delegate.options.scopes.single);
    await tester.pumpAndSettle();
    tester
        .widget<SuperadminFormStepNavigation>(find.byType(SuperadminFormStepNavigation))
        .onStepSelected(3);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('invite-profile-field')), findsOneWidget);
    expect(find.byKey(const Key('invite-form-send')), findsNothing);
    expect(repository.issues, 0);
  });

  testWidgets('repository replacement rejects previous options before showing the new denial', (
    tester,
  ) async {
    final gate = Completer<InviteFormOptions>();
    final first = _Repository(optionsGate: gate.future);
    final second = _Repository()..delegate.failure = const InviteUnauthorizedException();
    await tester.pumpWidget(_page(first));
    await tester.pumpWidget(_page(second));
    gate.complete(first.delegate.options);
    await tester.pumpAndSettle();
    expect(second.optionReads, 1);
    expect(find.byKey(const Key('invite-scope-field')), findsNothing);
    expect(find.textContaining('Turma Girassol'), findsNothing);
  });

  testWidgets('late issuance cannot expose its link in a replacement context', (tester) async {
    final gate = Completer<InviteCommandResult>();
    final first = _Repository(issueGate: gate.future);
    final second = _Repository()
      ..delegate.options = const InviteFormOptions(scopes: [], profiles: [], recipients: []);
    await tester.pumpWidget(_page(first));
    await tester.pumpAndSettle();
    await _prepare(tester, first.delegate.options);
    await tester.tap(find.byKey(const Key('invite-form-send')));
    await tester.pump();
    await tester.pumpWidget(_page(second));
    gate.complete(
      InviteCommandResult(
        invite: testInvite(),
        replayed: false,
        link: Uri.parse('https://example.invalid/synthetic-old-link'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invite-result-link')), findsNothing);
    expect(second.optionReads, 1);
    expect(find.byKey(const Key('invite-form-done')), findsNothing);
    expect(find.text('Nenhum contexto disponível'), findsOneWidget);
    expect(first.issues, 1);
    expect(second.issues, 0);
  });

  testWidgets('repeated send activation before a frame issues once', (tester) async {
    final gate = Completer<InviteCommandResult>();
    final repository = _Repository(issueGate: gate.future);
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();
    await _prepare(tester, repository.delegate.options);
    final submit = tester
        .widget<FilledButton>(find.byKey(const Key('invite-form-send')))
        .onPressed!;
    submit();
    submit();
    final calls = repository.issues;
    gate.complete(InviteCommandResult(invite: testInvite(), replayed: false));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });
}

Future<void> _prepare(WidgetTester tester, InviteFormOptions options) async {
  tester
      .widget<CoeloAdminSingleSelectField<InviteScopeOption?>>(
        find.byKey(const Key('invite-scope-field')),
      )
      .onChanged(options.scopes.single);
  await tester.pumpAndSettle();
  tester
      .widget<CoeloAdminSingleSelectField<InviteProfileOption?>>(
        find.byKey(const Key('invite-profile-field')),
      )
      .onChanged(options.profiles.single);
  await tester.pump();
  await tester.tap(find.byKey(const Key('invite-form-continue')));
  await tester.pumpAndSettle();
  tester
      .widget<CoeloAdminSingleSelectField<InviteRecipientOption?>>(
        find.byKey(const Key('invite-recipient-field')),
      )
      .onChanged(options.recipients.single);
  await tester.pump();
  await tester.tap(find.byKey(const Key('invite-form-continue')));
  await tester.pumpAndSettle();
  tester
      .widget<CoeloAdminMultiSelectField<InviteChannel>>(
        find.byKey(const Key('invite-channels-field')),
      )
      .onChanged({InviteChannel.link});
  await tester.pump();
  await tester.tap(find.byKey(const Key('invite-form-continue')));
  await tester.pumpAndSettle();
}

Widget _page(InviteRepository repository) => MaterialApp(
  theme: CoeloTheme.light,
  home: Scaffold(
    body: InviteFormPage(repository: repository, onCancel: () {}),
  ),
);

final class _Repository implements InviteRepository {
  _Repository({this.optionsGate, this.issueGate});
  final delegate = TestInviteRepository();
  Future<InviteFormOptions>? optionsGate;
  final Future<InviteCommandResult>? issueGate;
  int optionReads = 0;
  int issues = 0;
  @override
  Future<InviteFormOptions> fetchOptions(InviteOptionsQuery query) {
    optionReads++;
    return optionsGate ?? delegate.fetchOptions(query);
  }

  @override
  Future<InviteCommandResult> issue(InviteIssueCommand command) {
    issues++;
    return issueGate ?? delegate.issue(command);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
