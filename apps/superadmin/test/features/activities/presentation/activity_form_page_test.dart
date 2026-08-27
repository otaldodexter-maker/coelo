import 'dart:async';

import '../../../support/activities/fake_activity_directory_repository.dart';
import 'package:coelo_domain/profile_about.dart';
import 'package:coelo_superadmin/app/dev_menu/development_activity_fixture_repository.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_directory.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_profile_about_repository.dart';
import 'package:coelo_superadmin/features/activities/presentation/activity_form_controller.dart';
import 'package:coelo_superadmin/features/activities/presentation/activity_form_page.dart';
import 'package:coelo_superadmin/features/activities/presentation/activity_form_draft.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_action_footer.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_frame.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_step_navigation.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses the six-step institution baseline and chained categories', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(SuperadminFormStepNavigation), findsOneWidget);
    expect(find.byType(SuperadminFormFrame), findsOneWidget);
    expect(find.byType(SuperadminFormActionFooter), findsOneWidget);
    expect(find.textContaining(RegExp(r'apenas nesta sess', caseSensitive: false)), findsNothing);
    expect(
      tester.getRect(find.byKey(const Key('step-identidade'))).right,
      lessThan(tester.getRect(find.byKey(const Key('activity-form-name'))).left),
    );
    for (final label in [
      'Identidade',
      'Estrutura e locais',
      'Configuração pedagógica',
      'Vínculos',
      'Sobre do perfil',
      'Profissionais e revisão',
    ]) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.byKey(const Key('activity-form-name')), findsOneWidget);
    expect(find.byKey(const Key('activity-form-initials')), findsOneWidget);
    expect(find.byKey(const Key('activity-form-identity-color')), findsOneWidget);
    expect(find.byKey(const Key('activity-form-identity-icon')), findsOneWidget);
    expect(find.byKey(const Key('activity-form-category')), findsOneWidget);
    expect(find.text('Opcional'), findsOneWidget);
    final governance = tester.widget<CoeloAdminSingleSelectField<ActivityGovernance>>(
      find.byKey(const Key('activity-form-governance')),
    );
    expect(governance.options, [ActivityGovernance.optional, ActivityGovernance.mandatory]);
    expect(governance.optionLabel(ActivityGovernance.mandatory), 'Obrigatória');

    final category = tester.widget<CoeloAdminSingleSelectField<ActivityTaxonomyOption?>>(
      find.byKey(const Key('activity-form-category')),
    );
    category.onChanged(_languagesTaxonomy);
    await tester.pump();
    final template = tester.widget<CoeloAdminSingleSelectField<ActivityTemplateOption?>>(
      find.byKey(const Key('activity-form-template')),
    );
    expect(template.options, [null, _englishTemplate]);
    category.onChanged(_otherTaxonomy);
    await tester.pump();
    expect(find.byKey(const Key('activity-form-other')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps create form usable and retries a failed template catalog locally', (
    tester,
  ) async {
    final repository = _RecoveringCatalogRepository();
    await tester.pumpWidget(_app(repository: repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('activity-form-name')), findsOneWidget);
    expect(find.byKey(const Key('activity-catalog-options-state')), findsOneWidget);
    expect(find.text('Não foi possível carregar o formulário'), findsNothing);
    await tester.enterText(find.byKey(const Key('activity-form-name')), 'Robótica');
    final retryCatalog = find.byKey(const Key('activity-catalog-options-retry'));
    await Scrollable.ensureVisible(tester.element(retryCatalog), alignment: 0.5);
    await tester.pumpAndSettle();
    tester.widget<TextButton>(retryCatalog).onPressed!();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('activity-catalog-options-state')), findsNothing);
    expect(find.text('Robótica'), findsWidgets);
    expect(repository.templateCalls, 2);
  });

  testWidgets('uses the medium form inset at 768 pixels', (tester) async {
    await tester.binding.setSurfaceSize(const Size(768, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final outerPadding = tester
        .widgetList<Padding>(
          find.ancestor(
            of: find.byKey(const Key('activity-form-scroll')),
            matching: find.byType(Padding),
          ),
        )
        .firstWhere((widget) {
          final padding = widget.padding;
          return padding is EdgeInsets &&
              padding.bottom == CoeloSpacing.space4 &&
              padding.left == padding.top &&
              padding.left == padding.right;
        });
    expect((outerPadding.padding as EdgeInsets).left, CoeloSpacing.space6);
    final navigation = tester.getRect(find.byType(SuperadminFormStepNavigation));
    final scroll = tester.getRect(find.byKey(const Key('activity-form-scroll')));
    final footer = tester.getRect(find.byKey(const Key('activity-form-footer-surface')));
    expect(navigation.width, 248);
    expect(scroll.left - navigation.right, closeTo(CoeloSpacing.space6, 1));
    expect(footer.left, greaterThanOrEqualTo(navigation.right + CoeloSpacing.space6));
  });

  testWidgets('searches dense units and groups and separates student from professional links', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(repository: _DenseOptionsRepository()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('activity-form-name')), 'Robótica');
    await tester.tap(find.byKey(const Key('activity-form-continue')));
    await tester.pumpAndSettle();
    tester
        .widget<CoeloAdminSingleSelectField<String>>(
          find.byKey(const Key('activity-form-institution')),
        )
        .onChanged('institution-1');
    await tester.pump();

    expect(find.byKey(const Key('activity-units-search')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('activity-units-search')), 'Unidade 7');
    await tester.pump();
    expect(find.byKey(const Key('activity-unit-unit-7')), findsOneWidget);
    expect(find.byKey(const Key('activity-unit-unit-1')), findsNothing);
    tester
        .widget<CoeloAdminInteractiveCard>(
          find.descendant(
            of: find.byKey(const Key('activity-unit-unit-7')),
            matching: find.byType(CoeloAdminInteractiveCard),
          ),
        )
        .onPressed!();
    await tester.pump();
    tester.widget<FilledButton>(find.byKey(const Key('activity-form-continue'))).onPressed!();
    await tester.pumpAndSettle();
    tester.widget<FilledButton>(find.byKey(const Key('activity-form-continue'))).onPressed!();
    await tester.pumpAndSettle();

    expect(find.text('Vínculo Aluno'), findsOneWidget);
    expect(find.byKey(const Key('activity-groups-search')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('activity-groups-search')), 'Turma 7');
    await tester.pump();
    tester
        .widget<CoeloAdminInteractiveCard>(
          find.descendant(
            of: find.byKey(const Key('activity-group-group-7')),
            matching: find.byType(CoeloAdminInteractiveCard),
          ),
        )
        .onPressed!();
    await tester.pump();
    expect(find.byKey(const Key('activity-participation-group-7')), findsOneWidget);
    tester
        .widget<CoeloAdminSingleSelectField<ActivityParticipation>>(
          find.byKey(const Key('activity-participation-group-7')),
        )
        .onChanged(ActivityParticipation.selected);
    await tester.pump();
    expect(find.byType(CoeloAdminResizableTable<ActivityFormStudentOption>), findsOneWidget);
    expect(find.text('Ana Silva'), findsAtLeastNWidgets(1));
    expect(find.text('9'), findsOneWidget);
    expect(find.text('Feminino'), findsOneWidget);
    final belongs = tester.widget<CoeloAdminToggleField>(
      find.byKey(const Key('activity-student-belongs-child-group-link-7')),
    );
    expect(belongs.value, isTrue);
    belongs.onChanged!(false);
    await tester.pump();

    tester.widget<FilledButton>(find.byKey(const Key('activity-form-continue'))).onPressed!();
    await tester.pumpAndSettle();
    tester.widget<FilledButton>(find.byKey(const Key('activity-form-continue'))).onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('Vínculos Profissionais'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the compact chat launcher above the canonical footer', (tester) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    final launcher = find.byKey(const Key('superadmin-chat-launcher-surface'));
    final footer = find.byKey(const Key('activity-form-footer-surface'));
    expect(launcher, findsOneWidget);
    expect(
      tester.getBottomLeft(launcher).dy,
      lessThanOrEqualTo(tester.getTopLeft(footer).dy - CoeloSpacing.space4),
    );
  });

  testWidgets('saves a minimum draft then completes links and professional permissions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ActivityFormDraft? savedDraft;
    ActivityFormDraft? submittedDraft;

    await tester.pumpWidget(
      _app(
        repository: _ProfessionalOptionsRepository(),
        onSaveDraft: (draft) async => savedDraft = draft,
        onSubmit: (draft) async => submittedDraft = draft,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('activity-form-name')), 'Robótica');
    await tester.tap(find.byKey(const Key('activity-form-continue')));
    await tester.pumpAndSettle();

    final institution = tester.widget<CoeloAdminSingleSelectField<String>>(
      find.byKey(const Key('activity-form-institution')),
    );
    institution.onChanged('institution-1');
    await tester.pump();
    final unit = find.byKey(const Key('activity-unit-institution-1-unit-1'));
    await tester.ensureVisible(unit);
    await tester.tap(unit);
    await tester.pump();

    await tester.tap(find.byKey(const Key('activity-form-save-draft')));
    await tester.pumpAndSettle();
    expect(savedDraft?.unitIds, {'institution-1-unit-1'});

    await tester.tap(find.byKey(const Key('activity-form-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('activity-form-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('activity-group-institution-1-group-1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('activity-form-continue')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('activity-about-objective')),
      'Desenvolver raciocínio lógico',
    );
    await tester.tap(find.byKey(const Key('activity-form-continue')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('activity-invite-institution-1-group-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Marina');
    await tester.pump(const Duration(milliseconds: 351));
    await tester.pumpAndSettle();
    expect(find.text('Marina Costa'), findsOneWidget);
    expect(find.text('Rafael Lima'), findsNothing);
    await tester.tap(find.byKey(const Key('activity-professional-professional-1')));
    await tester.pump();
    await tester.tap(find.text('Concluir convite'));
    await tester.pumpAndSettle();

    for (final permission in ['happens', 'now', 'moments', 'chat', 'attendance']) {
      final field = tester.widget<CoeloAdminSingleSelectField<ActivityProfessionalAccess>>(
        find.byKey(Key('activity-permission-institution-1-group-1-professional-1-$permission')),
      );
      expect(field.value, ActivityProfessionalAccess.both);
    }
    final notes = tester.widget<OutlinedButton>(
      find.byKey(const Key('activity-permission-institution-1-group-1-professional-1-notes')),
    );
    expect(notes.onPressed, isNull);

    await tester.tap(find.byKey(const Key('activity-invite-admin')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('activity-professional-search')), 'Marina');
    await tester.pump(const Duration(milliseconds: 351));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('activity-professional-professional-1')));
    await tester.pump();
    await tester.tap(find.text('Concluir convite'));
    await tester.pumpAndSettle();
    expect(find.text('Administrador da atividade'), findsOneWidget);
    expect(find.text('Notas · Em breve'), findsOneWidget);

    await tester.tap(find.byKey(const Key('activity-form-submit')));
    await tester.pumpAndSettle();
    expect(submittedDraft?.groupIds, {'institution-1-group-1'});
    expect(submittedDraft?.assignments, hasLength(2));
    final submitted = submittedDraft!;
    expect(
      submitted.aboutPage?.fields
          .singleWhere((field) => field.key == ProfileAboutFieldKey.objective)
          .value,
      'Desenvolver raciocínio lógico',
    );
    final submittedInstructor = submitted.assignments.firstWhere(
      (item) => item.role == ActivityAssignmentRole.instructor,
    );
    expect(submittedInstructor.groupId, 'institution-1-group-1');
    expect(submittedInstructor.professionalId, 'professional-1');
    expect(submittedInstructor.permissions.happens, ActivityProfessionalAccess.both);
    final submittedAdmin = submitted.assignments.firstWhere(
      (item) => item.role == ActivityAssignmentRole.activityAdmin,
    );
    expect(submittedAdmin.groupId, isNull);
    expect(submittedAdmin.professionalId, 'professional-1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('creates a unit-scoped local and keeps edit institution fixed', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('activity-form-name')), 'Música');
    await tester.tap(find.byKey(const Key('activity-form-continue')));
    await tester.pumpAndSettle();
    tester
        .widget<CoeloAdminSingleSelectField<String>>(
          find.byKey(const Key('activity-form-institution')),
        )
        .onChanged('institution-1');
    await tester.pump();
    await tester.tap(find.byKey(const Key('activity-unit-institution-1-unit-1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('activity-create-location')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('activity-create-location-dialog')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('activity-location-name')), 'Sala maker');
    await tester.tap(find.byKey(const Key('activity-location-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Sala maker'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_app(activityId: 'activity-3'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('step-identidade')));
    await tester.pump();
    final governance = tester.widget<CoeloAdminSingleSelectField<ActivityGovernance>>(
      find.byKey(const Key('activity-form-governance')),
    );
    expect(governance.enabled, isFalse);
    expect(governance.value, ActivityGovernance.fixed);
  });

  testWidgets('edit route reloads when the activity id changes in place', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(activityId: 'activity-1'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(find.byKey(const Key('activity-form-name'))).controller?.text,
      'Música',
    );

    await tester.pumpWidget(_app(activityId: 'activity-2'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(find.byKey(const Key('activity-form-name'))).controller?.text,
      'Dança',
    );
  });

  testWidgets('edit route ignores an older activity response after an A to B swap', (tester) async {
    final repositoryA = _DelayedActivityRepository();
    final repositoryB = _DelayedActivityRepository();
    ActivityFormDraft? saved;

    await tester.pumpWidget(
      _app(
        activityId: 'activity-1',
        repository: repositoryA,
        onSaveDraft: (draft) async => saved = draft,
      ),
    );
    await tester.pump();
    await tester.pumpWidget(
      _app(
        activityId: 'activity-2',
        repository: repositoryB,
        onSaveDraft: (draft) async => saved = draft,
      ),
    );
    await tester.pump();

    await repositoryB.complete('activity-2');
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(find.byKey(const Key('activity-form-name'))).controller?.text,
      'Dança',
    );

    await repositoryA.complete('activity-1');
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(find.byKey(const Key('activity-form-name'))).controller?.text,
      'Dança',
    );

    await tester.tap(find.byKey(const Key('activity-form-save-draft')));
    await tester.pumpAndSettle();
    expect(saved?.name, 'Dança');
  });

  testWidgets('failed draft save exposes retry and preserves the draft', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      _app(
        onSaveDraft: (_) async {
          attempts++;
          if (attempts == 1) throw const ActivityDirectoryUnavailableException();
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('activity-form-name')), 'Robótica');
    await tester.tap(find.byKey(const Key('activity-form-continue')));
    await tester.pumpAndSettle();
    final institution = tester.widget<CoeloAdminSingleSelectField<String>>(
      find.byKey(const Key('activity-form-institution')),
    );
    institution.onChanged('institution-1');
    await tester.pump();
    final selectedUnit = find.byKey(const Key('activity-unit-institution-1-unit-1'));
    await tester.ensureVisible(selectedUnit);
    await tester.tap(selectedUnit);
    await tester.pump();
    await tester.tap(find.byKey(const Key('activity-form-save-draft')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('activity-form-command-error')), findsOneWidget);
    expect(find.text('Não foi possível salvar o rascunho.'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);

    final retry = find.text('Tentar novamente');
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.byKey(const Key('activity-form-command-error')), findsNothing);
    await tester.tap(find.byKey(const Key('activity-form-previous')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(find.byKey(const Key('activity-form-name'))).controller?.text,
      'Robótica',
    );
  });

  testWidgets('preserves a complete initial draft through the edit page contract', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ActivityFormDraft? savedDraft;
    const initialDraft = ActivityFormDraft(
      name: 'Ingl\u00EAs avan\u00E7ado',
      description: 'Conversa\u00E7\u00E3o para a Turma 1.',
      taxonomy: _languagesTaxonomy,
      subtype: null,
      template: _englishTemplate,
      taxonomyOtherDescription: '',
      governance: ActivityGovernance.optional,
      institutionId: 'institution-1',
      unitIds: {'institution-1-unit-1'},
      locationId: 'institution-1-unit-1-location-1',
      groupIds: {'institution-1-group-1'},
      assignments: [
        ActivityProfessionalAssignment(
          groupId: 'institution-1-group-1',
          professionalId: 'professional-1',
          permissions: ActivityProfessionalPermissions(
            happens: ActivityProfessionalAccess.both,
            now: ActivityProfessionalAccess.none,
            moments: ActivityProfessionalAccess.both,
            chat: ActivityProfessionalAccess.none,
          ),
        ),
      ],
      imageName: 'atividade.png',
      identityStorageRef: ActivityIdentityStorageRef(
        bucket: 'coelo-identities',
        path: 'activities/activity-1/profile.webp',
      ),
    );

    await tester.pumpWidget(
      _app(
        activityId: 'activity-1',
        initialDraft: initialDraft,
        onSaveDraft: (draft) async => savedDraft = draft,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextFormField>(find.byKey(const Key('activity-form-name'))).controller?.text,
      'Ingl\u00EAs avan\u00E7ado',
    );
    expect(find.text('Trocar foto'), findsOneWidget);
    expect(
      tester
          .widget<CoeloAdminSingleSelectField<ActivityTaxonomyOption?>>(
            find.byKey(const Key('activity-form-category')),
          )
          .value,
      _languagesTaxonomy,
    );

    await tester.tap(find.byKey(const Key('activity-form-save-draft')));
    await tester.pumpAndSettle();

    expect(savedDraft?.taxonomy, _languagesTaxonomy);
    expect(savedDraft?.template, _englishTemplate);
    expect(savedDraft?.institutionId, 'institution-1');
    expect(savedDraft?.unitIds, {'institution-1-unit-1'});
    expect(savedDraft?.locationId, 'institution-1-unit-1-location-1');
    expect(savedDraft?.groupIds, {'institution-1-group-1'});
    expect(savedDraft?.assignments.single.professionalId, 'professional-1');
    expect(savedDraft?.assignments.single.permissions.now, ActivityProfessionalAccess.none);
    expect(savedDraft?.assignments.single.permissions.chat, ActivityProfessionalAccess.none);
    expect(savedDraft?.imageName, 'atividade.png');
    expect(savedDraft?.identityStorageRef, initialDraft.identityStorageRef);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stacks local selector and create action at full width on compact screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('activity-form-name')), 'Robótica');
    await tester.tap(find.byKey(const Key('activity-form-continue')));
    await tester.pumpAndSettle();
    tester
        .widget<CoeloAdminSingleSelectField<String>>(
          find.byKey(const Key('activity-form-institution')),
        )
        .onChanged('institution-1');
    await tester.pump();
    await tester.tap(find.byKey(const Key('activity-unit-institution-1-unit-1')));
    await tester.ensureVisible(find.byKey(const Key('activity-unit-institution-1-unit-1')));
    await tester.pumpAndSettle();
    await tester.pump();

    final selectorRect = tester.getRect(find.byKey(const Key('activity-form-location')));
    final actionRect = tester.getRect(find.byKey(const Key('activity-create-location')));
    expect(actionRect.top, greaterThan(selectorRect.bottom));
    expect(actionRect.width, closeTo(selectorRect.width, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('supports 200 percent text at all approved widths', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 1000);
      await tester.pumpWidget(_app(textScaler: const TextScaler.linear(2)));
      await tester.pumpAndSettle();
      if (width < 768) {
        expect(find.text('Etapa 1 de 6'), findsOneWidget);
      } else {
        expect(find.text('Etapa 1 de 6'), findsNothing);
        expect(tester.getSize(find.byType(SuperadminFormStepNavigation)).width, 248);
      }
      expect(tester.takeException(), isNull, reason: '$width overflow');
    }
  });

  testWidgets('integrates the pedagogical configuration as step 3 of the activity wizard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    tester
        .widget<SuperadminFormStepNavigation>(find.byType(SuperadminFormStepNavigation))
        .onStepSelected(2);
    await tester.pumpAndSettle();

    expect(find.text('Etapa 3 de 6'), findsOneWidget);
    expect(find.byKey(const Key('activity-assessment-enabled')), findsOneWidget);
    expect(find.text('Configuração pedagógica'), findsWidgets);
    expect(find.byType(CoeloDateRangeField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Profile About is fail-closed without an approved production repository', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        initialInstitutionId: 'institution-1',
        initialStep: ActivityFormStep.about,
        aboutRepository: const UnavailableActivityProfileAboutRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('activity-about-unavailable')), findsOneWidget);
    expect(find.byKey(const Key('activity-about-editor')), findsNothing);
    expect(find.text('Sobre indisponível'), findsOneWidget);
  });

  testWidgets('pedagogical step uses canonical date and time fields without overflow', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 1800);
      await tester.pumpWidget(_app(textScaler: const TextScaler.linear(2)));
      await tester.pumpAndSettle();
      tester
          .widget<SuperadminFormStepNavigation>(find.byType(SuperadminFormStepNavigation))
          .onStepSelected(2);
      await tester.pumpAndSettle();
      tester
          .widget<CoeloAdminToggleField>(find.byKey(const Key('activity-assessment-enabled')))
          .onChanged!(true);
      await tester.pumpAndSettle();

      expect(find.byType(CoeloDateRangeField), findsAtLeastNWidgets(1));
      expect(find.byType(CoeloDateTimeField), findsAtLeastNWidgets(2));
      final preset = tester.widget<CoeloAdminSingleSelectField<String>>(
        find.byKey(const Key('activity-assessment-preset')),
      );
      expect(preset.options, hasLength(7));
      expect(
        preset.options.skip(1).map(preset.optionLabel),
        containsAll([
          'Educação infantil',
          'Ensino fundamental',
          'Idiomas',
          'Esportes',
          'Dança/Ballet',
          'Atividades culturais',
        ]),
      );
      expect(find.byKey(const Key('activity-assessment-grade-scale')), findsOneWidget);
      expect(find.byKey(const Key('activity-assessment-weight-total')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$width overflow');
    }
  });
}

Widget _app({
  String? activityId,
  ActivityFormDraft? initialDraft,
  ActivityDirectoryRepository? repository,
  String? initialInstitutionId,
  ActivityFormStep? initialStep,
  ActivityProfileAboutRepository? aboutRepository,
  Future<void> Function(ActivityFormDraft)? onSaveDraft,
  Future<void> Function(ActivityFormDraft)? onSubmit,
  TextScaler textScaler = TextScaler.noScaling,
}) => MaterialApp(
  theme: CoeloTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: textScaler),
    child: child!,
  ),
  home: ActivityFormPage(
    activityId: activityId,
    initialInstitutionId: initialInstitutionId,
    initialDraft: initialDraft,
    initialStep: initialStep,
    repository: repository ?? _TaxonomyOptionsRepository(),
    logout: () async => const LogoutResult.success(),
    onCancel: () {},
    onSaveDraft: onSaveDraft ?? (_) async {},
    onSubmit: onSubmit ?? (_) async {},
    onCreateLocation: (draft) async => [
      for (final unitId in draft.unitIds)
        ActivityFormLocationOption(
          id: 'session-location-$unitId',
          unitId: unitId,
          name: draft.name,
        ),
    ],
    imagePicker: () async => null,
    aboutRepository: aboutRepository ?? DevelopmentActivityProfileAboutRepository(),
  ),
);

final class _ProfessionalOptionsRepository implements ActivityDirectoryRepository {
  final FakeActivityDirectoryRepository _delegate = FakeActivityDirectoryRepository();

  @override
  Future<ActivityDetail?> fetchById(String activityId) => _delegate.fetchById(activityId);

  @override
  Future<ActivityFilterOptions> fetchFilterOptions() => _delegate.fetchFilterOptions();

  @override
  Future<ActivityFormOptions> fetchFormOptions({required String institutionId}) async {
    final options = await _delegate.fetchFormOptions(institutionId: institutionId);
    return ActivityFormOptions(
      institutions: options.institutions,
      units: options.units,
      locations: options.locations,
      groups: options.groups,
      professionals: const [
        ActivityFormProfessionalOption(
          id: 'professional-1',
          name: 'Marina Costa',
          role: 'Professora',
        ),
      ],
      taxonomy: const [_languagesTaxonomy, _otherTaxonomy],
      templates: const [_englishTemplate],
    );
  }

  @override
  Future<ActivityTemplateOptions> fetchTemplateOptions({String? institutionId}) =>
      _delegate.fetchTemplateOptions(institutionId: institutionId);

  @override
  Future<List<ActivityFormProfessionalOption>> searchProfessionals({
    required String institutionId,
    required String query,
    int limit = 20,
  }) async => const [
    ActivityFormProfessionalOption(id: 'professional-1', name: 'Marina Costa', role: 'Professora'),
  ];

  @override
  Future<ActivityDirectoryResult> fetchPage(ActivityDirectoryQuery query) =>
      _delegate.fetchPage(query);
}

final class _RecoveringCatalogRepository extends FakeActivityDirectoryRepository {
  int templateCalls = 0;

  @override
  Future<ActivityTemplateOptions> fetchTemplateOptions({String? institutionId}) {
    templateCalls++;
    if (templateCalls == 1) {
      return Future.error(const ActivityDirectoryUnavailableException());
    }
    return super.fetchTemplateOptions(institutionId: institutionId);
  }
}

const _languagesTaxonomy = ActivityTaxonomyOption(id: 'languages', label: 'Idiomas');
const _otherTaxonomy = ActivityTaxonomyOption(id: 'other', label: 'Outros', isOther: true);
const _englishTemplate = ActivityTemplateOption(
  id: 'english',
  name: 'Inglês',
  taxonomyId: 'languages',
);

final class _TaxonomyOptionsRepository implements ActivityDirectoryRepository {
  final FakeActivityDirectoryRepository _delegate = FakeActivityDirectoryRepository();

  @override
  Future<ActivityDetail?> fetchById(String activityId) => _delegate.fetchById(activityId);

  @override
  Future<ActivityFilterOptions> fetchFilterOptions() => _delegate.fetchFilterOptions();

  @override
  Future<ActivityFormOptions> fetchFormOptions({required String institutionId}) async {
    final options = await _delegate.fetchFormOptions(institutionId: institutionId);
    return ActivityFormOptions(
      institutions: options.institutions,
      units: options.units,
      locations: options.locations,
      groups: options.groups,
      professionals: options.professionals,
      taxonomy: const [_languagesTaxonomy, _otherTaxonomy],
      templates: const [_englishTemplate],
    );
  }

  @override
  Future<ActivityTemplateOptions> fetchTemplateOptions({String? institutionId}) async {
    final options = await fetchFormOptions(institutionId: institutionId ?? 'institution-1');
    return ActivityTemplateOptions(
      institutions: options.institutions,
      taxonomy: options.taxonomy,
      templates: options.templates,
    );
  }

  @override
  Future<List<ActivityFormProfessionalOption>> searchProfessionals({
    required String institutionId,
    required String query,
    int limit = 20,
  }) => _delegate.searchProfessionals(institutionId: institutionId, query: query, limit: limit);

  @override
  Future<ActivityDirectoryResult> fetchPage(ActivityDirectoryQuery query) =>
      _delegate.fetchPage(query);
}

final class _DelayedActivityRepository implements ActivityDirectoryRepository {
  final FakeActivityDirectoryRepository _delegate = FakeActivityDirectoryRepository();
  final Map<String, Completer<ActivityDetail?>> _requests = {};

  Future<void> complete(String activityId) async {
    _requests[activityId]!.complete(await _delegate.fetchById(activityId));
  }

  @override
  Future<ActivityDetail?> fetchById(String activityId) =>
      (_requests[activityId] ??= Completer<ActivityDetail?>()).future;

  @override
  Future<ActivityFilterOptions> fetchFilterOptions() => _delegate.fetchFilterOptions();

  @override
  Future<ActivityFormOptions> fetchFormOptions({required String institutionId}) =>
      _delegate.fetchFormOptions(institutionId: institutionId);

  @override
  Future<ActivityTemplateOptions> fetchTemplateOptions({String? institutionId}) =>
      _delegate.fetchTemplateOptions(institutionId: institutionId);

  @override
  Future<List<ActivityFormProfessionalOption>> searchProfessionals({
    required String institutionId,
    required String query,
    int limit = 20,
  }) => _delegate.searchProfessionals(institutionId: institutionId, query: query, limit: limit);

  @override
  Future<ActivityDirectoryResult> fetchPage(ActivityDirectoryQuery query) =>
      _delegate.fetchPage(query);
}

final class _DenseOptionsRepository implements ActivityDirectoryRepository {
  final FakeActivityDirectoryRepository _delegate = FakeActivityDirectoryRepository();

  @override
  Future<ActivityDetail?> fetchById(String activityId) => _delegate.fetchById(activityId);

  @override
  Future<ActivityFilterOptions> fetchFilterOptions() => _delegate.fetchFilterOptions();

  @override
  Future<ActivityFormOptions> fetchFormOptions({required String institutionId}) async =>
      ActivityFormOptions(
        institutions: const [
          ActivityFormInstitutionOption(id: 'institution-1', name: 'Colégio Horizonte'),
        ],
        units: [
          for (var index = 1; index <= 7; index++)
            ActivityFormUnitOption(
              id: 'unit-$index',
              institutionId: 'institution-1',
              name: 'Unidade $index',
            ),
        ],
        groups: [
          for (var index = 1; index <= 7; index++)
            ActivityFormGroupOption(
              id: 'group-$index',
              unitId: 'unit-7',
              name: 'Turma $index',
              participantCount: 14 + index,
            ),
        ],
        students: const [
          ActivityFormStudentOption(
            childGroupLinkId: 'child-group-link-7',
            id: 'child-7',
            groupId: 'group-7',
            name: 'Ana Silva',
            age: 9,
            gender: 'Feminino',
          ),
        ],
      );

  @override
  Future<ActivityTemplateOptions> fetchTemplateOptions({String? institutionId}) async =>
      const ActivityTemplateOptions(
        institutions: [
          ActivityFormInstitutionOption(id: 'institution-1', name: 'Colégio Horizonte'),
        ],
      );

  @override
  Future<List<ActivityFormProfessionalOption>> searchProfessionals({
    required String institutionId,
    required String query,
    int limit = 20,
  }) async => const [];

  @override
  Future<ActivityDirectoryResult> fetchPage(ActivityDirectoryQuery query) =>
      _delegate.fetchPage(query);
}
