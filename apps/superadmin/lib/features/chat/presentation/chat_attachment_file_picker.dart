import 'package:file_picker/file_picker.dart';

import '../domain/chat_repository.dart';

/// Platform picker for chat attachments.
///
/// It only reads the file and names its media type; nothing here authorises an
/// upload. The extension filter is a convenience — [ChatAttachmentPolicy] and
/// then the server are what actually decide, because an extension is not proof
/// of content.
Future<ChatAttachmentDraft?> pickChatAttachment() async {
  final result = await FilePicker.platform.pickFiles(
    withData: true,
    type: FileType.custom,
    allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
  );
  final file = result?.files.singleOrNull;
  final bytes = file?.bytes;
  if (file == null || bytes == null) return null;
  return ChatAttachmentDraft(
    fileName: file.name,
    mediaType: chatAttachmentMediaType(file.extension),
    bytes: bytes,
  );
}

/// Maps the selected extension to the media type the policy understands.
/// An unknown extension keeps a neutral type so the refusal is explicit instead
/// of the file being silently treated as something it is not.
String chatAttachmentMediaType(String? extension) => switch (extension?.toLowerCase()) {
  'jpg' || 'jpeg' => 'image/jpeg',
  'png' => 'image/png',
  'webp' => 'image/webp',
  'pdf' => 'application/pdf',
  _ => 'application/octet-stream',
};
