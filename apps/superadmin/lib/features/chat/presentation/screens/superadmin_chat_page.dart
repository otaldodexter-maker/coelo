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

typedef ChatAttachmentPicker = Future<ChatAttachmentDraft?> Function();

enum _AttachmentPhase { idle, uploading, ready, failed }

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

/// A revision intent whose id survives a failure, so retrying the same edit
/// replays it instead of recording a second revision.
final class _PendingChatEdit {
  const _PendingChatEdit({
    required this.repository,
    required this.messageId,
    required this.body,
    required this.idempotencyKey,
  });

  final ChatRepository repository;
  final String messageId;
  final String body;
  final String idempotencyKey;

  bool matches(ChatRepository candidateRepository, String candidateMessageId, String value) =>
      identical(repository, candidateRepository) &&
      messageId == candidateMessageId &&
      body == value;
}

/// The same preserved-intent rule for `chat.revoke`: a retry must replay the
/// recorded tombstone, never record a second one.
final class _PendingChatRevoke {
  const _PendingChatRevoke({
    required this.repository,
    required this.messageId,
    required this.idempotencyKey,
  });

  final ChatRepository repository;
  final String messageId;
  final String idempotencyKey;

  bool matches(ChatRepository candidateRepository, String candidateMessageId) =>
      identical(repository, candidateRepository) && messageId == candidateMessageId;
}

final class SuperadminChatPage extends StatefulWidget {
  const SuperadminChatPage({
    required this.logout,
    this.chatRepository,
    this.attachmentPicker,
    this.mediaReader,
    this.mediaSession,
    this.currentDestination = 'conversations',
    this.onDestinationSelected,
    this.onBack,
    super.key,
  });

  final LogoutAction logout;
  final ChatRepository? chatRepository;

