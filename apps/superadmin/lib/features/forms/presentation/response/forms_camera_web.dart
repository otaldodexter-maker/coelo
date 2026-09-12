// Conditional web implementation using the SDK already used by this app.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'forms_camera_port.dart';

FormsCameraPort createFormsCamera() => _WebFormsCamera();

final class _WebFormsCamera implements FormsCameraPort {
  final _video = html.VideoElement()
    ..autoplay = true
    ..muted = true
    ..setAttribute('playsinline', '')
    ..style.width = '100%'
    ..style.height = '100%'
    ..style.objectFit = 'contain';
  html.MediaStream? _stream;
  bool _closed = false;

  @override
  Future<void> start() async {
    try {
      final devices = html.window.navigator.mediaDevices;
      if (devices == null || _closed) throw const FormsCameraException();
      final stream = await devices.getUserMedia({
        'audio': false,
        'video': {
          'facingMode': {'ideal': 'environment'},
          'width': {'ideal': 1920},
          'height': {'ideal': 1080},
        },
      });
      if (_closed) {
        for (final track in stream.getTracks()) {
          track.stop();
        }
        throw const FormsCameraException();
      }
      _stream = stream;
      final ready = _video.onLoadedMetadata.first.timeout(const Duration(seconds: 15));
      _video.srcObject = stream;
      await ready;
      if (_closed) throw const FormsCameraException();
      await _video.play();
      if (_closed || _video.videoWidth <= 0 || _video.videoHeight <= 0) {
        throw const FormsCameraException();
      }
    } on Object {
      close();
      throw const FormsCameraException();
    }
  }

  @override
  Widget preview() => HtmlElementView.fromTagName(
    tagName: 'div',
    onElementCreated: (element) {
      final host = element as html.Element;
      host.style
        ..width = '100%'
        ..height = '100%';
      if (!_closed) host.append(_video);
    },
  );

  @override
  Future<Uint8List> capture() async {
    if (_closed || _stream == null || _video.videoWidth <= 0 || _video.videoHeight <= 0) {
      throw const FormsCameraException();
    }
    final scale = math.min(1.0, 2560 / math.max(_video.videoWidth, _video.videoHeight));
    final canvas = html.CanvasElement(
      width: (_video.videoWidth * scale).round(),
      height: (_video.videoHeight * scale).round(),
    );
    try {
      canvas.context2D.drawImageScaled(_video, 0, 0, canvas.width!, canvas.height!);
      final encoded = canvas.toDataUrl('image/jpeg', 0.9);
      return base64Decode(encoded.substring(encoded.indexOf(',') + 1));
    } on Object {
      throw const FormsCameraException();
    } finally {
      canvas.width = 0;
      canvas.height = 0;
    }
  }

  @override
  void close() {
    _closed = true;
    for (final track in _stream?.getTracks() ?? <html.MediaStreamTrack>[]) {
      track.stop();
    }
    _stream = null;
    _video.pause();
    _video.srcObject = null;
    _video.remove();
  }
}
