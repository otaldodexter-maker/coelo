import 'dart:async';

import 'package:coelo_domain/locations.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../domain/location_catalog_reader.dart';
import 'location_directory_controller.dart';
import 'location_read_widgets.dart';

/// The "Mapa e locais" section of an institution or unit registration.
///
/// The approved design puts this section in the form from the first save
/// onwards, and everything in it is optional. Before the owner exists there is
/// no catalog to read, so the section explains that instead of showing an empty
/// list that would read as "no locations".
///
/// The general map image, markers and per-location photos are not part of this
/// slice. The section says so rather than showing controls that cannot work.
class LocationsMapSection extends StatefulWidget {
  const LocationsMapSection({
    required this.ownerKind,
    this.scope,
    this.reader = const UnavailableLocationCatalogReader(),
    this.sessionAvailable = false,
    this.contextRevision = 0,
    this.onOpenCatalog,
    super.key,
  });

  final LocationOwnerKind ownerKind;

  /// Null while the owner is still being created and has no catalog yet.
  final LocationScope? scope;

  final LocationCatalogReader reader;
  final bool sessionAvailable;
  final int contextRevision;

  /// Opens the full catalog; absent when no route is composed for the caller.
  final VoidCallback? onOpenCatalog;

  @override
  State<LocationsMapSection> createState() => _LocationsMapSectionState();
}

enum LocationOwnerKind { institution, unit }

class _LocationsMapSectionState extends State<LocationsMapSection> {
  LocationDirectoryController? _controller;

  @override
  void initState() {
    super.initState();
    _syncController();
  }

  @override
  void didUpdateWidget(covariant LocationsMapSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final scope = widget.scope;
    final oldScope = oldWidget.scope;
    final changed =
        (scope == null) != (oldScope == null) ||
        scope != null && oldScope != null && !sameLocationScope(scope, oldScope) ||
        oldWidget.sessionAvailable != widget.sessionAvailable ||
        oldWidget.contextRevision != widget.contextRevision ||
        !identical(oldWidget.reader, widget.reader);
    if (changed) _syncController();
  }

  void _syncController() {
    final scope = widget.scope;
    _controller?.dispose();
    if (scope == null) {
      _controller = null;
      return;
    }
    final controller = LocationDirectoryController(
      scope: scope,
      reader: widget.reader,
      sessionAvailable: widget.sessionAvailable,
      contextRevision: widget.contextRevision,
    );
    _controller = controller;
    unawaited(controller.load());
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  String get _ownerWord =>
      widget.ownerKind == LocationOwnerKind.unit ? 'da unidade' : 'da instituição';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = _controller;
    return Column(
      key: const Key('locations-map-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text('Mapa e locais', style: theme.textTheme.titleLarge)),
        const SizedBox(height: CoeloSpacing.space2),
        Text(
          'O catálogo de locais $_ownerWord é opcional e pode ser preenchido '
          'a qualquer momento.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: CoeloSpacing.space4),
        if (controller == null)
          Text(
            widget.ownerKind == LocationOwnerKind.unit
                ? 'O catálogo de locais fica disponível depois que a unidade for '
                      'criada. Ele é independente do catálogo da instituição.'
                : 'O catálogo de locais fica disponível depois que a instituição '
                      'for criada.',
            key: const Key('locations-map-section-before-owner'),
            style: theme.textTheme.bodyMedium,
          )
        else
          AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final data = controller.data;
              if (controller.state != LocationReadState.ready || data == null) {
                return LocationReadStatePanel(
                  state: controller.state,
                  prefix: 'locations-map-section',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.totalCount == 1
                        ? '1 local cadastrado'
                        : '${data.totalCount} locais cadastrados',
                    key: const Key('locations-map-section-count'),
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: CoeloSpacing.space2),
                  for (final item in data.items.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: CoeloSpacing.space1),
                      child: Text(
                        '${item.name} · ${locationKindLabel(item.kind)}',
                        key: Key('locations-map-section-item-${item.id}'),
                      ),
                    ),
                ],
              );
            },
          ),
        const SizedBox(height: CoeloSpacing.space4),
        Text(
          'Planta, marcadores e fotos ainda não estão disponíveis.',
          key: const Key('locations-map-section-media-limit'),
          style: theme.textTheme.bodySmall,
        ),
        if (widget.onOpenCatalog != null && controller != null && widget.sessionAvailable) ...[
          const SizedBox(height: CoeloSpacing.space4),
          OutlinedButton.icon(
            key: const Key('locations-map-section-open'),
            onPressed: widget.onOpenCatalog,
            icon: const Icon(Icons.place_outlined),
            label: const Text('Abrir mapa e locais'),
          ),
        ],
      ],
    );
  }
}
