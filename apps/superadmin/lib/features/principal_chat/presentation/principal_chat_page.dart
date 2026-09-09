import 'dart:async';
import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../chat/domain/chat_repository.dart';
import '../../principal_shared/presentation/principal_global_navigation.dart';

/// Chat contextual da família Coelo (Principal), hospedado em `apps/superadmin`.
///
/// É uma superfície própria do Principal: consome o `ChatRepository` mantido por
/// Comunicação e não importa `SuperadminChat*` nem `coelo_ui_admin`. O launcher
/// Mensagens do dock abre esta tela, então ela não repete esse launcher —
/// a spec050 proíbe duas entradas de mensagens na mesma superfície — e oferece
/// retorno contextual para a superfície de origem.
///
/// Um id de conversa não concede acesso: inbox, thread, leitura e envio são
/// revalidados pelo servidor a cada chamada.
final class PrincipalChatPage extends StatefulWidget {
  const PrincipalChatPage({
    required this.chatRepository,
    this.embedded = false,
    this.onBack,
    this.onOpenMenu,
    this.onOpenNotifications,
    this.onOpenProfile,
    super.key,
  });

  /// Fora de `/dev` é o repository produtivo compartilhado. Quando a composição
  /// não puder fornecê-lo, a rota falha fechada antes de montar esta página.
  final ChatRepository chatRepository;

  /// Decisão final do Owner de 09/09/2026, registrada em `PRINCIPAL.md`: com o
  /// hospedeiro Superadmin, no web e no mobile, o shell/menu hospedeiro é
  /// preservado e a experiência Principal fica no contêiner de conteúdo.
  /// Hospedada assim, esta superfície não traz o próprio cabeçalho — só os
  /// elementos internos do Principal podem ser suspensos, nunca o shell.
  final bool embedded;

  final VoidCallback? onBack;
  final VoidCallback? onOpenMenu;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenProfile;

  @override
  State<PrincipalChatPage> createState() => _PrincipalChatPageState();
}

final class _PrincipalChatPageState extends State<PrincipalChatPage> {
  static const _pageSize = 20;

  final _search = TextEditingController();
  final _composer = TextEditingController();
  Timer? _searchDebounce;

  int _inboxGeneration = 0;
  int _threadGeneration = 0;
  int _sendGeneration = 0;

  late ChatRepository _repository;
  ChatInboxState _inboxState = const ChatInboxState.loading();
  ChatConversationSummary? _selected;
  ChatThreadPage? _thread;
  Object? _threadError;
  var _sending = false;
  var _loadingMore = false;
  String? _pendingIdempotencyKey;
  String? _pendingBody;

  @override
  void initState() {
    super.initState();
    _repository = widget.chatRepository;
    _loadInbox();
  }

