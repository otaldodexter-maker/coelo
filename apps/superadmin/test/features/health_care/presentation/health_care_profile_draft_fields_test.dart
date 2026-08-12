import 'dart:ui' as ui;

import 'package:coelo_superadmin/features/health_care/presentation/widgets/health_care_profile_draft_fields.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _other = 'other';
const _options = <HealthCareAllergyKind, List<String>>{
  HealthCareAllergyKind.food: ['peanut', _other],
  HealthCareAllergyKind.medication: ['medicine', _other],
  HealthCareAllergyKind.restriction: ['lactose', _other],
  HealthCareAllergyKind.other: [_other],
};
String _label(String id) =>
    {'peanut': 'Amendoim', 'medicine': 'Medicamento', _other: 'Outro'}[id] ?? id;

void main() {
  Widget subject(Widget child, {double width = 375}) => MaterialApp(
    theme: CoeloTheme.light,
    home: Scaffold(
      body: SizedBox(
        width: width,
        child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  );

  testWidgets('severity exposes five levels and selected semantics', (tester) async {
    var selected = HealthCareSeverityLevel.moderate;
    Widget field() =>
        subject(HealthCareSeverityField(value: selected, onChanged: (value) => selected = value));
    await tester.pumpWidget(field());
    for (final label in const ['Muito leve', 'Leve', 'Moderada', 'Grave', 'Muito grave']) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('Muito grave'));
    await tester.pumpWidget(field());
    expect(selected, HealthCareSeverityLevel.verySevere);
    expect(
      tester
          .getSemantics(find.byKey(const Key('health-severity-verySevere')))
          .flagsCollection
          .isSelected,
      ui.Tristate.isTrue,
    );
  });

  testWidgets('multiple allergy drafts preserve independent details', (tester) async {
    final changes = <(int, HealthCareAllergyDraft)>[];
    var added = false;
    var removed = -1;
    const drafts = [
      HealthCareAllergyDraft(
        id: 'one',
        itemId: 'peanut',
        reaction: 'Inchaço',
        guidance: 'Acionar responsável',
      ),
      HealthCareAllergyDraft(
        id: 'two',
        kind: HealthCareAllergyKind.medication,
        itemId: _other,
        otherItem: 'Prescrito',
        reaction: 'Vermelhidão',
      ),
    ];
    await tester.pumpWidget(
      subject(
        HealthCareAllergyDraftsEditor(
          drafts: drafts,
          itemOptions: _options,
          itemLabel: _label,
          otherItemId: _other,
          onChanged: (index, value) => changes.add((index, value)),
          onAdd: () => added = true,
          onRemove: (index) => removed = index,
        ),
      ),
    );
    expect(find.text('Amendoim'), findsOneWidget);
    expect(find.text('Prescrito'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('health-allergy-add')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('health-allergy-add')));
    expect(added, isTrue);
    await tester.ensureVisible(find.byKey(const Key('health-allergy-remove-1')));
    await tester.tap(find.byKey(const Key('health-allergy-remove-1')));
    expect(removed, 1);
    await tester.ensureVisible(find.byKey(const Key('health-allergy-reaction-0')));
    await tester.enterText(find.byKey(const Key('health-allergy-reaction-0')), 'Urticária');
    expect(changes.last.$1, 0);
    expect(changes.last.$2.guidance, 'Acionar responsável');
  });

  testWidgets('care items keep signs and adaptations per item', (tester) async {
    final changes = <(int, HealthCareCareItemDraft)>[];
    await tester.pumpWidget(
      subject(
        HealthCareCareItemDraftsEditor(
          drafts: const [
            HealthCareCareItemDraft(id: 'a', label: 'Autismo', signs: 'Sobrecarga'),
            HealthCareCareItemDraft(id: 'b', label: 'Diabetes', signs: 'Tremor'),
          ],
          onChanged: (index, value) => changes.add((index, value)),
        ),
      ),
    );
    await tester.ensureVisible(find.byKey(const Key('health-care-adaptations-1')));
    await tester.enterText(find.byKey(const Key('health-care-adaptations-1')), 'Medir glicemia');
    expect(changes.last.$1, 1);
    expect(changes.last.$2.signs, 'Tremor');
  });

  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('has no overflow at $width with 200 percent text', (tester) async {
      tester.view.physicalSize = Size(width, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: CoeloTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: HealthCareAllergyDraftsEditor(
                drafts: const [HealthCareAllergyDraft(id: 'one', itemId: 'peanut')],
                itemOptions: _options,
                itemLabel: _label,
                otherItemId: _other,
                onChanged: (_, _) {},
                onAdd: () {},
                onRemove: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
