import 'package:coelo_superadmin/features/chat/presentation/chat_fixtures.dart';
import 'package:coelo_superadmin/features/chat/presentation/chat_models.dart';
import 'package:coelo_superadmin/features/chat/presentation/widgets/superadmin_chat_context_panel.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the complete metric matrix with bordered icon cards', (tester) async {
    for (final conversation in superadminChatConversations) {
      await tester.pumpWidget(_app(conversation));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('superadmin-chat-context-metric')),
        findsNWidgets(conversation.metrics.length),
        reason: conversation.title,
      );
      expect(
        find.byKey(const Key('superadmin-chat-context-metric-icon')),
        findsNWidgets(conversation.metrics.length),
        reason: conversation.title,
      );
      await tester.scrollUntilVisible(
        find.text('Demonstração local'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Demonstração local'), findsOne);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('switches a dual profile between professional and guardian', (tester) async {
    final marina = superadminChatConversations.firstWhere((item) => item.id == 'marina');
    await tester.pumpWidget(_app(marina));
    await tester.pumpAndSettle();

    expect(find.text('Profissional'), findsOne);
    expect(find.text('Responsável'), findsOne);
    expect(find.text('Funcionários'), findsOne);
    await tester.tap(find.text('Responsável'));
    await tester.pumpAndSettle();

    expect(find.text('Lia'), findsOne);
    expect(find.text('Theo'), findsOne);
    expect(find.text('Funcionários'), findsNothing);
    expect(find.text('Instituições'), findsOne);
  });

  testWidgets('does not duplicate location and renders type and plan as subtle metadata', (
    tester,
  ) async {
    final institution = superadminChatConversations.firstWhere(
      (item) => item.kind == ChatContextKind.institution,
    );
    await tester.pumpWidget(_app(institution));
    await tester.pumpAndSettle();

    expect(find.text(institution.location!), findsOne);
    expect(find.byType(Chip), findsNothing);
    expect(find.byKey(const Key('superadmin-chat-context-type')), findsOne);
    expect(find.byKey(const Key('superadmin-chat-context-plan')), findsOne);
    final closeButton = tester.widget<IconButton>(
      find.ancestor(of: find.byTooltip('Fechar contexto'), matching: find.byType(IconButton)),
    );
    expect(closeButton.color, CoeloTheme.light.colorScheme.error);
  });

  testWidgets('shows members, roles and origins for a manual group', (tester) async {
    const group = SuperadminChatConversation(
      id: 'manual',
      title: 'Equipe integrada',
      initials: 'EI',
      preview: '2 participantes',
      timestamp: 'Agora',
      context: '2 instituições · Demonstração local',
      kind: ChatContextKind.conversationGroup,
      facets: {ChatAudience.institutional, ChatAudience.people},
      metrics: [SuperadminChatMetric('Participantes', 2), SuperadminChatMetric('Instituições', 2)],
      messages: [],
      members: [
        SuperadminChatMember(
          id: 'marina',
          name: 'Marina Alves',
          role: 'Professora',
          institution: 'Centro Horizonte',
          origin: 'Turma Girassol',
          facets: {ChatAudience.people},
        ),
        SuperadminChatMember(
          id: 'aurora',
          name: 'Instituto Aurora',
          role: 'Instituição',
          institution: 'Instituto Aurora',
          origin: 'Jardins, São Paulo/SP',
          facets: {ChatAudience.institutional},
        ),
      ],
    );
    await tester.pumpWidget(_app(group));
    await tester.pumpAndSettle();

    expect(find.text('Membros e origens'), findsOne);
    expect(find.text('Marina Alves'), findsOne);
    expect(find.textContaining('Professora · Centro Horizonte'), findsOne);
    expect(find.text('Instituto Aurora'), findsOne);
  });
}

Widget _app(SuperadminChatConversation conversation) {
  return MaterialApp(
    theme: CoeloTheme.light,
    home: Scaffold(
      body: SizedBox(
        width: 360,
        child: SuperadminChatContextPanel(conversation: conversation, onClose: () {}),
      ),
    ),
  );
}
