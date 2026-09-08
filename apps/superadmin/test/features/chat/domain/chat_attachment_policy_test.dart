import 'dart:typed_data';

import 'package:coelo_superadmin/features/chat/domain/chat_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// The client-side envelope for `chat.attach`.
///
/// It is a courtesy that explains a refusal before a pointless round trip; the
/// server revalidates all of it. That is exactly why every branch needs a test:
/// a courtesy nobody exercises quietly stops being one, and the operator gets a
/// generic failure from the gateway instead of a reason.
void main() {
  ChatAttachmentDraft draft({
    String fileName = 'documento.pdf',
    String mediaType = 'application/pdf',
    int bytes = 1024,
  }) => ChatAttachmentDraft(fileName: fileName, mediaType: mediaType, bytes: Uint8List(bytes));

  test('an accepted attachment has no issue', () {
    expect(ChatAttachmentPolicy.validate(draft()), isNull);
  });

  test('an empty file is refused before anything is uploaded', () {
    // Zero bytes is not a small file: there is nothing to store, and the
    // gateway would have to measure an object that does not exist.
    expect(ChatAttachmentPolicy.validate(draft(bytes: 0)), ChatAttachmentIssue.emptyFile);
  });

  test('a blank file name is refused', () {
    expect(ChatAttachmentPolicy.validate(draft(fileName: '   ')), ChatAttachmentIssue.nameTooLong);
  });

  test('a file name past the limit is refused at the boundary', () {
    final atLimit = 'a' * ChatAttachmentPolicy.maximumNameLength;
    expect(ChatAttachmentPolicy.validate(draft(fileName: atLimit)), isNull);
    expect(
      ChatAttachmentPolicy.validate(draft(fileName: '$atLimit!')),
      ChatAttachmentIssue.nameTooLong,
      reason: 'one character past the cap must already refuse',
    );
  });

  for (final type in ChatAttachmentPolicy.maximumBytesByMediaType.keys) {
    test('$type is accepted at its own limit and refused one byte past it', () {
      final limit = ChatAttachmentPolicy.maximumBytesByMediaType[type]!;
      expect(ChatAttachmentPolicy.validate(draft(mediaType: type, bytes: limit)), isNull);
      expect(
        ChatAttachmentPolicy.validate(draft(mediaType: type, bytes: limit + 1)),
        ChatAttachmentIssue.tooLarge,
      );
    });
  }

  for (final type in ['video/mp4', 'image/gif', 'text/plain', 'application/zip', '']) {
    test('${type.isEmpty ? '<empty>' : type} stays outside the Chat allowlist', () {
      // Video in particular: ADR 0032 does not require Stream for Chat in the
      // MVP, so accepting it here would promise a pipeline that does not exist.
      expect(
        ChatAttachmentPolicy.validate(draft(mediaType: type)),
        ChatAttachmentIssue.unsupportedMediaType,
      );
    });
  }

  test('an unsupported type is named before its size', () {
    // Order matters for the message the operator reads: an oversized GIF is
    // refused for being a GIF, not for its size.
    expect(
      ChatAttachmentPolicy.validate(draft(mediaType: 'image/gif', bytes: 50 * 1024 * 1024)),
      ChatAttachmentIssue.unsupportedMediaType,
    );
  });

  test('one attachment per message stays the conservative default', () {
    expect(ChatAttachmentPolicy.maximumPerMessage, 1);
  });
}
