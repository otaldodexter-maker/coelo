import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import 'chat_catalog_fixtures.dart';

Map<String, WidgetBuilder> buildChatCatalogExamples() {
  return {
    'core.chat-avatar': (context) => CoeloChatAvatar(
      key: const Key('catalog-chat-avatar-prominent-now'),
      label: 'Turma Girassol',
      initials: 'TG',
      nowState: CoeloNowState.unseen,
      presence: CoeloChatPresence.available,
      presenceLabel: 'Equipe disponível',
      onNowPressed: () => _showCatalogDialog(context, 'Preview de Now'),
      onProfilePressed: () => _showCatalogDialog(context, 'Perfil contextual'),
    ),
    'core.conversation-tile': (context) => CoeloConversationTile(
      avatar: const CoeloChatAvatar(label: 'Turma Girassol', initials: 'TG'),
      title: 'Turma Girassol',
      preview: 'Marina enviou uma mensagem.',
      timestamp: '2 min',
      unreadCount: 3,
      onPressed: () => _showCatalogDialog(context, 'Conversa selecionada'),
    ),
    'core.conversation-header': (context) => CoeloConversationHeader(
      avatar: const CoeloChatAvatar(label: 'Turma Girassol', initials: 'TG'),
      title: 'Turma Girassol',
      subtitle: 'Centro Horizonte · Unidade Cambuí',
      onProfilePressed: () => _showCatalogDialog(context, 'Vínculos autorizados'),
      actions: [
        IconButton(
          tooltip: 'Ver vínculos',
          onPressed: () => _showCatalogDialog(context, 'Vínculos autorizados'),
          icon: const Icon(Icons.info_outline),
        ),
      ],
    ),
    'core.message-bubble': (_) => const Padding(
      padding: EdgeInsets.all(CoeloSpacing.space4),
      child: Column(
        children: [
          CoeloMessageBubble(
            direction: CoeloMessageDirection.received,
            body: 'A atividade de hoje termina às 17h.',
            timestamp: '16:32',
            authorLabel: 'Marina · Professora',
            contextLabel: 'Turma Girassol',
            childLabels: ['Lia'],
          ),
          CoeloMessageBubble(
            direction: CoeloMessageDirection.sent,
            body: 'Obrigada pelo aviso.',
            timestamp: '16:34',
            deliveryState: CoeloMessageDeliveryState.read,
          ),
        ],
      ),
    ),
    'core.chat-composer': (_) => const _ComposerExample(),
    'admin.context-picker': (context) => SizedBox(
      width: 520,
      height: 620,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Selecione este nível ou avance pela hierarquia.'),
          const SizedBox(height: CoeloSpacing.space2),
          Expanded(
            child: CoeloAdminContextPicker(
              options: catalogAdminContextOptions,
              onSelected: (path) =>
                  _showCatalogDialog(context, path.map((option) => option.label).join(' / ')),
            ),
          ),
        ],
      ),
    ),
    'admin.chat-context-summary': (_) => SizedBox(
      width: 288,
      height: 640,
      child: CoeloAdminChatContextSummary(
        title: 'Turma Girassol',
        subtitle: 'Centro Horizonte · Unidade Cambuí',
        metrics: const [
          CoeloAdminChatMetric('Professores', 3),
          CoeloAdminChatMetric('Crianças', 18),
          CoeloAdminChatMetric('Responsáveis', 27),
          CoeloAdminChatMetric('Atividades', 4),
        ],
        collapsed: false,
        onToggle: _noop,
        image: const CoeloChatAvatar(
          label: 'Turma Girassol',
          initials: 'TG',
          size: CoeloSize.avatarXl,
        ),
        footer: const Text('Dados simulados'),
      ),
    ),
  };
}

void _noop() {}

Future<void> _showCatalogDialog(BuildContext context, String title) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: const Text('Interação local do catálogo, sem persistência.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fechar')),
      ],
    ),
  );
}

final class _ComposerExample extends StatefulWidget {
  const _ComposerExample();

  @override
  State<_ComposerExample> createState() => _ComposerExampleState();
}

final class _ComposerExampleState extends State<_ComposerExample> {
  final _controller = TextEditingController();
  var _sent = 0;
  String? _activityLabel;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CoeloChatComposer(
          controller: _controller,
          onSend: () => setState(() {
            _sent++;
            _controller.clear();
          }),
          showAudioAction: true,
          showMediaAction: true,
          onAudioPressed: () => setState(() => _activityLabel = 'Gravando áudio…'),
          onMediaPressed: () => setState(() => _activityLabel = 'Carregando mídia…'),
        ),
        if (_activityLabel != null) Text(_activityLabel!),
        Text('Mensagens simuladas: $_sent'),
      ],
    );
  }
}
