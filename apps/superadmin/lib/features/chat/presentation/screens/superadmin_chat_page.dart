import 'dart:async';
import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/shell/superadmin_shell.dart';
import '../../../auth/domain/logout_action.dart';
import '../../data/supabase_chat_repository.dart';
import '../../domain/chat_repository.dart';
import '../widgets/superadmin_chat_attachment_tile.dart';
import '../widgets/superadmin_chat_composer.dart';

final class _PendingChatSend {
  const _PendingChatSend({
    required this.repository,
    required this.conversationId,
    required this.body,
    required this.idempotencyKey,
  });

  final ChatRepository repository;
  final String conversationId;
  final String body;
  final String idempotencyKey;

  bool matches(ChatRepository candidateRepository, String candidateConversationId, String value) =>
      identical(repository, candidateRepository) &&
      conversationId == candidateConversationId &&
      body == value;
}

final class SuperadminChatPage extends StatefulWidget {
  const SuperadminChatPage({
    required this.logout,
    this.chatRepository,
    this.currentDestination = 'conversations',
    this.onDestinationSelected,
    this.onBack,
    super.key,
  });

  final LogoutAction logout;
  final ChatRepository? chatRepository;
  final String currentDestination;
  final ValueChanged<String>? onDestinationSelected;
  final VoidCallback? onBack;

  @override
  State<SuperadminChatPage> createState() => _SuperadminChatPageState();
}

final class _SuperadminChatPageState extends State<SuperadminChatPage> {
  final _search = TextEditingController();
  final _composer = TextEditingController();
  Timer? _searchDebounce;
  int _inboxRequestGeneration = 0;
  int _threadRequestGeneration = 0;
  int _sendRequestGeneration = 0;
  final List<ChatCursor?> _inboxCursors = [null];
  int _inboxPage = 0;
  late ChatRepository _repository;
  ChatInboxState _inboxState = const ChatInboxState.loading();
  ChatConversationSummary? _selected;
  ChatThreadPage? _thread;
  Object? _threadError;
  var _sending = false;
  _PendingChatSend? _pendingSend;

  @override
  void initState() {
    super.initState();
    _repository = widget.chatRepository ?? _configuredRepository();
    _loadInbox();
  }

