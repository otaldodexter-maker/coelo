import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../application/moments_publication_controller.dart';
import '../domain/moments_publication.dart';
import 'principal_moments_publication_page.dart';

/// Owns the production controller lifecycle for the real Momentos publisher.
final class PrincipalMomentsPublicationRoute extends StatefulWidget {
  const PrincipalMomentsPublicationRoute({
    required this.repository,
    required this.publicationContext,
    this.onClose,
    this.onPublished,
    this.mediaPicker,
    super.key,
  });

  final MomentsPublicationRepository repository;
  final MomentsPublicationContext publicationContext;
  final VoidCallback? onClose;
  final ValueChanged<MomentsPublication>? onPublished;

  /// Media selection port. Defaults to the local file selection used by the
  /// other Principal publishers; tests inject a deterministic one.
  final MomentsMediaPicker? mediaPicker;

  @override
  State<PrincipalMomentsPublicationRoute> createState() => _PrincipalMomentsPublicationRouteState();
}

final class _PrincipalMomentsPublicationRouteState extends State<PrincipalMomentsPublicationRoute> {
  late MomentsPublicationController _controller;

  @override
  void initState() {
    super.initState();
    _createController();
  }

  @override
  void didUpdateWidget(covariant PrincipalMomentsPublicationRoute oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.repository, widget.repository) &&
        oldWidget.publicationContext == widget.publicationContext) {
      return;
    }
    _controller.dispose();
    _createController();
  }

  void _createController() {
    _controller = MomentsPublicationController(
      repository: widget.repository,
      context: widget.publicationContext,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PrincipalMomentsPublicationPage(
    controller: _controller,
    embedded: false,
    mediaPicker: widget.mediaPicker ?? pickMomentsMediaFiles,
    onClose: widget.onClose,
    onPublished: widget.onPublished,
  );
}

/// Local file selection for the productive Momentos publisher.
///
/// It only reads bytes the person chose. Bucket, key, provider, tenant and
/// authorization stay server-side: the media reaches R2 through the
/// `moments-media` server path when the publication is accepted.
Future<List<MomentsMediaCandidate>> pickMomentsMediaFiles() async {
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: true,
    withData: true,
    type: FileType.custom,
    allowedExtensions: MomentsMediaLimits.acceptedExtensions,
  );
  return (result?.files ?? const <PlatformFile>[])
      .where((file) => file.bytes != null)
      .map(
        (file) => MomentsMediaCandidate(
          name: file.name,
          mimeType: _mimeType(file.extension),
          bytes: file.bytes!,
        ),
      )
      .toList(growable: false);
}

String _mimeType(String? extension) => switch (extension?.toLowerCase()) {
  'jpg' || 'jpeg' => 'image/jpeg',
  'png' => 'image/png',
  'webp' => 'image/webp',
  _ => 'application/octet-stream',
};
