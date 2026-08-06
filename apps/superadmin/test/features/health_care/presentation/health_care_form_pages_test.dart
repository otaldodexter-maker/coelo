import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_care_form_pages.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_action_footer.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('profile create is a responsive full page with canonical fields', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: HealthCareProfileFormPage(
          logout: unavailableSuperadminLogout,
          onCancel: () {},
          onSaved: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alergias e restrições'), findsOneWidget);
    expect(find.text('Orientações de cuidado'), findsOneWidget);
    await tester.tap(find.text('Orientações de cuidado'));
    await tester.pumpAndSettle();
    expect(find.byType(CoeloAdminMultiSelectField<String>), findsOneWidget);
    expect(find.byType(SuperadminFormActionFooter), findsOneWidget);
    expect(find.byKey(const Key('superadmin-chat-launcher-surface')), findsOneWidget);
    expect(find.byType(RadioListTile), findsNothing);
    expect(find.text('Criança'), findsWidgets);
  });

  testWidgets('profile edit locks the child identity', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: HealthCareProfileFormPage(
          logout: unavailableSuperadminLogout,
          childId: 'child-demo-a',
          onCancel: () {},
          onSaved: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Criança Demo A'), findsWidgets);
    expect(find.byType(CoeloAdminSingleSelectField<String>), findsNothing);
    await tester.tap(find.text('Alergias e restrições'));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString().startsWith('CoeloAdminSingleSelectField<'),
      ),
      findsNWidgets(3),
    );
  });

  testWidgets('medication plan separates medicine, period, schedules and document', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.dark,
        home: HealthMedicationPlanFormPage(
          logout: unavailableSuperadminLogout,
          onCancel: () {},
          onSaved: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Criança e medicamento'), findsOneWidget);
    expect(find.text('Vigência'), findsOneWidget);
    expect(find.text('Horários e responsáveis'), findsOneWidget);
    await tester.tap(find.text('Horários e responsáveis'));
    await tester.pumpAndSettle();
    expect(find.text('Contextos de administração'), findsOneWidget);
    await tester.tap(find.text('Documento'));
    await tester.pumpAndSettle();
    expect(find.text('Documento opcional'), findsOneWidget);
    expect(find.byType(SuperadminFormActionFooter), findsOneWidget);
  });

  for (final textScale in [1.0, 2.0]) {
    testWidgets('mobile launchers clear both form footers at ${textScale}x text', (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final page in <Widget>[
        HealthCareProfileFormPage(
          logout: unavailableSuperadminLogout,
          onCancel: () {},
          onSaved: () async {},
        ),
        HealthMedicationPlanFormPage(
          logout: unavailableSuperadminLogout,
          onCancel: () {},
          onSaved: () async {},
        ),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: CoeloTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: page,
          ),
        );
        await tester.pumpAndSettle();

        final launcher = find.byKey(const Key('superadmin-chat-launcher-surface'));
        final footer = find.byType(SuperadminFormActionFooter);
        final primaryAction = find.widgetWithText(FilledButton, 'Continuar');
        final reason = '${page.runtimeType} at ${textScale}x';
        expect(launcher, findsOneWidget, reason: reason);
        expect(footer, findsOneWidget, reason: reason);
        expect(primaryAction, findsOneWidget, reason: reason);
        expect(tester.getRect(launcher).overlaps(tester.getRect(footer)), isFalse, reason: reason);
        expect(
          tester.getRect(launcher).overlaps(tester.getRect(primaryAction)),
          isFalse,
          reason: reason,
        );
      }
    });
  }

  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('both forms have no overflow at $width with 200% text', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final page in <Widget>[
        HealthCareProfileFormPage(
          logout: unavailableSuperadminLogout,
          onCancel: () {},
          onSaved: () async {},
        ),
        HealthMedicationPlanFormPage(
          logout: unavailableSuperadminLogout,
          onCancel: () {},
          onSaved: () async {},
        ),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: CoeloTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: page,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
}