  /// Injected so the selection step is exercisable without a platform picker.
  final ChatAttachmentPicker? attachmentPicker;
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
  _PendingChatSend? _pendingSend;
  int _revisionRequestGeneration = 0;
  String? _revisingMessageId;
  _PendingChatEdit? _pendingEdit;
  _PendingChatRevoke? _pendingRevoke;
  int _attachmentGeneration = 0;
  ChatAttachmentDraft? _attachmentDraft;
  ChatAttachment? _attachmentAsset;
  String? _attachmentRequestId;
  String? _attachmentFinalizeRequestId;
  var _attachmentPhase = _AttachmentPhase.idle;
  String? _attachmentMessage;
  var _attachmentRetryable = false;
  final _composerFocus = FocusNode();

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
    _revisionRequestGeneration++;
    _repository = widget.chatRepository ?? _configuredRepository();
    _search.clear();
    _composer.clear();
    _selected = null;
    _thread = null;
    _threadError = null;
    _sending = false;
    _pendingSend = null;
    _revisingMessageId = null;
    _pendingEdit = null;
    _pendingRevoke = null;
    _clearAttachment();
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
    _composerFocus.dispose();
    super.dispose();
  }

  // Superadmin uses the isolated internal identity realm (ADR 0019). The
  // existing Supabase Chat RPCs resolve people/current_person_id and therefore
  // cannot be selected implicitly for this surface. Production remains
  // fail-closed until an internal-identity gateway is approved and injected by
  // the composition root; `/dev` continues to inject its deterministic repo.
  ChatRepository _configuredRepository() => const UnavailableChatRepository();

  Future<void> _loadInbox({bool reset = false}) async {
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
      if (page.items.isNotEmpty) {
        await _select(
          page.items.first,
          inboxRequestGeneration: requestGeneration,
          inboxSearch: search,
        );
      }
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
      // A revision intent belongs to one message in one conversation. Leaving
      // it alive across a switch could replay it against the wrong thread.
      _revisionRequestGeneration++;
      _pendingEdit = null;
      _pendingRevoke = null;
    }
    setState(() {
      _selected = conversation;
      _thread = null;
      _threadError = null;
      if (conversationChanged) {
        _sending = false;
        _revisingMessageId = null;
      }
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
    final attachment = _attachmentPhase == _AttachmentPhase.ready ? _attachmentAsset : null;
    if (conversation == null || conversation.isReadOnly || _sending) return;
    if (body.isEmpty && attachment == null) return;
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
          attachmentIds: attachment == null ? const [] : [attachment.id],
        ),
      );
      if (!_isCurrentSend(sendGeneration, requestedRepository, conversation.id)) return;
      _pendingSend = null;
      setState(() {
        if (_composer.text.trim() == body) _composer.clear();
        if (attachment != null) _clearAttachment();
        _thread = ChatThreadPage(items: [sent, ...?_thread?.items]);
      });
    } on ChatUnauthorizedException catch (error) {
      if (_isCurrentSend(sendGeneration, requestedRepository, conversation.id)) {
        _denyAccess(error);
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

  /// The revision transport, when this repository has one. A repository without
  /// it cannot honour `chat.edit` / `chat.revoke`, which is reported as
  /// unavailable — never as permission granted or denied.
  ChatMessageRevisionRepository? get _revisions {
    // Widened on purpose: the revision contract is deliberately not a subtype of
    // ChatRepository, and only a local typed Object? promotes to it cleanly.
    final Object repository = _repository;
    return repository is ChatMessageRevisionRepository ? repository : null;
  }

  static const _editUnavailableNotice = 'A edicao de mensagens aguarda o servico autorizado.';
  static const _revokeUnavailableNotice = 'A remocao de mensagens aguarda o servico autorizado.';

  String _bodyIssueMessage(ChatMessageBodyIssue issue) => switch (issue) {
    ChatMessageBodyIssue.empty => 'A mensagem nao pode ficar vazia.',
    ChatMessageBodyIssue.tooLong =>
      'A mensagem passa de ${ChatMessageBodyPolicy.maximumCharacters} caracteres.',
  };

  Future<void> _editMessage(ChatMessage message) async {
    final conversation = _selected;
    // The affordance is only ever the one the authorised projection granted.
    if (conversation == null || !message.canEdit || message.isRevoked) return;
    if (_revisingMessageId != null) return;
    final draft = await _promptEditedBody(message);
    if (!mounted || draft == null) return;
    final body = draft.trim();
    if (body == message.body) return;
    // Courtesy only: the server revalidates the same body before it writes.
    final issue = ChatMessageBodyPolicy.validate(body);
    if (issue != null) {
      _showNotice(_bodyIssueMessage(issue));
      return;
    }
    final revisions = _revisions;
    if (revisions == null) {
      _showNotice(_editUnavailableNotice);
      return;
    }
    final pending = _pendingEdit;
    final intent = pending != null && pending.matches(_repository, message.id, body)
        ? pending
        : _PendingChatEdit(
            repository: _repository,
            messageId: message.id,
            body: body,
            idempotencyKey: _requestId(),
          );
    _pendingEdit = intent;
    final generation = ++_revisionRequestGeneration;
    final requestedRepository = intent.repository;
    setState(() => _revisingMessageId = message.id);
    try {
      final revised = await revisions.editMessage(
        ChatEditMessageCommand(
          conversationId: conversation.id,
          messageId: message.id,
          body: body,
          idempotencyKey: intent.idempotencyKey,
        ),
      );
      if (!_isCurrentRevision(generation, requestedRepository, conversation.id)) return;
      _pendingEdit = null;
      // Only the server's re-projection replaces the message, so an edit can
      // never be rendered as a silent local rewrite.
      setState(() => _thread = _replaceMessage(revised));
    } on ChatUnauthorizedException catch (error) {
      if (_isCurrentRevision(generation, requestedRepository, conversation.id)) _denyAccess(error);
    } on ChatEditUnavailableException {
      if (_isCurrentRevision(generation, requestedRepository, conversation.id)) {
        _showNotice(_editUnavailableNotice);
      }
    } on ChatEditRejectedException catch (error) {
      if (_isCurrentRevision(generation, requestedRepository, conversation.id)) {
        _showNotice(_bodyIssueMessage(error.issue));
      }
    } on ChatOfflineException {
      if (_isCurrentRevision(generation, requestedRepository, conversation.id)) {
        _showNotice('Sem conexao. A mensagem nao foi editada.');
      }
    } catch (_) {
      if (_isCurrentRevision(generation, requestedRepository, conversation.id)) {
        _showNotice('Nao foi possivel editar. Tente novamente.');
      }
    } finally {
      _finishRevision(generation);
    }
  }

  Future<void> _revokeMessage(ChatMessage message) async {
    final conversation = _selected;
    if (conversation == null || !message.canRevoke || message.isRevoked) return;
    if (_revisingMessageId != null) return;
    if (!await _confirmRevoke()) return;
    if (!mounted || _selected?.id != conversation.id) return;
    final revisions = _revisions;
    if (revisions == null) {
      _showNotice(_revokeUnavailableNotice);
      return;
    }
    final pending = _pendingRevoke;
    final intent = pending != null && pending.matches(_repository, message.id)
        ? pending
        : _PendingChatRevoke(
            repository: _repository,
            messageId: message.id,
            idempotencyKey: _requestId(),
          );
    _pendingRevoke = intent;
    final generation = ++_revisionRequestGeneration;
    final requestedRepository = intent.repository;
    setState(() => _revisingMessageId = message.id);
    try {
      await revisions.revokeMessage(
        ChatRevokeMessageCommand(
          conversationId: conversation.id,
          messageId: message.id,
          idempotencyKey: intent.idempotencyKey,
        ),
      );
      if (!_isCurrentRevision(generation, requestedRepository, conversation.id)) return;
      _pendingRevoke = null;
      // The tombstone is proved by re-reading the authorised thread. The row is
      // never dropped locally, which would only hide it on this device.
      await _reloadRevokedThread(generation, requestedRepository, conversation.id);
    } on ChatUnauthorizedException catch (error) {
      if (_isCurrentRevision(generation, requestedRepository, conversation.id)) _denyAccess(error);
    } on ChatRevokeUnavailableException {
      if (_isCurrentRevision(generation, requestedRepository, conversation.id)) {
        _showNotice(_revokeUnavailableNotice);
      }
    } on ChatOfflineException {
      if (_isCurrentRevision(generation, requestedRepository, conversation.id)) {
        _showNotice('Sem conexao. A mensagem nao foi removida.');
      }
    } catch (_) {
      if (_isCurrentRevision(generation, requestedRepository, conversation.id)) {
        _showNotice('Nao foi possivel remover. Tente novamente.');
      }
    } finally {
      _finishRevision(generation);
    }
  }

  Future<void> _reloadRevokedThread(
    int generation,
    ChatRepository requestedRepository,
    String conversationId,
  ) async {
    try {
      final thread = await requestedRepository.fetchThread(
        ChatThreadQuery(conversationId: conversationId),
      );
      if (!_isCurrentRevision(generation, requestedRepository, conversationId)) return;
      setState(() => _thread = thread);
    } on ChatUnauthorizedException catch (error) {
      if (_isCurrentRevision(generation, requestedRepository, conversationId)) _denyAccess(error);
    } catch (_) {
      if (!_isCurrentRevision(generation, requestedRepository, conversationId)) return;
      // The revocation was accepted but its result could not be confirmed. The
      // list stays as the server last projected it instead of being edited here.
      _showNotice('Mensagem removida. Recarregue a conversa para confirmar.');
    }
  }

  void _finishRevision(int generation) {
    if (!mounted || generation != _revisionRequestGeneration) return;
    setState(() => _revisingMessageId = null);
  }

  ChatThreadPage _replaceMessage(ChatMessage revised) {
    final current = _thread;
    if (current == null) return ChatThreadPage(items: [revised]);
    return ChatThreadPage(
      items: [for (final item in current.items) item.id == revised.id ? revised : item],
      nextCursor: current.nextCursor,
      totalCount: current.totalCount,
      hasMore: current.hasMore,
    );
  }

  Future<String?> _promptEditedBody(ChatMessage message) => showDialog<String>(
    context: context,
    builder: (_) => _ChatEditDialog(body: message.body),
  );

  Future<bool> _confirmRevoke() async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          key: const Key('superadmin-chat-revoke-dialog'),
          title: const Text('Remover mensagem'),
          content: const Text(
            'A mensagem deixa de ser exibida para os participantes, mas continua '
            'registrada para auditoria.',
          ),
          actions: [
            TextButton(
              key: const Key('superadmin-chat-revoke-cancel'),
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const Key('superadmin-chat-revoke-confirm'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Remover'),
            ),
          ],
        ),
      ) ??
      false;

  bool _isCurrentRevision(
    int generation,
    ChatRepository requestedRepository,
    String conversationId,
  ) =>
      mounted &&
      generation == _revisionRequestGeneration &&
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
    _revisionRequestGeneration++;
    _search.clear();
    _composer.clear();
    setState(() {
      _selected = null;
      _thread = null;
      _threadError = null;
      _pendingSend = null;
      _sending = false;
      _revisingMessageId = null;
      _pendingEdit = null;
      _pendingRevoke = null;
      _clearAttachment();
      _inboxPage = 1;
      _inboxCursor = null;
      _inboxCursorHistory.clear();
      _inboxState = ChatInboxState.unauthorized(error);
    });
  }

  void _clearAttachment() {
    _attachmentGeneration++;
    _attachmentDraft = null;
    _attachmentAsset = null;
    _attachmentRequestId = null;
    _attachmentFinalizeRequestId = null;
    _attachmentPhase = _AttachmentPhase.idle;
    _attachmentMessage = null;
    _attachmentRetryable = false;
  }

  String _attachmentIssueMessage(ChatAttachmentIssue issue) => switch (issue) {
    ChatAttachmentIssue.emptyFile => 'O arquivo esta vazio.',
    ChatAttachmentIssue.unsupportedMediaType => 'Formato nao aceito. Use JPG, PNG, WebP ou PDF.',
    ChatAttachmentIssue.tooLarge => 'Arquivo acima do limite permitido.',
    ChatAttachmentIssue.nameTooLong => 'Nome de arquivo invalido.',
  };

  Future<void> _pickAttachment() async {
    final picker = widget.attachmentPicker;
    final conversation = _selected;
    if (picker == null) {
      _showNotice('Anexos aguardam o gateway R2 autorizado.');
      return;
    }
    if (conversation == null || conversation.isReadOnly || _sending) return;
    if (_attachmentPhase == _AttachmentPhase.uploading) return;
    final generation = ++_attachmentGeneration;
    final requestedRepository = _repository;
    final draft = await picker();
    if (!_isCurrentAttachment(generation, requestedRepository, conversation.id)) return;
    if (draft == null) {
      _composerFocus.requestFocus();
      return;
    }
    final issue = ChatAttachmentPolicy.validate(draft);
    if (issue != null) {
      setState(() {
        _attachmentDraft = draft;
        _attachmentAsset = null;
        _attachmentPhase = _AttachmentPhase.failed;
        _attachmentMessage = _attachmentIssueMessage(issue);
        _attachmentRetryable = false;
      });
      _composerFocus.requestFocus();
      return;
    }
    setState(() {
      _attachmentDraft = draft;
      _attachmentAsset = null;
      _attachmentRequestId = _requestId();
      _attachmentFinalizeRequestId = _requestId();
      _attachmentPhase = _AttachmentPhase.uploading;
      _attachmentMessage = null;
    });
    await _uploadAttachment(draft, generation, requestedRepository, conversation.id);
  }

  Future<void> _uploadAttachment(
    ChatAttachmentDraft draft,
    int generation,
    ChatRepository requestedRepository,
    String conversationId,
  ) async {
    try {
      final asset = await requestedRepository.uploadAttachment(
        ChatAttachmentUploadCommand(
          conversationId: conversationId,
          draft: draft,
          idempotencyKey: _attachmentRequestId ?? _requestId(),
          finalizeIdempotencyKey: _attachmentFinalizeRequestId ?? _requestId(),
        ),
      );
      if (!_isCurrentAttachment(generation, requestedRepository, conversationId)) return;
      setState(() {
        _attachmentAsset = asset;
        _attachmentPhase = _AttachmentPhase.ready;
        _attachmentMessage = null;
        _attachmentRetryable = false;
      });
      _composerFocus.requestFocus();
    } on ChatUnauthorizedException catch (error) {
      if (_isCurrentAttachment(generation, requestedRepository, conversationId)) {
        _denyAccess(error);
      }
    } on ChatAttachmentUnavailableException {
      if (!_isCurrentAttachment(generation, requestedRepository, conversationId)) return;
      setState(() {
        _attachmentPhase = _AttachmentPhase.failed;
        // Retrying cannot help while the gateway does not exist, so the copy
        // does not invite it.
        _attachmentMessage = 'Anexos aguardam o gateway autorizado.';
        _attachmentRetryable = false;
      });
      _composerFocus.requestFocus();
    } on ChatAttachmentRejectedException catch (error) {
      if (!_isCurrentAttachment(generation, requestedRepository, conversationId)) return;
      setState(() {
        _attachmentPhase = _AttachmentPhase.failed;
        _attachmentMessage = _attachmentIssueMessage(error.issue);
        _attachmentRetryable = false;
      });
      _composerFocus.requestFocus();
    } on Object {
      if (!_isCurrentAttachment(generation, requestedRepository, conversationId)) return;
      setState(() {
        _attachmentPhase = _AttachmentPhase.failed;
        _attachmentMessage = 'Nao foi possivel anexar agora. Tente novamente.';
        _attachmentRetryable = true;
      });
      _composerFocus.requestFocus();
    }
  }

  Future<void> _retryAttachment() async {
    final draft = _attachmentDraft;
    final conversation = _selected;
    if (draft == null || conversation == null || !_attachmentRetryable) return;
    final generation = ++_attachmentGeneration;
    final requestedRepository = _repository;
    setState(() {
      _attachmentPhase = _AttachmentPhase.uploading;
      _attachmentMessage = null;
    });
    await _uploadAttachment(draft, generation, requestedRepository, conversation.id);
  }

  void _removeAttachment() {
    setState(_clearAttachment);
    _composerFocus.requestFocus();
  }

  bool _isCurrentAttachment(int generation, ChatRepository repository, String conversationId) =>
      mounted &&
      generation == _attachmentGeneration &&
      identical(repository, _repository) &&
      _selected?.id == conversationId;

  Widget? _attachmentSurface() {
    final draft = _attachmentDraft;
    if (draft == null) return null;
    final colors = Theme.of(context).colorScheme;
    final failed = _attachmentPhase == _AttachmentPhase.failed;
    final uploading = _attachmentPhase == _AttachmentPhase.uploading;
    return Semantics(
      container: true,
      label: 'Anexo ${draft.fileName}, ${_attachmentStateLabel()}',
      child: ExcludeSemantics(
        child: DecoratedBox(
          key: const Key('superadmin-chat-attachment-pending'),
          decoration: BoxDecoration(
            color: failed ? colors.errorContainer : colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(CoeloRadius.md),
            border: Border.all(color: failed ? colors.error : colors.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(CoeloSpacing.space2),
            child: Row(
              children: [
                if (uploading)
                  const SizedBox(
                    width: CoeloSize.iconMd,
                    height: CoeloSize.iconMd,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    draft.mediaType == 'application/pdf'
                        ? Icons.picture_as_pdf_outlined
                        : Icons.image_outlined,
                    color: failed ? colors.error : colors.onSurfaceVariant,
                  ),
                const SizedBox(width: CoeloSpacing.space2),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(draft.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        _attachmentMessage ?? _attachmentStateLabel(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: failed ? colors.error : colors.onSurfaceVariant,
                        ),
                      ),
                      // Kept inside the column so a long refusal never pushes the
                      // action off the row on a narrow composer.
                      if (failed)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            key: const Key('superadmin-chat-attachment-retry'),
                            onPressed: _attachmentRetryable ? _retryAttachment : null,
                            child: const Text('Tentar novamente'),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('superadmin-chat-attachment-remove'),
                  tooltip: 'Remover anexo',
                  color: colors.error,
                  hoverColor: colors.errorContainer,
                  focusColor: colors.errorContainer,
                  onPressed: uploading ? null : _removeAttachment,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _attachmentStateLabel() => switch (_attachmentPhase) {
    _AttachmentPhase.idle => 'selecionado',
    _AttachmentPhase.uploading => 'enviando',
    _AttachmentPhase.ready => 'pronto para enviar',
    _AttachmentPhase.failed => 'falhou',
  };

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
                    ),
                    // Two separate problems, two separate fixes. The outline is
                    // painted in front of the content, because the inbox
                    // pagination footer sits flush with the card edge and blurs
                    // its own backdrop, which erased the 1 px line. And the
                    // content is clipped to the same radius, because the footer
                    // is a plain rectangle: without the clip it paints past the
                    // arc and squares off the corners under the border.
                    child: DecoratedBox(
                      position: DecorationPosition.foreground,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(CoeloRadius.lg),
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(CoeloRadius.lg),
                        child: _body(),
                      ),
                    ),
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
            itemCount: thread.items.length,
            itemBuilder: (context, index) {
              final message = thread.items[index];
              return _MessageBubble(
                key: ValueKey(message.id),
                message: message,
                busy: _revisingMessageId != null,
                // Gated by the server projection alone. Nothing here derives
                // authorship, ownership or a revision window.
                onEdit: message.canEdit ? () => _editMessage(message) : null,
                onRevoke: message.canRevoke ? () => _revokeMessage(message) : null,
                mediaReader: widget.mediaReader,
                mediaSession: widget.mediaSession,
              );
            },
          ),
        ),
        if (!conversation.isReadOnly)
          SuperadminChatComposer(
            controller: _composer,
            focusNode: _composerFocus,
            compact: compact,
            onSend: _send,
            canSendWithoutText: _attachmentPhase == _AttachmentPhase.ready,
            attachment: _attachmentSurface(),
            onAudio: () =>
                _showNotice('Gravacao de audio estara disponivel na experiencia completa.'),
            onImage: _pickAttachment,
          ),
      ],
    );
  }
}

