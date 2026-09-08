import 'dart:async';

import 'package:coelo_superadmin/features/meal_plans/data/dev/development_meal_plan_repository.dart';
import 'package:coelo_superadmin/features/meal_plans/domain/meal_plan_image_repository.dart';
import 'package:coelo_superadmin/features/meal_plans/domain/meal_plan_repository.dart';
import 'package:coelo_superadmin/features/meal_plans/presentation/meal_plan_wizard_page.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_action_footer.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_frame.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_step_navigation.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('image selection is fail-closed until the private R2 gateway is composed', () {
    final page = MealPlanWizardPage(
      repository: DevelopmentMealPlanRepository(),
      imageRepository: const UnavailableMealPlanImageRepository(),
      onSaved: () {},
      onCancel: () {},
    );

    expect(page.imageSelectionEnabled, isFalse);
  });

  for (final destination in ['same', 'other', 'new']) {
    testWidgets('template editing preserves unknown fields only for $destination resource', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _TemplateUnknownFieldsRepository();
      Widget page(String? id) => MaterialApp(
        home: Scaffold(
          body: MealPlanWizardPage(
            repository: repository,
            imageRepository: const UnavailableMealPlanImageRepository(),
            imageSelectionEnabled: false,
            isTemplate: true,
            mealPlanModelId: id,
            onSaved: () {},
            onCancel: () {},
          ),
        ),
      );
      await tester.pumpWidget(page('model-a'));
      await tester.pumpAndSettle();
      if (destination != 'same') {
        await tester.pumpWidget(page(destination == 'other' ? 'model-b' : null));
        await tester.pumpAndSettle();
      }
      if (destination == 'new') {
        await tester.enterText(find.byType(TextFormField).first, 'Modelo novo');
      }
      await _selectAudienceOption(tester, 'Instituição do modelo', 'Colégio Coelo');
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).first, 'Prato alterado');
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pump();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Salvar rascunho'));
      await tester.pumpAndSettle();
      expect(repository.savedDrafts, hasLength(1));
      final draft = repository.savedDrafts.single;
      expect(
        draft.id,
        destination == 'same'
            ? 'model-a'
            : destination == 'other'
            ? 'model-b'
            : null,
      );
      expect(
        draft.payload['futureField'],
        destination == 'new' ? null : {'resource': destination == 'same' ? 'model-a' : 'model-b'},
      );
      expect((draft.payload['menu'] as List).single['dishName'], 'Prato alterado');
      expect(tester.takeException(), isNull);
    });
  }
  for (final selection in ['replace', 'clear', 'retain']) {
    testWidgets('source template selection $selection preserves matching content and version', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _SourceTemplateRepository(
        editing: true,
        missing: false,
        includeAlternative: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MealPlanWizardPage(
              repository: repository,
              imageRepository: const UnavailableMealPlanImageRepository(),
              imageSelectionEnabled: false,
              mealPlanId: 'existing-plan',
              onSaved: () {},
              onCancel: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final field = find.byWidgetPredicate(
        (widget) => widget is CoeloAdminSingleSelectField<String> && widget.label == 'Modelo-base',
      );
      await tester.tap(find.descendant(of: field, matching: find.text('Modelo histórico')));
      await tester.pumpAndSettle();
      final option = switch (selection) {
        'replace' => 'Modelo v4',
        'clear' => 'Criar sem modelo',
        _ => 'Modelo histórico',
      };
      await tester.tap(find.text(option).last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pump();
      await _selectAudienceOption(tester, 'Instituições', 'Colégio Coelo');
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pump();
      final expectedDish = selection == 'replace' ? 'Prato detalhe v4' : 'Prato histórico v1';
      expect(find.text(expectedDish), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pump();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Salvar rascunho'));
      await tester.pumpAndSettle();
      expect(repository.savedDrafts, hasLength(1));
      final draft = repository.savedDrafts.single;
      expect(draft.sourceTemplateId, switch (selection) {
        'replace' => 'alternative-template',
        'clear' => null,
        _ => 'source-template',
      });
      expect(draft.sourceTemplateVersion, switch (selection) {
        'replace' => 4,
        'clear' => null,
        _ => 1,
      });
      expect(draft.menu.single.dishName, expectedDish);
      expect(tester.takeException(), isNull);
    });
  }
  for (final editing in [false, true]) {
    for (final missing in [false, true]) {
      testWidgets('source template version survives page editing=$editing missing=$missing', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(1440, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repository = _SourceTemplateRepository(editing: editing, missing: missing);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MealPlanWizardPage(
                repository: repository,
                imageRepository: const UnavailableMealPlanImageRepository(),
                imageSelectionEnabled: false,
                mealPlanId: editing ? 'existing-plan' : null,
                templatePlanId: editing ? null : 'source-template',
                onSaved: () {},
                onCancel: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
        await tester.pump();
        await _selectAudienceOption(tester, 'Instituições', 'Colégio Coelo');
        await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
        await tester.pump();
        expect(find.text(editing ? 'Prato histórico v1' : 'Prato detalhe v3'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
        await tester.pump();
        await tester.tap(find.widgetWithText(OutlinedButton, 'Salvar rascunho'));
        await tester.pumpAndSettle();
        expect(repository.savedDrafts, hasLength(1));
        final draft = repository.savedDrafts.single;
        expect(draft.sourceTemplateId, 'source-template');
        expect(draft.sourceTemplateVersion, editing ? 1 : 3);
        expect(draft.menu.single.dishName, editing ? 'Prato histórico v1' : 'Prato detalhe v3');
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final status in ['draft', 'archived', 'active', 'published']) {
    testWidgets('template publication requires published response $status', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _TemplatePublicationRepository(status);
      var savedCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MealPlanWizardPage(
              repository: repository,
              imageRepository: const UnavailableMealPlanImageRepository(),
              imageSelectionEnabled: false,
              isTemplate: true,
              onSaved: () => savedCount++,
              onCancel: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Modelo publicado');
      await _selectAudienceOption(tester, 'Instituição do modelo', 'Colégio Coelo');
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).first, 'Arroz e feijão');
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Publicar modelo'));
      await tester.pumpAndSettle();
      expect(repository.calls, 1);
      expect(savedCount, status == 'published' ? 1 : 0);
      expect(
        find.text('Não foi possível confirmar a publicação do modelo.'),
        status == 'published' ? findsNothing : findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
  for (final stage in ['conflicts', 'review', 'publish']) {
    for (final validation in <bool?>[false, true, null]) {
      testWidgets('retry preserves confirmed resource after $stage validation=$validation', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(1440, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repository = _RejectedContinuationRepository(stage, validation);
        var savedCount = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MealPlanWizardPage(
                repository: repository,
                imageRepository: const UnavailableMealPlanImageRepository(),
                imageSelectionEnabled: false,
                onSaved: () => savedCount++,
                onCancel: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).first, 'Cardápio retomado');
        await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
        await tester.pump();
        await _selectAudienceOption(tester, 'Instituições', 'Colégio Coelo');
        await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
        await tester.pump();
        await tester.enterText(find.byType(TextFormField).first, 'Arroz e feijão');
        await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Enviar e publicar'));
        await tester.pumpAndSettle();
        expect(find.text('Continuação rejeitada.'), findsOneWidget);
        expect(savedCount, 0);
        final confirmed = repository.lastConfirmed!;
        final originalRequest = repository.drafts.single.requestId;
        await tester.tap(find.widgetWithText(FilledButton, 'Enviar e publicar'));
        await tester.pumpAndSettle();
        expect(repository.drafts, hasLength(2));
        if (validation == null) {
          // An uncertain transport result retains the original request,
          // including its original create identity, for idempotent replay.
          expect(repository.drafts.last.mealPlanId, isNull);
          expect(repository.drafts.last.expectedRevision, repository.drafts.first.expectedRevision);
          expect(repository.drafts.last.requestId, originalRequest);
        } else {
          expect(repository.drafts.last.mealPlanId, confirmed.id);
          expect(repository.drafts.last.expectedRevision, confirmed.revision);
          expect(repository.drafts.last.requestId, isNot(originalRequest));
        }
        expect(repository.lastConfirmed!.id, confirmed.id);
        expect(savedCount, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final outcome in [
    (status: MealPlanStatus.draft, isDraft: true, requiresReview: false),
    (status: MealPlanStatus.inReview, isDraft: false, requiresReview: true),
    (status: MealPlanStatus.published, isDraft: true, requiresReview: false),
    (status: MealPlanStatus.published, isDraft: false, requiresReview: true),
    (status: MealPlanStatus.published, isDraft: false, requiresReview: false),
  ]) {
    testWidgets('publication completion validates state $outcome', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _PendingMealPlanRepository(
        publicationStatus: outcome.status,
        publicationIsDraft: outcome.isDraft,
        publicationRequiresReview: outcome.requiresReview,
      );
      var savedCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MealPlanWizardPage(
              repository: repository,
              imageRepository: const UnavailableMealPlanImageRepository(),
              imageSelectionEnabled: false,
              onSaved: () => savedCount++,
              onCancel: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Cardápio publicado');
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pump();
      await _selectAudienceOption(tester, 'Instituições', 'Colégio Coelo');
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).first, 'Arroz e feijão');
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Enviar e publicar'));
      repository.pendingSave.complete(_plan('meal-a', 'Cardápio publicado'));
      await tester.pumpAndSettle();
      final valid =
          outcome.status == MealPlanStatus.published && !outcome.isDraft && !outcome.requiresReview;
      expect(savedCount, valid ? 1 : 0);
      expect(repository.publishCalls, 1);
      expect(
        find.text('Não foi possível confirmar a publicação do cardápio.'),
        valid ? findsNothing : findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final publish in [false, true]) {
    testWidgets('meal plan command is single flight before rebuild publish=$publish', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _PendingMealPlanRepository();
      var savedCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MealPlanWizardPage(
              repository: repository,
              imageRepository: const UnavailableMealPlanImageRepository(),
              imageSelectionEnabled: false,
              onSaved: () => savedCount++,
              onCancel: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Cardápio único');
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pump();
      await _selectAudienceOption(tester, 'Instituições', 'Colégio Coelo');
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).first, 'Arroz e feijão');
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pump();
      final save = tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Salvar rascunho'))
          .onPressed!;
      final submit = tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Enviar e publicar'))
          .onPressed!;
      final first = publish ? submit : save;
      first();
      first();
      (publish ? save : submit)();
      expect(repository.saveCalls, 1);
      await tester.pump();
      first();
      expect(repository.saveCalls, 1);
      repository.pendingSave.complete(_plan('meal-a', 'Cardápio único'));
      await tester.pumpAndSettle();
      expect(savedCount, 1);
      expect(repository.reviewCalls, publish ? 1 : 0);
      expect(repository.publishCalls, publish ? 1 : 0);
      await tester.pumpWidget(const SizedBox.shrink());
      first();
      await tester.pump();
      expect(repository.saveCalls, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'publication conflict retry updates the confirmed draft instead of creating another',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _ConflictMealPlanRepository();
      var savedCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MealPlanWizardPage(
              repository: repository,
              imageRepository: const UnavailableMealPlanImageRepository(),
              tenantId: 'dev-tenant',
              imageSelectionEnabled: false,
              onSaved: () => savedCount++,
              onCancel: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Cardápio com conflito');
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pump();
      await _selectAudienceOption(tester, 'Instituições', 'Colégio Coelo');
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).first, 'Arroz e feijão');
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Enviar e publicar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Publicação bloqueada:'), findsOneWidget);
      expect(repository.drafts.single.mealPlanId, isNull);
      final confirmed = repository.saved.single;
      await tester.tap(find.widgetWithText(OutlinedButton, 'Anterior'));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).first, 'Arroz, feijão e salada');
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Enviar e publicar'));
      await tester.pumpAndSettle();
      expect(repository.drafts, hasLength(2));
      expect(repository.drafts.last.mealPlanId, confirmed.id);
      expect(repository.drafts.last.expectedRevision, confirmed.revision);
      expect(repository.drafts.last.requestId, isNot(repository.drafts.first.requestId));
      expect(repository.saved.last.id, confirmed.id);
      expect(repository.reviewCalls, 0);
      expect(repository.publishCalls, 0);
      expect(savedCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final isTemplate in [false, true]) {
    testWidgets('dev ${isTemplate ? 'model' : 'meal plan'} opens in the canonical wizard', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MealPlanWizardPage(
              repository: DevelopmentMealPlanRepository(),
              imageRepository: const UnavailableMealPlanImageRepository(),
              tenantId: 'dev-tenant',
              imageSelectionEnabled: false,
              isTemplate: isTemplate,
              onSaved: () {},
              onCancel: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SuperadminFormFrame), findsOneWidget);
      expect(find.byType(SuperadminFormStepNavigation), findsOneWidget);
      expect(find.byType(SuperadminFormActionFooter), findsOneWidget);
      expect(find.text('Revise esta etapa'), findsNothing);
      expect(
        tester.widget<MealPlanWizardPage>(find.byType(MealPlanWizardPage)).tenantId,
        'dev-tenant',
      );
      expect(
        tester.widget<MealPlanWizardPage>(find.byType(MealPlanWizardPage)).imageSelectionEnabled,
        isFalse,
      );
      expect(find.text(isTemplate ? 'Novo modelo de cardápio' : 'Novo cardápio'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('dev meal plan navigates back and persists review then publish locally', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = DevelopmentMealPlanRepository();
    var savedCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MealPlanWizardPage(
            repository: repository,
            imageRepository: const UnavailableMealPlanImageRepository(),
            tenantId: 'dev-tenant',
            imageSelectionEnabled: false,
            onSaved: () => savedCount++,
            onCancel: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Cardápio da primavera');
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();
    await _selectAudienceOption(tester, 'Instituições', 'Colégio Coelo');
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).first, 'Arroz, feijão e salada');
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Anterior'));
    await tester.pump();
    expect(find.text('Refeição 1'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Enviar e publicar'));
    await tester.pumpAndSettle();

    expect(savedCount, 1);
    final created = (await repository.fetchPage(
      const MealPlanListFilter(pageSize: 100),
    )).items.singleWhere((item) => item.name == 'Cardápio da primavera');
    expect(created.status, MealPlanStatus.published);
    expect(tester.takeException(), isNull);
  });

  testWidgets('meal time picker follows dish name and details are multiline', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MealPlanWizardPage(
            repository: DevelopmentMealPlanRepository(),
            imageRepository: const UnavailableMealPlanImageRepository(),
            tenantId: 'dev-tenant',
            imageSelectionEnabled: false,
            onSaved: () {},
            onCancel: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Cardápio com horário');
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();
    await _selectAudienceOption(tester, 'Instituições', 'Colégio Coelo');
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();
    await tester.tap(find.text('Definir horário de início e fim'));
    await tester.pump();

    expect(find.byType(CoeloTimeField), findsNWidgets(2));
    expect(
      tester.getTopLeft(find.byType(CoeloTimeField).first).dy,
      greaterThan(tester.getTopLeft(find.byType(TextFormField).first).dy),
    );
    final details = tester.widget<CoeloFormTextField>(
      find.byWidgetPredicate(
        (widget) => widget is CoeloFormTextField && widget.labelText == 'Detalhes do prato',
      ),
    );
    expect(details.maxLines, greaterThan(1));

    await tester.tap(find.text('Selecionar hora').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('coelo-time-picker-dialog')), findsOneWidget);
  });

  testWidgets('contextual links follow the hierarchy and exclusions win over inclusions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MealPlanWizardPage(
            repository: DevelopmentMealPlanRepository(),
            imageRepository: const UnavailableMealPlanImageRepository(),
            tenantId: 'dev-tenant',
            imageSelectionEnabled: false,
            onSaved: () {},
            onCancel: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Cardápio com vínculos');
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Vínculos contextuais'), findsNWidgets(3));
    expect(find.byType(FilterChip), findsNothing);
    expect(find.byType(CoeloAdminMultiSelectField<String>), findsNWidgets(6));

    await _selectAudienceOption(tester, 'Instituições', 'Colégio Coelo');
    await _selectAudienceOption(tester, 'Pessoas incluídas', 'Helena Silva');
    await _selectAudienceOption(tester, 'Pessoas excluídas', 'Helena Silva');

    final included = tester.widget<CoeloAdminMultiSelectField<String>>(
      _audienceField('Pessoas incluídas'),
    );
    final excluded = tester.widget<CoeloAdminMultiSelectField<String>>(
      _audienceField('Pessoas excluídas'),
    );
    expect(included.selectedValues, isEmpty);
    expect(excluded.selectedValues, {'dev-child'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('route A cannot overwrite route B when meal plans load out of order', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _OrderedMealPlanRepository();

    Widget page(String id) => MaterialApp(
      home: Scaffold(
        body: MealPlanWizardPage(
          repository: repository,
          imageRepository: const UnavailableMealPlanImageRepository(),
          mealPlanId: id,
          tenantId: 'dev-tenant',
          imageSelectionEnabled: false,
          onSaved: () {},
          onCancel: () {},
        ),
      ),
    );

    await tester.pumpWidget(page('meal-a'));
    await tester.pump();
    await tester.pumpWidget(page('meal-b'));
    await tester.pump();

    expect(repository.requests.keys, contains('meal-b'));
    repository.requests['meal-b']!.complete(_plan('meal-b', 'Cardápio B'));
    await tester.pump();
    expect(find.text('Cardápio B'), findsOneWidget);

    repository.requests['meal-a']!.complete(_plan('meal-a', 'Cardápio A'));
    await tester.pump();
    expect(find.text('Cardápio B'), findsOneWidget);
    expect(find.text('Cardápio A'), findsNothing);
  });

  testWidgets('a pending save from route A cannot complete after swapping to route B', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _PendingMealPlanRepository();
    var savedCount = 0;

    Widget page(String? id) => MaterialApp(
      home: Scaffold(
        body: MealPlanWizardPage(
          repository: repository,
          imageRepository: const UnavailableMealPlanImageRepository(),
          mealPlanId: id,
          tenantId: 'dev-tenant',
          imageSelectionEnabled: false,
          onSaved: () => savedCount++,
          onCancel: () {},
        ),
      ),
    );

    await tester.pumpWidget(page(null));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Cardápio A');
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();
    await _selectAudienceOption(tester, 'Instituições', 'Colégio Coelo');
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).first, 'Arroz e feijão');
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Enviar e publicar'));
    await tester.pump();

    await tester.pumpWidget(page('meal-b'));
    await tester.pump();
    repository.requests['meal-b']!.complete(_plan('meal-b', 'Cardápio B'));
    await tester.pump();
    repository.pendingSave.complete(_plan('meal-a', 'Cardápio A'));
    await tester.pump();

    expect(savedCount, 0);
    expect(repository.reviewCalls, 0);
    expect(repository.publishCalls, 0);
    expect(find.text('Cardápio B'), findsOneWidget);
    expect(find.text('Cardápio A'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('load fails closed when repository returns another meal plan id', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _OrderedMealPlanRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MealPlanWizardPage(
            repository: repository,
            imageRepository: const UnavailableMealPlanImageRepository(),
            mealPlanId: 'meal-a',
            tenantId: 'dev-tenant',
            imageSelectionEnabled: false,
            onSaved: () {},
            onCancel: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    repository.requests['meal-a']!.complete(_plan('meal-b', 'Cardápio incorreto'));
    await tester.pump();

    expect(find.text('O cardápio solicitado não pôde ser validado.'), findsOneWidget);
    expect(find.text('Cardápio incorreto'), findsNothing);
  });
}

Finder _audienceField(String label) => find.byWidgetPredicate(
  (widget) => widget is CoeloAdminMultiSelectField<String> && widget.label == label,
);

Future<void> _selectAudienceOption(WidgetTester tester, String label, String option) async {
  await tester.tap(find.descendant(of: _audienceField(label), matching: find.text('Selecionar')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Aplicar'));
  await tester.pumpAndSettle();
}

MealPlan _plan(
  String id,
  String name, {
  MealPlanStatus status = MealPlanStatus.draft,
  bool isDraft = true,
  bool requiresReview = false,
  String? sourceTemplateId,
  int? sourceTemplateVersion,
  String? sourceTemplateName,
  String? dishName,
}) => MealPlan(
  id: id,
  tenantId: 'dev-tenant',
  name: name,
  status: status,
  sourceType: MealPlanSourceType.global,
  scopeLevel: MealPlanScopeLevel.global,
  scopeId: 'dev-tenant',
  startDate: DateTime(2026, 8, 24),
  endDate: DateTime(2026, 8, 30),
  recurrence: MealPlanRecurrence(
    kind: MealPlanRecurrenceKind.weekly,
    weekdays: const {1, 2, 3, 4, 5},
  ),
  menu: [
    MealPlanMenuEntry.fromJson({
      ...MealPlanMenuEntry.empty().toJson(),
      'dishName': dishName ?? '',
      if (dishName != null) 'weekdays': [1, 2, 3, 4, 5],
    }),
  ],
  allergens: const [],
  alerts: const [],
  attachments: const [],
  priority: 0,
  conflictState: false,
  revision: 1,
  isDraft: isDraft,
  requiresReview: requiresReview,
  createdBy: 'dev',
  updatedBy: 'dev',
  sourceTemplateId: sourceTemplateId,
  sourceTemplateVersion: sourceTemplateVersion,
  sourceTemplateName: sourceTemplateName,
);

class _OrderedMealPlanRepository implements MealPlanRepository {
  final _delegate = DevelopmentMealPlanRepository();
  final requests = <String, Completer<MealPlan>>{};

  @override
  Future<MealPlan> getById(String id) => (requests[id] = Completer<MealPlan>()).future;

  @override
  Future<MealPlanAudienceOptions> fetchAudienceOptions() => _delegate.fetchAudienceOptions();

  @override
  Future<MealPlanPage> fetchTemplatePage(MealPlanListFilter filter) =>
      _delegate.fetchTemplatePage(filter);

  @override
  Future<MealPlanPage> fetchPage(MealPlanListFilter filter) => _delegate.fetchPage(filter);

  @override
  Future<MealPlanTemplate> getTemplateById(String id) => _delegate.getTemplateById(id);

  @override
  Future<MealPlanTemplate> saveTemplate(MealPlanTemplateDraft draft, {required bool publish}) =>
      _delegate.saveTemplate(draft, publish: publish);

  @override
  Future<MealPlan> createOrUpdateDraft(MealPlanDraft draft) => _delegate.createOrUpdateDraft(draft);

  @override
  Future<MealPlan> submitForReview(String mealPlanId, String requestId, int expectedRevision) =>
      _delegate.submitForReview(mealPlanId, requestId, expectedRevision);

  @override
  Future<MealPlan> publish(String mealPlanId, String requestId, int expectedRevision) =>
      _delegate.publish(mealPlanId, requestId, expectedRevision);

  @override
  Future<List<MealPlanConflict>> checkConflicts({
    required String scopeLevel,
    required String scopeId,
    required DateTime startDate,
    required DateTime endDate,
    required MealPlanRecurrence recurrence,
    required List<MealPlanMenuEntry> menu,
  }) => _delegate.checkConflicts(
    scopeLevel: scopeLevel,
    scopeId: scopeId,
    startDate: startDate,
    endDate: endDate,
    recurrence: recurrence,
    menu: menu,
  );

  @override
  Future<MealPlan> fetchEffectiveSnapshot(MealPlanDraft draft) =>
      _delegate.fetchEffectiveSnapshot(draft);
}

final class _SourceTemplateRepository extends _OrderedMealPlanRepository {
  _SourceTemplateRepository({
    required this.editing,
    required this.missing,
    this.includeAlternative = false,
  });
  final bool editing, missing;
  final bool includeAlternative;
  final savedDrafts = <MealPlanDraft>[];
  MealPlanTemplate _template(int version, {String id = 'source-template'}) => MealPlanTemplate(
    id: id,
    name: 'Modelo v$version',
    planVariant: MealPlanPlanVariant.complete,
    audienceSegment: MealPlanAudienceSegment.students,
    status: 'published',
    version: version,
    payload: {
      'menu': [
        {
          ...MealPlanMenuEntry.empty().toJson(),
          'dishName': 'Prato detalhe v$version',
          'weekdays': [1, 2, 3, 4, 5],
        },
      ],
    },
    createdAt: DateTime(2026, 8, 1),
    updatedAt: DateTime(2026, 8, 2),
  );
  @override
  Future<MealPlanPage> fetchTemplatePage(MealPlanListFilter filter) async => MealPlanPage(
    items: missing
        ? []
        : [
            _template(2).toDirectoryItem(),
            if (includeAlternative) _template(4, id: 'alternative-template').toDirectoryItem(),
          ],
    total: missing
        ? 101
        : includeAlternative
        ? 2
        : 1,
    limit: filter.pageSize,
    offset: filter.offset,
  );
  @override
  Future<MealPlanTemplate> getTemplateById(String id) async => _template(3);
  @override
  Future<MealPlan> getById(String id) async => _plan(
    id,
    'Cardápio histórico',
    sourceTemplateId: 'source-template',
    sourceTemplateVersion: 1,
    sourceTemplateName: 'Modelo histórico',
    dishName: 'Prato histórico v1',
  );
  @override
  Future<MealPlan> createOrUpdateDraft(MealPlanDraft draft) async {
    savedDrafts.add(draft);
    return _plan(draft.mealPlanId ?? 'created-plan', draft.name);
  }
}

final class _TemplateUnknownFieldsRepository extends _OrderedMealPlanRepository {
  final savedDrafts = <MealPlanTemplateDraft>[];
  @override
  Future<MealPlanTemplate> getTemplateById(String id) async => MealPlanTemplate(
    id: id,
    name: 'Modelo $id',
    planVariant: MealPlanPlanVariant.complete,
    audienceSegment: MealPlanAudienceSegment.students,
    status: 'draft',
    version: 2,
    payload: {
      'menu': [
        {
          ...MealPlanMenuEntry.empty().toJson(),
          'dishName': 'Prato original',
          'weekdays': [1, 2, 3, 4, 5],
        },
      ],
      'futureField': {'resource': id},
    },
    createdAt: DateTime(2026, 9, 1),
    updatedAt: DateTime(2026, 9, 1),
  );
  @override
  Future<MealPlanTemplate> saveTemplate(
    MealPlanTemplateDraft draft, {
    required bool publish,
  }) async {
    savedDrafts.add(draft);
    return getTemplateById(draft.id ?? 'new-model');
  }
}

final class _TemplatePublicationRepository extends _OrderedMealPlanRepository {
  _TemplatePublicationRepository(this.status);
  final String status;
  int calls = 0;

  @override
  Future<MealPlanTemplate> saveTemplate(
    MealPlanTemplateDraft draft, {
    required bool publish,
  }) async {
    calls++;
    expect(publish, isTrue);
    return MealPlanTemplate(
      id: draft.id ?? 'template-confirmed',
      name: draft.name,
      planVariant: draft.planVariant,
      audienceSegment: draft.audienceSegment,
      status: status,
      version: 1,
      payload: draft.payload,
      createdAt: DateTime(2026, 9, 8),
      updatedAt: DateTime(2026, 9, 8),
    );
  }
}

final class _ConflictMealPlanRepository extends _OrderedMealPlanRepository {
  final drafts = <MealPlanDraft>[];
  final saved = <MealPlan>[];
  int reviewCalls = 0;
  int publishCalls = 0;

  @override
  Future<MealPlan> createOrUpdateDraft(MealPlanDraft draft) async {
    drafts.add(draft);
    final result = await super.createOrUpdateDraft(draft);
    saved.add(result);
    return result;
  }

  @override
  Future<List<MealPlanConflict>> checkConflicts({
    required String scopeLevel,
    required String scopeId,
    required DateTime startDate,
    required DateTime endDate,
    required MealPlanRecurrence recurrence,
    required List<MealPlanMenuEntry> menu,
  }) async => [
    MealPlanConflict.fromJson(const {'scopeLevel': 'institution'}),
  ];

  @override
  Future<MealPlan> submitForReview(String id, String request, int revision) {
    reviewCalls++;
    return super.submitForReview(id, request, revision);
  }

  @override
  Future<MealPlan> publish(String id, String request, int revision) {
    publishCalls++;
    return super.publish(id, request, revision);
  }
}

final class _RejectedContinuationRepository extends _OrderedMealPlanRepository {
  _RejectedContinuationRepository(this.stage, this.validation);
  final String stage;
  final bool? validation;
  bool rejected = false;
  MealPlan? lastConfirmed;
  final drafts = <MealPlanDraft>[];

  void _reject(String current) {
    if (stage != current || rejected) return;
    rejected = true;
    if (validation == null) throw const MealPlanUnavailableException('Continuação rejeitada.');
    if (validation!) throw const MealPlanValidationException('Continuação rejeitada.');
    throw const MealPlanConflictException('Continuação rejeitada.');
  }

  @override
  Future<MealPlan> createOrUpdateDraft(MealPlanDraft draft) async {
    drafts.add(draft);
    return lastConfirmed = await super.createOrUpdateDraft(draft);
  }

  @override
  Future<List<MealPlanConflict>> checkConflicts({
    required String scopeLevel,
    required String scopeId,
    required DateTime startDate,
    required DateTime endDate,
    required MealPlanRecurrence recurrence,
    required List<MealPlanMenuEntry> menu,
  }) async {
    _reject('conflicts');
    return const [];
  }

  @override
  Future<MealPlan> submitForReview(String id, String request, int revision) async {
    _reject('review');
    return lastConfirmed = await super.submitForReview(id, request, revision);
  }

  @override
  Future<MealPlan> publish(String id, String request, int revision) async {
    _reject('publish');
    return lastConfirmed = await super.publish(id, request, revision);
  }
}

final class _PendingMealPlanRepository extends _OrderedMealPlanRepository {
  _PendingMealPlanRepository({
    this.publicationStatus = MealPlanStatus.published,
    this.publicationIsDraft = false,
    this.publicationRequiresReview = false,
  });
  final MealPlanStatus publicationStatus;
  final bool publicationIsDraft;
  final bool publicationRequiresReview;
  final pendingSave = Completer<MealPlan>();
  int saveCalls = 0;
  int reviewCalls = 0;
  int publishCalls = 0;

  @override
  Future<MealPlan> createOrUpdateDraft(MealPlanDraft draft) {
    saveCalls++;
    return pendingSave.future;
  }

  @override
  Future<List<MealPlanConflict>> checkConflicts({
    required String scopeLevel,
    required String scopeId,
    required DateTime startDate,
    required DateTime endDate,
    required MealPlanRecurrence recurrence,
    required List<MealPlanMenuEntry> menu,
  }) async => const [];

  @override
  Future<MealPlan> submitForReview(
    String mealPlanId,
    String requestId,
    int expectedRevision,
  ) async {
    reviewCalls++;
    return _plan(mealPlanId, 'Cardápio A');
  }

  @override
  Future<MealPlan> publish(String mealPlanId, String requestId, int expectedRevision) async {
    publishCalls++;
    return _plan(
      mealPlanId,
      'Cardápio A',
      status: publicationStatus,
      isDraft: publicationIsDraft,
      requiresReview: publicationRequiresReview,
    );
  }
}
