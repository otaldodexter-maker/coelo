import 'dart:async';
import 'dart:io';

import 'package:coelo_superadmin/features/meal_plans/domain/meal_plan_repository.dart';
import 'package:coelo_superadmin/features/meal_plans/domain/meal_plan_image_repository.dart';
import 'package:coelo_superadmin/features/meal_plans/presentation/meal_plan_directory_page.dart';
import 'package:coelo_superadmin/features/meal_plans/presentation/meal_plan_wizard_page.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_frame.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(_loadGoldenFonts);

  testWidgets('directory follows toolbar then tabs without a duplicate local header', (
    tester,
  ) async {
    _configureDesktop(tester);

    await tester.pumpWidget(
      _goldenApp(
        boundaryKey: const Key('meal-plan-directory-contract-root'),
        child: MealPlanDirectoryPage(
          repository: FakeMealPlanRepository(),
          onCreate: (_) {},
          onEdit: (_) {},
          onCreateTemplate: () {},
          onEditTemplate: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cardápios'), findsOneWidget);
    final searchTop = tester.getTopLeft(find.byType(CoeloSearchField)).dy;
    final tabsTop = tester.getTopLeft(find.byKey(const Key('meal-plan-type-tabs'))).dy;
    expect(searchTop, lessThan(tabsTop));
  });

  testWidgets('wizard uses the canonical Superadmin form frame', (tester) async {
    _configureDesktop(tester);

    await tester.pumpWidget(
      _goldenApp(
        boundaryKey: const Key('meal-plan-wizard-frame-contract-root'),
        child: MealPlanWizardPage(
          repository: FakeMealPlanRepository(),
          imageRepository: const _UnavailableMealPlanImageRepository(),
          onSaved: () {},
          onCancel: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SuperadminFormFrame), findsOneWidget);
  });

  testWidgets('last zero-based repository page disables next and preserves previous', (
    tester,
  ) async {
    _configureDesktop(tester);
    final repository = FakeMealPlanRepository(totalOverride: 25);

    await tester.pumpWidget(
      _goldenApp(
        boundaryKey: const Key('meal-plan-pagination-contract-root'),
        child: MealPlanDirectoryPage(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    var pagination = tester.widget<CoeloAdminPagination>(find.byType(CoeloAdminPagination));
    pagination.onPageSelected!(3);
    await tester.pumpAndSettle();

    expect(repository.lastPageFilter?.page, 2);
    pagination = tester.widget<CoeloAdminPagination>(find.byType(CoeloAdminPagination));
    expect(pagination.currentPage, 3);
    expect(pagination.totalPages, 3);
    expect(pagination.onPrevious, isNotNull);
    expect(pagination.onNext, isNull);
  });

  testWidgets('unauthorized directory is fail closed without controls or creation', (tester) async {
    _configureDesktop(tester);

    await tester.pumpWidget(
      _goldenApp(
        boundaryKey: const Key('meal-plan-unauthorized-contract-root'),
        child: MealPlanDirectoryPage(
          repository: FakeMealPlanRepository(
            pageLoader: (_) => Future<MealPlanPage>.error(const MealPlanUnauthorizedException()),
          ),
          onCreate: (_) {},
          onCreateTemplate: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('meal-plans-unauthorized')), findsOneWidget);
    expect(find.byType(CoeloSearchField), findsNothing);
    expect(find.byKey(const Key('meal-plan-type-tabs')), findsNothing);
    expect(find.byType(CoeloAdminCreateAction), findsNothing);
  });

  testWidgets('loading never offers creation before permission is known', (tester) async {
    _configureDesktop(tester);
    final page = Completer<MealPlanPage>();

    await tester.pumpWidget(
      _goldenApp(
        boundaryKey: const Key('meal-plan-loading-contract-root'),
        child: MealPlanDirectoryPage(
          repository: FakeMealPlanRepository(pageLoader: (_) => page.future),
          onCreate: (_) {},
          onCreateTemplate: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('meal-plans-loading')), findsOneWidget);
    expect(find.byType(CoeloAdminCreateAction), findsNothing);
    page.complete(const MealPlanPage(items: [], total: 0, limit: 12, offset: 0));
    await tester.pumpAndSettle();
  });

  testWidgets('missing callbacks disable create and card interaction instead of no-op success', (
    tester,
  ) async {
    _configureDesktop(tester);

    await tester.pumpWidget(
      _goldenApp(
        boundaryKey: const Key('meal-plan-callback-contract-root'),
        child: MealPlanDirectoryPage(repository: FakeMealPlanRepository()),
      ),
    );
    await tester.pumpAndSettle();

    final createActions = tester.widgetList<CoeloAdminCreateAction>(
      find.byType(CoeloAdminCreateAction),
    );
    expect(createActions, isNotEmpty);
    expect(createActions.every((action) => action.onPressed == null), isTrue);
    final cards = tester.widgetList<CoeloAdminInteractiveCard>(
      find.byType(CoeloAdminInteractiveCard),
    );
    expect(cards, isNotEmpty);
    expect(cards.every((card) => card.onPressed == null), isTrue);
  });

  testWidgets('matches the meal plan directory cards at desktop', (tester) async {
    _configureDesktop(tester);
    final repository = FakeMealPlanRepository();

    await tester.pumpWidget(
      _goldenApp(
        boundaryKey: const Key('meal-plan-directory-golden-root'),
        child: MealPlanDirectoryPage(
          repository: repository,
          onCreate: (_) {},
          onEdit: (_) {},
          onCreateTemplate: () {},
          onEditTemplate: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const Key('meal-plan-directory-golden-root')),
      matchesGoldenFile('goldens/meal_plan_directory_light_1440.png'),
    );
  });

  testWidgets('matches new meal plan identification at desktop', (tester) async {
    _configureDesktop(tester);

    await tester.pumpWidget(
      _goldenApp(
        boundaryKey: const Key('meal-plan-wizard-new-golden-root'),
        child: MealPlanWizardPage(
          repository: FakeMealPlanRepository(),
          imageRepository: const _UnavailableMealPlanImageRepository(),
          onSaved: () {},
          onCancel: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const Key('meal-plan-wizard-new-golden-root')),
      matchesGoldenFile('goldens/meal_plan_wizard_new_light_1440.png'),
    );
  });

  testWidgets('matches new meal plan model identification at desktop', (tester) async {
    _configureDesktop(tester);

    await tester.pumpWidget(
      _goldenApp(
        boundaryKey: const Key('meal-plan-model-new-golden-root'),
        child: MealPlanWizardPage(
          repository: FakeMealPlanRepository(),
          imageRepository: const _UnavailableMealPlanImageRepository(),
          isTemplate: true,
          onSaved: () {},
          onCancel: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const Key('meal-plan-model-new-golden-root')),
      matchesGoldenFile('goldens/meal_plan_model_new_light_1440.png'),
    );
  });

  testWidgets('matches the meal plan directory cards on mobile', (tester) async {
    _configureSize(tester, const Size(375, 1000));
    final repository = FakeMealPlanRepository();

    await tester.pumpWidget(
      _goldenApp(
        boundaryKey: const Key('meal-plan-directory-mobile-golden-root'),
        child: MealPlanDirectoryPage(
          repository: repository,
          onCreate: (_) {},
          onEdit: (_) {},
          onCreateTemplate: () {},
          onEditTemplate: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const Key('meal-plan-directory-mobile-golden-root')),
      matchesGoldenFile('goldens/meal_plan_directory_light_375.png'),
    );
  });

  testWidgets('matches the meal plan directory cards in dark theme', (tester) async {
    _configureDesktop(tester);
    final repository = FakeMealPlanRepository();

    await tester.pumpWidget(
      _goldenApp(
        boundaryKey: const Key('meal-plan-directory-dark-golden-root'),
        theme: CoeloTheme.dark,
        child: MealPlanDirectoryPage(
          repository: repository,
          onCreate: (_) {},
          onEdit: (_) {},
          onCreateTemplate: () {},
          onEditTemplate: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const Key('meal-plan-directory-dark-golden-root')),
      matchesGoldenFile('goldens/meal_plan_directory_dark_1440.png'),
    );
  });

  testWidgets('matches directory card hover at desktop', (tester) async {
    _configureDesktop(tester);
    final repository = FakeMealPlanRepository();

    await tester.pumpWidget(
      _goldenApp(
        boundaryKey: const Key('meal-plan-directory-hover-golden-root'),
        child: MealPlanDirectoryPage(
          repository: repository,
          onCreate: (_) {},
          onEdit: (_) {},
          onCreateTemplate: () {},
          onEditTemplate: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('Cardápio semanal - Educação Infantil')));
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const Key('meal-plan-directory-hover-golden-root')),
      matchesGoldenFile('goldens/meal_plan_directory_card_hover_light_1440.png'),
    );
  });

  testWidgets('matches directory flyout at desktop', (tester) async {
    _configureDesktop(tester);
    final repository = FakeMealPlanRepository();

    await tester.pumpWidget(
      _goldenApp(
        boundaryKey: const Key('meal-plan-directory-flyout-golden-root'),
        child: MealPlanDirectoryPage(
          repository: repository,
          onCreate: (_) {},
          onEdit: (_) {},
          onCreateTemplate: () {},
          onEditTemplate: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ações').first);
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const Key('meal-plan-directory-flyout-golden-root')),
      matchesGoldenFile('goldens/meal_plan_directory_flyout_light_1440.png'),
    );
  });

  testWidgets('matches new meal plan identification on mobile', (tester) async {
    _configureSize(tester, const Size(375, 1000));

    await tester.pumpWidget(
      _goldenApp(
        boundaryKey: const Key('meal-plan-wizard-new-mobile-golden-root'),
        child: MealPlanWizardPage(
          repository: FakeMealPlanRepository(),
          imageRepository: const _UnavailableMealPlanImageRepository(),
          onSaved: () {},
          onCancel: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const Key('meal-plan-wizard-new-mobile-golden-root')),
      matchesGoldenFile('goldens/meal_plan_wizard_new_light_375.png'),
    );
  });

  testWidgets('matches edit meal plan identification in dark theme', (tester) async {
    _configureDesktop(tester);

    await tester.pumpWidget(
      _goldenApp(
        boundaryKey: const Key('meal-plan-wizard-edit-dark-golden-root'),
        theme: CoeloTheme.dark,
        child: MealPlanWizardPage(
          repository: FakeMealPlanRepository(),
          imageRepository: const _UnavailableMealPlanImageRepository(),
          mealPlanId: _publishedPlan.id,
          onSaved: () {},
          onCancel: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const Key('meal-plan-wizard-edit-dark-golden-root')),
      matchesGoldenFile('goldens/meal_plan_wizard_edit_dark_1440.png'),
    );
  });

  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('renders directory and wizard without overflow at ${width.toInt()}', (
      tester,
    ) async {
      _configureSize(tester, Size(width, 1000));
      final repository = FakeMealPlanRepository();

      await tester.pumpWidget(
        _goldenApp(
          boundaryKey: Key('meal-plan-responsive-directory-${width.toInt()}'),
          child: MealPlanDirectoryPage(
            repository: repository,
            onCreate: (_) {},
            onEdit: (_) {},
            onCreateTemplate: () {},
            onEditTemplate: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        _goldenApp(
          boundaryKey: Key('meal-plan-responsive-wizard-${width.toInt()}'),
          child: MealPlanWizardPage(
            repository: repository,
            imageRepository: const _UnavailableMealPlanImageRepository(),
            onSaved: () {},
            onCancel: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('supports 200 percent text without overflow at ${width.toInt()}', (tester) async {
      _configureSize(tester, Size(width, 1200));
      final repository = FakeMealPlanRepository();

      await tester.pumpWidget(
        _goldenApp(
          boundaryKey: Key('meal-plan-text-scale-directory-${width.toInt()}'),
          textScale: 2,
          child: MealPlanDirectoryPage(
            repository: repository,
            onCreate: (_) {},
            onEdit: (_) {},
            onCreateTemplate: () {},
            onEditTemplate: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'directory width=$width textScale=2');

      await tester.pumpWidget(
        _goldenApp(
          boundaryKey: Key('meal-plan-text-scale-wizard-${width.toInt()}'),
          textScale: 2,
          child: MealPlanWizardPage(
            repository: repository,
            imageRepository: const _UnavailableMealPlanImageRepository(),
            onSaved: () {},
            onCancel: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'wizard width=$width textScale=2');
    });
  }
}

void _configureDesktop(WidgetTester tester) => _configureSize(tester, const Size(1440, 1000));

void _configureSize(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Widget _goldenApp({
  required Key boundaryKey,
  required Widget child,
  ThemeData? theme,
  double textScale = 1,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme ?? CoeloTheme.light.copyWith(scaffoldBackgroundColor: Colors.white),
    themeAnimationStyle: AnimationStyle.noAnimation,
    builder: (context, page) => RepaintBoundary(
      key: boundaryKey,
      child: MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: true, textScaler: TextScaler.linear(textScale)),
        child: page!,
      ),
    ),
    home: Scaffold(body: child),
  );
}

final class FakeMealPlanRepository implements MealPlanRepository {
  FakeMealPlanRepository({this.totalOverride, this.pageLoader})
    : mealPlans = [_publishedPlan, _reviewPlan],
      templates = [_template],
      audienceOptions = const MealPlanAudienceOptions(
        institutions: [MealPlanAudienceOption(id: 'institution-coelo', label: 'Colégio Coelo')],
        units: [
          MealPlanAudienceOption(
            id: 'unit-centro',
            label: 'Unidade Centro',
            institutionId: 'institution-coelo',
          ),
        ],
        groups: [
          MealPlanAudienceOption(
            id: 'group-5a',
            label: 'Turma 5A',
            institutionId: 'institution-coelo',
            unitId: 'unit-centro',
          ),
        ],
        activities: [
          MealPlanAudienceOption(
            id: 'activity-integral',
            label: 'Período integral',
            institutionId: 'institution-coelo',
            unitId: 'unit-centro',
            groupId: 'group-5a',
          ),
        ],
        people: [
          MealPlanAudienceOption(
            id: 'person-ana',
            label: 'Ana Martins',
            institutionId: 'institution-coelo',
            unitId: 'unit-centro',
            groupId: 'group-5a',
            audienceSegment: MealPlanAudienceSegment.students,
          ),
          MealPlanAudienceOption(
            id: 'person-carlos',
            label: 'Carlos Lima',
            institutionId: 'institution-coelo',
            unitId: 'unit-centro',
            audienceSegment: MealPlanAudienceSegment.staff,
          ),
        ],
      );

  final int? totalOverride;
  final Future<MealPlanPage> Function(MealPlanListFilter filter)? pageLoader;
  final List<MealPlan> mealPlans;
  final List<MealPlanTemplate> templates;
  final MealPlanAudienceOptions audienceOptions;
  MealPlanListFilter? lastPageFilter;

  @override
  Future<MealPlanPage> fetchPage(MealPlanListFilter filter) async {
    lastPageFilter = filter;
    final loader = pageLoader;
    if (loader != null) return loader(filter);
    return MealPlanPage(
      items: mealPlans,
      total: totalOverride ?? mealPlans.length,
      limit: filter.pageSize,
      offset: filter.offset,
    );
  }

  @override
  Future<MealPlanPage> fetchTemplatePage(MealPlanListFilter filter) async {
    lastPageFilter = filter;
    final loader = pageLoader;
    if (loader != null) return loader(filter);
    return MealPlanPage(
      items: templates.map((template) => template.toDirectoryItem()).toList(),
      total: totalOverride ?? templates.length,
      limit: filter.pageSize,
      offset: filter.offset,
    );
  }

  @override
  Future<MealPlan> getById(String id) async => mealPlans.firstWhere((item) => item.id == id);

  @override
  Future<MealPlanTemplate> getTemplateById(String id) async =>
      templates.firstWhere((item) => item.id == id);

  @override
  Future<MealPlanAudienceOptions> fetchAudienceOptions() async => audienceOptions;

  @override
  Future<MealPlanTemplate> saveTemplate(
    MealPlanTemplateDraft draft, {
    required bool publish,
  }) async => MealPlanTemplate(
    id: draft.id ?? 'template-created',
    tenantId: 'tenant-coelo',
    institutionId: 'institution-coelo',
    name: draft.name,
    planVariant: draft.planVariant,
    audienceSegment: draft.audienceSegment,
    status: publish ? 'published' : 'draft',
    version: draft.expectedVersion + 1,
    payload: draft.payload,
    createdAt: _fixedNow,
    updatedAt: _fixedNow,
  );

  @override
  Future<MealPlan> createOrUpdateDraft(MealPlanDraft draft) async => _fromDraft(draft);

  @override
  Future<MealPlan> submitForReview(
    String mealPlanId,
    String requestId,
    int expectedRevision,
  ) async => mealPlans.firstWhere((item) => item.id == mealPlanId);

  @override
  Future<MealPlan> publish(String mealPlanId, String requestId, int expectedRevision) async =>
      mealPlans.firstWhere((item) => item.id == mealPlanId);

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
  Future<MealPlan> fetchEffectiveSnapshot(MealPlanDraft draft) async => _fromDraft(draft);
}

final _fixedNow = DateTime(2026, 8, 20, 12);

final _publishedPlan = MealPlan(
  id: 'meal-plan-1',
  tenantId: 'tenant-coelo',
  institutionId: 'institution-coelo',
  unitId: 'unit-centro',
  name: 'Cardápio semanal - Educação Infantil',
  status: MealPlanStatus.published,
  sourceType: MealPlanSourceType.institution,
  scopeLevel: MealPlanScopeLevel.unit,
  scopeId: 'unit-centro',
  startDate: DateTime(2026, 8, 24),
  endDate: DateTime(2026, 8, 28),
  recurrence: MealPlanRecurrence(
    kind: MealPlanRecurrenceKind.weekly,
    weekdays: const {1, 2, 3, 4, 5},
  ),
  menu: [
    MealPlanMenuEntry(
      mealType: 'lunch',
      dishName: 'Arroz, feijão, frango assado e legumes',
      hasTime: true,
      startTime: '11:30',
      endTime: '12:30',
      weekdays: const {1, 2, 3, 4, 5},
    ),
  ],
  allergens: const [],
  alerts: const [],
  attachments: const [],
  priority: 10,
  conflictState: false,
  revision: 3,
  isDraft: false,
  requiresReview: false,
  createdBy: 'person-admin',
  updatedBy: 'person-admin',
  planVariant: MealPlanPlanVariant.complete,
  audienceSegment: MealPlanAudienceSegment.students,
);

final _reviewPlan = MealPlan(
  id: 'meal-plan-2',
  tenantId: 'tenant-coelo',
  institutionId: 'institution-coelo',
  classId: 'group-5a',
  name: 'Cardápio especial - Semana da Família',
  status: MealPlanStatus.inReview,
  sourceType: MealPlanSourceType.classLevel,
  scopeLevel: MealPlanScopeLevel.classLevel,
  scopeId: 'group-5a',
  startDate: DateTime(2026, 8, 31),
  endDate: DateTime(2026, 9, 4),
  recurrence: MealPlanRecurrence(kind: MealPlanRecurrenceKind.singleWeek),
  menu: [
    MealPlanMenuEntry(
      mealType: 'afternoonSnack',
      dishName: 'Bolo de banana e suco natural',
      weekdays: const {1, 2, 3, 4, 5},
      restrictions: const ['Contém glúten'],
    ),
  ],
  allergens: const ['Glúten'],
  alerts: const ['Revisão nutricional pendente'],
  attachments: const [],
  priority: 20,
  conflictState: false,
  revision: 1,
  isDraft: false,
  requiresReview: true,
  createdBy: 'person-admin',
  updatedBy: 'person-admin',
  planVariant: MealPlanPlanVariant.complete,
  audienceSegment: MealPlanAudienceSegment.all,
);

final _template = MealPlanTemplate(
  id: 'template-1',
  tenantId: 'tenant-coelo',
  institutionId: 'institution-coelo',
  name: 'Modelo semanal equilibrado',
  planVariant: MealPlanPlanVariant.complete,
  audienceSegment: MealPlanAudienceSegment.students,
  status: 'published',
  version: 2,
  payload: {
    'menu': [
      MealPlanMenuEntry(
        mealType: 'lunch',
        dishName: 'Prato principal equilibrado',
        weekdays: const {1, 2, 3, 4, 5},
      ).toJson(),
    ],
  },
  createdAt: DateTime(2026, 8, 1),
  updatedAt: DateTime(2026, 8, 18),
);

MealPlan _fromDraft(MealPlanDraft draft) => MealPlan(
  id: draft.mealPlanId ?? 'meal-plan-created',
  tenantId: draft.tenantId,
  institutionId: draft.institutionId,
  unitId: draft.unitId,
  classId: draft.classId,
  personId: draft.personId,
  name: draft.name,
  status: MealPlanStatus.draft,
  sourceType: draft.sourceType,
  scopeLevel: draft.scopeLevel,
  scopeId: draft.scopeId,
  startDate: draft.startDate,
  endDate: draft.endDate,
  recurrence: draft.recurrence,
  menu: draft.menu,
  allergens: draft.allergens,
  alerts: draft.alerts,
  attachments: draft.attachments,
  priority: draft.priority,
  conflictState: false,
  revision: draft.expectedRevision + 1,
  isDraft: true,
  requiresReview: false,
  createdBy: 'person-admin',
  updatedBy: 'person-admin',
  inheritanceOriginId: draft.inheritanceOriginId,
  planVariant: draft.planVariant,
  audienceSegment: draft.audienceSegment,
  visibilityMode: draft.visibilityMode,
  visibleFrom: draft.visibleFrom,
  sourceTemplateId: draft.sourceTemplateId,
  sourceTemplateVersion: draft.sourceTemplateVersion,
  scopeRules: draft.scopeRules,
  simpleImage: draft.simpleImage,
  simpleImageAlt: draft.simpleImageAlt,
  simpleNotes: draft.simpleNotes,
);

Future<void> _loadGoldenFonts() async {
  final nunitoSans = FontLoader('Nunito Sans')
    ..addFont(rootBundle.load('assets/brand/NunitoSans-VariableFont.ttf'));
  await nunitoSans.load();

  final flutterArtifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final materialIcons = File(
    '${flutterArtifacts.path}/material_fonts/MaterialIcons-Regular.otf',
  ).readAsBytesSync();
  final materialIconsLoader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(materialIcons)));
  await materialIconsLoader.load();
}

final class _UnavailableMealPlanImageRepository implements MealPlanImageRepository {
  const _UnavailableMealPlanImageRepository();

  @override
  Future<MealPlanImageAsset> upload(MealPlanImageUploadRequest request) =>
      Future<MealPlanImageAsset>.error(const MealPlanImageUnavailableException());

  @override
  Future<Uri> createSignedReadUrl(String assetId) =>
      Future<Uri>.error(const MealPlanImageUnavailableException());

  @override
  Future<void> delete({required String assetId, required String requestId}) =>
      Future<void>.error(const MealPlanImageUnavailableException());
}
