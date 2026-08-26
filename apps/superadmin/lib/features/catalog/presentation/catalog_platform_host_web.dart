// This implementation is conditionally exported only for Flutter web.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

bool get catalogEmbeddingSupported => true;

String get catalogHostOrigin => html.window.location.origin;

Widget buildCatalogPlatformHost(Uri uri) => _CatalogWebHost(uri: uri);

void openCatalogExternally(Uri uri) {
  html.window.open(uri.toString(), '_blank', 'noopener,noreferrer');
}

final class _CatalogWebHost extends StatefulWidget {
  const _CatalogWebHost({required this.uri});

  final Uri uri;

  @override
  State<_CatalogWebHost> createState() => _CatalogWebHostState();
}

final class _CatalogWebHostState extends State<_CatalogWebHost> {
  static var _nextViewId = 0;

  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'coelo-catalog-${_nextViewId++}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) {
      final frame = html.IFrameElement()
        ..src = widget.uri.toString()
        ..title = 'Catálogo Coelo'
        ..referrerPolicy = 'no-referrer'
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%';
      for (final permission in const ['allow-same-origin', 'allow-scripts']) {
        frame.sandbox?.add(permission);
      }
      return frame;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Catálogo Coelo incorporado',
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
