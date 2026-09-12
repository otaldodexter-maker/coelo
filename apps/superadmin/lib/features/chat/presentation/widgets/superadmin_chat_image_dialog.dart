import 'dart:async';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../../domain/chat_repository.dart';

final class SuperadminChatImageDialog extends StatefulWidget {
  const SuperadminChatImageDialog({
    required this.assetId,
    required this.reader,
    required this.session,
    this.isContextCurrent,
    super.key,
  }) : attachmentId = null,
       attachmentRepository = null;

  const SuperadminChatImageDialog.attachment({
    required this.attachmentId,
    required this.attachmentRepository,
    required this.session,
    this.isContextCurrent,
    super.key,
  }) : assetId = null,
       reader = null;

  final String? assetId;
  final MediaReader? reader;
  final String? attachmentId;
  final ChatAttachmentRepository? attachmentRepository;
  final MediaSession session;

  /// Local route ownership only; never substitutes server authorization.
  final bool Function()? isContextCurrent;

  @override
  State<SuperadminChatImageDialog> createState() => _SuperadminChatImageDialogState();
}

final class _SuperadminChatImageDialogState extends State<SuperadminChatImageDialog>
    with WidgetsBindingObserver {
  MediaReadState? _state;
  NetworkImage? _image;
  DateTime? _expiresAt;
  Timer? _expiry;
  void Function()? _unregister;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bind();
  }

  @override
  void didUpdateWidget(covariant SuperadminChatImageDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetId != widget.assetId ||
        oldWidget.reader != widget.reader ||
        oldWidget.attachmentId != widget.attachmentId ||
        oldWidget.attachmentRepository != widget.attachmentRepository ||
        oldWidget.session != widget.session) {
      _unregister?.call();
      _bind();
    }
  }

  void _bind() {
    final generation = ++_generation;
    unawaited(_clearImage());
    if (widget.session.isInvalidated) {
      _generation++;
      unawaited(_clearImage());
      _state = MediaReadState.unavailable;
      return;
    }
    _unregister = widget.session.registerPurge(() {
      _generation++;
      final purged = _clearImage();
      if (mounted) setState(() => _state = MediaReadState.unavailable);
      return purged;
    });
    _state = null;
    // The route may build before its originating tile receives a context
    // replacement in this frame. Do not start I/O until ownership is settled.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && generation == _generation && _contextCurrent) unawaited(_read());
    });
  }

  bool get _contextCurrent => widget.isContextCurrent?.call() ?? true;

  Future<void> _clearImage() async {
    _expiry?.cancel();
    _expiry = null;
    _expiresAt = null;
    final previous = _image;
    _image = null;
    if (previous != null) await previous.evict();
  }

  Future<void> _read() async {
    if (!mounted || widget.session.isInvalidated || !_contextCurrent) return;
    final generation = ++_generation;
    unawaited(_clearImage());
    setState(() => _state = null);
    try {
      final bindingRepository = widget.attachmentRepository;
      if (bindingRepository != null) {
        final ticket = await bindingRepository.readAttachment(widget.attachmentId!);
        if (!mounted ||
            generation != _generation ||
            !_contextCurrent ||
            widget.session.isInvalidated) {
          return;
        }
        if (!ticket.expiresAt.isAfter(DateTime.now().toUtc())) {
          throw const MediaTicketExpiredException();
        }
        setState(() {
          _state = MediaReadState.available;
          _image = NetworkImage(ticket.url.toString());
          _expiresAt = ticket.expiresAt;
          _expiry = Timer(ticket.expiresAt.difference(DateTime.now().toUtc()), _expire);
        });
        return;
      }
      final result = await SessionMediaReader(
        delegate: widget.reader!,
        session: widget.session,
      ).read(MediaReadRequest(assetId: widget.assetId!, rendition: MediaReadRendition.preview));
      if (!mounted || generation != _generation || !_contextCurrent) return;
      final ticket = result.ticket;
      setState(() {
        _state = result.state;
        if (ticket != null) {
          _image = NetworkImage(ticket.url.toString(), headers: ticket.headers);
          _expiresAt = ticket.expiresAt;
          _expiry = Timer(ticket.expiresAt.difference(DateTime.now().toUtc()), _expire);
        }
      });
    } catch (error) {
      if (!mounted || generation != _generation || !_contextCurrent) return;
      setState(() {
        _state = error is MediaTicketExpiredException
            ? MediaReadState.expired
            : MediaReadState.unavailable;
      });
    }
  }

  void _expire() {
    if (!mounted) return;
    _generation++;
    unawaited(_clearImage());
    setState(() => _state = MediaReadState.expired);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final expiresAt = _expiresAt;
    if (state == AppLifecycleState.resumed &&
        expiresAt != null &&
        !expiresAt.isAfter(DateTime.now().toUtc())) {
      _expire();
    }
  }

  @override
  void dispose() {
    _generation++;
    _unregister?.call();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_clearImage());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    final generation = _generation;
    final route = ModalRoute.of(context);
    final assetId = widget.assetId;
    final reader = widget.reader;
    final bindingId = widget.attachmentId;
    final bindingRepository = widget.attachmentRepository;
    final session = widget.session;
    void closeOwnedRoute() {
      if (!mounted ||
          !_contextCurrent ||
          widget.assetId != assetId ||
          widget.attachmentId != bindingId ||
          !identical(widget.attachmentRepository, bindingRepository) ||
          !identical(widget.reader, reader) ||
          !identical(widget.session, session) ||
          route?.isCurrent != true) {
        return;
      }
      route!.navigator?.pop();
    }

    final canRetry =
        _state != null && _state != MediaReadState.available && !widget.session.isInvalidated;
    final close = OutlinedButton(
      onPressed: closeOwnedRoute,
      style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
      child: const Text('Fechar'),
    );
    return CoeloAdminDialogShell(
      title: 'Imagem da conversa',
      onClose: closeOwnedRoute,
      primaryAction: canRetry
          ? FilledButton(
              onPressed: () {
                if (!mounted || generation != _generation) return;
                unawaited(_read());
              },
              child: const Text('Tentar novamente'),
            )
          : close,
      secondaryAction: canRetry ? close : null,
      body: image != null
          ? Image(
              key: const Key('chat-image-preview'),
              image: image,
              fit: BoxFit.contain,
              semanticLabel: 'Imagem compartilhada na conversa',
              errorBuilder: (_, _, _) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted || generation != _generation || !identical(image, _image)) return;
                  _generation++;
                  unawaited(_clearImage());
                  setState(() => _state = MediaReadState.unavailable);
                });
                return const Text('Não foi possível exibir a imagem.');
              },
            )
          : Semantics(
              liveRegion: true,
              child: Text(switch (_state) {
                null => 'Carregando imagem…',
                MediaReadState.processing =>
                  'A imagem está sendo preparada. Tente novamente em instantes.',
                MediaReadState.expired =>
                  'O acesso temporário expirou. Tente novamente para solicitar acesso.',
                _ => 'A imagem não está disponível neste contexto.',
              }, key: Key('chat-image-${_state?.name ?? 'loading'}')),
            ),
    );
  }
}
