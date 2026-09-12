import 'dart:async';
import 'dart:typed_data';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import 'forms_camera_platform.dart';
import 'forms_camera_port.dart';

typedef FormsCameraCapture =
    Future<Uint8List?> Function(BuildContext context, MediaSession session);

Future<Uint8List?> showFormsCameraCapture(BuildContext context, MediaSession session) =>
    showDialog<Uint8List>(
      context: context,
      builder: (_) => FormsCameraCaptureDialog(session: session),
    );

final class FormsCameraCaptureDialog extends StatefulWidget {
  const FormsCameraCaptureDialog({
    required this.session,
    this.createCamera = createFormsCamera,
    super.key,
  });

  final MediaSession session;
  final FormsCameraFactory createCamera;

  @override
  State<FormsCameraCaptureDialog> createState() => _FormsCameraCaptureDialogState();
}

final class _FormsCameraCaptureDialogState extends State<FormsCameraCaptureDialog>
    with WidgetsBindingObserver {
  FormsCameraPort? _camera;
  void Function()? _unregister;
  int _generation = 0;
  bool _ready = false;
  bool _capturing = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bind();
  }

  @override
  void didUpdateWidget(covariant FormsCameraCaptureDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.session, widget.session) ||
        !identical(oldWidget.createCamera, widget.createCamera)) {
      _bind();
    }
  }

  void _bind() {
    _unregister?.call();
    _unregister = null;
    _stop();
    _ready = false;
    _capturing = false;
    if (widget.session.isInvalidated) {
      _message = 'A sessão terminou. Abra novamente o formulário.';
    } else {
      _unregister = widget.session.registerPurge(() async {
        _stop();
        if (mounted) {
          setState(() {
            _ready = false;
            _capturing = false;
            _message = 'A sessão terminou. Abra novamente o formulário.';
          });
        }
      });
      unawaited(_start());
    }
  }

  void _stop() {
    _generation++;
    _camera?.close();
    _camera = null;
  }

  bool _current(int generation) =>
      mounted && generation == _generation && !widget.session.isInvalidated;

  Future<void> _start() async {
    _stop();
    if (widget.session.isInvalidated) return;
    final generation = _generation;
    setState(() {
      _ready = false;
      _capturing = false;
      _message = null;
    });
    FormsCameraPort? camera;
    try {
      camera = widget.createCamera();
      _camera = camera;
      await camera.start();
      if (!_current(generation)) {
        camera.close();
        return;
      }
      setState(() => _ready = true);
    } on Object {
      camera?.close();
      if (_current(generation)) {
        setState(() {
          _camera = null;
          _message = const FormsCameraException().message;
        });
      }
    }
  }

  Future<void> _capture() async {
    final camera = _camera;
    if (!_ready || _capturing || camera == null || widget.session.isInvalidated) return;
    final generation = _generation;
    setState(() => _capturing = true);
    try {
      final bytes = await camera.capture();
      if (!_current(generation)) {
        bytes.fillRange(0, bytes.length, 0);
        return;
      }
      _stop();
      if (mounted) Navigator.of(context).pop(bytes);
    } on Object {
      if (!_current(generation)) return;
      _stop();
      if (mounted) {
        setState(() {
          _ready = false;
          _capturing = false;
          _message = 'Não foi possível capturar a foto. Tente novamente.';
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _stop();
      if (mounted) {
        setState(() {
          _ready = false;
          _capturing = false;
          _message = 'A câmera foi encerrada. Toque em tentar novamente para reabrir.';
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unregister?.call();
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope<Uint8List>(
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) _stop();
    },
    child: AlertDialog(
      scrollable: true,
      title: const Text('Capturar foto'),
      content: SizedBox(
        width: CoeloBreakpoints.compact.maxWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Confira a imagem e toque em Usar foto para anexá-la à resposta.'),
            const SizedBox(height: CoeloSpacing.space3),
            if (_ready && _camera != null)
              AspectRatio(aspectRatio: 4 / 3, child: _camera!.preview())
            else if (_message == null)
              const LinearProgressIndicator(semanticsLabel: 'Abrindo câmera'),
            if (_message != null) Semantics(liveRegion: true, child: Text(_message!)),
            if (_message != null && !widget.session.isInvalidated)
              TextButton(onPressed: _start, child: const Text('Tentar novamente')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _ready && !_capturing && !widget.session.isInvalidated ? _capture : null,
          child: Text(_capturing ? 'Capturando…' : 'Usar foto'),
        ),
      ],
    ),
  );
}
