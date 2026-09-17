import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../../domain/chat_repository.dart';

/// Envio em lote (spec 058): os arquivos selecionados viram UMA mensagem.
///
/// O diálogo mostra o estado de cada item, o progresso "k de N" e, em falha
/// parcial, deixa o autor remover os que falharam (a mensagem publica com os
/// restantes) ou cancelar o envio (a mensagem é arquivada). O rascunho de
/// texto do compositor não é tocado.
final class SuperadminChatBatchUploadDialog extends StatefulWidget {
  const SuperadminChatBatchUploadDialog({
    required this.repository,
    required this.command,
    required this.isContextCurrent,
    super.key,
  });
  final ChatAttachmentBatchRepository repository;
  final ChatAttachmentBatchUpload command;
  final bool Function() isContextCurrent;

  @override
  State<SuperadminChatBatchUploadDialog> createState() => _SuperadminChatBatchUploadDialogState();
}

enum _Phase { idle, sending, partial, resolving }

final class _SuperadminChatBatchUploadDialogState extends State<SuperadminChatBatchUploadDialog> {
  _Phase _phase = _Phase.idle;
  ChatAttachmentBatchResult? _result;
  String? _error;

  bool get _busy => _phase == _Phase.sending || _phase == _Phase.resolving;

  Future<void> _send() async {
    if (_busy || !widget.isContextCurrent()) return;
    setState(() {
      _phase = _Phase.sending;
      _error = null;
      _result = null;
    });
    try {
      final result = await widget.repository.uploadAttachmentBatch(
        widget.command,
        onProgress: (snapshot) {
          if (mounted) setState(() => _result = snapshot);
        },
      );
      if (!mounted || !widget.isContextCurrent()) return;
      if (result.isPublished) {
        _finish(result.messageId);
        return;
      }
      setState(() {
        _result = result;
        _phase = _Phase.partial;
        _error = result.failed.isEmpty
            ? 'Não foi possível publicar a mensagem. Tente novamente.'
            : '${result.failed.length} de ${result.items.length} arquivos não foram enviados.';
      });
    } catch (error) {
      if (!mounted || !widget.isContextCurrent()) return;
      setState(() {
        _phase = _Phase.idle;
        _result = null;
        _error = _describe(error);
      });
    }
  }

  /// Remove os itens que falharam; a mensagem publica com os restantes.
  Future<void> _discardFailedAndPublish() async {
    final result = _result;
    if (result == null || _busy || !widget.isContextCurrent()) return;
    setState(() => _phase = _Phase.resolving);
    await _discard(result.failed, expectPublished: true);
  }

  /// Remove todos os itens; a mensagem em rascunho é arquivada.
  Future<void> _cancelSend() async {
    final result = _result;
    if (result == null || _busy || !widget.isContextCurrent()) return;
    setState(() => _phase = _Phase.resolving);
    await _discard(
      result.items.where((item) => item.state != ChatAttachmentBatchItemState.waiting),
      expectPublished: false,
    );
  }

  Future<void> _discard(
    Iterable<ChatAttachmentBatchItem> items, {
    required bool expectPublished,
  }) async {
    final result = _result!;
    try {
      String status = result.messageStatus;
      for (final item in items) {
        final id = item.attachmentId;
        if (id == null) continue;
        status = (await widget.repository.discardAttachment(id)).messageStatus;
      }
      if (!mounted || !widget.isContextCurrent()) return;
      if (expectPublished && status == 'active') {
        _finish(result.messageId);
      } else if (!expectPublished) {
        _finish(null);
      } else {
        setState(() {
          _phase = _Phase.partial;
          _error = 'Não foi possível publicar a mensagem. Tente novamente.';
        });
      }
    } catch (error) {
      if (!mounted || !widget.isContextCurrent()) return;
      setState(() {
        _phase = _Phase.partial;
        _error = _describe(error);
      });
    }
  }

  void _finish(String? messageId) {
    final route = ModalRoute.of(context);
    if (route == null) return;
    if (route.isCurrent) {
      Navigator.of(context).pop(messageId);
    } else if (route.isActive) {
      route.navigator?.removeRoute(route, messageId);
    }
  }

  void _close() {
    if (!_busy &&
        _phase != _Phase.partial &&
        widget.isContextCurrent() &&
        ModalRoute.of(context)?.isCurrent == true) {
      Navigator.of(context).pop();
    }
  }