  @override
  void didUpdateWidget(covariant PrincipalChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.chatRepository, widget.chatRepository)) return;
    // Trocar o repositório troca o ator autorizado. Nada do contexto anterior
    // pode sobreviver a essa troca, nem respostas ainda em voo.
    _searchDebounce?.cancel();
    _inboxGeneration++;
    _threadGeneration++;
    _sendGeneration++;
    _repository = widget.chatRepository;
    _search.clear();
    _composer.clear();
    _selected = null;
    _thread = null;
    _threadError = null;
    _sending = false;
    _loadingMore = false;
    _pendingIdempotencyKey = null;
    _pendingBody = null;
    _inboxState = const ChatInboxState.loading();
    _loadInbox();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    _composer.dispose();
    super.dispose();
  }

  Future<void> _loadInbox() async {
    final generation = ++_inboxGeneration;
    final requested = _repository;
    final search = _search.text;
    setState(() => _inboxState = const ChatInboxState.loading());
    try {
      final page = await requested.fetchInbox(
        ChatInboxQuery(search: search, pageSize: _pageSize),
      );
      if (!_isCurrentInbox(generation, requested)) return;
      setState(() => _inboxState = ChatInboxState.loaded(page, search: search));
    } on ChatUnauthorizedException catch (error) {
      if (_isCurrentInbox(generation, requested)) _denyAccess(error);
    } on ChatOfflineException catch (error) {
      if (_isCurrentInbox(generation, requested)) {
        setState(() => _inboxState = ChatInboxState.offline(error));
      }
    } catch (error) {
      if (_isCurrentInbox(generation, requested)) {
        setState(() => _inboxState = ChatInboxState.failure(error));
      }
    }
  }

  bool _isCurrentInbox(int generation, ChatRepository requested) =>
      mounted && generation == _inboxGeneration && identical(requested, _repository);

  /// Acrescenta a próxima página ao final da lista, sem trocar a tela por um
  /// painel de carregamento: quem já está lendo a inbox não perde o contexto.
  /// A busca em curso viaja junto, senão a continuação traria outro conjunto.
  Future<void> _loadMoreConversations() async {
    final current = _inboxState.page;
    final cursor = current?.nextCursor;
    if (current == null || cursor == null || _loadingMore) return;
    final generation = _inboxGeneration;
    final requested = _repository;
    final search = _search.text;
    setState(() => _loadingMore = true);
    try {
      final next = await requested.fetchInbox(
        ChatInboxQuery(search: search, cursor: cursor, pageSize: _pageSize),
      );
      if (!_isCurrentInbox(generation, requested) || _search.text != search) return;
      setState(
        () => _inboxState = ChatInboxState.loaded(
          ChatInboxPage(
            items: [...current.items, ...next.items],
            totalUnread: next.totalUnread,
            nextCursor: next.nextCursor,
            totalCount: next.totalCount,
            hasMore: next.hasMore,
          ),
          search: search,
        ),
      );
    } on ChatUnauthorizedException catch (error) {
      if (_isCurrentInbox(generation, requested)) _denyAccess(error);
    } on ChatOfflineException {
      if (_isCurrentInbox(generation, requested)) {
        _notify('Sem conexão. Não foi possível carregar mais conversas.');
      }
    } catch (_) {
      if (_isCurrentInbox(generation, requested)) {
        _notify('Não foi possível carregar mais conversas.');
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  bool _isCurrentThread(int generation, ChatRepository requested, String conversationId) =>
      mounted &&
      generation == _threadGeneration &&
      identical(requested, _repository) &&
      _selected?.id == conversationId;

  Future<void> _open(ChatConversationSummary conversation) async {
    final generation = ++_threadGeneration;
    final requested = _repository;
    _sendGeneration++;
    _pendingIdempotencyKey = null;
    _pendingBody = null;
    setState(() {
      _selected = conversation;
      _thread = null;
      _threadError = null;
      _sending = false;
      _composer.clear();
    });
    try {
      final thread = await requested.fetchThread(
        ChatThreadQuery(conversationId: conversation.id, pageSize: _pageSize),
      );
      if (!_isCurrentThread(generation, requested, conversation.id)) return;
      setState(() => _thread = thread);
      // Marcar como lida só depois que o servidor autorizou a thread.
      if (thread.items.isNotEmpty) {
        await requested.markRead(
          conversationId: conversation.id,
          upToMessageId: thread.items.first.id,
        );
      }
    } on ChatUnauthorizedException catch (error) {
      if (_isCurrentThread(generation, requested, conversation.id)) _denyAccess(error);
    } catch (error) {
      if (_isCurrentThread(generation, requested, conversation.id)) {
        setState(() => _threadError = error);
      }
    }
  }

  Future<void> _send() async {
    final conversation = _selected;
    final body = _composer.text.trim();
    if (conversation == null || body.isEmpty || conversation.isReadOnly || _sending) return;
    // Uma tentativa repetida do mesmo texto reusa a chave: o servidor decide se
    // aquilo é a mesma intenção, e não criamos uma segunda mensagem por retry.
    final reuse = _pendingIdempotencyKey != null && _pendingBody == body;
    final idempotencyKey = reuse ? _pendingIdempotencyKey! : _requestId();
    _pendingIdempotencyKey = idempotencyKey;
    _pendingBody = body;
    final generation = ++_sendGeneration;
    final requested = _repository;
    setState(() => _sending = true);
    try {
      await requested.sendMessage(
        ChatSendMessageCommand(
          conversationId: conversation.id,
          body: body,
          idempotencyKey: idempotencyKey,
        ),
      );
      if (!_isCurrentSend(generation, requested, conversation.id)) return;
      // A spec exige recarregar a thread pela resposta normalizada do servidor,
      // em vez de promover um eco local a sucesso.
      final thread = await requested.fetchThread(
        ChatThreadQuery(conversationId: conversation.id, pageSize: _pageSize),
      );
      if (!_isCurrentSend(generation, requested, conversation.id)) return;
      _pendingIdempotencyKey = null;
      _pendingBody = null;
      setState(() {
        if (_composer.text.trim() == body) _composer.clear();
        _thread = thread;
      });
    } on ChatUnauthorizedException catch (error) {
      if (_isCurrentSend(generation, requested, conversation.id)) _denyAccess(error);
    } on ChatOfflineException {
      if (_isCurrentSend(generation, requested, conversation.id)) {
        _notify('Sem conexão. A mensagem não foi enviada.');
      }
    } catch (_) {
      if (_isCurrentSend(generation, requested, conversation.id)) {
        _notify('Não foi possível enviar. Tente novamente.');
      }
    } finally {
      if (_isCurrentSend(generation, requested, conversation.id)) {
        setState(() => _sending = false);
      }
    }
  }

  bool _isCurrentSend(int generation, ChatRepository requested, String conversationId) =>
      mounted &&
      generation == _sendGeneration &&
      identical(requested, _repository) &&
      _selected?.id == conversationId;

  void _denyAccess(ChatUnauthorizedException error) {
    // Negação confirmada invalida todo o instantâneo privado desta tela,
    // inclusive rascunho do composer e requisições ainda em voo.
    _searchDebounce?.cancel();
    _inboxGeneration++;
    _threadGeneration++;
    _sendGeneration++;
    _search.clear();
    _composer.clear();
    setState(() {
      _selected = null;
      _thread = null;
      _threadError = null;
      _sending = false;
      _loadingMore = false;
      _pendingIdempotencyKey = null;
      _pendingBody = null;
      _inboxState = ChatInboxState.unauthorized(error);
    });
  }

  void _notify(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  void _scheduleSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), _loadInbox);
  }

  void _prototype(String label) =>
      _notify('$label estará disponível na experiência completa.');

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
      // Hospedada no contêiner do shell, a superfície não desenha cabeçalho
      // próprio: duplicar chrome é justamente o defeito que PRINCIPAL.md veda.
      if (widget.embedded) {
        return ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: _body(compact),
        );
      }
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: PrincipalGlobalHeader(
          keyPrefix: 'principal-chat',
          onOpenMenu: () => widget.onOpenMenu == null
              ? _prototype('O menu')
              : widget.onOpenMenu!(),
          onOpenNotifications: () => widget.onOpenNotifications == null
              ? _prototype('As notificações')
              : widget.onOpenNotifications!(),
          onOpenProfile: () => widget.onOpenProfile == null
              ? _prototype('O perfil')
              : widget.onOpenProfile!(),
        ),
        body: SafeArea(top: false, child: _body(compact)),
      );
    },
  );

  Widget _body(bool compact) {
    final conversation = _selected;
    if (compact && conversation != null) return _thread_(conversation, compact: true);
    if (compact) return _inbox(compact: true);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 336, child: _inbox(compact: false)),
        const VerticalDivider(width: 1),
        Expanded(
          child: conversation == null
              ? const Center(
                  child: CoeloStatePanel(
                    key: Key('principal-chat-thread-idle'),
                    title: 'Selecione uma conversa',
                    message: 'Escolha uma conversa à esquerda para ver as mensagens.',
                    icon: Icons.forum_outlined,
                  ),
                )
              : _thread_(conversation, compact: false),
        ),
      ],
    );
  }

  Widget _inbox({required bool compact}) {
    final state = _inboxState;
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(
        CoeloSpacing.space4,
        CoeloSpacing.space3,
        CoeloSpacing.space4,
        CoeloSpacing.space2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (widget.onBack != null)
                IconButton(
                  key: const Key('principal-chat-back'),
                  tooltip: 'Voltar',
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              Expanded(
                child: Text('Mensagens', style: Theme.of(context).textTheme.titleLarge),
              ),
            ],
          ),
          const SizedBox(height: CoeloSpacing.space2),
          CoeloSearchField(
            key: const Key('principal-chat-search'),
            controller: _search,
            semanticLabel: 'Buscar conversas',
            hintText: 'Buscar conversas',
            onChanged: (_) => _scheduleSearch(),
          ),
        ],
      ),
    );

    final content = switch (state.kind) {
      ChatInboxLoadState.loading => const Center(
        child: CoeloStatePanel(
          key: Key('principal-chat-inbox-loading'),
          title: 'Carregando conversas',
          message: 'Buscando suas conversas autorizadas.',
          loading: true,
        ),
      ),
      ChatInboxLoadState.empty => Center(
        child: CoeloStatePanel(
          key: const Key('principal-chat-inbox-empty'),
          title: 'Ainda não há conversas',
          message: 'Quando uma conversa for aberta com você, ela aparece aqui.',
          icon: Icons.forum_outlined,
          actionLabel: 'Atualizar',
          onAction: _loadInbox,
        ),
      ),
      ChatInboxLoadState.noResults => Center(
        child: CoeloStatePanel(
          key: const Key('principal-chat-inbox-no-results'),
          title: 'Nenhuma conversa encontrada',
          message: 'Nenhuma conversa corresponde à sua busca.',
          icon: Icons.search_off_rounded,
          actionLabel: 'Limpar busca',
          onAction: () {
            _search.clear();
            _loadInbox();
          },
        ),
      ),
      // Sem permissão não oferece nova tentativa: repetir não concede acesso.
      ChatInboxLoadState.unauthorized => const Center(
        child: CoeloStatePanel(
          key: Key('principal-chat-inbox-unauthorized'),
          title: 'Acesso não disponível',
          message: 'Sua conta não tem permissão para ver estas conversas.',
          icon: Icons.lock_outline_rounded,
        ),
      ),
      ChatInboxLoadState.offline => Center(
        child: CoeloStatePanel(
          key: const Key('principal-chat-inbox-offline'),
          title: 'Sem conexão',
          message: 'Verifique sua conexão e tente novamente.',
          icon: Icons.cloud_off_outlined,
          actionLabel: 'Tentar novamente',
          onAction: _loadInbox,
        ),
      ),
      ChatInboxLoadState.failure => Center(
        child: CoeloStatePanel(
          key: const Key('principal-chat-inbox-failure'),
          title: 'Não foi possível carregar',
          message: 'Tente novamente em instantes.',
          icon: Icons.error_outline_rounded,
          actionLabel: 'Tentar novamente',
          onAction: _loadInbox,
        ),
      ),
      ChatInboxLoadState.ready => Builder(
        builder: (context) {
          final page = state.page!;
          final canLoadMore = page.nextCursor != null;
          return ListView.separated(
            key: const Key('principal-chat-inbox-list'),
            padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space3),
            itemCount: page.items.length + (canLoadMore ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: CoeloSpacing.space1),
            itemBuilder: (context, index) {
              if (index == page.items.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space3),
                  child: Center(
                    child: _loadingMore
                        ? const SizedBox(
                            width: CoeloSize.iconSm,
                            height: CoeloSize.iconSm,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : TextButton(
                            key: const Key('principal-chat-load-more'),
                            onPressed: _loadMoreConversations,
                            child: const Text('Carregar mais conversas'),
                          ),
                  ),
                );
              }
              final item = page.items[index];
              return _ConversationTile(
                key: ValueKey('principal-chat-conversation-${item.id}'),
                conversation: item,
                selected: _selected?.id == item.id,
                onOpen: () => _open(item),
              );
            },
          );
        },
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [header, Expanded(child: content)],
    );
  }

  Widget _thread_(ChatConversationSummary conversation, {required bool compact}) {
    final thread = _thread;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space3),
          child: Row(
            children: [
              if (compact)
                IconButton(
                  key: const Key('principal-chat-thread-back'),
                  tooltip: 'Voltar para conversas',
                  onPressed: () => setState(() {
                    _selected = null;
                    _thread = null;
                    _threadError = null;
                  }),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(conversation.title, style: Theme.of(context).textTheme.titleMedium),
                    if (conversation.contextLabel.isNotEmpty)
                      Text(
                        conversation.contextLabel,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                  ],
                ),
              ),
              if (conversation.isReadOnly)
                const Tooltip(
                  message: 'Conversa somente leitura',
                  child: Icon(Icons.lock_outline_rounded),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _threadBody(conversation, thread)),
        if (!conversation.isReadOnly) _composerBar(),
      ],
    );
  }

  Widget _threadBody(ChatConversationSummary conversation, ChatThreadPage? thread) {
    if (_threadError != null) {
      final offline = _threadError is ChatOfflineException;
      return Center(
        child: CoeloStatePanel(
          key: const Key('principal-chat-thread-error'),
          title: offline ? 'Sem conexão' : 'Não foi possível abrir a conversa',
          message: offline
              ? 'Verifique sua conexão e tente novamente.'
              : 'Tente novamente em instantes.',
          icon: offline ? Icons.cloud_off_outlined : Icons.error_outline_rounded,
          actionLabel: 'Tentar novamente',
          onAction: () => _open(conversation),
        ),
      );
    }
    if (thread == null) {
      return const Center(
        child: CoeloStatePanel(
          key: Key('principal-chat-thread-loading'),
          title: 'Carregando conversa',
          message: 'Buscando as mensagens autorizadas.',
          loading: true,
        ),
      );
    }
    if (thread.items.isEmpty) {
      return const Center(
        child: CoeloStatePanel(
          key: Key('principal-chat-thread-empty'),
          title: 'Nenhuma mensagem ainda',
          message: 'Escreva a primeira mensagem desta conversa.',
          icon: Icons.chat_bubble_outline_rounded,
        ),
      );
    }
    return ListView.builder(
      key: const Key('principal-chat-thread-list'),
      reverse: true,
      padding: const EdgeInsets.all(CoeloSpacing.space3),
      itemCount: thread.items.length,
      itemBuilder: (context, index) => _PrincipalMessageBubble(
        key: ValueKey('principal-chat-message-${thread.items[index].id}'),
        message: thread.items[index],
      ),
    );
  }

  Widget _composerBar() => Padding(
    padding: const EdgeInsets.all(CoeloSpacing.space3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            key: const Key('principal-chat-composer'),
            controller: _composer,
            minLines: 1,
            maxLines: 4,
            maxLength: 4000,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              hintText: 'Escreva uma mensagem',
              counterText: '',
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: CoeloSpacing.space2),
        IconButton.filled(
          key: const Key('principal-chat-send'),
          tooltip: 'Enviar mensagem',
          onPressed: _sending || _composer.text.trim().isEmpty ? null : _send,
          icon: _sending
              ? const SizedBox(
                  width: CoeloSize.iconSm,
                  height: CoeloSize.iconSm,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_rounded),
        ),
      ],
    ),
  );
}

