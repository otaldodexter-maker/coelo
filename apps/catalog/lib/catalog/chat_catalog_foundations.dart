import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import 'catalog_foundation.dart';
import 'chat_catalog_fixtures.dart';

Map<String, CatalogFoundation> buildChatFoundationRegistry() {
  const coreIds = [
    'core.chat-avatar',
    'core.conversation-tile',
    'core.conversation-header',
    'core.message-bubble',
    'core.chat-composer',
  ];
  return {
    'pattern.chat-admin': CatalogFoundation(
      id: 'pattern.chat-admin',
      referencedComponentIds: const [...coreIds, 'admin.context-picker'],
      builder: (_) => const _AdministrativeChatFoundation(),
    ),
    'pattern.chat-principal-mobile': CatalogFoundation(
      id: 'pattern.chat-principal-mobile',
      referencedComponentIds: coreIds,
      builder: (_) => const _PrincipalChatFoundation(),
    ),
    'pattern.chat-principal-web': CatalogFoundation(
      id: 'pattern.chat-principal-web',
      referencedComponentIds: coreIds,
      builder: (_) => const _WebChatLauncherFoundation(),
    ),
    'pattern.chat-states': CatalogFoundation(
      id: 'pattern.chat-states',
      referencedComponentIds: const ['core.state-panel'],
      builder: (_) => const _ChatStatesFoundation(),
    ),
  };
}

final class _AdministrativeChatFoundation extends StatefulWidget {
  const _AdministrativeChatFoundation();

  @override
  State<_AdministrativeChatFoundation> createState() => _AdministrativeChatFoundationState();
}

final class _AdministrativeChatFoundationState extends State<_AdministrativeChatFoundation> {
  var _selected = 1;

  Future<void> _openContextPicker() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: SizedBox(
          width: 560,
          height: 680,
          child: Padding(
            padding: const EdgeInsets.all(CoeloSpacing.space4),
            child: CoeloAdminContextPicker(
              options: catalogAdminContextOptions,
              onSelected: (_) => Navigator.of(dialogContext).pop(),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 700,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inbox = _ConversationInbox(
            selected: _selected,
            onSelected: (index) => setState(() => _selected = index),
            onNewConversation: _openContextPicker,
          );
          if (constraints.maxWidth < 720) {
            return inbox;
          }
          return Row(
            children: [
              SizedBox(width: 320, child: inbox),
              const VerticalDivider(width: 1),
              const Expanded(child: _ConversationThread(showAdministrativeActions: true)),
            ],
          );
        },
      ),
    );
  }
}

final class _PrincipalChatFoundation extends StatelessWidget {
  const _PrincipalChatFoundation();

  Future<void> _showNow(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => const AlertDialog(
        title: Text('Preview de Now'),
        content: AspectRatio(
          aspectRatio: 9 / 16,
          child: ColoredBox(
            color: Colors.black87,
            child: Center(child: Icon(Icons.auto_stories_outlined, color: Colors.white, size: 48)),
          ),
        ),
      ),
    );
  }

  Future<void> _showProfile(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(CoeloSpacing.space5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Vínculos autorizados'),
              SizedBox(height: CoeloSpacing.space2),
              Text('Centro Horizonte / Unidade Cambuí / Turma Girassol'),
              SizedBox(height: CoeloSpacing.space2),
              Text('Criança relacionada: Lia'),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 700,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: ListTile(
              leading: const CoeloChatAvatar(label: 'Coelo oficial', initials: 'C', size: 40),
              title: const Text('Coelo'),
              subtitle: const Text('Assistente oficial · Em breve'),
              trailing: const Icon(Icons.verified_outlined),
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => const AlertDialog(
                  title: Text('Coelo'),
                  content: Text('O assistente de dúvidas chegará em breve.'),
                ),
              ),
            ),
          ),
          CoeloConversationHeader(
            avatar: CoeloChatAvatar(
              key: const Key('catalog-chat-avatar-now'),
              label: 'Turma Girassol',
              initials: 'TG',
              nowState: CoeloNowState.unseen,
              presence: CoeloChatPresence.available,
              presenceLabel: 'Equipe disponível',
              onNowPressed: () => _showNow(context),
              onProfilePressed: () => _showProfile(context),
            ),
            title: 'Turma Girassol',
            subtitle: 'Centro Horizonte · Unidade Cambuí',
            onProfilePressed: () => _showProfile(context),
          ),
          const Expanded(child: _MessageHistory()),
          const _CatalogComposer(),
          NavigationBar(
            selectedIndex: 2,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Flow'),
              NavigationDestination(icon: Icon(Icons.event_note_outlined), label: 'Rotina'),
              NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
              NavigationDestination(icon: Icon(Icons.calendar_month_outlined), label: 'Agenda'),
            ],
          ),
        ],
      ),
    );
  }
}

