import 'package:flutter/widgets.dart';

typedef CatalogFoundationBuilder = Widget Function(BuildContext context);

final class CatalogFoundation {
  const CatalogFoundation({
    required this.id,
    required this.builder,
    this.referencedComponentIds = const [],
  });

  final String id;
  final CatalogFoundationBuilder builder;
  final List<String> referencedComponentIds;
}
