import 'dart:typed_data';

/// Reads the duration declared by the ISO BMFF movie header without decoding
/// the video. Returns null for malformed or unsupported containers.
Duration? readMp4Duration(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final movieHeader = _findAtom(data, 0, data.lengthInBytes, 'mvhd');
  if (movieHeader == null || movieHeader.payloadLength < 20) return null;

  final version = data.getUint8(movieHeader.payloadOffset);
  final timescaleOffset = movieHeader.payloadOffset + (version == 1 ? 20 : 12);
  final durationOffset = timescaleOffset + 4;
  if (durationOffset + (version == 1 ? 8 : 4) > movieHeader.end) return null;

  final timescale = data.getUint32(timescaleOffset);
  if (timescale == 0) return null;
  final duration = version == 1 ? data.getUint64(durationOffset) : data.getUint32(durationOffset);
  if (duration == 0) return null;
  return Duration(microseconds: (duration * Duration.microsecondsPerSecond) ~/ timescale);
}

_Atom? _findAtom(ByteData data, int start, int end, String target) {
  var offset = start;
  while (offset + 8 <= end) {
    final size32 = data.getUint32(offset);
    final type = String.fromCharCodes([
      data.getUint8(offset + 4),
      data.getUint8(offset + 5),
      data.getUint8(offset + 6),
      data.getUint8(offset + 7),
    ]);
    var headerSize = 8;
    var size = size32;
    if (size32 == 1) {
      if (offset + 16 > end) return null;
      final extended = data.getUint64(offset + 8);
      if (extended > 0x7fffffff) return null;
      size = extended.toInt();
      headerSize = 16;
    } else if (size32 == 0) {
      size = end - offset;
    }
    if (size < headerSize || offset + size > end) return null;
    final atom = _Atom(offset + headerSize, offset + size);
    if (type == target) return atom;
    if (type == 'moov') {
      final nested = _findAtom(data, atom.payloadOffset, atom.end, target);
      if (nested != null) return nested;
    }
    offset += size;
  }
  return null;
}

final class _Atom {
  const _Atom(this.payloadOffset, this.end);
  final int payloadOffset;
  final int end;
  int get payloadLength => end - payloadOffset;
}