final class _WebChatLauncherFoundation extends StatefulWidget {
  const _WebChatLauncherFoundation();

  @override
  State<_WebChatLauncherFoundation> createState() => _WebChatLauncherFoundationState();
}

final class _WebChatLauncherFoundationState extends State<_WebChatLauncherFoundation> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 680,
      child: Stack(
        children: [
          const Center(
            child: CoeloStatePanel(
              title: 'Suas mensagens',
              message: 'Escolha uma conversa ou inicie uma nova.',
              icon: Icons.chat_bubble_outline,
            ),
          ),
          Positioned(
            right: CoeloSpacing.space4,
            bottom: CoeloSpacing.space4,
            child: _open
                ? Material(
                    elevation: CoeloElevation.level3,
                    borderRadius: BorderRadius.circular(CoeloRadius.lg),
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox(
                      width: 340,
                      height: 460,
                      child: _ConversationInbox(
                        selected: 1,
                        onSelected: (_) {},
                        onClose: () => setState(() => _open = false),
                        onNewConversation: () {},
                      ),
                    ),
                  )
                : FilledButton.tonalIcon(
                    key: const Key('catalog-chat-launcher'),
                    onPressed: () => setState(() => _open = true),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Mensagens 3'),
                  ),
          ),
        ],
      ),
    );
  }
}

final class _ConversationInbox extends StatelessWidget {
  const _ConversationInbox({
    required this.selected,
    required this.onSelected,
    required this.onNewConversation,
    this.onClose,
  });

  final int selected;
  final ValueChanged<int> onSelected;
  final VoidCallback onNewConversation;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            CoeloSpacing.space4,
            CoeloSpacing.space2,
            CoeloSpacing.space2,
            CoeloSpacing.space2,
          ),
          child: Row(
            children: [
              Expanded(child: Text('Conversas', style: Theme.of(context).textTheme.titleMedium)),
              IconButton(
                tooltip: 'Nova conversa',
                onPressed: onNewConversation,
                icon: const Icon(Icons.edit_square),
              ),
              if (onClose != null)
                IconButton(
                  tooltip: 'Fechar conversas',
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: CoeloSpacing.space3),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Buscar conversas',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        const SizedBox(height: CoeloSpacing.space2),
        Expanded(
          child: ListView.builder(
            itemCount: catalogChatConversations.length,
            itemBuilder: (context, index) {
              final conversation = catalogChatConversations[index];
              return CoeloConversationTile(
                avatar: CoeloChatAvatar(
                  label: conversation.title,
                  initials: conversation.initials,
                  nowState: conversation.nowState,
                  presence: conversation.presence,
                  presenceLabel: conversation.presence == CoeloChatPresence.available
                      ? 'Equipe disponível'
                      : null,
                ),
                title: conversation.title,
                preview: conversation.preview,
                timestamp: conversation.timestamp,
                unreadCount: conversation.unreadCount,
                selected: selected == index,
                onPressed: () => onSelected(index),
              );
            },
          ),
        ),
      ],
    );
  }
}

final class _ConversationThread extends StatelessWidget {
  const _ConversationThread({this.showAdministrativeActions = false});

