import 'package:flutter/widgets.dart';

bool get catalogEmbeddingSupported => false;

String? get catalogHostOrigin => null;

Widget buildCatalogPlatformHost(Uri uri) => const SizedBox.shrink();

void openCatalogExternally(Uri uri) {}
