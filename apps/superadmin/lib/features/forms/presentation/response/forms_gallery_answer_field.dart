import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../data/forms_image_upload.dart';
import '../operations/forms_media_page.dart';

typedef FormsGalleryPicker = Future<Uint8List?> Function();

final class FormsGalleryAnswerField extends StatefulWidget {
  const FormsGalleryAnswerField({
    required this.api,
    required this.session,
    required this.occurrenceId,
    required this.item,
    required this.assetIds,
    required this.onChanged,
    required this.onBusyChanged,
    this.reader,
    this.editSecret,
    this.enabled = true,
    this.pickImage = pickFormsGalleryImage,
    this.createUploadClient,
    super.key,
  }) : questionApi = null,
       questionTarget = null,
       readyAssetIds = null;

  const FormsGalleryAnswerField.questionImage({
    required FormsQuestionImageApi api,
    required FormQuestionImageTarget target,
    required this.session,
    required this.item,
    required this.assetIds,
    required this.readyAssetIds,
    required this.onChanged,
    required this.onBusyChanged,
    this.enabled = true,
    this.pickImage = pickFormsGalleryImage,
    this.createUploadClient,
    super.key,
  }) : api = null,
       questionApi = api,
       questionTarget = target,
       occurrenceId = '',
       editSecret = null,
       reader = null;
  final FormsApi? api;
  final FormsQuestionImageApi? questionApi;
  final FormQuestionImageTarget? questionTarget;
  final Set<String>? readyAssetIds;
  final http.Client Function()? createUploadClient;
  final MediaSession session;
  final MediaReader? reader;
  final String? editSecret;
  final String occurrenceId;
  final FormItem item;
  final List<String> assetIds;
  final ValueChanged<List<String>> onChanged;
  final ValueChanged<bool> onBusyChanged;
  final bool enabled;
  final FormsGalleryPicker pickImage;

  @override
  State<FormsGalleryAnswerField> createState() => _FormsGalleryAnswerFieldState();
}

final class _FormsGalleryAnswerFieldState extends State<FormsGalleryAnswerField> {
  FormsImageUpload? _operation;
  bool _busy = false;
  String? _message;
  final _lifetime = MediaSession();
  void Function()? _unregister;

  @override
  void initState() {
    super.initState();
    if (!widget.session.isInvalidated) {
      _unregister = widget.session.registerPurge(() {
        final purged = _lifetime.invalidate();
        if (mounted) {
          setState(() {
            _busy = false;
            _operation = null;
            _message = 'A sessão de mídia terminou. Abra novamente o formulário.';
          });
        }
        return purged;
      });
    } else {
      unawaited(_lifetime.invalidate());
    }
  }

  @override
  void dispose() {
    _operation?.cancel();
    unawaited(_lifetime.invalidate());
    _unregister?.call();
    super.dispose();
  }

  bool get _active => mounted && !_lifetime.isInvalidated && !widget.session.isInvalidated;

  void _setBusy(bool busy) {
    if (!_active) return;
    setState(() => _busy = busy);
    widget.onBusyChanged(busy || _operation != null);
  }

  Future<void> _pick() async {
    if (!_active ||
        !widget.enabled ||
        _busy ||
        _operation != null ||
        widget.assetIds.length >= (widget.item.config.maxImages ?? 5)) {
      return;
    }
    _setBusy(true);
    try {
      final bytes = await widget.pickImage();
      if (bytes == null) return;
      if (!_active) {
        bytes.fillRange(0, bytes.length, 0);
        return;
      }
      final operation = widget.questionApi != null
          ? FormsImageUpload.questionImage(
              api: widget.questionApi!,
              target: widget.questionTarget!,
              session: _lifetime,
              requestId: _requestId(),
              finalizeRequestId: _requestId(),
              createClient: widget.createUploadClient,
            )
          : FormsImageUpload(
              api: widget.api!,
              session: _lifetime,
              occurrenceId: widget.occurrenceId,
              itemId: widget.item.id,
              editSecret: widget.editSecret,
              requestId: _requestId(),
              finalizeRequestId: _requestId(),
              createClient: widget.createUploadClient,
            );
      setState(() {
        _operation = operation;
        _message = 'Enviando imagem…';
      });
      final asset = await operation.upload(bytes);
      _accept(asset);
    } on FormsImageUploadException catch (error) {
      if (_active) setState(() => _message = error.message);
    } on Object {
      if (_active) {
        setState(() => _message = 'Não foi possível selecionar a imagem. Tente novamente.');
      }
    } finally {
      if (_active) {
        if (_operation?.assetId == null) _operation = null;
        _setBusy(false);
      }
    }
  }