  String _describe(Object error) => error is ChatAttachmentInvalidException
      ? 'Use imagens de até 4 MB, PDF ou vídeo MP4 de até 10 MB.'
      : error is ChatAttachmentLimitException
      ? 'Limite de 10 anexos por mensagem. Selecione até 10 arquivos.'
      : error is ChatUnauthorizedException
      ? 'Você não tem acesso para enviar estes arquivos.'
      : error is ChatConflictException
      ? 'Esta conversa não aceita novos arquivos.'
      : error is ChatOfflineException
      ? 'Sem conexão. Tente novamente.'
      : 'Não foi possível enviar os arquivos. Tente novamente.';

  String _stateLabel(ChatAttachmentBatchItemState state) => switch (state) {
    ChatAttachmentBatchItemState.waiting => 'Aguardando',
    ChatAttachmentBatchItemState.sending => 'Enviando…',
    ChatAttachmentBatchItemState.ready => 'Pronto',
    ChatAttachmentBatchItemState.failed => 'Falhou',
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final total = widget.command.items.length;
    final result = _result;
    final done = result == null
        ? 0
        : result.items
              .where(
                (item) =>
                    item.state == ChatAttachmentBatchItemState.ready ||
                    item.state == ChatAttachmentBatchItemState.failed,
              )
              .length;
    final hasReady = result != null && result.ready.isNotEmpty;
    final Widget primary;
    final Widget? secondary;
    switch (_phase) {
      case _Phase.idle:
        primary = FilledButton(
          key: const Key('superadmin-chat-batch-send'),
          onPressed: _send,
          child: Text(
            _error == null
                ? (total == 1 ? 'Enviar arquivo' : 'Enviar $total arquivos')
                : 'Tentar novamente',
          ),
        );
        secondary = OutlinedButton(
          onPressed: _close,
          style: OutlinedButton.styleFrom(foregroundColor: colors.error),
          child: const Text('Cancelar'),
        );
      case _Phase.sending:
        primary = FilledButton(onPressed: null, child: Text('Enviando $done de $total…'));
        secondary = null;
      case _Phase.partial:
        primary = hasReady
            ? FilledButton(
                key: const Key('superadmin-chat-batch-discard-failed'),
                onPressed: _discardFailedAndPublish,
                child: const Text('Remover os que falharam e publicar'),
              )
            : FilledButton(
                key: const Key('superadmin-chat-batch-cancel'),
                onPressed: _cancelSend,
                child: const Text('Cancelar envio'),
              );
        secondary = hasReady
            ? OutlinedButton(
                key: const Key('superadmin-chat-batch-cancel'),
                onPressed: _cancelSend,
                style: OutlinedButton.styleFrom(foregroundColor: colors.error),
                child: const Text('Cancelar envio'),
              )
            : null;
      case _Phase.resolving:
        primary = const FilledButton(onPressed: null, child: Text('Atualizando…'));
        secondary = null;
    }
    return PopScope(
      canPop: !_busy && _phase != _Phase.partial,
      child: CoeloAdminDialogShell(
        title: total == 1 ? 'Arquivo da conversa' : 'Arquivos da conversa',
        onClose: _close,
        primaryAction: primary,
        secondaryAction: secondary,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              total == 1
                  ? 'O arquivo será enviado como uma mensagem.'
                  : 'Os $total arquivos serão enviados juntos, como uma única mensagem.',
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < total; index++)
              _ItemRow(
                key: Key('superadmin-chat-batch-item-$index'),
                fileName: widget.command.items[index].fileName,
                sizeKb: (widget.command.items[index].bytes.length / 1024).ceil(),
                state: result == null ? null : _stateLabel(result.items[index].state),
                failed:
                    result != null &&
                    result.items[index].state == ChatAttachmentBatchItemState.failed,
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Semantics(liveRegion: true, child: Text(_error!)),
            ],
          ],
        ),
      ),
    );
  }
}

final class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.fileName,
    required this.sizeKb,
    required this.state,
    required this.failed,
    super.key,
  });
  final String fileName;
  final int sizeKb;
  final String? state;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text('$fileName · $sizeKb KB', maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          if (state != null) ...[
            const SizedBox(width: 8),
            Text(state!, style: TextStyle(color: failed ? colors.error : colors.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}
