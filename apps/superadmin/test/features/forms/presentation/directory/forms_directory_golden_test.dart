import 'dart:io';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_superadmin/app/shell/superadmin_shell.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/forms/data/development_forms_api.dart';
import 'package:coelo_superadmin/features/forms/presentation/directory/forms_directory_page.dart';
import 'package:coelo_superadmin/features/forms/presentation/directory/forms_schedule_dialog.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(_loadGoldenFonts);

  testWidgets('matches the approved responsive directory contract', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(_goldenApp(brightness));
        await tester.pumpAndSettle();

        await expectLater(
          find.byKey(const Key('forms-directory-golden-root')),
          matchesGoldenFile('goldens/forms_directory_${brightness.name}_${width.toInt()}.png'),
        );
      }
    }
  });

  testWidgets('matches the approved flyout and content-height schedule dialog', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_goldenApp(Brightness.light));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ações do formulário Fotos — Visita Pedagógica'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('forms-directory-golden-root')),
      matchesGoldenFile('goldens/forms_directory_actions_light_1440.png'),
    );

    await tester.tap(find.widgetWithText(MenuItemButton, 'Agendamentos'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('forms-directory-golden-root')),
      matchesGoldenFile('goldens/forms_directory_schedule_light_1440.png'),
    );
  });

  testWidgets('captures the honest unavailable schedule state from the directory', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_goldenApp(Brightness.light, scheduleIntegrationAvailable: false));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ações do formulário Fotos — Visita Pedagógica'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Agendamentos'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const Key('forms-directory-golden-root')),
      matchesGoldenFile('goldens/forms_directory_schedule_unavailable_light_1440.png'),
    );
  });

  testWidgets('captures empty, no-results, failure and unauthorized directory states', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    tester.view.physicalSize = const Size(375, 900);
    await tester.pumpWidget(_goldenApp(Brightness.light, api: const _StateFormsApi()));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('forms-directory-golden-root')),
      matchesGoldenFile('goldens/forms_directory_empty_light_375_v4_19.png'),
    );

    await tester.pumpWidget(
      _goldenApp(Brightness.light, api: const _StateFormsApi(noResults: true)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).first, 'sem correspondência');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('forms-directory-golden-root')),
      matchesGoldenFile('goldens/forms_directory_no_results_light_375_v4_19.png'),
    );

    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpWidget(_goldenApp(Brightness.dark, api: const _StateFormsApi(failure: true)));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('forms-directory-golden-root')),
      matchesGoldenFile('goldens/forms_directory_failure_dark_1440_v4_19.png'),
    );

    tester.view.physicalSize = const Size(375, 1000);
    await tester.pumpWidget(
      _goldenApp(Brightness.light, api: const _StateFormsApi(unauthorized: true), textScale: 2),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('forms-directory-golden-root')),
      matchesGoldenFile('goldens/forms_directory_unauthorized_light_375_200_v4_19.png'),
    );
  });
}

