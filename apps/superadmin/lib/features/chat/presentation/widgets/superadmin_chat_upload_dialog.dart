import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../../domain/chat_repository.dart';

/// The selected file is sent separately; the text composer remains untouched.
final class SuperadminChatUploadDialog extends StatefulWidget {
  const SuperadminChatUploadDialog({
    required this.repository,
    required this.command,
    required this.isContextCurrent,
    super.key,
  });
  final ChatAttachmentRepository repository;
  final ChatAttachmentUpload command;
  final bool Function() isContextCurrent;

  @override
  State<SuperadminChatUploadDialog> createState() => _SuperadminChatUploadDialogState();
}

final class _SuperadminChatUploadDialogState extends State<SuperadminChatUploadDialog> {
  bool _sending = false;
  String? _error;

  Future<void> _send() async {
    if (_sending || !widget.isContextCurrent()) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final messageId = await widget.repository.uploadAttachment(widget.command);
      if (!mounted || !widget.isContextCurrent()) return;
      final route = ModalRoute.of(context);
      if (route == null) return;
      if (route.isCurrent) {
        Navigator.of(context).pop(messageId);
      } else if (route.isActive) {
        route.navigator?.removeRoute(route, messageId);
      }
    } catch (error) {
      if (!mounted || !widget.isContextCurrent()) return;
      setState(() {
        _sending = false;
        _error = error is ChatAttachmentInvalidException
            ? 'Use uma imagem de até 4 MB ou um PDF de até 10 MB.'
            : error is ChatUnauthorizedException
            ? 'Você não tem acesso para enviar este arquivo.'
            : error is ChatConflictException
            ? 'Esta conversa não aceita novos arquivos.'
            : 'Não foi possível enviar o arquivo. Tente novamente.';
      });
    }
  }

  void _close() {
    if (!_sending && widget.isContextCurrent() && ModalRoute.of(context)?.isCurrent == true) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_sending,
    child: CoeloAdminDialogShell(
      title: 'Arquivo da conversa',
      onClose: _close,
      primaryAction: FilledButton(
        onPressed: _sending ? null : _send,
        child: Text(
          _sending
              ? 'Enviando…'
              : _error == null
              ? 'Enviar arquivo'
              : 'Tentar novamente',
        ),
      ),
      secondaryAction: OutlinedButton(
        onPressed: _sending ? null : _close,
        style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
        child: const Text('Cancelar'),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.command.fileName),
          Text('${(widget.command.bytes.length / 1024).ceil()} KB'),
          const Text('O arquivo será enviado como uma mensagem separada.'),
          if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
        ],
      ),
    ),
  );
}
