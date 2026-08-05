import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/groups/data/fake_group_directory_repository.dart';
import 'package:coelo_superadmin/features/groups/presentation/group_form_page.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_action_footer.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
          institutions: institutions,
          repository: repository,
          logout: () async => const LogoutResult.success(),
          onCancel: () {},
          onSaved: (value) => result = value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Criar turma'), findsWidgets);
    expect(find.text('Ativo'), findsOneWidget);
    expect(find.byType(SuperadminFormActionFooter), findsOneWidget);
    expect(find.byKey(const Key('group-handle-field')), findsOneWidget);
    expect(find.byKey(const Key('group-primary-color-field')), findsOneWidget);
    expect(find.byKey(const Key('group-secondary-color-field')), findsOneWidget);
    expect(find.byKey(const Key('group-activity-links')), findsOneWidget);
    expect(find.text('Hierarquia'), findsOneWidget);
    expect(find.text('Identidade'), findsOneWidget);
    expect(find.textContaining('Atividades da turma'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('group-name-field')), 'Turma Girassol');
    await tester.enterText(find.byKey(const Key('group-type-field')), 'class');
    await tester.enterText(find.byKey(const Key('group-handle-field')), '@girassol');
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
          institutions: institutions,
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
          institutions: institutions,
          repository: FakeGroupDirectoryRepository(institutions),
          logout: () async => const LogoutResult.success(),
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

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
          institutions: institutions,
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