Widget _goldenApp(
  Brightness brightness, {
  bool scheduleIntegrationAvailable = true,
  FormsApi api = const _GoldenFormsApi(),
  double textScale = 1,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: CoeloTheme.light,
  darkTheme: CoeloTheme.dark,
  themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
  themeAnimationStyle: AnimationStyle.noAnimation,
  builder: (context, child) => RepaintBoundary(
    key: const Key('forms-directory-golden-root'),
    child: MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: true, textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
  ),
  home: Builder(
    builder: (context) => SuperadminShell(
      logout: _logout,
      title: 'Formulários',
      subtitle: 'Crie, publique, copie e agende formulários por contexto.',
      currentDestination: 'forms',
      canAccessCapability: (_) => true,
      child: FormsDirectoryPage(
        api: api,
        canManage: true,
        canManageLifecycle: true,
        canTransferCrossInstitution: true,
        visualMetadata: _visualMetadata,
        onCreate: () {},
        onOpen: (_) {},
        onEdit: (_) {},
        onManageSchedules: (_) => showFormsScheduleDialog(
          context: context,
          initialValue: FormsScheduleDraft(
            active: true,
            name: 'Visita pedagógica — fotos',
            startsAt: DateTime(2026, 8, 12, 8),
            endsAt: DateTime(2026, 11, 30, 18),
            frequency: FormsScheduleFrequency.weekly,
            weekdays: const {DateTime.monday, DateTime.wednesday, DateTime.friday},
            audienceLabel: 'Professores e auxiliares',
          ),
          onSave: scheduleIntegrationAvailable ? (_) async {} : null,
          unavailableReason: scheduleIntegrationAvailable
              ? null
              : 'A integração de agendamentos não está disponível neste ambiente.',
        ),
      ),
    ),
  ),
);

Future<LogoutResult> _logout() async => const LogoutResult.success();

final class _GoldenFormsApi implements FormsApi {
  const _GoldenFormsApi();

  @override
  Future<FormCursorPage<FormDirectoryItem>> listDirectory(FormDirectoryQuery query) async =>
      FormCursorPage(items: _items, nextCursor: 'next');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _StateFormsApi implements FormsApi {
  const _StateFormsApi({this.noResults = false, this.failure = false, this.unauthorized = false});

  final bool noResults;
  final bool failure;
  final bool unauthorized;

  @override
  Future<FormCursorPage<FormDirectoryItem>> listDirectory(FormDirectoryQuery query) async {
    if (unauthorized) {
      throw const FormApiException(FormApiFailureKind.unauthorized, 'denied');
    }
    if (failure) throw const FormApiException(FormApiFailureKind.unavailable, 'offline');
    if (noResults && (query.search?.isNotEmpty ?? false)) {
      return FormCursorPage(items: const [], nextCursor: null);
    }
    return FormCursorPage(items: const [], nextCursor: null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _visualMetadata = <String, DevelopmentFormVisualMetadata>{};

final _items = [
  _item(
    '1',
    'Fotos — Visita Pedagógica',
    FormOperationalStatus.active,
    'Todas as unidades',
    'Professores',
    42,
    1,
    8,
  ),
  _item(
    '2',
    'Autorização — Feira Cultural',
    FormOperationalStatus.scheduled,
    'Unidade Centro',
    'Famílias',
    18,
    2,
    12,
  ),
  _item(
    '3',
    'Atualização cadastral',
    FormOperationalStatus.active,
    'Instituição',
    'Responsáveis',
    73,
    0,
    2,
  ),
  _item(
    '4',
    'Pesquisa de satisfação',
    FormOperationalStatus.active,
    'Unidade Norte',
    'Equipe escolar',
    31,
    1,
    24,
  ),
  _item(
    '5',
    'Confirmação de matrícula 2027',
    FormOperationalStatus.scheduled,
    'Todas as unidades',
    'Famílias',
    9,
    1,
    18,
  ),
  _item(
    '6',
    'Registro de atividade complementar',
    FormOperationalStatus.active,
    'Turmas selecionadas',
    'Professores',
    27,
    0,
    9,
  ),
];

FormDirectoryItem _item(
  String id,
  String title,
  FormOperationalStatus operationalStatus,
  String context,
  String audience,
  int responses,
  int schedules,
  int day,
) {
  final formId = 'form-$id';
  _visualMetadata[formId] = DevelopmentFormVisualMetadata(
    contextLabel: context,
    audienceLabel: audience,
    responseCount: responses,
    scheduleCount: schedules,
    createdAt: DateTime(2026, 8, day),
  );
  return FormDirectoryItem(
    id: formId,
    title: title,
    kind: FormKind.form,
    status: FormStatus.published,
    operationalStatus: operationalStatus,
    identityMode: FormIdentityMode.identified,
    updatedAt: DateTime(2026, 8, 28),
    managementVersion: 2,
  );
}

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
