import 'dart:async';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/groups/data/fake_group_directory_repository.dart';
import 'package:coelo_superadmin/features/groups/domain/group_directory.dart';
import 'package:coelo_superadmin/features/groups/presentation/group_form_page.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_action_footer.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_frame.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_step_navigation.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final phase in ['loaded', 'find', 'context', 'same-props']) {
    testWidgets('group initial context stays scoped $phase', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final delegate = FakeGroupDirectoryRepository(FakeInstitutionDirectoryRepository());
      final repository = _PendingGroupRepository(delegate);
      final replacement = _PendingGroupRepository(delegate);
      final context = await delegate.fetchFormContext();
      if (phase == 'find') repository.pendingFind = Completer<GroupRecord?>();
      if (phase == 'context' || phase == 'same-props') {
        repository.pendingContext = Completer<GroupDirectoryFormContext>();
      }
      Widget app(bool changed) => MaterialApp(
        theme: CoeloTheme.light,
        home: GroupFormPage(
          key: const ValueKey('initial-context-form'),
          repository: changed && phase == 'find' ? replacement : repository,
          groupId: phase == 'find'
              ? 'old-group'
              : changed && phase == 'loaded'
              ? 'new-group'
              : null,
          initialInstitutionId: changed && phase == 'context' ? 'new-institution' : null,
          initialUnitId: changed && phase == 'context' ? 'new-unit' : null,
          logout: () async => const LogoutResult.success(),
          onCancel: () {},
          onSaved: (_) => fail('No save should complete in this test'),
        ),
      );
      await tester.pumpWidget(app(false));
      await tester.pump();
      VoidCallback? retainedSave;
      if (phase == 'loaded') {
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('group-form-continue')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('group-name-field')), 'Turma anterior');
        await tester.tap(find.byKey(const Key('step-convites')));
        await tester.pumpAndSettle();
        retainedSave = tester
            .widget<FilledButton>(find.byKey(const Key('group-form-save')))
            .onPressed;
      }
      await tester.pumpWidget(app(true));
      await tester.pump();
      final blockedBeforeCompletion = find
          .byKey(const Key('group-form-save-context-changed'))
          .evaluate()
          .isNotEmpty;
      repository.pendingFind?.complete(null);
      repository.pendingContext?.complete(context);
      await tester.pumpAndSettle();
      retainedSave?.call();
      await tester.pump();
      expect(repository.requests, isEmpty);
      expect(replacement.requests, isEmpty);
      expect(replacement.contextCalls, 0);
      if (phase == 'same-props') {
        expect(repository.contextCalls, 1);
        expect(find.byKey(const Key('group-form-continue')), findsOneWidget);
        expect(find.byKey(const Key('group-form-save-context-changed')), findsNothing);
      } else {
        if (phase == 'find') expect(repository.contextCalls, 0);
        expect(blockedBeforeCompletion, isTrue);
        expect(find.textContaining('Reabra o formulário'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byKey(const Key('group-form-continue')), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }
  for (final change in ['repository', 'groupId', 'institution', 'unit']) {
    testWidgets('group retry rejects changed context $change', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final institutions = FakeInstitutionDirectoryRepository();
      final repository = _PendingGroupRepository(FakeGroupDirectoryRepository(institutions));
      final replacement = _PendingGroupRepository(FakeGroupDirectoryRepository(institutions));
      var saved = 0;
      Widget app(bool changed) => MaterialApp(
        theme: CoeloTheme.light,
        home: GroupFormPage(
          key: const ValueKey('same-form'),
          repository: changed && change == 'repository' ? replacement : repository,
          groupId: changed && change == 'groupId' ? 'different-group' : null,
          initialInstitutionId: changed && change == 'institution' ? 'different-institution' : null,
          initialUnitId: changed && change == 'unit' ? 'different-unit' : null,
          logout: () async => const LogoutResult.success(),
          onCancel: () {},
          onSaved: (_) => saved++,
        ),
      );
      await tester.pumpWidget(app(false));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('group-form-continue')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('group-name-field')), 'Turma A');
      await tester.tap(find.byKey(const Key('step-convites')));
      await tester.pumpAndSettle();
      final retainedSave = tester
          .widget<FilledButton>(find.byKey(const Key('group-form-save')))
          .onPressed!;
      await tester.tap(find.byKey(const Key('group-form-save')));
      await tester.pump();
      final first = repository.requests.single;
      final retry = tester.state<State<GroupFormPage>>(find.byType(GroupFormPage));
      final failedBeforeChange = change == 'repository' || change == 'institution';
      if (failedBeforeChange) {
        repository.pending.completeError(const GroupDirectoryUnavailableException());
        await tester.pumpAndSettle();
        repository.pending = Completer<GroupDirectorySaveResult>();
      }
      await tester.pumpWidget(app(true));
      await tester.pump();
      if (!failedBeforeChange) {
        repository.pending.complete(
          GroupDirectorySaveResult(
            requestId: first.requestId,
            steps: [GroupDirectorySaveStepResult.success(stage: GroupDirectorySaveStage.group)],
          ),
        );
        await tester.pumpAndSettle();
      }
      expect(saved, 0, reason: 'A stale completion must not invoke onSaved');
      expect(tester.state<State<GroupFormPage>>(find.byType(GroupFormPage)), same(retry));
      retainedSave();
      await tester.pump();
      expect(saved, 0, reason: 'The old scope must never report success for the new scope');
      expect(repository.requests, hasLength(1));
      expect(replacement.requests, isEmpty);
      expect(find.textContaining('Reabra o formulário'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  for (final change in ['none', 'name', 'status', 'appearance', 'same-status', 'trim-name']) {
    testWidgets('group ambiguous retry keeps intent unless edited $change', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final editAfterFailure = ['name', 'status', 'appearance'].contains(change);
      final institutions = FakeInstitutionDirectoryRepository();
      final repository = _PendingGroupRepository(FakeGroupDirectoryRepository(institutions));
      await tester.pumpWidget(
        MaterialApp(
          theme: CoeloTheme.light,
          home: GroupFormPage(
            repository: repository,
            logout: () async => const LogoutResult.success(),
            onCancel: () {},
            onSaved: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('group-form-continue')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('group-name-field')), 'Turma A');
      await tester.tap(find.byKey(const Key('step-convites')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('group-form-save')));
      await tester.pump();
      final first = repository.requests.single;
      repository.pending.completeError(const GroupDirectoryUnavailableException());
      await tester.pumpAndSettle();
      repository.pending = Completer<GroupDirectorySaveResult>();
      if (change != 'none') {
        await tester.tap(find.byKey(const Key('step-identidade')));
        await tester.pumpAndSettle();
        if (change == 'name' || change == 'trim-name') {
          await tester.enterText(
            find.byKey(const Key('group-name-field')),
            change == 'name' ? 'Turma B' : '  Turma A  ',
          );
        } else if (change == 'status' || change == 'same-status') {
          tester
              .widget<CoeloAdminSingleSelectField<GroupStatus>>(
                find.byKey(const Key('group-status-field')),
              )
              .onChanged(change == 'status' ? GroupStatus.inactive : GroupStatus.active);
          await tester.pumpAndSettle();
        } else {
          await tester.tap(find.byKey(const Key('group-form-continue')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('group-inherit-appearance')));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byKey(const Key('step-convites')));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const Key('group-form-save')));
      await tester.pump();
      try {
        expect(repository.requests, hasLength(2));
        final second = repository.requests.last;
        expect(second.requestId, editAfterFailure ? isNot(first.requestId) : first.requestId);
        expect(second.record.name, change == 'name' ? 'Turma B' : 'Turma A');
        expect(
          second.record.status,
          change == 'status' ? GroupStatus.inactive : GroupStatus.active,
        );
        expect(second.record.inheritAppearance, change != 'appearance');
        if (!editAfterFailure) expect(second, same(first));
      } finally {
        repository.pending.complete(
          GroupDirectorySaveResult(
            requestId: repository.requests.last.requestId,
            steps: [GroupDirectorySaveStepResult.success(stage: GroupDirectorySaveStage.group)],
          ),
        );
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  }
  for (final failure in [false, true]) {
    testWidgets(
      'group pending save rejects duplicate submission and further editing failure=$failure',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1024, 1100));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final institutions = FakeInstitutionDirectoryRepository();
        final repository = _PendingGroupRepository(FakeGroupDirectoryRepository(institutions));
        var saved = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: CoeloTheme.light,
            home: GroupFormPage(
              repository: repository,
              logout: () async => const LogoutResult.success(),
              onCancel: () {},
              onSaved: (_) => saved++,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('group-form-continue')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('group-name-field')), 'Turma A');
        await tester.tap(find.byKey(const Key('step-convites')));
        await tester.pumpAndSettle();
        final submit = tester
            .widget<FilledButton>(find.byKey(const Key('group-form-save')))
            .onPressed!;
        submit();
        await tester.pump();
        try {
          expect(repository.requests, hasLength(1));
          submit();
          await tester.pump();
          expect(repository.requests, hasLength(1), reason: 'One in-flight intention');
          final add = find.byKey(const Key('group-invite-add'));
          await tester.ensureVisible(add);
          await tester.pump();
          await tester.tap(add, warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.byKey(const Key('group-invite-identifier-field')), findsNothing);
          await tester.tap(find.byKey(const Key('step-identidade')), warnIfMissed: false);
          await tester.pump();
          expect(find.byKey(const Key('group-name-field')), findsNothing);
          expect(find.text('Salvando altera\u00e7\u00f5es\u2026'), findsOneWidget);
        } finally {
          if (failure) {
            repository.pending.completeError(const GroupDirectoryUnauthorizedException());
          } else {
            repository.pending.complete(
              GroupDirectorySaveResult(
                requestId: repository.requests.first.requestId,
                steps: [GroupDirectorySaveStepResult.success(stage: GroupDirectorySaveStage.group)],
              ),
            );
          }
          await tester.pumpAndSettle();
        }
        expect(saved, failure ? 0 : 1);
        expect(repository.requests.single.record.name, 'Turma A');
        expect(find.text('Salvando altera\u00e7\u00f5es\u2026'), findsNothing);
        await tester.tap(find.byKey(const Key('step-identidade')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('group-name-field')), 'Turma B');
        await tester.tap(find.byKey(const Key('group-form-cancel')));
        await tester.pumpAndSettle();
        expect(find.text('Sair sem salvar?'), findsOneWidget);
      },
    );
  }
  testWidgets('renders inherited access without a raw Material ListTile', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final institutions = FakeInstitutionDirectoryRepository();
    final institution = institutions.records.first;
    final unit = institution.units.first;
    final now = DateTime(2026, 8, 24);
    final record = GroupRecord(
      id: 'group-inherited-access',
      institutionId: institution.id,
      institutionName: institution.publicName,
      unitId: unit.id,
      unitName: unit.name,
      name: 'Turma com acesso herdado',
      groupType: 'class',
      status: GroupStatus.active,
      createdAt: now,
      updatedAt: now,
      effectiveAccess: const [
        GroupEffectiveAccess(
          personId: 'person-1',
          displayName: 'Responsável herdado',
          origin: 'unit',
          inherited: true,
          profileId: 'profile-1',
          profileCode: 'guardian',
          profileName: 'Responsável',
          capabilities: ['visualizar'],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: GroupFormPage(
          repository: FakeGroupDirectoryRepository(institutions, records: [record]),
          groupId: record.id,
          logout: () async => const LogoutResult.success(),
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profissionais e admins'));
    await tester.pumpAndSettle();

    final summary = find.byKey(const Key('group-inherited-access-summary'));
    expect(summary, findsOneWidget);
    expect(find.descendant(of: summary, matching: find.byType(ListTile)), findsNothing);
    expect(find.text('Responsável herdado'), findsOneWidget);
  });

  testWidgets('uses six external-free steps and the canonical continuation footer', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final institutions = FakeInstitutionDirectoryRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: GroupFormPage(
          repository: FakeGroupDirectoryRepository(institutions),
          logout: () async => const LogoutResult.success(),
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SuperadminFormStepNavigation), findsOneWidget);
    expect(find.byType(SuperadminFormFrame), findsOneWidget);
    expect(find.byKey(const Key('superadmin-form-step-summary')), findsNothing);
    expect(find.byType(Stepper), findsNothing);
    expect(tester.widget(find.byKey(const Key('group-hierarchy-section'))), isA<Column>());
    expect(
      tester.getRect(find.byType(SuperadminFormStepNavigation)).left,
      lessThan(tester.getRect(find.byKey(const Key('group-form-scroll'))).left),
    );
    expect(find.byKey(const Key('group-form-continue')), findsOneWidget);
    expect(find.byKey(const Key('group-form-save')), findsNothing);
    for (final label in [
      'Hierarquia',
      'Identidade',
      'Vínculos e aparência',
      'Pessoas da turma',
      'Profissionais e admins',
      'Convites',
    ]) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.text('Sobre do perfil'), findsNothing);
    final forbidden = RegExp(r'fake|demo|dev|catálogo|teste', caseSensitive: false);
    for (final label in ['Vínculos e aparência', 'Profissionais e admins', 'Convites']) {
      await tester.tap(find.widgetWithText(TextButton, label));
      await tester.pumpAndSettle();
      expect(find.textContaining(forbidden), findsNothing, reason: label);
    }

    await tester.binding.setSurfaceSize(const Size(768, 900));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('superadmin-form-step-summary')), findsNothing);
    final mediumNavigation = tester.getRect(find.byType(SuperadminFormStepNavigation));
    final mediumForm = tester.getRect(find.byKey(const Key('group-form-scroll')));
    final mediumFooter = tester.getRect(find.byKey(const Key('group-form-footer-surface')));
    expect(mediumNavigation.width, 248);
    expect(mediumForm.left - mediumNavigation.right, closeTo(CoeloSpacing.space6, 1));
    expect(mediumFooter.left, greaterThanOrEqualTo(mediumNavigation.right + CoeloSpacing.space6));
    expect(tester.takeException(), isNull);

    await tester.binding.setSurfaceSize(const Size(375, 900));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('superadmin-form-step-summary')), findsOneWidget);
    final launcher = find.byKey(const Key('superadmin-chat-launcher-surface'));
    final footer = find.byType(SuperadminFormActionFooter);
    expect(launcher, findsOneWidget);
    expect(
      tester.getBottomLeft(launcher).dy,
      lessThanOrEqualTo(tester.getTopLeft(footer).dy - CoeloSpacing.space4),
    );
  });

  testWidgets('supports 200 percent text at all approved widths', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      final institutions = FakeInstitutionDirectoryRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: CoeloTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: GroupFormPage(
            key: ValueKey(width),
            repository: FakeGroupDirectoryRepository(institutions),
            logout: () async => const LogoutResult.success(),
            onCancel: () {},
            onSaved: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('superadmin-form-step-summary')),
        width < 768 ? findsOneWidget : findsNothing,
        reason: '$width summary',
      );
      expect(tester.takeException(), isNull, reason: '$width overflow');
    }
  });

  testWidgets('validates the identity step and preserves its draft when navigating back', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final institutions = FakeInstitutionDirectoryRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: GroupFormPage(
          repository: FakeGroupDirectoryRepository(institutions),
          logout: () async => const LogoutResult.success(),
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('group-form-continue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('group-form-previous')), findsOneWidget);

    await tester.tap(find.byKey(const Key('group-form-continue')));
    await tester.pumpAndSettle();
    expect(find.text('Informe o nome da turma.'), findsOneWidget);
    expect(find.byKey(const Key('group-links-section')), findsNothing);

    await tester.enterText(find.byKey(const Key('group-name-field')), 'Turma preservada');
    await tester.tap(find.byKey(const Key('group-form-continue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('group-links-section')), findsOneWidget);

    await tester.tap(find.byKey(const Key('group-form-previous')));
    await tester.pumpAndSettle();
    expect(find.text('Turma preservada'), findsOneWidget);
  });

  testWidgets('creates a custom group type with its canonical description', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final institutions = FakeInstitutionDirectoryRepository();
    final repository = FakeGroupDirectoryRepository(institutions);
    GroupFormSaveResult? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: GroupFormPage(
          repository: repository,
          logout: () async => const LogoutResult.success(),
          onCancel: () {},
          onSaved: (value) => result = value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Criar turma'), findsWidgets);
    expect(find.byType(SuperadminFormActionFooter), findsOneWidget);
    expect(find.byKey(const Key('group-institution-field')), findsOneWidget);

    await tester.tap(find.byKey(const Key('group-form-continue')));
    await tester.pumpAndSettle();
    expect(find.text('Ativo'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('group-name-field')), 'Turma Girassol');
    await tester.tap(
      find.descendant(of: find.byKey(const Key('group-type-field')), matching: find.text('Turma')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Outros'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('group-type-other-field')), 'Oficina maker');

    await tester.tap(find.byKey(const Key('group-form-continue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('group-handle-field')), findsNothing);
    expect(find.byKey(const Key('group-primary-color-field')), findsNothing);
    expect(find.byKey(const Key('group-secondary-color-field')), findsNothing);
    expect(find.byKey(const Key('group-activity-links')), findsOneWidget);
    expect(
      tester.widget<CoeloAdminToggleField>(find.byKey(const Key('group-inherit-appearance'))).value,
      isTrue,
    );
    expect(find.byType(SwitchListTile), findsNothing);
    await tester.tap(find.byKey(const Key('group-inherit-appearance')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('group-primary-color-field')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('group-primary-color-field')), '#112233');
    await tester.tap(find.byKey(const Key('group-inherit-appearance')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('group-primary-color-field')), findsNothing);
    expect(find.textContaining('Aparência herdada de'), findsOneWidget);

    await tester.tap(find.byKey(const Key('step-convites')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('group-form-save')));
    await tester.pumpAndSettle();

    expect(result, GroupFormSaveResult.created);
    final saved = repository.records.lastWhere((record) => record.name == 'Turma Girassol');
    expect(saved.groupType, 'other');
    expect(saved.groupTypeOtherText, 'Oficina maker');
  });

  testWidgets('locks hierarchy while editing and preserves dirty work on cancel', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final institutions = FakeInstitutionDirectoryRepository();
    final repository = FakeGroupDirectoryRepository(institutions);
    var cancelled = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.dark,
        home: GroupFormPage(
          repository: repository,
          groupId: repository.records.first.id,
          logout: () async => const LogoutResult.success(),
          onCancel: () => cancelled = true,
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final institutionField = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byKey(const Key('group-institution-field')),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    final unitField = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byKey(const Key('group-unit-field')),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(institutionField.ignoring, isTrue);
    expect(unitField.ignoring, isTrue);

    await tester.tap(find.byKey(const Key('step-identidade')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('group-name-field')), 'Nome alterado');
    await tester.tap(find.byKey(const Key('group-form-cancel')));
    await tester.pumpAndSettle();
    expect(find.text('Sair sem salvar?'), findsOneWidget);

    await tester.tap(find.text('Continuar editando'));
    await tester.pumpAndSettle();
    expect(find.text('Sair sem salvar?'), findsNothing);
    expect(find.text('Nome alterado'), findsWidgets);

    await tester.tap(find.byKey(const Key('group-form-cancel')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar editando'));
    await tester.pumpAndSettle();
    expect(cancelled, isFalse);
    expect(find.text('Nome alterado'), findsWidgets);
  });

  testWidgets('shows compact localized invite rows without overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final institutions = FakeInstitutionDirectoryRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: GroupFormPage(
          repository: FakeGroupDirectoryRepository(institutions),
          logout: () async => const LogoutResult.success(),
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('group-form-continue')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('group-name-field')), 'Turma compacta');
    for (var step = 0; step < 4; step++) {
      await tester.tap(find.byKey(const Key('group-form-continue')));
      await tester.pumpAndSettle();
    }

    await tester.ensureVisible(find.byKey(const Key('group-invite-add')));
    expect(find.byKey(const Key('group-invite-add')), findsOneWidget);
    expect(find.byKey(const Key('group-invite-export')), findsNothing);
    expect(find.byKey(const Key('group-invite-import')), findsNothing);
    await tester.tap(find.byKey(const Key('group-invite-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('group-invite-identifier-field')), '@responsavel');
    await tester.tap(find.byKey(const Key('group-invite-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('group-invite-compact-0')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('group-invite-compact-0')),
        matching: find.text('Responsável'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('shows not found instead of creating from an invalid edit route', (tester) async {
    final institutions = FakeInstitutionDirectoryRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: GroupFormPage(
          repository: FakeGroupDirectoryRepository(institutions),
          groupId: 'missing-group',
          logout: () async => const LogoutResult.success(),
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('group-form-not-found')), findsOneWidget);
    expect(find.text('Turma não encontrada'), findsOneWidget);
    expect(find.byKey(const Key('group-form-save')), findsNothing);
  });

  testWidgets('restores the save action when the repository throws an Error', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final institutions = FakeInstitutionDirectoryRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: GroupFormPage(
          repository: _ErrorOnSaveGroupDirectoryRepository(
            FakeGroupDirectoryRepository(institutions),
          ),
          logout: () async => const LogoutResult.success(),
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('group-form-continue')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('group-name-field')), 'Turma resiliente');
    await tester.tap(find.byKey(const Key('step-convites')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('group-form-save')));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      find.text('Não foi possível salvar a turma. Revise os dados e tente novamente.'),
      findsOneWidget,
    );
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('group-form-save'))).onPressed,
      isNotNull,
    );
  });
}

final class _ErrorOnSaveGroupDirectoryRepository implements GroupDirectoryRepository {
  const _ErrorOnSaveGroupDirectoryRepository(this._delegate);

  final GroupDirectoryRepository _delegate;

  @override
  String createId(String institutionId, String unitId, String name) =>
      _delegate.createId(institutionId, unitId, name);

  @override
  Future<GroupDirectoryPage> fetchPage(GroupDirectoryQuery query) => _delegate.fetchPage(query);

  @override
  Future<GroupDirectoryFilterOptions> fetchFilterOptions({Set<String> institutionIds = const {}}) =>
      _delegate.fetchFilterOptions(institutionIds: institutionIds);

  @override
  Future<GroupDirectoryFormContext> fetchFormContext({String? institutionId}) =>
      _delegate.fetchFormContext(institutionId: institutionId);

  @override
  Future<GroupRecord?> findById(String id) => _delegate.findById(id);

  @override
  Future<GroupDirectoryExportResult> requestExport(GroupDirectoryQuery query) =>
      _delegate.requestExport(query);

  @override
  Future<GroupDirectorySaveResult> saveComposition(GroupDirectorySaveRequest request) =>
      throw UnimplementedError('synthetic save Error');

  @override
  Future<void> upsert(GroupRecord record) => _delegate.upsert(record);
}

final class _PendingGroupRepository implements GroupDirectoryRepository {
  _PendingGroupRepository(this.delegate);
  final GroupDirectoryRepository delegate;
  var pending = Completer<GroupDirectorySaveResult>();
  final requests = <GroupDirectorySaveRequest>[];
  Completer<GroupRecord?>? pendingFind;
  Completer<GroupDirectoryFormContext>? pendingContext;
  int contextCalls = 0;
  @override
  Future<GroupDirectorySaveResult> saveComposition(GroupDirectorySaveRequest request) {
    requests.add(request);
    return pending.future;
  }

  @override
  String createId(String institutionId, String unitId, String name) =>
      delegate.createId(institutionId, unitId, name);
  @override
  Future<GroupDirectoryPage> fetchPage(GroupDirectoryQuery query) => delegate.fetchPage(query);
  @override
  Future<GroupDirectoryFilterOptions> fetchFilterOptions({Set<String> institutionIds = const {}}) =>
      delegate.fetchFilterOptions(institutionIds: institutionIds);
  @override
  Future<GroupDirectoryFormContext> fetchFormContext({String? institutionId}) {
    contextCalls++;
    return pendingContext?.future ?? delegate.fetchFormContext(institutionId: institutionId);
  }

  @override
  Future<GroupRecord?> findById(String id) => pendingFind?.future ?? delegate.findById(id);
  @override
  Future<GroupDirectoryExportResult> requestExport(GroupDirectoryQuery query) =>
      delegate.requestExport(query);
  @override
  Future<void> upsert(GroupRecord record) => delegate.upsert(record);
}
