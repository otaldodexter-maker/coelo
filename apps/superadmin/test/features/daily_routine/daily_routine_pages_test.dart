import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/daily_routine/daily_routine.dart';
import 'package:coelo_superadmin/features/daily_routine/daily_routine_pages.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app(Widget child) => MaterialApp(theme: CoeloTheme.light, home: child);

  Future<void> pumpWide(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(child));
    await tester.pumpAndSettle();
  }

  Future<void> openStep(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).first);
    await tester.pumpAndSettle();
  }

  DailyRoutineEditorPage editor(
    InMemoryDailyRoutineRepository repository, {
    bool readOnly = false,
    String? modelId,
  }) => DailyRoutineEditorPage(
    repository: repository,
    permissions: readOnly ? DailyRoutinePermissions.readOnly : DailyRoutinePermissions.owner,
    logout: unavailableSuperadminLogout,
    modelId: modelId,
  );

  testWidgets('directory alternates cards and table and respects read-only', (tester) async {
    final repository = InMemoryDailyRoutineRepository.seeded();
    await pumpWide(
      tester,
      DailyRoutineDirectoryPage(
        repository: repository,
        permissions: DailyRoutinePermissions.owner,
        logout: unavailableSuperadminLogout,
      ),
    );
    expect(find.text('Criar modelo'), findsWidgets);
    await tester.tap(find.byKey(const Key('daily-routine-view-table')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('daily-routine-table')), findsOneWidget);

    await pumpWide(
      tester,
      DailyRoutineDirectoryPage(
        repository: repository,
        permissions: DailyRoutinePermissions.readOnly,
        logout: unavailableSuperadminLogout,
      ),
    );
    expect(find.text('Modo somente leitura'), findsOneWidget);
    expect(find.text('Criar modelo'), findsNothing);
  });

  testWidgets('directory separates models and routines with contextual actions', (tester) async {
    final repository = InMemoryDailyRoutineRepository.seeded();
    DailyRoutineEntryType? requestedType;
    String? openedId;
    await pumpWide(
      tester,
      DailyRoutineDirectoryPage(
        repository: repository,
        permissions: DailyRoutinePermissions.owner,
        logout: unavailableSuperadminLogout,
        onCreateEntry: (type) => requestedType = type,
        onEdit: (id) => openedId = id,
      ),
    );

    expect(find.text('Modelos'), findsOneWidget);
    expect(find.text('Rotinas'), findsOneWidget);
    expect(find.text('Todos'), findsNothing);
    expect(find.text('Ativos'), findsNothing);
    expect(find.text('Inativos'), findsNothing);
    expect(find.text('Modelo Berçário'), findsOneWidget);
    expect(find.text('Rotina Unidade Centro'), findsNothing);

    await tester.tap(find.text('Rotinas'));
    await tester.pumpAndSettle();
    expect(find.text('Rotina Unidade Centro'), findsOneWidget);
    expect(find.text('Nova rotina'), findsWidgets);
    await tester.tap(find.text('Nova rotina').first);
    expect(requestedType, DailyRoutineEntryType.routine);

    await tester.tap(find.text('Modelos'));
    await tester.pumpAndSettle();
    final duplicate = find.byKey(const Key('daily-routine-duplicate-institution-model'));
    await tester.ensureVisible(duplicate);
    await tester.tap(duplicate);
    await tester.pumpAndSettle();
    expect(find.text('Duplicar modelo?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('daily-routine-confirm-duplicate')));
    await tester.pumpAndSettle();
    expect(find.text('Modelo Berçário (2)'), findsOneWidget);

    final useModel = find.byKey(const Key('daily-routine-use-model-institution-model'));
    await tester.ensureVisible(useModel);
    await tester.tap(useModel);
    await tester.pumpAndSettle();
    expect(openedId, isNotNull);
    expect(
      repository.models.firstWhere((item) => item.id == openedId).type,
      DailyRoutineEntryType.routine,
    );
  });

  testWidgets('Coelo model opens in consultation mode', (tester) async {
    await pumpWide(
      tester,
      editor(InMemoryDailyRoutineRepository.seeded(), modelId: 'institution-model'),
    );

    expect(find.text('Modelo Coelo somente para consulta'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byKey(const Key('daily-routine-continue'))).onPressed,
      isNull,
    );
  });
  testWidgets('wizard exposes four steps and preserves identity draft', (tester) async {
    await pumpWide(tester, editor(InMemoryDailyRoutineRepository.seeded()));
    for (final label in const ['Identidade', 'Alcance', 'Seções e campos', 'Revisão e ativação']) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.text('Participantes e prévia'), findsNothing);
    expect(find.byKey(const Key('daily-routine-step-participants')), findsNothing);
    await tester.enterText(find.byKey(const Key('daily-routine-name')), 'Rotina compartilhada');
    await tester.tap(find.byKey(const Key('daily-routine-continue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('daily-routine-step-scope')), findsOneWidget);
    await tester.tap(find.byKey(const Key('daily-routine-previous')));
    await tester.pumpAndSettle();
    expect(find.text('Rotina compartilhada'), findsOneWidget);
  });

  testWidgets('identity validation exposes an accessible error', (tester) async {
    await pumpWide(tester, editor(InMemoryDailyRoutineRepository.seeded()));
    await tester.tap(find.byKey(const Key('daily-routine-continue')));
    await tester.pumpAndSettle();
    expect(find.text('Informe o nome do modelo.'), findsOneWidget);
    expect(find.byKey(const Key('daily-routine-step-identity')), findsOneWidget);
  });

  testWidgets('fields step exposes all six approved types', (tester) async {
    await pumpWide(tester, editor(InMemoryDailyRoutineRepository.seeded()));
    await openStep(tester, 'Seções e campos');
    for (final label in const [
      'Texto curto',
      'Texto longo',
      'Escolha única',
      'Escolha múltipla',
      'Número',
      'Sim/Não',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('read-only wizard disables continuation', (tester) async {
    await pumpWide(tester, editor(InMemoryDailyRoutineRepository.seeded(), readOnly: true));
    expect(find.text('Modo somente leitura'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byKey(const Key('daily-routine-continue'))).onPressed,
      isNull,
    );
  });

  testWidgets('directory exposes loading empty error no-results and pagination', (tester) async {
    await pumpWide(
      tester,
      DailyRoutineDirectoryPage(
        repository: InMemoryDailyRoutineRepository.empty(),
        permissions: DailyRoutinePermissions.owner,
        logout: unavailableSuperadminLogout,
      ),
    );
    expect(find.byKey(const Key('daily-routine-empty')), findsOneWidget);

    await tester.pumpWidget(
      app(
        DailyRoutineDirectoryPage(
          repository: InMemoryDailyRoutineRepository.empty(),
          permissions: DailyRoutinePermissions.owner,
          logout: unavailableSuperadminLogout,
          loading: true,
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('daily-routine-loading')), findsOneWidget);
    var retried = false;
    await pumpWide(
      tester,
      DailyRoutineDirectoryPage(
        repository: InMemoryDailyRoutineRepository.empty(),
        permissions: DailyRoutinePermissions.owner,
        logout: unavailableSuperadminLogout,
        errorMessage: 'Falha local de teste.',
        onRetry: () => retried = true,
      ),
    );
    expect(find.byKey(const Key('daily-routine-error')), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    expect(retried, isTrue);

    final repository = InMemoryDailyRoutineRepository.empty();
    for (var index = 0; index < 12; index++) {
      repository.save(
        DailyRoutineModel(
          id: 'routine-$index',
          name: 'Rotina $index',
          description: 'Modelo local',
          origin: DailyRoutineOrigin.institution,
          version: 1,
          status: DailyRoutineStatus.draft,
          sections: const [],
        ),
      );
    }
    await pumpWide(
      tester,
      DailyRoutineDirectoryPage(
        repository: repository,
        permissions: DailyRoutinePermissions.owner,
        logout: unavailableSuperadminLogout,
      ),
    );
    expect(find.byKey(const Key('daily-routine-pagination')), findsOneWidget);
    final search = find.descendant(
      of: find.byKey(const Key('daily-routine-search')),
      matching: find.byType(EditableText),
    );
    await tester.enterText(search, 'inexistente');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('daily-routine-no-results')), findsOneWidget);
    await tester.tap(find.text('Limpar filtros'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('daily-routine-pagination')), findsOneWidget);
  });

  testWidgets('section and field dialogs edit the local draft', (tester) async {
    await pumpWide(tester, editor(InMemoryDailyRoutineRepository.empty()));
    await tester.enterText(find.byKey(const Key('daily-routine-name')), 'Rotina local');
    await openStep(tester, 'Seções e campos');

    await tester.tap(find.byKey(const Key('daily-routine-add-section')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('daily-routine-section-name')), 'Cuidados');
    await tester.tap(find.byKey(const Key('daily-routine-section-save')));
    await tester.pumpAndSettle();
    expect(find.text('1. Cuidados'), findsOneWidget);

    await tester.tap(find.byKey(const Key('daily-routine-section-section-1-add-field')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('daily-routine-field-label')), 'Hidratação');
    await tester.enterText(
      find.byKey(const Key('daily-routine-field-initial-value')),
      'Não informado',
    );
    await tester.tap(find.byKey(const Key('daily-routine-field-save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Hidratação • Texto curto • Opcional'), findsOneWidget);
    expect(find.textContaining('Inicial: Não informado'), findsOneWidget);
  });

  testWidgets('choice popup requires a valid initial option after removal', (tester) async {
    await pumpWide(tester, editor(InMemoryDailyRoutineRepository.empty()));
    await openStep(tester, 'Seções e campos');
    await tester.tap(find.byKey(const Key('daily-routine-add-section')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('daily-routine-section-name')), 'Chegada');
    await tester.tap(find.byKey(const Key('daily-routine-section-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('daily-routine-section-section-1-add-field')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('daily-routine-field-label')), 'Humor');
    final type = find.byKey(const Key('daily-routine-field-type'));
    await tester.tap(find.descendant(of: type, matching: find.text('Texto curto')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Escolha única').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('daily-routine-field-options')), 'Calmo, Animado');
    await tester.pumpAndSettle();

    final initial = find.byKey(const Key('daily-routine-field-initial-choice'));
    await tester.tap(find.descendant(of: initial, matching: find.text('Sem valor inicial')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calmo').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('daily-routine-field-options')), 'Animado');
    await tester.pumpAndSettle();

    expect(find.text('A opção inicial foi removida. Selecione um novo valor.'), findsOneWidget);
    await tester.tap(find.descendant(of: initial, matching: find.text('Sem valor inicial')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Animado').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('daily-routine-field-save')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Inicial: Animado'), findsOneWidget);
  });
  testWidgets('class variation is configured inside its selected class', (tester) async {
    final repository = InMemoryDailyRoutineRepository.seeded();
    await pumpWide(
      tester,
      DailyRoutineEditorPage(
        repository: repository,
        permissions: DailyRoutinePermissions.owner,
        logout: unavailableSuperadminLogout,
        modelId: 'unit-model',
      ),
    );
    await openStep(tester, 'Alcance');
    await tester.tap(find.byKey(const Key('daily-routine-scope-group-a-variation')));
    await tester.pumpAndSettle();
    expect(find.text('Variação de Berçário A'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('daily-routine-variation-initial-value')), 'Calmo');
    await tester.tap(find.byKey(const Key('daily-routine-variation-save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 variação'), findsOneWidget);
  });

  testWidgets('escape closes dirty-exit dialog and preserves the draft', (tester) async {
    await pumpWide(tester, editor(InMemoryDailyRoutineRepository.seeded()));
    await tester.enterText(find.byKey(const Key('daily-routine-name')), 'Rascunho preservado');
    await tester.tap(find.byKey(const Key('daily-routine-cancel')));
    await tester.pumpAndSettle();
    expect(find.text('Descartar alterações?'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Descartar alterações?'), findsNothing);
    expect(find.text('Rascunho preservado'), findsOneWidget);
  });

  testWidgets('dirty exit can continue editing and restores focus', (tester) async {
    await pumpWide(tester, editor(InMemoryDailyRoutineRepository.seeded()));
    await tester.enterText(find.byKey(const Key('daily-routine-name')), 'Rascunho com foco');
    await tester.tap(find.byKey(const Key('daily-routine-cancel')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar editando'));
    await tester.pumpAndSettle();

    expect(find.text('Descartar alterações?'), findsNothing);
    expect(find.text('Rascunho com foco'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scope and fields expose semantic errors when incomplete', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpWide(tester, editor(InMemoryDailyRoutineRepository.empty()));
    await openStep(tester, 'Alcance');
    await tester.tap(find.byKey(const Key('daily-routine-continue')));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Alcance, com erro'), findsOneWidget);

    await openStep(tester, 'Seções e campos');
    await tester.tap(find.byKey(const Key('daily-routine-continue')));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Seções e campos, com erro'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('class variation can add local field and revert base override', (tester) async {
    await pumpWide(tester, editor(InMemoryDailyRoutineRepository.seeded(), modelId: 'unit-model'));
    await openStep(tester, 'Alcance');
    await tester.tap(find.byKey(const Key('daily-routine-scope-group-a-local-field')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('daily-routine-local-field-label')),
      'Recado da turma',
    );
    await tester.tap(find.byKey(const Key('daily-routine-local-field-save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Campo local: Recado da turma'), findsOneWidget);

    await tester.tap(find.byKey(const Key('daily-routine-scope-group-a-variation')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('daily-routine-variation-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('daily-routine-scope-group-a-variation')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('daily-routine-variation-reset')));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 variação'), findsNothing);
  });

  testWidgets('unit origin is shown in identity and review', (tester) async {
    await pumpWide(
      tester,
      DailyRoutineEditorPage(
        repository: InMemoryDailyRoutineRepository.seeded(),
        permissions: DailyRoutinePermissions.owner,
        logout: unavailableSuperadminLogout,
        modelId: 'unit-model',
      ),
    );
    expect(find.byKey(const Key('daily-routine-origin-unit')), findsOneWidget);
    expect(find.text('Unidade Centro'), findsOneWidget);
    await openStep(tester, 'Revisão e ativação');
    expect(find.text('Unidade: Unidade Centro'), findsOneWidget);
  });

  testWidgets('primary final action preserves selected draft status', (tester) async {
    final repository = InMemoryDailyRoutineRepository.empty();
    repository.save(
      const DailyRoutineModel(
        id: 'draft-model',
        name: 'Rotina em rascunho',
        description: '',
        origin: DailyRoutineOrigin.institution,
        version: 2,
        status: DailyRoutineStatus.draft,
        sections: [
          DailyRoutineSection(
            id: 'care',
            name: 'Cuidados',
            fields: [
              DailyRoutineField(
                id: 'notes',
                label: 'Observações',
                type: DailyRoutineFieldType.longText,
              ),
            ],
          ),
        ],
        scopes: [DailyRoutineScope(groupId: 'group-a')],
      ),
    );
    await pumpWide(
      tester,
      DailyRoutineEditorPage(
        repository: repository,
        permissions: DailyRoutinePermissions.owner,
        logout: unavailableSuperadminLogout,
        modelId: 'draft-model',
      ),
    );
    await openStep(tester, 'Revisão e ativação');
    await tester.tap(find.byKey(const Key('daily-routine-save')));
    await tester.pump();
    expect(repository.models.single.status, DailyRoutineStatus.draft);
    expect(repository.models.single.version, 2);
  });

  testWidgets('step error exposes semantic error state', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpWide(tester, editor(InMemoryDailyRoutineRepository.empty()));
    await tester.tap(find.byKey(const Key('daily-routine-continue')));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Identidade, com erro'), findsOneWidget);
    semantics.dispose();
  });
  testWidgets('wizard remains usable across widths themes and 200 percent text', (tester) async {
    for (final width in const [375.0, 768.0, 1024.0, 1440.0]) {
      for (final brightness in Brightness.values) {
        for (final scale in const [1.0, 2.0]) {
          tester.view.physicalSize = Size(width, 1200);
          tester.view.devicePixelRatio = 1;
          await tester.pumpWidget(
            MaterialApp(
              theme: CoeloTheme.light,
              darkTheme: CoeloTheme.dark,
              themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: editor(InMemoryDailyRoutineRepository.seeded()),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            tester.takeException(),
            isNull,
            reason: 'width=$width brightness=$brightness scale=$scale',
          );
          final surface = tester.widget<ColoredBox>(
            find.byKey(const Key('daily-routine-page-surface')),
          );
          expect(
            surface.color,
            Theme.of(
              tester.element(find.byKey(const Key('daily-routine-page-surface'))),
            ).colorScheme.surface,
          );
        }
      }
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('all wizard steps remain usable at 200 percent text across widths', (tester) async {
    for (final width in const [375.0, 768.0, 1024.0, 1440.0]) {
      for (final brightness in Brightness.values) {
        for (final label in const [
          'Identidade',
          'Alcance',
          'Seções e campos',
          'Revisão e ativação',
        ]) {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(1024, 1200);
          await tester.pumpWidget(
            MaterialApp(
              theme: CoeloTheme.light,
              darkTheme: CoeloTheme.dark,
              themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: DailyRoutineEditorPage(
                repository: InMemoryDailyRoutineRepository.seeded(),
                permissions: DailyRoutinePermissions.owner,
                logout: unavailableSuperadminLogout,
                modelId: 'institution-model',
              ),
            ),
          );
          await tester.pumpAndSettle();
          await openStep(tester, label);
          tester.view.physicalSize = Size(width, 1200);
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'step=$label width=$width brightness=$brightness',
          );
        }
      }
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('directory cards and table remain usable at 200 percent text', (tester) async {
    for (final width in const [375.0, 768.0, 1024.0, 1440.0]) {
      for (final brightness in Brightness.values) {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            theme: CoeloTheme.light,
            darkTheme: CoeloTheme.dark,
            themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: DailyRoutineDirectoryPage(
              repository: InMemoryDailyRoutineRepository.seeded(),
              permissions: DailyRoutinePermissions.owner,
              logout: unavailableSuperadminLogout,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'cards width= brightness=');
        await tester.tap(find.byKey(const Key('daily-routine-view-table')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'table width= brightness=');
      }
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
