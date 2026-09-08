import 'package:coelo_superadmin/features/chat/domain/chat_repository.dart';
import 'package:coelo_superadmin/features/chat/presentation/chat_attachment_file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps every accepted extension to its media type', () {
    expect(chatAttachmentMediaType('JPG'), 'image/jpeg');
    expect(chatAttachmentMediaType('jpeg'), 'image/jpeg');
    expect(chatAttachmentMediaType('png'), 'image/png');
    expect(chatAttachmentMediaType('webp'), 'image/webp');
    expect(chatAttachmentMediaType('pdf'), 'application/pdf');
  });

  test('an unknown or missing extension stays neutral and is refused', () {
    for (final extension in <String?>[null, '', 'exe', 'mp4', 'xlsx']) {
      final mediaType = chatAttachmentMediaType(extension);
      expect(mediaType, 'application/octet-stream');
      expect(
        ChatAttachmentPolicy.validate(
          ChatAttachmentDraft(fileName: 'arquivo', mediaType: mediaType, bytes: const [1]),
        ),
        ChatAttachmentIssue.unsupportedMediaType,
        reason: 'a neutral type must be refused instead of guessed',
      );
    }
  });

  test('the picker filter never widens what the policy accepts', () {
    // Every extension offered by the picker must map to a media type the policy allows.
    for (final extension in const ['jpg', 'jpeg', 'png', 'webp', 'pdf']) {
      expect(
        ChatAttachmentPolicy.maximumBytesByMediaType,
        contains(chatAttachmentMediaType(extension)),
      );
    }
  });
}
