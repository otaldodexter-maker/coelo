import 'package:coelo_superadmin/features/chat/presentation/chat_fixtures.dart';
import 'package:coelo_superadmin/features/chat/presentation/widgets/superadmin_chat_context_panel.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows granular simulated metrics for every supported recipient', (tester) async {
    final cases = <({SuperadminChatConversation conversation, List<String> labels})>[
      (
        conversation: superadminChatConversations[3],
        labels: const ['Unidades', 'Grupos', 'Atividades', 'Pessoas'],
      ),
      (
        conversation: superadminChatConversations[1],
        labels: const ['Grupos', 'Funcionários', 'Crianças', 'Atividades'],
      ),
      (
        conversation: superadminChatConversations[0],
        labels: const ['Professores', 'Crianças', 'Responsáveis', 'Atividades'],
      ),
      (
        conversation: _personConversation,
        labels: const ['Instituições', 'Unidades', 'Turmas', 'Crianças'],
      ),
    ];

    for (final testCase in cases) {
      await tester.pumpWidget(_app(testCase.conversation));

      expect(
        find.byKey(const Key('coelo-admin-chat-context-metric')),
        findsNWidgets(testCase.labels.length),
        reason: testCase.conversation.title,
      );
      for (final label in testCase.labels) {
        expect(find.text(label), findsOne, reason: testCase.conversation.title);
      }
      expect(find.text('Dados simulados'), findsOne);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('toggles between the summary and its collapsed control', (tester) async {
    var toggles = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: SizedBox(
            width: 720,
            height: 720,
            child: SuperadminChatContextPanel(
              conversation: superadminChatConversations.first,
              collapsed: false,
              onToggle: () => toggles++,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Turma Girassol'), findsOne);
    await tester.tap(find.byTooltip('Recolher painel contextual'));
    expect(toggles, 1);

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: SizedBox(
            width: CoeloSize.touchMin + CoeloSpacing.space4,
            height: 720,
            child: SuperadminChatContextPanel(
              conversation: superadminChatConversations.first,
              collapsed: true,
              onToggle: () => toggles++,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('superadmin-chat-context-panel-collapsed')), findsOne);
    await tester.tap(find.byTooltip('Mostrar detalhes do contexto'));
    expect(toggles, 2);
  });

  for (final themeCase in [
    (name: 'light', data: CoeloTheme.light),
    (name: 'dark', data: CoeloTheme.dark),
  ]) {
    testWidgets('supports 200 percent text in ${themeCase.name}', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: themeCase.data,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 720,
              child: SuperadminChatContextPanel(
                conversation: superadminChatConversations.first,
                collapsed: false,
                onToggle: _noop,
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('superadmin-chat-context-panel')), findsOne);
      expect(find.text('Professores'), findsOne);
      expect(tester.takeException(), isNull);
    });
  }
}

const _personConversation = SuperadminChatConversation(
  id: 'person-demo',
  title: 'Pessoa simulada',
  initials: 'PS',
  preview: 'Conversa de demonstração local.',
  timestamp: 'Agora',
  context: 'Demonstração local',
  institution: 'Instituição simulada',
  targetKind: CoeloAdminContextKind.institution,
  metrics: [
    CoeloAdminChatMetric('Instituições', 2),
    CoeloAdminChatMetric('Unidades', 3),
    CoeloAdminChatMetric('Turmas', 2),
    CoeloAdminChatMetric('Crianças', 2),
  ],
);

Widget _app(SuperadminChatConversation conversation) {
  return MaterialApp(
    theme: CoeloTheme.light,
    home: Scaffold(
      body: SizedBox(
        width: 320,
        height: 720,
        child: SuperadminChatContextPanel(
          conversation: conversation,
          collapsed: false,
          onToggle: _noop,
        ),
      ),
    ),
  );
}

void _noop() {}
