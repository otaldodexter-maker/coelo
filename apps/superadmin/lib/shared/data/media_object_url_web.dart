// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:typed_data';

/// `blob:` da própria origem: o `<img>`/`<video>` lê da memória do navegador,
/// sem URL assinada nem CORS.
String createMediaObjectUrl(Uint8List bytes, String mimeType) =>
    html.Url.createObjectUrlFromBlob(html.Blob([bytes], mimeType));