  final bool showAdministrativeActions;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CoeloConversationHeader(
          avatar: const CoeloChatAvatar(label: 'Turma Girassol', initials: 'TG'),
          title: 'Turma Girassol',
          subtitle: 'Centro Horizonte · Unidade Cambuí',
          onProfilePressed: () => _showAuthorizedRelationships(context),
          actions: [
            if (showAdministrativeActions)
              IconButton(
                tooltip: 'Ver vínculos',
                onPressed: () => _showAuthorizedRelationships(context),
                icon: const Icon(Icons.account_tree_outlined),
              ),
          ],
        ),
        const Expanded(child: _MessageHistory()),
        const _CatalogComposer(),
      ],
    );
  }

  Future<void> _showAuthorizedRelationships(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vínculos autorizados'),
        content: const Text('Centro Horizonte / Unidade Cambuí / Turma Girassol'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fechar')),
        ],
      ),
    );
  }
}

final class _MessageHistory extends StatelessWidget {
  const _MessageHistory();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      children: const [
        Center(child: Text('Hoje, 16:30')),
        CoeloMessageBubble(
          direction: CoeloMessageDirection.received,
          authorLabel: 'Marina · Professora',
          contextLabel: 'Turma Girassol',
          childLabels: ['Lia'],
          body: 'A atividade de hoje termina às 17h.',
          timestamp: '16:32',
        ),
        CoeloMessageBubble(
          direction: CoeloMessageDirection.sent,
          body: 'Obrigada pelo aviso.',
          timestamp: '16:34',
          deliveryState: CoeloMessageDeliveryState.read,
        ),
      ],
    );
  }
}

final class _CatalogComposer extends StatefulWidget {
  const _CatalogComposer();

  @override
  State<_CatalogComposer> createState() => _CatalogComposerState();
}

final class _CatalogComposerState extends State<_CatalogComposer> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CoeloChatComposer(
      controller: _controller,
      onSend: _controller.clear,
      showAudioAction: true,
      showMediaAction: true,
      onAudioPressed: () => _showSimulation(context, 'Gravando áudio…'),
      onMediaPressed: () => _showSimulation(context, 'Carregando mídia…'),
    );
  }

  void _showSimulation(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

final class _ChatStatesFoundation extends StatelessWidget {
  const _ChatStatesFoundation();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: CoeloSpacing.space4,
      runSpacing: CoeloSpacing.space4,
      children: const [
        _StatePreview(
          title: 'Carregando conversas',
          message: 'Buscando apenas os contextos autorizados.',
          icon: Icons.hourglass_top_outlined,
        ),
        _StatePreview(
          title: 'Sem conversas',
          message: 'Inicie uma conversa dentro de um contexto autorizado.',
          icon: Icons.chat_bubble_outline,
        ),
        _StatePreview(
          title: 'Sem conexão',
          message: 'Verifique sua internet e tente novamente.',
          icon: Icons.cloud_off_outlined,
        ),
        _StatePreview(
          title: 'Não foi possível carregar',
          message: 'Tente novamente sem perder o contexto selecionado.',
          icon: Icons.error_outline,
        ),
        _StatePreview(
          title: 'Somente leitura',
          message: 'Este vínculo terminou. O histórico continua disponível.',
          icon: Icons.lock_outline,
        ),
        _StatePreview(
          title: 'Acesso bloqueado',
          message: 'Você não possui permissão para ver esta conversa.',
          icon: Icons.block_outlined,
        ),
        _StatePreview(
          title: 'Acesso revogado',
          message: 'O fio saiu da inbox e permanece no histórico somente leitura.',
          icon: Icons.history_toggle_off_outlined,
        ),
        _StatePreview(
          title: 'Coelo · Em breve',
          message: 'O assistente oficial ainda não está disponível.',
          icon: Icons.smart_toy_outlined,
        ),
      ],
    );
  }
}

final class _StatePreview extends StatelessWidget {
  const _StatePreview({required this.title, required this.message, required this.icon});

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 304,
      child: Card(
        child: CoeloStatePanel(title: title, message: message, icon: icon),
      ),
    );
  }
}
