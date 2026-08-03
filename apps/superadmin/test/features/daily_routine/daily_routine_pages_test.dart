import 'package:coelo_superadmin/features/daily_routine/daily_routine.dart';
import 'package:coelo_superadmin/features/daily_routine/daily_routine_pages.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app(Widget child) => MaterialApp(theme: CoeloTheme.light, home: child);
  Finder editorScroll() => find
      .descendant(
        of: find.byKey(const Key('daily-routine-editor-scroll')),
        matching: find.byType(Scrollable),
      )
      .first;

  testWidgets('owner can create and read-only actor is explicitly limited', (tester) async {
    final repository = InMemoryDailyRoutineRepository.seeded();
    await tester.pumpWidget(
      app(
        DailyRoutineDirectoryPage(
          repository: repository,
          permissions: DailyRoutinePermissions.owner,
          logout: unavailableSuperadminLogout,
        ),
      ),
    );
    expect(find.text('Criar modelo de rotina diária'), findsOneWidget);

    await tester.pumpWidget(
      app(
        DailyRoutineDirectoryPage(
          repository: repository,
          permissions: DailyRoutinePermissions.readOnly,
          logout: unavailableSuperadminLogout,
        ),
      ),
    );
    expect(find.text('Modo somente leitura'), findsOneWidget);
    expect(find.text('Criar modelo de rotina diária'), findsNothing);
  });

  testWidgets('directory alternates cards and the resizable table', (tester) async {
    await tester.pumpWidget(
      app(
        DailyRoutineDirectoryPage(
          repository: InMemoryDailyRoutineRepository.seeded(),
          permissions: DailyRoutinePermissions.owner,
          logout: unavailableSuperadminLogout,
        ),
      ),
    );
    expect(find.byKey(const Key('daily-routine-cards')), findsOneWidget);
    expect(find.byKey(const Key('daily-routine-table')), findsNothing);
    await tester.tap(find.byKey(const Key('daily-routine-view-table')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('daily-routine-cards')), findsNothing);
    expect(find.byKey(const Key('daily-routine-table')), findsOneWidget);
  });

  testWidgets('editor exposes all six approved field types and preview', (tester) async {
    await tester.pumpWidget(
      app(
        DailyRoutineEditorPage(
          repository: InMemoryDailyRoutineRepository.seeded(),
          permissions: DailyRoutinePermissions.owner,
          logout: unavailableSuperadminLogout,
        ),
      ),
    );
    for (final label in const [
      'Texto curto',
      'Texto longo',
      'Escolha única',
      'Escolha múltipla',
      'Número',
      'Sim/Não',
    ]) {
      expect(find.text(label), findsWidgets);
    }
    await tester.scrollUntilVisible(
      find.text('Prévia operacional'),
      300,
      scrollable: editorScroll(),
    );
    expect(find.text('Prévia operacional'), findsOneWidget);
  });

  testWidgets('editor exposes optional feelings without an automatic value', (tester) async {
    final repository = InMemoryDailyRoutineRepository.seeded();
    await tester.pumpWidget(
      app(
        DailyRoutineEditorPage(
          repository: repository,
          permissions: DailyRoutinePermissions.owner,
          logout: unavailableSuperadminLogout,
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('daily-routine-participant-participant-2-feeling')),
      300,
      scrollable: editorScroll(),
    );

    expect(find.text('Como chegou? (opcional)'), findsWidgets);
    expect(find.text('Não informado'), findsWidgets);
    expect(find.text('Tranquilo'), findsNothing);
    expect(repository.participantFeeling('participant-2'), isNull);
  });

  testWidgets('owner selects an additional participant feeling and clears it', (tester) async {
    final repository = InMemoryDailyRoutineRepository.seeded();
    await tester.pumpWidget(
      app(
        DailyRoutineEditorPage(
          repository: repository,
          permissions: DailyRoutinePermissions.owner,
          logout: unavailableSuperadminLogout,
        ),
      ),
    );

    final more = find.byKey(const Key('daily-routine-participant-participant-2-feeling-more'));
    await tester.scrollUntilVisible(more, 300, scrollable: editorScroll());
    await tester.ensureVisible(more);
    await tester.pumpAndSettle();
    await tester.tap(more);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('daily-routine-feeling-sad')));
    await tester.pumpAndSettle();

    expect(repository.participantFeeling('participant-2'), DailyRoutineFeeling.sad);

    final clear = find.byKey(const Key('daily-routine-participant-participant-2-feeling-clear'));
    await tester.scrollUntilVisible(clear, 200, scrollable: editorScroll());
    await tester.tap(clear);
    await tester.pump();
    expect(repository.participantFeeling('participant-2'), isNull);
  });

  testWidgets('bulk feeling requires a choice and preserves participant exceptions', (
    tester,
  ) async {
    final repository = InMemoryDailyRoutineRepository.seeded();
    await tester.pumpWidget(
      app(
        DailyRoutineEditorPage(
          repository: repository,
          permissions: DailyRoutinePermissions.owner,
          logout: unavailableSuperadminLogout,
        ),
      ),
    );

    final apply = find.byKey(const Key('daily-routine-apply-feeling-bulk'));
    await tester.scrollUntilVisible(apply, 400, scrollable: editorScroll());
    expect(tester.widget<FilledButton>(apply).onPressed, isNull);

    final animated = find.byKey(const Key('daily-routine-bulk-feeling-animated'));
    await tester.scrollUntilVisible(animated, 200, scrollable: editorScroll());
    await tester.tap(animated);
    await tester.pump();
    expect(tester.widget<FilledButton>(apply).onPressed, isNotNull);

    await tester.tap(apply);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preservar'));
    await tester.pumpAndSettle();

    expect(repository.participantFeeling('participant-1'), DailyRoutineFeeling.sleepy);
    expect(repository.participantFeeling('participant-2'), DailyRoutineFeeling.animated);
  });

  testWidgets('suggestion remains pending and outside the approved catalog', (tester) async {
    final repository = InMemoryDailyRoutineRepository.seeded();
    await tester.pumpWidget(
      app(
        DailyRoutineEditorPage(
          repository: repository,
          permissions: DailyRoutinePermissions.owner,
          logout: unavailableSuperadminLogout,
        ),
      ),
    );

    final more = find.byKey(const Key('daily-routine-participant-participant-2-feeling-more'));
    await tester.scrollUntilVisible(more, 300, scrollable: editorScroll());
    await tester.ensureVisible(more);
    await tester.pumpAndSettle();
    await tester.tap(more);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sugerir sentimento'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('daily-routine-feeling-suggestion-field')),
      'Curioso',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('daily-routine-feeling-suggestion-submit')));
    await tester.pumpAndSettle();

    expect(repository.feelingSuggestions.single.text, 'Curioso');
    expect(find.text('Sugestão enviada para avaliação.'), findsOneWidget);
    expect(DailyRoutineFeeling.values.map((feeling) => feeling.label), isNot(contains('Curioso')));
  });

  testWidgets('read-only editor shows feelings without mutable controls', (tester) async {
    final repository = InMemoryDailyRoutineRepository.seeded();
    await tester.pumpWidget(
      app(
        DailyRoutineEditorPage(
          repository: repository,
          permissions: DailyRoutinePermissions.readOnly,
          logout: unavailableSuperadminLogout,
        ),
      ),
    );

    final animated = find.byKey(
      const Key('daily-routine-participant-participant-1-feeling-animated'),
    );
    await tester.scrollUntilVisible(animated, 300, scrollable: editorScroll());
    final chip = tester.widget<ChoiceChip>(
      find.descendant(of: animated, matching: find.byType(ChoiceChip)),
    );

    expect(chip.onSelected, isNull);
    expect(
      find.byKey(const Key('daily-routine-participant-participant-1-feeling-clear')),
      findsNothing,
    );
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const Key('daily-routine-participant-participant-1-select')),
          )
          .onChanged,
      isNull,
    );
  });
}
