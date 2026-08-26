import '../../../support/activities/fake_activity_directory_repository.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_directory.dart';
import 'package:coelo_superadmin/features/activities/presentation/activity_detail_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders a minimized read-only activity detail', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var editCount = 0;
    ActivityDetail? assessmentDetail;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: ActivityDetailPage(
          activityId: 'activity-1',
          repository: FakeActivityDirectoryRepository(),
          logout: () async => const LogoutResult.success(),
          onBack: () {},
          onEdit: () => editCount++,
          onAssessmentSettings: (detail) => assessmentDetail = detail,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Visualizar atividade'), findsOneWidget);
    expect(find.text('Identidade'), findsOneWidget);
    expect(find.text('Governança'), findsWidgets);
    expect(find.text('Unidades vinculadas'), findsOneWidget);
    expect(find.text('Turmas vinculadas'), findsOneWidget);
    expect(find.text('Profissionais atribuídos'), findsWidgets);
    expect(find.text('Participantes'), findsWidgets);
    expect(find.text('Editar atividade'), findsOneWidget);
    expect(find.text('Configuração avaliativa'), findsOneWidget);
    expect(find.textContaining('Criar'), findsNothing);
    expect(find.textContaining('Arquivos'), findsNothing);
    expect(find.byType(CoeloFormTextField), findsNothing);
    expect(find.byType(TextFormField), findsNothing);

    await tester.tap(find.text('Editar atividade'));
    expect(editCount, 1);
    await tester.tap(find.text('Configuração avaliativa'));
    expect(assessmentDetail?.item.id, 'activity-1');
  });

  testWidgets('renders not-found without exposing an edit action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.dark,
        home: ActivityDetailPage(
          activityId: 'missing',
          repository: FakeActivityDirectoryRepository(),
          logout: () async => const LogoutResult.success(),
          onBack: () {},
          onEdit: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Atividade não encontrada'), findsOneWidget);
    expect(find.textContaining('Editar'), findsNothing);
  });
}
