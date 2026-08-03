import 'dart:ui' show Tristate;

import 'package:coelo_superadmin/features/daily_routine/daily_routine.dart';
import 'package:coelo_superadmin/features/daily_routine/daily_routine_feeling_dialogs.dart';
import 'package:coelo_superadmin/features/daily_routine/daily_routine_feeling_picker.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app(Widget child) => MaterialApp(
    theme: CoeloTheme.light,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  testWidgets('shows five primary feelings and reveals four additional options', (tester) async {
    await tester.pumpWidget(
      app(
        DailyRoutineFeelingPicker(
          value: null,
          enabled: true,
          onChanged: (_) {},
          onSuggestFeeling: () async {},
        ),
      ),
    );

    for (final feeling in DailyRoutineFeeling.primary) {
      expect(find.text('${feeling.emoji} ${feeling.label}'), findsOneWidget);
    }
    for (final feeling in DailyRoutineFeeling.additional) {
      expect(find.text('${feeling.emoji} ${feeling.label}'), findsNothing);
    }

    await tester.tap(find.byKey(const Key('daily-routine-feeling-more')));
    await tester.pumpAndSettle();

    for (final feeling in DailyRoutineFeeling.additional) {
      expect(find.text('${feeling.emoji} ${feeling.label}'), findsOneWidget);
    }
    expect(find.text('Sugerir sentimento'), findsOneWidget);
  });

  testWidgets('selects an additional feeling and can clear it', (tester) async {
    DailyRoutineFeeling? selected = DailyRoutineFeeling.calm;

    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, setState) => DailyRoutineFeelingPicker(
            value: selected,
            enabled: true,
            onChanged: (value) => setState(() => selected = value),
            onSuggestFeeling: () async {},
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('daily-routine-feeling-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('daily-routine-feeling-sad')));
    await tester.pumpAndSettle();
    expect(selected, DailyRoutineFeeling.sad);
    expect(find.text('Selecionado: 😢 Triste'), findsOneWidget);

    await tester.tap(find.byKey(const Key('daily-routine-feeling-clear')));
    await tester.pump();
    expect(selected, isNull);
  });

  testWidgets('disabled picker exposes values without mutable actions', (tester) async {
    var changes = 0;
    await tester.pumpWidget(
      app(
        DailyRoutineFeelingPicker(
          value: DailyRoutineFeeling.calm,
          enabled: false,
          onChanged: (_) => changes += 1,
          onSuggestFeeling: () async => changes += 1,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('daily-routine-feeling-animated')));
    await tester.tap(find.byKey(const Key('daily-routine-feeling-more')));
    await tester.pump();

    expect(changes, 0);
    expect(find.text('Mais sentimentos'), findsNothing);
    expect(find.byKey(const Key('daily-routine-feeling-clear')), findsNothing);
  });

  testWidgets('selected feeling exposes accessible selected semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      app(
        DailyRoutineFeelingPicker(
          value: DailyRoutineFeeling.animated,
          enabled: true,
          onChanged: (_) {},
          onSuggestFeeling: () async {},
        ),
      ),
    );

    final data = tester
        .getSemantics(find.byKey(const Key('daily-routine-feeling-animated')))
        .getSemanticsData();
    expect(data.label, contains('Animado'));
    expect(data.flagsCollection.isSelected, Tristate.isTrue);
    semantics.dispose();
  });

  testWidgets('feeling labels declare a cross-platform emoji font fallback', (tester) async {
    await tester.pumpWidget(
      app(
        DailyRoutineFeelingPicker(
          value: DailyRoutineFeeling.animated,
          enabled: true,
          onChanged: (_) {},
          onSuggestFeeling: () async {},
        ),
      ),
    );

    final label = tester.widget<Text>(find.text('😊 Animado'));
    expect(label.style?.fontFamilyFallback, contains('Segoe UI Emoji'));
    expect(label.style?.fontFamilyFallback, contains('Apple Color Emoji'));
    expect(label.style?.fontFamilyFallback, contains('Noto Color Emoji'));
  });

  testWidgets('suggestion dialog blocks blank text and returns normalized suggestion', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await showDailyRoutineFeelingSuggestionDialog(context);
            },
            child: const Text('Abrir sugestão'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir sugestão'));
    await tester.pumpAndSettle();
    final submit = find.byKey(const Key('daily-routine-feeling-suggestion-submit'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('daily-routine-feeling-suggestion-field')), '   ');
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('daily-routine-feeling-suggestion-field')),
      '  Curioso  ',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);

    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(result, 'Curioso');
    expect(find.text('Curioso'), findsNothing);
  });
}
