import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../principal_circulars/application/circular_composer_controller.dart';
import '../../principal_circulars/domain/circular_repository.dart';
import '../data/development_circular_repository.dart';
import 'superadmin_circular_composer_page.dart';

final class DevelopmentCircularComposerHost extends StatefulWidget {
  const DevelopmentCircularComposerHost({
    required this.repository,
    required this.onCancel,
    required this.onDone,
    this.circularId,
    super.key,
  });

  final DevelopmentCircularRepository repository;
  final String? circularId;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  @override
  State<DevelopmentCircularComposerHost> createState() => _DevelopmentCircularComposerHostState();
}

final class _DevelopmentCircularComposerHostState extends State<DevelopmentCircularComposerHost> {
  CircularComposerController? _controller;
  var _assetSequence = 1;

  @override
  void initState() {
    super.initState();
    final circularId = widget.circularId;
    final draft = circularId == null ? null : widget.repository.draftFor(circularId);
    if (circularId == null || draft != null) {
      _controller = CircularComposerController(
        repository: widget.repository,
        scope: const CircularScope(institutionId: 'development-preview'),
        initialDraft: draft,
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const CoeloStatePanel(
        title: 'Circular não encontrada',
        message: 'A Circular solicitada não existe neste ambiente.',
        icon: Icons.search_off_rounded,
      );
    }
    return SuperadminCircularComposerPage(
      controller: controller,
      onCancel: widget.onCancel,
      onPublished: widget.onDone,
      onPickFiles: () async {
        controller.addMediaAsset('anexo-circular-${_assetSequence++}.pdf');
      },
    );
  }
}
