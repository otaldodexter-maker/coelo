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
    super.key,
  });

  final MomentsPublicationRepository repository;
  final MomentsPublicationContext publicationContext;
  final VoidCallback? onClose;
  final ValueChanged<MomentsPublication>? onPublished;

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
    onClose: widget.onClose,
    onPublished: widget.onPublished,
  );
}