final class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    this.onEdit,
    this.onRevoke,
    this.busy = false,
    this.mediaReader,
    this.mediaSession,
    super.key,
  });
  final ChatMessage message;

  /// Supplied only when the authorised projection granted the action.
  final VoidCallback? onEdit;
  final VoidCallback? onRevoke;

  /// Another revision is in flight; the menu stays visible but inert.
  final bool busy;
  final MediaReader? mediaReader;
  final MediaSession? mediaSession;

  bool get _hasActions => !message.isRevoked && (onEdit != null || onRevoke != null);

  String _timestampLabel(BuildContext context) {
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(message.sentAt), alwaysUse24HourFormat: true);
    // An edit is always stated; a body is never swapped silently.
    return message.isEdited ? '$time · editada' : time;
  }

  String get _semanticsLabel {
    if (message.isRevoked) return '${message.authorName}. Mensagem removida.';
    return message.isEdited
        ? '${message.authorName}. ${message.body}. Mensagem editada.'
        : '${message.authorName}. ${message.body}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: _semanticsLabel,
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
              if (_hasActions)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        message.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                    const SizedBox(width: CoeloSpacing.space1),
                    _RevisionMenu(
                      message: message,
                      onEdit: onEdit,
                      onRevoke: onRevoke,
                      enabled: !busy,
                    ),
                  ],
                )
              else
                Text(message.authorName, style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: CoeloSpacing.space1),
              if (message.isRevoked)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.block_outlined,
                      size: CoeloSize.iconSm,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: CoeloSpacing.space1),
                    Flexible(
                      child: Text(
                        'Mensagem removida',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                )
              else
                Text(message.body),
              // A tombstone keeps its attachments in place, marked as removed.
              for (final attachment in message.attachments) ...[
                const SizedBox(height: CoeloSpacing.space2),
                SuperadminChatAttachmentTile(
                  key: ValueKey(attachment.id),
                  attachment: attachment,
                  state: message.isRevoked
                      ? SuperadminChatAttachmentState.deleted
                      : SuperadminChatAttachmentState.ready,
                  mediaReader: mediaReader,
                  mediaSession: mediaSession,
                ),
              ],
              const SizedBox(height: CoeloSpacing.space1),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _timestampLabel(context),
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

/// Editing dialog for one message body.
///
/// It owns its controller so the field outlives the awaited route and is
/// disposed only once the route itself is gone. Disposing on `whenComplete`
/// tears the controller down while the exit transition is still rebuilding the
/// field.
final class _ChatEditDialog extends StatefulWidget {
  const _ChatEditDialog({required this.body});

  final String body;

  @override
  State<_ChatEditDialog> createState() => _ChatEditDialogState();
}

final class _ChatEditDialogState extends State<_ChatEditDialog> {
  late final _controller = TextEditingController(text: widget.body);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const Key('superadmin-chat-edit-dialog'),
    title: const Text('Editar mensagem'),
    content: TextField(
      key: const Key('superadmin-chat-edit-field'),
      controller: _controller,
      autofocus: true,
      minLines: 1,
      maxLines: 5,
      decoration: const InputDecoration(labelText: 'Mensagem'),
    ),
    actions: [
      TextButton(
        key: const Key('superadmin-chat-edit-cancel'),
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const Key('superadmin-chat-edit-save'),
        onPressed: () => Navigator.pop(context, _controller.text),
        child: const Text('Salvar'),
      ),
    ],
  );
}