  @override
  void didUpdateWidget(covariant SuperadminChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.chatRepository, widget.chatRepository)) return;
    _searchDebounce?.cancel();
    _inboxRequestGeneration++;
    _threadRequestGeneration++;
    _sendRequestGeneration++;
    _repository = widget.chatRepository ?? _configuredRepository();
    _search.clear();
    _composer.clear();
    _selected = null;
    _thread = null;
    _threadError = null;
    _sending = false;
    _pendingSend = null;
    _inboxCursors
      ..clear()
      ..add(null);
    _inboxPage = 0;
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

  ChatRepository _configuredRepository() {
    try {
      return SupabaseChatRepository(Supabase.instance.client);
    } catch (_) {
      return const _UnavailableChatRepository();
    }
  }

  Future<void> _loadInbox({bool resetPagination = false}) async {
    if (resetPagination) {
      _inboxCursors
        ..clear()
        ..add(null);
      _inboxPage = 0;
    }
    final requestGeneration = ++_inboxRequestGeneration;
    final requestedRepository = _repository;
    final search = _search.text;
    setState(() => _inboxState = const ChatInboxState.loading());
    try {
      final page = await requestedRepository.fetchInbox(
        ChatInboxQuery(search: search, cursor: _inboxCursors[_inboxPage]),
      );
      if (!mounted ||
          requestGeneration != _inboxRequestGeneration ||
          !identical(requestedRepository, _repository)) {
        return;
      }
      setState(() => _inboxState = ChatInboxState.loaded(page, search: search));
      if (page.items.isNotEmpty) {
        await _select(
          page.items.first,
          inboxRequestGeneration: requestGeneration,
          inboxSearch: search,
        );
      }
    } on ChatUnauthorizedException catch (error) {
      if (!_isCurrentInboxRequest(requestGeneration, requestedRepository)) return;
      setState(() => _inboxState = ChatInboxState.unauthorized(error));
    } on ChatOfflineException catch (error) {
      if (!_isCurrentInboxRequest(requestGeneration, requestedRepository)) return;
      setState(() => _inboxState = ChatInboxState.offline(error));
    } catch (error) {
      if (!_isCurrentInboxRequest(requestGeneration, requestedRepository)) return;
      setState(() => _inboxState = ChatInboxState.failure(error));
    }
  }

  bool _isCurrentInboxRequest(int generation, ChatRepository requestedRepository) =>
      mounted &&
      generation == _inboxRequestGeneration &&
      identical(requestedRepository, _repository);

  Future<void> _select(
    ChatConversationSummary conversation, {
    int? inboxRequestGeneration,
    String? inboxSearch,
  }) async {
    final conversationChanged = _selected?.id != conversation.id;
    if (!conversationChanged && _thread != null && _threadError == null) return;
    final threadGeneration = ++_threadRequestGeneration;
    final requestedRepository = _repository;
    if (conversationChanged) {
      _sendRequestGeneration++;
      _pendingSend = null;
    }
    bool isCurrentAutomaticSelection() =>
        inboxRequestGeneration == null ||
        (inboxRequestGeneration == _inboxRequestGeneration && inboxSearch == _search.text);
    if (!isCurrentAutomaticSelection()) return;
    setState(() {
      _selected = conversation;
      _thread = null;
      _threadError = null;
      if (conversationChanged) _sending = false;
    });
    try {
      final thread = await requestedRepository.fetchThread(
        ChatThreadQuery(conversationId: conversation.id),
      );
      if (!mounted ||
          threadGeneration != _threadRequestGeneration ||
          !identical(requestedRepository, _repository) ||
          _selected?.id != conversation.id ||
          !isCurrentAutomaticSelection()) {
        return;
      }
      setState(() => _thread = thread);
      if (thread.items.isNotEmpty) {
        await requestedRepository.markRead(
          conversationId: conversation.id,
          upToMessageId: thread.items.first.id,
        );
      }
    } catch (error) {
      if (mounted &&
          threadGeneration == _threadRequestGeneration &&
          identical(requestedRepository, _repository) &&
          _selected?.id == conversation.id &&
          isCurrentAutomaticSelection()) {
        setState(() => _threadError = error);
      }
    }
  }

  Future<void> _send() async {
    final conversation = _selected;
    final body = _composer.text.trim();
    if (conversation == null || body.isEmpty || conversation.isReadOnly || _sending) return;
    final pending = _pendingSend;
    final intent = pending != null && pending.matches(_repository, conversation.id, body)
        ? pending
        : _PendingChatSend(
            repository: _repository,
            conversationId: conversation.id,
            body: body,
            idempotencyKey: _requestId(),
          );
    _pendingSend = intent;
    final sendGeneration = ++_sendRequestGeneration;
    final requestedRepository = intent.repository;
    setState(() => _sending = true);
    try {
      final sent = await requestedRepository.sendMessage(
        ChatSendMessageCommand(
          conversationId: conversation.id,
          body: body,
          idempotencyKey: intent.idempotencyKey,
        ),
      );
      if (!_isCurrentSend(sendGeneration, requestedRepository, conversation.id)) return;
      _pendingSend = null;
      setState(() {
        if (_composer.text.trim() == body) _composer.clear();
        _thread = ChatThreadPage(items: [sent, ...?_thread?.items]);
      });
    } on ChatUnauthorizedException {
      if (_isCurrentSend(sendGeneration, requestedRepository, conversation.id)) {
        _pendingSend = null;
        _showNotice('Sua permissao para esta conversa foi alterada.');
      }
    } on ChatOfflineException {
      if (_isCurrentSend(sendGeneration, requestedRepository, conversation.id)) {
        _showNotice('Sem conexao. A mensagem nao foi enviada.');
      }
    } catch (_) {
      if (_isCurrentSend(sendGeneration, requestedRepository, conversation.id)) {
        _showNotice('Nao foi possivel enviar. Tente novamente.');
      }
    } finally {
      if (_isCurrentSend(sendGeneration, requestedRepository, conversation.id)) {
        setState(() => _sending = false);
      }
    }
  }

  bool _isCurrentSend(int generation, ChatRepository requestedRepository, String conversationId) =>
      mounted &&
      generation == _sendRequestGeneration &&
      identical(requestedRepository, _repository) &&
      _selected?.id == conversationId;

  void _showNotice(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  void _scheduleInboxSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _loadInbox(resetPagination: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SuperadminShell(
      logout: widget.logout,
      title: 'Conversas',
      subtitle: 'Comunicacao institucional privada e contextual.',
      actions: [_fileActions(compact: false)],
      compactActions: [_fileActions(compact: true)],
      currentDestination: widget.currentDestination,
      onDestinationSelected: widget.onDestinationSelected,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final contentPadding = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
              ? CoeloSpacing.space10
              : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
              ? CoeloSpacing.space6
              : CoeloSpacing.space4;
          return Padding(
            key: const Key('superadmin-chat-content-inset'),
            padding: EdgeInsets.all(contentPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.onBack != null) ...[
                  IconButton(
                    key: const Key('superadmin-chat-back'),
                    tooltip: 'Voltar',
                    onPressed: widget.onBack,
                    constraints: const BoxConstraints.tightFor(
                      width: CoeloSize.touchMin,
                      height: CoeloSize.touchMin,
                    ),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(height: CoeloSpacing.space2),
                ],
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(CoeloRadius.lg),
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    child: _body(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _fileActions({required bool compact}) => CoeloAdminFileActions(
    compact: compact,
    actions: [
      CoeloAdminFileAction(
        label: 'Importar',
        icon: Icons.upload_file_outlined,
        onPressed: () => _showNotice('A importação de conversas ainda não está disponível.'),
      ),
      CoeloAdminFileAction(
        label: 'Exportar CSV',
        icon: Icons.table_rows_outlined,
        onPressed: () => _showNotice('A exportação de conversas ainda não está disponível.'),
      ),
      CoeloAdminFileAction(
        label: 'Exportar XLSX',
        icon: Icons.grid_on_outlined,
        onPressed: () => _showNotice('A exportação de conversas ainda não está disponível.'),
      ),
    ],
  );

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
          _loadInbox(resetPagination: true);
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
          child: CoeloSearchField(
            key: const Key('superadmin-chat-search'),
            controller: _search,
            onChanged: (_) => _scheduleInboxSearch(),
            semanticLabel: 'Buscar conversas',
            hintText: 'Buscar conversas',
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
                              '${_conversationKindLabel(item.kind)} · ${item.contextLabel}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(
                                context,
                              ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
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
        _ChatInboxPagination(
          page: _inboxPage + 1,
          onPrevious: _inboxPage == 0
              ? null
              : () {
                  setState(() => _inboxPage--);
                  _loadInbox();
                },
          onNext: page.nextCursor == null
              ? null
              : () {
                  final nextCursor = page.nextCursor!;
                  if (_inboxCursors.length == _inboxPage + 1) {
                    _inboxCursors.add(nextCursor);
                  } else {
                    _inboxCursors[_inboxPage + 1] = nextCursor;
                  }
                  setState(() => _inboxPage++);
                  _loadInbox();
                },
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
            itemBuilder: (context, index) {
              final message = thread.items[index];
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
              for (final attachment in message.attachments) ...[
                const SizedBox(height: CoeloSpacing.space2),
                SuperadminChatAttachmentTile(
                  attachment: attachment,
                  state: SuperadminChatAttachmentState.ready,
                ),
              ],
              const SizedBox(height: CoeloSpacing.space1),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  MaterialLocalizations.of(context).formatTimeOfDay(
                    TimeOfDay.fromDateTime(message.sentAt),
                    alwaysUse24HourFormat: true,
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _ChatInboxPagination extends StatelessWidget {
  const _ChatInboxPagination({required this.page, this.onPrevious, this.onNext});

  final int page;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Paginação das conversas. Página $page.',
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space1),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Página anterior',
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Text('Página $page', style: Theme.of(context).textTheme.labelLarge),
            IconButton(
              tooltip: 'Próxima página',
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ),
    ),
  );
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

String _conversationKindLabel(String kind) => switch (kind) {
  'direct' => 'Direta',
  'group' => 'Grupo',
  'support' => 'Suporte',
  _ => 'Conversa',
};

String _requestId() {
  final random = math.Random.secure();
  final values = List<int>.generate(16, (_) => random.nextInt(256));
  values[6] = (values[6] & 0x0f) | 0x40;
  values[8] = (values[8] & 0x3f) | 0x80;
  final hex = values.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
