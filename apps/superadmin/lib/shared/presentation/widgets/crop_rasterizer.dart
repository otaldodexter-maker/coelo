import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

typedef CoeloCropRasterizer =
    Future<Uint8List?> Function({
      required Uint8List bytes,
      required Size viewportSize,
      required Matrix4 transform,
      required int outputWidth,
      required int outputHeight,
    });

Future<Uint8List?> rasterizeCoeloCrop({
  required Uint8List bytes,
  required Size viewportSize,
  required Matrix4 transform,
  required int outputWidth,
  required int outputHeight,
}) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..scale(outputWidth / viewportSize.width, outputHeight / viewportSize.height)
    ..transform(transform.storage);
  paintImage(
    canvas: canvas,
    rect: Offset.zero & viewportSize,
    image: frame.image,
    fit: BoxFit.cover,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(outputWidth, outputHeight);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  frame.image.dispose();
  codec.dispose();
  return data?.buffer.asUint8List();
}
