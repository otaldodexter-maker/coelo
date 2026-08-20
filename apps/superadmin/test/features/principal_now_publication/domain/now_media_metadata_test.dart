import 'dart:typed_data';

import 'package:coelo_superadmin/features/principal_now_publication/domain/now_media_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads duration from an MP4 movie header', () {
    final bytes = Uint8List(40);
    final data = ByteData.sublistView(bytes);
    data.setUint32(0, 40);
    bytes.setRange(4, 8, 'moov'.codeUnits);
    data.setUint32(8, 32);
    bytes.setRange(12, 16, 'mvhd'.codeUnits);
    data.setUint8(16, 0);
    data.setUint32(28, 1000);
    data.setUint32(32, 12500);

    expect(readMp4Duration(bytes), const Duration(milliseconds: 12500));
  });

  test('rejects malformed or missing movie headers', () {
    expect(readMp4Duration(Uint8List(4)), isNull);
    expect(readMp4Duration(Uint8List(24)), isNull);
  });
}