  void _accept(FormAsset asset) {
    if (!_active) return;
    setState(() {
      _operation = null;
      _message = widget.questionApi != null
          ? 'Imagem da pergunta confirmada.'
          : 'Imagem confirmada. Salve ou envie sua resposta.';
    });
    widget.onChanged([...widget.assetIds, asset.id]);
  }

  Future<void> _verify() async {
    if (!_active || _busy || _operation == null) return;
    _setBusy(true);
    try {
      _accept(await _operation!.finalize());
    } on FormsImageUploadException catch (error) {
      if (_active) setState(() => _message = error.message);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _discardPending() async {
    if (!_active || _busy || _operation == null) return;
    _setBusy(true);
    try {
      await _operation!.discard(_requestId());
      if (_active) {
        setState(() {
          _operation = null;
          _message = 'Envio descartado.';
        });
      }
    } on FormsImageUploadException catch (error) {
      if (_active) setState(() => _message = error.message);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _removeQuestionImage(String id) async {
    if (!_active || _busy || !widget.enabled) return;
    _setBusy(true);
    try {
      await _lifetime.run(
        () => widget.questionApi!.deleteQuestionImage(
          FormCommand(requestId: _requestId(), expectedVersion: 0, payload: FormAssetIdPayload(id)),
        ),
      );
      if (_active) widget.onChanged([...widget.assetIds]..remove(id));
    } on Object {
      if (_active) setState(() => _message = 'Não foi possível excluir a imagem. Tente novamente.');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _view(String assetId) async {
    final reader = widget.reader ?? widget.questionApi?.questionImageReader;
    if (!_active || reader == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          body: FormsMediaPage(
            assetId: assetId,
            reader: reader,
            rendition: widget.editSecret == null
                ? MediaReadRendition.preview
                : MediaReadRendition.original,
            session: _lifetime,
            onBack: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Até ${widget.item.config.maxImages ?? 5} imagens. JPEG, PNG ou WebP, até ${widget.questionApi == null ? 10 : 4} MB por imagem.',
      ),
      for (var index = 0; index < widget.assetIds.length; index++)
        Wrap(
          spacing: CoeloSpacing.space2,
          children: [
            TextButton(
              onPressed:
                  (widget.reader == null && widget.questionApi == null) ||
                      (widget.readyAssetIds != null &&
                          !widget.readyAssetIds!.contains(widget.assetIds[index]))
                  ? null
                  : () => _view(widget.assetIds[index]),
              child: Text(
                widget.readyAssetIds != null &&
                        !widget.readyAssetIds!.contains(widget.assetIds[index])
                    ? 'Imagem ${index + 1} não confirmada'
                    : 'Ver imagem ${index + 1}',
              ),
            ),
            TextButton(
              onPressed: widget.enabled && !_busy && _operation == null
                  ? () => widget.questionApi != null
                        ? _removeQuestionImage(widget.assetIds[index])
                        : widget.onChanged([...widget.assetIds]..removeAt(index))
                  : null,
              child: Text(
                widget.questionApi != null
                    ? 'Excluir imagem ${index + 1}'
                    : 'Remover imagem ${index + 1} da resposta',
              ),
            ),
          ],
        ),
      Wrap(
        spacing: CoeloSpacing.space2,
        runSpacing: CoeloSpacing.space2,
        children: [
          OutlinedButton.icon(
            key: Key('forms-gallery-add-${widget.item.id}'),
            onPressed:
                widget.enabled &&
                    !_busy &&
                    _operation == null &&
                    widget.assetIds.length < (widget.item.config.maxImages ?? 5) &&
                    _active
                ? _pick
                : null,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Selecionar imagem'),
          ),
          if (_busy && _operation != null)
            TextButton(onPressed: _operation!.cancel, child: const Text('Cancelar envio')),
          if (!_busy && _operation?.assetId != null) ...[
            OutlinedButton(onPressed: _verify, child: const Text('Verificar envio')),
            TextButton(onPressed: _discardPending, child: const Text('Descartar envio')),
          ],
        ],
      ),
      if (_busy) const LinearProgressIndicator(semanticsLabel: 'Enviando imagem'),
      if (_message != null) Semantics(liveRegion: true, child: Text(_message!)),
    ],
  );
}

Future<Uint8List?> pickFormsGalleryImage() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
    allowMultiple: false,
    withData: true,
  );
  return result?.files.single.bytes;
}

String _requestId() {
  final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
