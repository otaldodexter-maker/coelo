import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/shell/superadmin_shell.dart';
import '../../../auth/domain/logout_action.dart';
import '../../data/supabase_chat_repository.dart';
import '../../domain/chat_repository.dart';
import '../widgets/superadmin_chat_composer.dart';

final class SuperadminChatPage extends StatefulWidget {
  const SuperadminChatPage({
    required this.logout,
    this.chatRepository,
    this.onDestinationSelected,
    this.onBack,
    super.key,
  });

  final LogoutAction logout;
  final ChatRepository? chatRepository;
  final ValueChanged<String>? onDestinationSelected;
  final VoidCallback? onBack;

  @override
  State<SuperadminChatPage> createState() => _SuperadminChatPageState();
}

final class _SuperadminChatPageState extends State<SuperadminChatPage> {
  final _search = TextEditingController();
  final _composer = TextEditingController();
  late final ChatRepository _repository;
  ChatInboxState _inboxState = const ChatInboxState.loading();
  ChatConversationSummary? _selected;
  ChatThreadPage? _thread;
  Object? _threadError;
  var _sending = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.chatRepository ?? _configuredRepository();
    _loadInbox();
  }

  @override
  void dispose() {
    _search.dispose();
    _composer.dispose();
    super.dispose();
  }

  ChatRepository _configuredRepository() {
    try {
      return SupabaseChatRepository(Supabase.instance.client);
    } catch (_) {
      return const _UnavailableChatRepository();
    }
  }

  Future<void> _loadInbox() async {
    setState(() => _inboxState = const ChatInboxState.loading());
    try {
      final page = await _repository.fetchInbox(ChatInboxQuery(search: _search.text));
      if (!mounted) return;
      setState(() => _inboxState = ChatInboxState.loaded(page, search: _search.text));
      if (page.items.isNotEmpty) await _select(page.items.first);
    } on ChatUnauthorizedException catch (error) {
      if (mounted) setState(() => _inboxState = ChatInboxState.unauthorized(error));
    } on ChatOfflineException catch (error) {
      if (mounted) setState(() => _inboxState = ChatInboxState.offline(error));
    } catch (error) {
      if (mounted) setState(() => _inboxState = ChatInboxState.failure(error));
    }
  }

  Future<void> _select(ChatConversationSummary conversation) async {
    setState(() {
      _selected = conversation;
      _thread = null;
      _threadError = null;
    });
    try {
      final thread = await _repository.fetchThread(
        ChatThreadQuery(conversationId: conversation.id),
      );
      if (!mounted || _selected?.id != conversation.id) return;
      setState(() => _thread = thread);
      if (thread.items.isNotEmpty) {
        await _repository.markRead(
          conversationId: conversation.id,
          upToMessageId: thread.items.first.id,
        );
      }
    } catch (error) {
      if (mounted && _selected?.id == conversation.id) setState(() => _threadError = error);
    }
  }

  Future<void> _send() async {
    final conversation = _selected;
    final body = _composer.text.trim();
    if (conversation == null || body.isEmpty || conversation.isReadOnly || _sending) return;
    setState(() => _sending = true);
    try {
      final sent = await _repository.sendMessage(
        ChatSendMessageCommand(
          conversationId: conversation.id,
          body: body,
          idempotencyKey: _requestId(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _composer.clear();
        _thread = ChatThreadPage(items: [...?_thread?.items, sent]);
      });
    } on ChatUnauthorizedException {
      if (mounted) _showNotice('Sua permissao para esta conversa foi alterada.');
    } on ChatOfflineException {
      if (mounted) _showNotice('Sem conexao. A mensagem nao foi enviada.');
    } catch (_) {
      if (mounted) _showNotice('Nao foi possivel enviar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showNotice(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    return SuperadminShell(
      logout: widget.logout,
      title: 'Conversas',
      subtitle: 'Comunicacao institucional privada e contextual.',
      currentDestination: 'conversations',
      onDestinationSelected: widget.onDestinationSelected,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(CoeloRadius.lg),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: _body(),
      ),
    );
  }

  Widget _body() {
    return switch (_inboxState.kind) {
      ChatInboxLoadState.loading => const CoeloStatePanel(
        title: 'Carregando conversas',
        message: 'Aguarde enquanto buscamos suas conversas.',
        loading: true,
      ),
      ChatInboxLoadState.empty => CoeloStatePanel(
        title: 'Ainda n\u00e3o h\u00e1 conversas',
        message: 'Quando uma conversa autorizada existir, ela aparecera aqui.',
        icon: Icons.forum_outlined,
        actionLabel: 'Atualizar',
        onAction: _loadInbox,
      ),
      ChatInboxLoadState.noResults => CoeloStatePanel(
        title: 'Nenhuma conversa encontrada',
        message: 'Ajuste a busca e tente novamente.',
        icon: Icons.search_off_rounded,
        actionLabel: 'Limpar busca',
        onAction: () {
          _search.clear();
          _loadInbox();
        },
      ),
      ChatInboxLoadState.unauthorized => CoeloStatePanel(
        title: 'Acesso nao autorizado',
        message: 'Seu perfil nao permite consultar estas conversas.',
        icon: Icons.lock_outline,
      ),
      ChatInboxLoadState.offline => CoeloStatePanel(
        title: 'Sem conexao',
        message: 'Verifique sua conexao e tente novamente.',
        icon: Icons.cloud_off_outlined,
        actionLabel: 'Tentar novamente',
        onAction: _loadInbox,
      ),
      ChatInboxLoadState.failure => CoeloStatePanel(
        title: 'Nao foi possivel carregar',
        message: 'Tente novamente em instantes.',
        icon: Icons.error_outline,
        actionLabel: 'Tentar novamente',
        onAction: _loadInbox,
      ),
      ChatInboxLoadState.ready => _workspace(_inboxState.page!),
    };
  }

  Widget _workspace(ChatInboxPage page) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
        final inbox = _inbox(page, compact: compact);
        final thread = _threadBody(compact: compact);
        if (compact && _selected != null) return thread;
        return Row(
          children: [
            SizedBox(width: compact ? constraints.maxWidth : 336, child: inbox),
            if (!compact) const VerticalDivider(width: 1),
            if (!compact) Expanded(child: thread),
          ],
        );
      },
    );
  }

  Widget _inbox(ChatInboxPage page, {required bool compact}) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space3),
          child: TextField(
            controller: _search,
            onSubmitted: (_) => _loadInbox(),
            decoration: InputDecoration(
              hintText: 'Buscar conversas',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                tooltip: 'Buscar',
                onPressed: _loadInbox,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: page.items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = page.items[index];
              final selected = item.id == _selected?.id;
              return Semantics(
                button: true,
                selected: selected,
                label: '${item.title}, ${item.unreadCount} nao lidas',
                child: TextButton(
                  key: Key('chat-real-conversation-${item.id}'),
                  onPressed: () => _select(item),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(CoeloSize.touchMin),
                    padding: const EdgeInsets.all(CoeloSpacing.space3),
                    alignment: Alignment.centerLeft,
                    backgroundColor: selected ? colors.primaryContainer : colors.surface,
                    foregroundColor: selected ? colors.primary : colors.onSurface,
                    shape: const RoundedRectangleBorder(),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(child: Text(_initials(item.title))),
                      const SizedBox(width: CoeloSpacing.space3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text(
                              item.preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (item.unreadCount > 0)
                        Badge(label: Text(item.unreadCount > 9 ? '9+' : '${item.unreadCount}')),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _threadBody({required bool compact}) {
    final conversation = _selected;
    if (conversation == null) {
      return const CoeloStatePanel(
        title: 'Selecione uma conversa',
        message: 'Escolha uma conversa autorizada para ver as mensagens.',
        icon: Icons.forum_outlined,
      );
    }
    if (_threadError != null) {
      return CoeloStatePanel(
        title: 'Nao foi possivel carregar a conversa',
        message: 'Tente novamente.',
        icon: Icons.error_outline,
        actionLabel: 'Tentar novamente',
        onAction: () => _select(conversation),
      );
    }
    final thread = _thread;
    if (thread == null) {
      return const CoeloStatePanel(
        title: 'Carregando conversa',
        message: 'Aguarde enquanto buscamos as mensagens.',
        loading: true,
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space3),
          child: Row(
            children: [
              if (compact)
                IconButton(
                  tooltip: 'Voltar para conversas',
                  onPressed: () => setState(() => _selected = null),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              Expanded(
                child: Text(conversation.title, style: Theme.of(context).textTheme.titleMedium),
              ),
              if (conversation.isReadOnly) const Icon(Icons.lock_outline),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            reverse: true,
            padding: const EdgeInsets.all(CoeloSpacing.space3),
            itemCount: thread.items.length,
            itemBuilder: (context, reverseIndex) {
              final message = thread.items[thread.items.length - 1 - reverseIndex];
              return _MessageBubble(message: message);
            },
          ),
        ),
        if (!conversation.isReadOnly)
          SuperadminChatComposer(
            controller: _composer,
            compact: compact,
            onSend: _send,
            onAudio: () => _showNotice('Anexos aguardam o gateway R2 autorizado.'),
            onImage: () => _showNotice('Anexos aguardam o gateway R2 autorizado.'),
          ),
      ],
    );
  }
}

final class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: '${message.authorName}. ${message.body}',
      child: Align(
        alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: CoeloSize.touchMin * 11),
          margin: const EdgeInsets.only(bottom: CoeloSpacing.space2),
          padding: const EdgeInsets.all(CoeloSpacing.space3),
          decoration: BoxDecoration(
            color: message.isMine ? colors.primaryContainer : colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(CoeloRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message.authorName, style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: CoeloSpacing.space1),
              Text(message.body),
            ],
          ),
        ),
      ),
    );
  }
}