final class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.selected,
    required this.onOpen,
    super.key,
  });

  final ChatConversationSummary conversation;
  final bool selected;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(CoeloRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space3),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: scheme.secondaryContainer,
                foregroundColor: scheme.onSecondaryContainer,
                child: Text(_initials(conversation.title)),
              ),
              const SizedBox(width: CoeloSpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conversation.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (conversation.preview.isNotEmpty)
                      Text(
                        conversation.preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              if (conversation.unreadCount > 0) ...[
                const SizedBox(width: CoeloSpacing.space2),
                Badge(
                  key: ValueKey('principal-chat-unread-${conversation.id}'),
                  label: Text('${math.min(conversation.unreadCount, 99)}'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

final class _PrincipalMessageBubble extends StatelessWidget {
  const _PrincipalMessageBubble({required this.message, super.key});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final receiptLabel = _receiptLabel(message);
    return Semantics(
      label: [
        '${message.authorName}.',
        message.body,
        if (message.isEdited) 'Mensagem editada.',
        if (receiptLabel != null) '$receiptLabel.',
      ].join(' '),
      child: Align(
        alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: CoeloSize.touchMin * 11),
          margin: const EdgeInsets.only(bottom: CoeloSpacing.space2),
          padding: const EdgeInsets.all(CoeloSpacing.space3),
          decoration: BoxDecoration(
            color: message.isMine ? scheme.primaryContainer : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(CoeloRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message.authorName, style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: CoeloSpacing.space1),
              Text(message.body),
              const SizedBox(height: CoeloSpacing.space1),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (message.isEdited)
                    Padding(
                      padding: const EdgeInsets.only(right: CoeloSpacing.space2),
                      child: Text(
                        'editada',
                        key: Key('principal-chat-edited-${message.id}'),
                        style: Theme.of(
                          context,
                        ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  Text(
                    MaterialLocalizations.of(context).formatTimeOfDay(
                      TimeOfDay.fromDateTime(message.sentAt),
                      alwaysUse24HourFormat: true,
                    ),
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  if (receiptLabel != null) ...[
                    const SizedBox(width: CoeloSpacing.space1),
                    Text(
                      receiptLabel,
                      key: Key('principal-chat-receipt-${message.id}'),
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Null quando o servidor não projetou recibo: a superfície renderiza nada em
/// vez de afirmar um estado que o servidor não enviou.
String? _receiptLabel(ChatMessage message) {
  final receipt = message.receipt;
  if (receipt == null) return null;
  if (receipt.isMine) {
    if (receipt.recipientCount == 0) return null;
    return 'Lida por ${receipt.readCount} de ${receipt.recipientCount}';
  }
  return receipt.isReadByMe ? 'Lida' : null;
}

String _initials(String value) => value
    .split(RegExp(r'\s+'))
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
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}
