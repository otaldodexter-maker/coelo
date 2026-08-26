import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/groups/data/fake_group_directory_repository.dart';
import 'package:coelo_superadmin/features/groups/domain/group_directory.dart';
import 'package:coelo_superadmin/features/groups/presentation/group_form_page.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_action_footer.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_frame.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_step_navigation.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  testWidgets('creates a group with the confirmed fields and active default', (tester) async {
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

    await tester.tap(find.byKey(const Key('group-form-continue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('group-handle-field')), findsNothing);
    expect(find.byKey(const Key('group-primary-color-field')), findsNothing);
    expect(find.byKey(const Key('group-secondary-color-field')), findsNothing);
    expect(find.byKey(const Key('group-activity-links')), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byKey(const Key('group-inherit-appearance'))).value,
      isTrue,
    );
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
    expect(repository.records.any((record) => record.name == 'Turma Girassol'), isTrue);
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
}
