import 'dart:async';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

/// Shows a stored brand image by asking the media gateway for it.
///
/// Consumes the published read contract and adds no transport of its own: the
/// gateway decides, per request, whether this actor may see this asset, and the
/// ticket it returns is temporary. Uploading is a different contract that does
/// not exist yet, so this widget only reads.
///
/// The ticket is never logged, never persisted and never rebuilt from parts. It
/// is requested again whenever the asset, the reader or the context changes, so
/// a revoked session cannot leave a readable image behind.
class InstitutionBrandImage extends StatefulWidget {
  const InstitutionBrandImage({
    required this.assetId,
    required this.placeholder,
    this.reader,
    this.rendition = MediaReadRendition.preview,
    this.contextRevision = 0,
    this.imageBuilder,
    this.size = 96,
    super.key,
  });

  final String assetId;

  /// Shown while there is nothing legitimate to display.
  final Widget placeholder;

  /// Absent until a composition provides the gateway; then nothing is read.
  final MediaReader? reader;

  final MediaReadRendition rendition;
  final int contextRevision;

  /// Renders the authorized ticket. Injected so a test can assert what the
  /// widget hands to the network without decoding bytes.
  final Widget Function(Uri url, Map<String, String> headers)? imageBuilder;

  final double size;

  @override
  State<InstitutionBrandImage> createState() => _InstitutionBrandImageState();
}

class _InstitutionBrandImageState extends State<InstitutionBrandImage> {
  MediaReadResult? _result;
  bool _failed = false;
  int _epoch = 0;

  /// Provider of the ticket currently on screen, kept only to evict it.
  ///
  /// Flutter caches decoded network images by URL, so without this the bytes of
  /// a revoked or expired capability would survive in memory and keep
  /// rendering. Purging them is part of the read contract, not an optimisation.
  ImageProvider<Object>? _cached;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant InstitutionBrandImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetId != widget.assetId ||
        oldWidget.rendition != widget.rendition ||
        oldWidget.contextRevision != widget.contextRevision ||
        !identical(oldWidget.reader, widget.reader)) {
      unawaited(_load());
    }
  }

  void _purge() {
    final cached = _cached;
    _cached = null;
    if (cached != null) cached.evict().ignore();
  }

  @override
  void dispose() {
    _purge();
    super.dispose();
  }

  Future<void> _load() async {
    final epoch = ++_epoch;
    final reader = widget.reader;
    _purge();
    setState(() {
      _result = null;
      _failed = false;
    });
    if (reader == null) return;
    try {
      final result = await reader.read(
        MediaReadRequest(assetId: widget.assetId, rendition: widget.rendition),
      );
      if (!mounted || epoch != _epoch) return;
      setState(() => _result = result);
    } on Object {
      // An invalidated session, a purge or any other failure shows the
      // placeholder. No server detail reaches the screen.
      if (!mounted || epoch != _epoch) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    if (widget.reader == null || _failed || result == null) {
      return _wrap(widget.placeholder, key: const Key('institution-brand-image-placeholder'));
    }
    return switch (result.state) {
      MediaReadState.available => _available(result),
      MediaReadState.processing => _note(
        'Imagem em processamento.',
        const Key('institution-brand-image-processing'),
      ),
      MediaReadState.expired => _retry(),
      MediaReadState.unavailable => _wrap(
        widget.placeholder,
        key: const Key('institution-brand-image-unavailable'),
      ),
    };
  }

  Widget _available(MediaReadResult result) {
    final ticket = result.ticket;
    if (ticket == null || !ticket.expiresAt.isAfter(DateTime.now().toUtc())) {
      // Available without a usable ticket is not something to render.
      return _retry();
    }
    final builder = widget.imageBuilder;
    if (builder != null) {
      return _wrap(
        builder(ticket.url, ticket.headers),
        key: const Key('institution-brand-image-available'),
      );
    }
    final provider = NetworkImage(ticket.url.toString(), headers: ticket.headers);
    _cached = provider;
    return _wrap(
      Image(
        image: provider,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => widget.placeholder,
      ),
      key: const Key('institution-brand-image-available'),
    );
  }

  Widget _retry() => _wrap(
    Semantics(
      button: true,
      label: 'Recarregar imagem',
      child: IconButton(
        key: const Key('institution-brand-image-retry'),
        onPressed: () => unawaited(_load()),
        icon: const Icon(Icons.refresh_rounded),
      ),
    ),
    key: const Key('institution-brand-image-expired'),
  );

  Widget _note(String message, Key key) => _wrap(
    Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space1),
      child: Text(message, textAlign: TextAlign.center),
    ),
    key: key,
  );

  Widget _wrap(Widget child, {required Key key}) => SizedBox.square(
    key: key,
    dimension: widget.size,
    child: Center(child: child),
  );
}