enum _RevisionAction { edit, revoke }

/// Renders only the revisions the authorised projection already granted for
/// this message. It has no rule of its own about who may edit or revoke.
final class _RevisionMenu extends StatelessWidget {
  const _RevisionMenu({required this.message, required this.enabled, this.onEdit, this.onRevoke});

  final ChatMessage message;
  final bool enabled;
  final VoidCallback? onEdit;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: CoeloSize.touchMin,
      height: CoeloSize.touchMin,
      child: PopupMenuButton<_RevisionAction>(
        key: Key('superadmin-chat-message-menu-${message.id}'),
        tooltip: 'Acoes da mensagem',
        enabled: enabled,
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.more_horiz_rounded, size: CoeloSize.iconSm),
        itemBuilder: (context) => [
          if (onEdit != null)
            const PopupMenuItem<_RevisionAction>(
              key: Key('superadmin-chat-message-edit'),
              value: _RevisionAction.edit,
              child: Text('Editar mensagem'),
            ),
          if (onRevoke != null)
            const PopupMenuItem<_RevisionAction>(
              key: Key('superadmin-chat-message-revoke'),
              value: _RevisionAction.revoke,
              child: Text('Remover mensagem'),
            ),
        ],
        onSelected: (action) => switch (action) {
          _RevisionAction.edit => onEdit?.call(),
          _RevisionAction.revoke => onRevoke?.call(),
        },
      ),
    );
  }
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
