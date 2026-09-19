import 'dart:convert';
import 'dart:typed_data';

String createMediaObjectUrl(Uint8List bytes, String mimeType) => 'data:$mimeType;base64,${base64.encode(bytes)}';