final class _UnavailableChatRepository implements ChatRepository {
  const _UnavailableChatRepository();
  @override
  Future<int> fetchUnreadTotal() async => 0;

  @override
  Future<ChatInboxPage> fetchInbox(ChatInboxQuery query) =>
      Future<ChatInboxPage>.error(const ChatFailureException());
  @override
  Future<ChatThreadPage> fetchThread(ChatThreadQuery query) =>
      Future<ChatThreadPage>.error(const ChatFailureException());
  @override
  Future<ChatMessage> sendMessage(ChatSendMessageCommand command) =>
      Future<ChatMessage>.error(const ChatFailureException());
  @override
  Future<void> markRead({required String conversationId, required String upToMessageId}) =>
      Future<void>.error(const ChatFailureException());
  @override
  Future<ChatRealtimeRefresh> refreshAfterRealtime({required String conversationId}) =>
      Future<ChatRealtimeRefresh>.error(const ChatFailureException());
}

String _initials(String value) => value
    .split(RegExp(r'\\s+'))
    .where((part) => part.isNotEmpty)
    .take(2)
    .map((part) => part[0])
    .join()
    .toUpperCase();

String _requestId() {
  final random = math.Random.secure();
  final values = List<int>.generate(16, (_) => random.nextInt(256));
  values[6] = (values[6] & 0x0f) | 0x40;
  values[8] = (values[8] & 0x3f) | 0x80;
  final hex = values.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
