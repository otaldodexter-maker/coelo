import 'package:coelo_superadmin/features/activities/data/fake_activity_directory_repository.dart';
import 'package:coelo_superadmin/features/activities/presentation/activity_form_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_action_footer.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('creates a visual prototype with only confirmed fields', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var submitted = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: ActivityFormPage(
          repository: FakeActivityDirectoryRepository(),
          logout: () async => const LogoutResult.success(),
          onCancel: () {},
          onPrototypeSubmitted: () => submitted = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Criar atividade'), findsWidgets);
    expect(find.byType(CoeloFormTextField), findsNWidgets(2));
    expect(find.byType(CoeloAdminSingleSelectField<String>), findsNWidgets(2));
    expect(find.text('Status'), findsNothing);
    expect(find.text('Recorrência'), findsNothing);
    expect(find.byType(SuperadminFormActionFooter), findsOneWidget);
    expect(find.byKey(const Key('activity-suggestions')), findsOneWidget);
    for (final label in [
      'Acadêmicas',
      'Linguagens',
      'Português',
      'Inglês',
      'Exatas',
      'Matemática',
      'Robótica',
      'Esportes',
      'Aquáticos',
      'Natação',
      'Lutas',
      'Judô',
      'Campo',
      'Futebol',
      'Artes',
      'Visuais',
      'Desenho',
      'Natureza',
      'Educação ambiental',
      'Horta',
      'Outro',
    ]) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.byKey(const Key('activity-context-preview')), findsOneWidget);
    expect(find.byKey(const Key('activity-photo-preview')), findsOneWidget);
    expect(find.byKey(const Key('activity-conversation-preview')), findsOneWidget);
    expect(find.byKey(const Key('activity-publication-preview')), findsOneWidget);
    expect(find.text('Atividade Nova atividade · Grupo selecionado'), findsOneWidget);

    await tester.tap(find.byKey(const Key('activity-form-submit')));
    await tester.pump();
    expect(find.text('Informe o nome da atividade.'), findsOneWidget);
    expect(submitted, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hydrates edit and keeps institutional context read-only', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.dark,
        home: ActivityFormPage(
          activityId: 'activity-1',
          repository: FakeActivityDirectoryRepository(),
          logout: () async => const LogoutResult.success(),
          onCancel: () {},
          onPrototypeSubmitted: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Editar atividade'), findsOneWidget);
    expect(find.text('Casa Nuvem'), findsOneWidget);
    expect(find.text('Instituição'), findsWidgets);
    expect(find.text('Origem'), findsOneWidget);
    expect(find.byType(CoeloAdminSingleSelectField<String>), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
