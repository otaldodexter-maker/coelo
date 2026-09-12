import 'dart:typed_data';

import 'package:flutter/widgets.dart';

abstract interface class FormsCameraPort {
  Future<void> start();
  Widget preview();
  Future<Uint8List> capture();
  void close();
}

typedef FormsCameraFactory = FormsCameraPort Function();

final class FormsCameraException implements Exception {
  const FormsCameraException();

  String get message =>
      'Não foi possível acessar a câmera. Confira a permissão e a câmera do dispositivo e tente novamente.';

  @override
  String toString() => message;
}
