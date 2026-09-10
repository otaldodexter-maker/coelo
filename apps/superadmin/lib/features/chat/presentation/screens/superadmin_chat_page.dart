import 'dart:async';
import 'dart:math' as math;

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../../app/shell/superadmin_shell.dart';
import '../../../../shared/presentation/widgets/superadmin_listing_pagination_footer.dart';
import '../../../auth/domain/logout_action.dart';
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
    this.mediaReader,
    this.mediaSession,
    this.currentDestination = 'conversations',
    this.onDestinationSelected,
    this.onBack,
    super.key,
  });

  final LogoutAction logout;
  final ChatRepository? chatRepository;
  final MediaReader? mediaReader;
  final MediaSession? mediaSession;
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
  int _manageRequestGeneration = 0;
  int _inboxPage = 1;
  static const int _inboxPageSize = 8;
  ChatCursor? _inboxCursor;
  final List<ChatCursor?> _inboxCursorHistory = [];
  late ChatRepository _repository;
  ChatInboxState _inboxState = const ChatInboxState.loading();
  ChatConversationSummary? _selected;
  ChatThreadPage? _thread;
  Object? _threadError;
  var _sending = false;
  var _managing = false;
  var _loadingOlder = false;
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
    _manageRequestGeneration++;
    _repository = widget.chatRepository ?? _configuredRepository();
    _search.clear();
    _composer.clear();
    _selected = null;
    _thread = null;
    _threadError = null;
    _sending = false;
    _managing = false;
    _pendingSend = null;
    _inboxPage = 1;
    _inboxCursor = null;
    _inboxCursorHistory.clear();
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

  // Superadmin uses the isolated internal identity realm (ADR 0019). The
  // existing Supabase Chat RPCs resolve people/current_person_id and therefore
  // cannot be selected implicitly for this surface. Production remains
  // fail-closed until an internal-identity gateway is approved and injected by
  // the composition root; `/dev` continues to inject its deterministic repo.
  ChatRepository _configuredRepository() => const UnavailableChatRepository();

  /// `preserveSelection` rele a inbox sem trocar a conversa aberta. A recarga
  /// normal resseleciona o primeiro item, o que e certo na abertura e na busca,
  /// mas seria destrutivo depois de uma recusa: o operador perderia a conversa
  /// que estava lendo por causa de uma recusa naquela mesma conversa.
  Future<void> _loadInbox({bool reset = false, bool preserveSelection = false}) async {
    if (reset) {
      _inboxPage = 1;
      _inboxCursor = null;
      _inboxCursorHistory.clear();
    }
    final requestGeneration = ++_inboxRequestGeneration;
    final requestedRepository = _repository;
    final search = _search.text;
    setState(() => _inboxState = const ChatInboxState.loading());
    try {
      final page = await requestedRepository.fetchInbox(
        ChatInboxQuery(search: search, cursor: _inboxCursor, pageSize: _inboxPageSize),
      );
      if (!mounted ||
          requestGeneration != _inboxRequestGeneration ||
          !identical(requestedRepository, _repository)) {
        return;
      }
      setState(() => _inboxState = ChatInboxState.loaded(page, search: search));
      if (page.items.isEmpty) return;
      if (preserveSelection) {
        final selectedId = _selected?.id;
        final refreshed = page.items.where((item) => item.id == selectedId).firstOrNull;
        // Reselecionar a MESMA conversa cai no ramo que preserva a thread e o
        // envio em voo, e so atualiza o resumo — inclusive `isReadOnly`, que e
        // o que faz a affordance de escrita sumir sozinha.
        if (refreshed != null) {
          await _select(
            refreshed,
            inboxRequestGeneration: requestGeneration,
            inboxSearch: search,
          );
        }
        return;
      }
      await _select(
        page.items.first,
        inboxRequestGeneration: requestGeneration,
        inboxSearch: search,
      );
    } on ChatUnauthorizedException catch (error) {
      if (!_isCurrentInboxRequest(requestGeneration, requestedRepository)) return;
      _denyAccess(error);
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
    bool isCurrentAutomaticSelection() =>
        inboxRequestGeneration == null ||
        (inboxRequestGeneration == _inboxRequestGeneration && inboxSearch == _search.text);
    if (!isCurrentAutomaticSelection()) return;
    final conversationChanged = _selected?.id != conversation.id;
    if (!conversationChanged && _thread != null && _threadError == null) {
      // A fresh inbox may change readonly/title/context without changing the
      // conversation ID. Preserve the thread and any single-flight send.
      setState(() => _selected = conversation);
      return;
    }
    final threadGeneration = ++_threadRequestGeneration;
    final requestedRepository = _repository;
    if (conversationChanged) {
      _sendRequestGeneration++;
      _pendingSend = null;
    }
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
        // The receipt this write produces is read back on the next thread
        // fetch. The page does not patch the bubbles from the command, so a
        // rendered receipt is always one the server actually returned.
        await requestedRepository.markRead(
          conversationId: conversation.id,
          upToMessageId: thread.items.first.id,
        );
      }
    } catch (error) {
      if (mounted &&
          threadGeneration == _threadRequestGeneration &&
          identical(requestedRepository, _repository) &&
          _selected?.id == conversation.id) {
        if (error is ChatUnauthorizedException) {
          // A same-conversation inbox refresh does not invalidate a pending
          // read receipt's denial. Presentation errors still follow the search.
          _denyAccess(error);
        } else if (isCurrentAutomaticSelection()) {
          setState(() => _threadError = error);
        }
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
        // Enviar acrescenta uma mensagem ao topo; nao torna o resto da
        // conversa inalcancavel. Preservar o cursor e o `hasMore` que o
        // servidor ja tinha devolvido, senao o controle de continuacao some
        // depois do primeiro envio e o operador fica preso na pagina mais
        // recente sem nenhum sinal de que algo mudou.
        final current = _thread;
        _thread = ChatThreadPage(
          items: [sent, ...?current?.items],
          nextCursor: current?.nextCursor,
          totalCount: current?.totalCount ?? 0,
          hasMore: current?.hasMore ?? false,
        );
      });
      // A lista mostra a ULTIMA mensagem de cada conversa; sem reconciliar, o
      // preview e a ordenacao continuariam anteriores ao que acabou de ser
      // enviado. `preserveSelection` reconcilia sem resselecionar o primeiro
      // item, que trocaria a conversa aberta na mao do operador.
      unawaited(_loadInbox(preserveSelection: true));
    } on ChatUnauthorizedException catch (error) {
      if (_isCurrentSend(sendGeneration, requestedRepository, conversation.id)) {
        _denyAccess(error);
      }
    } on ChatConflictException {
      if (_isCurrentSend(sendGeneration, requestedRepository, conversation.id)) {
        // A conversa recusou por estado proprio, nao por acesso: o instantaneo
        // local esta velho. Sem reler, o operador repetiria a mesma intencao
        // contra uma conversa que nunca vai aceita-la, e o composer continuaria
        // oferecido. Recarregar traz `isReadOnly` do servidor e a affordance
        // some sozinha. A sessao e o restante da tela permanecem.
        _pendingSend = null;
        _showNotice('A conversa nao aceita novas mensagens. A tela foi atualizada.');
        unawaited(_loadInbox(preserveSelection: true));
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

  Future<void> _editMessage(ChatMessage message) async {
    final conversation = _selected;
    if (conversation == null || !message.canManage || _managing) return;
    final edited = await _promptForEditedBody(message);
    if (edited == null || !mounted) return;
    final body = edited.trim();
    if (body.isEmpty || body == message.body) return;
    final manageGeneration = ++_manageRequestGeneration;
    final requestedRepository = _repository;
    setState(() => _managing = true);
    try {
      await requestedRepository.editMessage(
        ChatEditMessageCommand(
          conversationId: conversation.id,
          messageId: message.id,
          body: body,
          idempotencyKey: _requestId(),
        ),
      );
      if (!_isCurrentManage(manageGeneration, requestedRepository, conversation.id)) return;
      // The edited row carries its own receipt and edit marker; re-read the
      // thread instead of patching a single bubble from the command's echo.
      await _reloadThread(conversation, manageGeneration, requestedRepository);
      // Editar e revogar mudam a ULTIMA mensagem da conversa, que e o preview
      // da lista. No caso de revogar isso nao e cosmetico: o servidor ja exclui
      // a mensagem revogada do preview, entao deixar o corpo antigo na tela
      // desfaz o efeito da revogacao na superficie que o operador mais olha.
      unawaited(_loadInbox(preserveSelection: true));
    } on ChatUnauthorizedException catch (error) {
      if (_isCurrentManage(manageGeneration, requestedRepository, conversation.id)) {
        _denyAccess(error);
      }
    } on ChatConflictException catch (error) {
      if (_isCurrentManage(manageGeneration, requestedRepository, conversation.id)) {
        _showNotice(_conflictMessage(error.reason));
      }
    } on ChatOfflineException {
      if (_isCurrentManage(manageGeneration, requestedRepository, conversation.id)) {
        _showNotice('Sem conexao. A mensagem nao foi editada.');
      }
    } catch (_) {
      if (_isCurrentManage(manageGeneration, requestedRepository, conversation.id)) {
        _showNotice('Nao foi possivel editar a mensagem.');
      }
    } finally {
      if (_isCurrentManage(manageGeneration, requestedRepository, conversation.id)) {
        setState(() => _managing = false);
      }
    }
  }

  Future<void> _revokeMessage(ChatMessage message) async {
    final conversation = _selected;
    if (conversation == null || !message.canManage || _managing) return;
    final confirmed = await _confirmRevocation();
    if (confirmed != true || !mounted) return;
    final manageGeneration = ++_manageRequestGeneration;
    final requestedRepository = _repository;
    setState(() => _managing = true);
    try {
      await requestedRepository.revokeMessage(
        ChatRevokeMessageCommand(
          conversationId: conversation.id,
          messageId: message.id,
          idempotencyKey: _requestId(),
        ),
      );
      if (!_isCurrentManage(manageGeneration, requestedRepository, conversation.id)) return;
      await _reloadThread(conversation, manageGeneration, requestedRepository);
      // Editar e revogar mudam a ULTIMA mensagem da conversa, que e o preview
      // da lista. No caso de revogar isso nao e cosmetico: o servidor ja exclui
      // a mensagem revogada do preview, entao deixar o corpo antigo na tela
      // desfaz o efeito da revogacao na superficie que o operador mais olha.
      unawaited(_loadInbox(preserveSelection: true));
      if (_isCurrentManage(manageGeneration, requestedRepository, conversation.id)) {
        _showNotice('Mensagem revogada.');
      }
    } on ChatUnauthorizedException catch (error) {
      if (_isCurrentManage(manageGeneration, requestedRepository, conversation.id)) {
        _denyAccess(error);
      }
    } on ChatConflictException catch (error) {
      if (_isCurrentManage(manageGeneration, requestedRepository, conversation.id)) {
        _showNotice(_conflictMessage(error.reason));
      }
    } on ChatOfflineException {
      if (_isCurrentManage(manageGeneration, requestedRepository, conversation.id)) {
        _showNotice('Sem conexao. A mensagem nao foi revogada.');
      }
    } catch (_) {
      if (_isCurrentManage(manageGeneration, requestedRepository, conversation.id)) {
        _showNotice('Nao foi possivel revogar a mensagem.');
      }
    } finally {
      if (_isCurrentManage(manageGeneration, requestedRepository, conversation.id)) {
        setState(() => _managing = false);
      }
    }
  }

  Future<void> _reloadThread(
    ChatConversationSummary conversation,
    int manageGeneration,
    ChatRepository requestedRepository,
  ) async {
    final thread = await requestedRepository.fetchThread(
      ChatThreadQuery(conversationId: conversation.id),
    );
    if (!_isCurrentManage(manageGeneration, requestedRepository, conversation.id)) return;
    setState(() => _thread = thread);
  }

  /// A thread chega mais nova primeiro; a continuacao acrescenta as antigas ao
  /// fim da lista, que e o topo visual por causa do `reverse: true`. Mesmo
  /// desenho ja usado na superficie Principal, sobre a mesma RPC.
  Future<void> _loadOlderMessages() async {
    final conversation = _selected;
    final current = _thread;
    final cursor = current?.nextCursor;
    if (conversation == null || current == null || cursor == null || _loadingOlder) return;
    final threadGeneration = _threadRequestGeneration;
    final requestedRepository = _repository;
    setState(() => _loadingOlder = true);
    try {
      final older = await requestedRepository.fetchThread(
        ChatThreadQuery(conversationId: conversation.id, cursor: cursor),
      );
      if (!_isCurrentThreadRequest(threadGeneration, requestedRepository, conversation.id)) return;
      // A lista pode ter mudado enquanto a continuacao estava em voo: um envio
      // que terminou antes dela acrescentou uma mensagem ao topo. Reescrever a
      // partir do instantaneo capturado no INICIO engoliria essa mensagem, e o
      // operador acreditaria ter perdido um envio que o servidor aceitou.
      // A continuacao so acrescenta ao fim o que veio do servidor.
      final latest = _thread ?? current;
      setState(
        () => _thread = ChatThreadPage(
          items: [...latest.items, ...older.items],
          nextCursor: older.nextCursor,
          totalCount: older.totalCount,
          hasMore: older.hasMore,
        ),
      );
    } on ChatUnauthorizedException catch (error) {
      // Perder acesso durante a continuacao invalida o instantaneo privado
      // inteiro, pela mesma regra que ja vale para inbox, thread e envio.
      if (_isCurrentThreadRequest(threadGeneration, requestedRepository, conversation.id)) {
        _denyAccess(error);
      }
    } on ChatOfflineException {
      if (_isCurrentThreadRequest(threadGeneration, requestedRepository, conversation.id)) {
        _showNotice('Sem conexao. Nao foi possivel carregar mensagens anteriores.');
      }
    } catch (_) {
      if (_isCurrentThreadRequest(threadGeneration, requestedRepository, conversation.id)) {
        _showNotice('Nao foi possivel carregar mensagens anteriores.');
      }
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  bool _isCurrentThreadRequest(
    int generation,
    ChatRepository requestedRepository,
    String conversationId,
  ) =>
      mounted &&
      generation == _threadRequestGeneration &&
      identical(requestedRepository, _repository) &&
      _selected?.id == conversationId;

  Future<String?> _promptForEditedBody(ChatMessage message) => showDialog<String>(
    context: context,
    builder: (_) => _EditMessageDialog(initialBody: message.body),
  );

  Future<bool?> _confirmRevocation() => showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Revogar mensagem'),
      content: const Text(
        'A mensagem sai da conversa para todos os participantes. '
        'O registro fica retido apenas para auditoria.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('superadmin-chat-revoke-confirm'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Revogar'),
        ),
      ],
    ),
  );

  static String _conflictMessage(ChatConflictReason reason) => switch (reason) {
    ChatConflictReason.editWindowClosed => 'O prazo de edicao desta mensagem terminou.',
    ChatConflictReason.alreadyRevoked => 'Esta mensagem ja foi revogada.',
    ChatConflictReason.readOnly => 'Esta conversa e somente leitura.',
  };

  bool _isCurrentManage(
    int generation,
    ChatRepository requestedRepository,
    String conversationId,
  ) =>
      mounted &&
      generation == _manageRequestGeneration &&
      identical(requestedRepository, _repository) &&
      _selected?.id == conversationId;

  bool _isCurrentSend(int generation, ChatRepository requestedRepository, String conversationId) =>
      mounted &&
      generation == _sendRequestGeneration &&
      identical(requestedRepository, _repository) &&
      _selected?.id == conversationId;

  void _denyAccess(ChatUnauthorizedException error) {
    // A confirmed denial invalidates this page's private snapshot, including
    // outstanding requests. Network failures keep their separate retry path.
    _searchDebounce?.cancel();
    _inboxRequestGeneration++;
    _threadRequestGeneration++;
    _sendRequestGeneration++;
    _manageRequestGeneration++;
    _search.clear();
    _composer.clear();
    setState(() {
      _selected = null;
      _thread = null;
      _threadError = null;
      _pendingSend = null;
      _sending = false;
      _managing = false;
      _inboxPage = 1;
      _inboxCursor = null;
      _inboxCursorHistory.clear();
      _inboxState = ChatInboxState.unauthorized(error);
    });
  }

  void _showNotice(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  void _scheduleInboxSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () => _loadInbox(reset: true));
  }

  void _nextInboxPage(ChatInboxPage page) {
    final cursor = page.nextCursor;
    if (cursor == null) return;
    _inboxCursorHistory.add(_inboxCursor);
    _inboxCursor = cursor;
    _inboxPage++;
    _loadInbox();
  }

  void _previousInboxPage() {
    if (_inboxPage <= 1 || _inboxCursorHistory.isEmpty) return;
    _inboxCursor = _inboxCursorHistory.removeLast();
    _inboxPage--;
    _loadInbox();
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
          _loadInbox(reset: true);
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
    final totalPages = math.max(1, (page.totalCount / _inboxPageSize).ceil());
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
        SuperadminListingPaginationFooter(
          horizontalPadding: CoeloSpacing.space3,
          semanticKey: const Key('superadmin-chat-pagination'),
          compactCurrentPage: _inboxPage,
          compactTotalPages: totalPages,
          compactOnPrevious: _inboxPage > 1 ? _previousInboxPage : null,
          compactOnNext: page.nextCursor != null ? () => _nextInboxPage(page) : null,
          child: CoeloAdminPagination(
            currentPage: _inboxPage,
            totalPages: totalPages,
            pageSize: _inboxPageSize,
            pageSizeOptions: const [8, 20, 50, 100],
            onPrevious: _inboxPage > 1 ? _previousInboxPage : null,
            onNext: page.nextCursor != null ? () => _nextInboxPage(page) : null,
            onPageSelected: null,
            onPageSizeChanged: null,
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
            // O controle de continuacao so existe quando o SERVIDOR devolveu
            // cursor. Oferece-lo sem cursor prometeria uma pagina inexistente.
            itemCount: thread.items.length + (thread.nextCursor != null ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == thread.items.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space2),
                  child: Center(
                    child: _loadingOlder
                        ? const SizedBox(
                            width: CoeloSize.iconSm,
                            height: CoeloSize.iconSm,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : TextButton(
                            key: const Key('superadmin-chat-load-older'),
                            onPressed: _loadOlderMessages,
                            child: const Text('Carregar mensagens anteriores'),
                          ),
                  ),
                );
              }
              final message = thread.items[index];
              return _MessageBubble(
                key: ValueKey(message.id),
                message: message,
                mediaReader: widget.mediaReader,
                mediaSession: widget.mediaSession,
                // A read-only conversation refuses the commands server-side;
                // do not offer an affordance that cannot succeed.
                onEdit: conversation.isReadOnly || _managing
                    ? null
                    : () => _editMessage(message),
                onRevoke: conversation.isReadOnly || _managing
                    ? null
                    : () => _revokeMessage(message),
              );
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
  const _MessageBubble({
    required this.message,
    this.mediaReader,
    this.mediaSession,
    this.onEdit,
    this.onRevoke,
    super.key,
  });
  final ChatMessage message;
  final MediaReader? mediaReader;
  final MediaSession? mediaSession;
  final VoidCallback? onEdit;
  final VoidCallback? onRevoke;

  /// Affordances appear only where the server said this caller may manage the
  /// message. Hiding them is presentation, never the access control itself.
  bool get _canManage => message.canManage && (onEdit != null || onRevoke != null);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
            color: message.isMine ? colors.primaryContainer : colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(CoeloRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      message.authorName,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  if (_canManage)
                    PopupMenuButton<_MessageAction>(
                      key: Key('superadmin-chat-manage-${message.id}'),
                      tooltip: 'Acoes da mensagem',
                      icon: const Icon(Icons.more_horiz_rounded, size: CoeloSize.iconSm),
                      onSelected: (action) => switch (action) {
                        _MessageAction.edit => onEdit?.call(),
                        _MessageAction.revoke => onRevoke?.call(),
                      },
                      itemBuilder: (context) => [
                        if (onEdit != null)
                          const PopupMenuItem(
                            key: Key('superadmin-chat-action-edit'),
                            value: _MessageAction.edit,
                            child: Text('Editar'),
                          ),
                        if (onRevoke != null)
                          const PopupMenuItem(
                            key: Key('superadmin-chat-action-revoke'),
                            value: _MessageAction.revoke,
                            child: Text('Revogar'),
                          ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: CoeloSpacing.space1),
              Text(message.body),
              for (final attachment in message.attachments) ...[
                const SizedBox(height: CoeloSpacing.space2),
                SuperadminChatAttachmentTile(
                  key: ValueKey(attachment.id),
                  attachment: attachment,
                  state: SuperadminChatAttachmentState.ready,
                  mediaReader: mediaReader,
                  mediaSession: mediaSession,
                ),
              ],
              const SizedBox(height: CoeloSpacing.space1),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (message.isEdited)
                    Padding(
                      padding: const EdgeInsets.only(right: CoeloSpacing.space2),
                      child: Text(
                        'editada',
                        key: Key('superadmin-chat-edited-${message.id}'),
                        style: Theme.of(
                          context,
                        ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ),
                  Text(
                    MaterialLocalizations.of(context).formatTimeOfDay(
                      TimeOfDay.fromDateTime(message.sentAt),
                      alwaysUse24HourFormat: true,
                    ),
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
                  ),
                  if (receiptLabel != null) ...[
                    const SizedBox(width: CoeloSpacing.space1),
                    Icon(
                      _receiptIcon(message.receipt!),
                      key: Key('superadmin-chat-receipt-${message.id}'),
                      size: CoeloSize.iconSm,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: CoeloSpacing.space1),
                    Text(
                      receiptLabel,
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
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

enum _MessageAction { edit, revoke }

/// Owns its own controller so the field stays alive through the dialog's exit
/// animation. Disposing alongside the returned future tears it down too early.
final class _EditMessageDialog extends StatefulWidget {
  const _EditMessageDialog({required this.initialBody});

  final String initialBody;

  @override
  State<_EditMessageDialog> createState() => _EditMessageDialogState();
}

final class _EditMessageDialogState extends State<_EditMessageDialog> {
  late final _controller = TextEditingController(text: widget.initialBody);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Editar mensagem'),
    content: TextField(
      key: const Key('superadmin-chat-edit-field'),
      controller: _controller,
      autofocus: true,
      maxLines: 4,
      minLines: 1,
      maxLength: 4000,
      decoration: const InputDecoration(labelText: 'Mensagem'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const Key('superadmin-chat-edit-confirm'),
        onPressed: () => Navigator.of(context).pop(_controller.text),
        child: const Text('Salvar'),
      ),
    ],
  );
}

/// Null whenever the server projected no receipt, so an older gateway renders
/// nothing rather than an invented "unread" or "read" claim.
String? _receiptLabel(ChatMessage message) {
  final receipt = message.receipt;
  if (receipt == null) return null;
  if (receipt.isMine) {
    if (receipt.recipientCount == 0) return null;
    return 'Lida por ${receipt.readCount} de ${receipt.recipientCount}';
  }
  // A received message claims a receipt only once the server confirmed the
  // read. Silence here means "not yet confirmed", never "unread".
  return receipt.isReadByMe ? 'Lida' : null;
}

IconData _receiptIcon(ChatMessageReceipt receipt) {
  if (receipt.isMine) {
    if (receipt.isReadByEveryone) return Icons.done_all_rounded;
    if (receipt.isDeliveredToEveryone) return Icons.done_rounded;
    return Icons.schedule_rounded;
  }
  return receipt.isReadByMe ? Icons.done_all_rounded : Icons.mark_email_unread_outlined;
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
