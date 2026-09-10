import 'package:coelo_domain/locations.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../domain/location_catalog_reader.dart';
import '../domain/location_consumer_bindings_reader.dart';
import '../domain/location_consumer_selection_reader.dart';
import '../domain/location_reservation_gateway.dart';
import '../domain/location_selection_source.dart';
import 'location_reservation_panel.dart';
import 'location_consumer_bindings_section.dart';
import 'location_consumer_selection_section.dart';
import 'location_selection_field.dart';

/// Reservation context for an already authorized, persisted consumer.
/// Choosing a location here does not change the consumer's form or selection.
/// The server reauthorizes the consumer/location pair for every operation.
class LocationConsumerReservations extends StatefulWidget {
  const LocationConsumerReservations({
    required this.consumer,
    required this.scopes,
    required this.sessionAvailable,
    required this.contextRevision,
    this.reader = const UnavailableLocationCatalogReader(),
    this.bindingsReader = const UnavailableLocationConsumerBindingsReader(),
    this.gateway = const UnavailableLocationReservationGateway(),
    this.canRead = false,
    this.selectionReader,
    this.canReadSelection = false,
    this.canManage = false,
    this.canOverride = false,
    super.key,
  });

  final LocationReservationConsumer consumer;
  final List<({LocationScope scope, String label})> scopes;
  final LocationCatalogReader reader;
  final LocationConsumerBindingsReader bindingsReader;
  final LocationReservationGateway gateway;
  final bool sessionAvailable;
  final int contextRevision;
  final bool canRead;
  final LocationConsumerSelectionReader? selectionReader;
  final bool canReadSelection;
  final bool canManage;
  final bool canOverride;

  @override
  State<LocationConsumerReservations> createState() => _LocationConsumerReservationsState();
}

class _LocationConsumerReservationsState extends State<LocationConsumerReservations> {
  late LocationSelectionSource _source;
  String? _owner;
  LocationReferenceSnapshot? _location;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _source = CatalogLocationSelectionSource(widget.reader);
  }

  @override
  void didUpdateWidget(covariant LocationConsumerReservations oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.consumer != widget.consumer ||
        oldWidget.contextRevision != widget.contextRevision ||
        oldWidget.sessionAvailable != widget.sessionAvailable ||
        oldWidget.canRead != widget.canRead ||
        !identical(oldWidget.reader, widget.reader) ||
        !identical(oldWidget.bindingsReader, widget.bindingsReader) ||
        !identical(oldWidget.gateway, widget.gateway) ||
        _scopeKeys(oldWidget) != _scopeKeys(widget)) {
      _owner = null;
      _location = null;
      ++_generation;
      _source = CatalogLocationSelectionSource(widget.reader);
    }
  }

  static String _scopeKeys(LocationConsumerReservations widget) =>
      widget.scopes.map((option) => _ownerKey(option.scope)).join('|');

  bool get _allowed =>
      widget.sessionAvailable &&
      widget.canRead &&
      validLocationId(widget.consumer.id) &&
      const {
        LocationReservationConsumerKind.activity,
        LocationReservationConsumerKind.group,
      }.contains(widget.consumer.kind) &&
      widget.scopes.isNotEmpty &&
      widget.scopes.every((option) => validLocationScope(option.scope)) &&
      widget.scopes.map((option) => _ownerKey(option.scope)).toSet().length == widget.scopes.length;

  @override
  Widget build(BuildContext context) {
    final selectionReader = widget.selectionReader;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (selectionReader != null) ...[
          LocationConsumerSelectionSection(
            key: const Key('consumer-current-selection'),
            consumer: widget.consumer,
            scopes: widget.scopes.map((option) => option.scope).toList(),
            reader: selectionReader,
            sessionAvailable: widget.sessionAvailable,
            canRead: widget.canReadSelection,
            contextRevision: widget.contextRevision,
          ),
          const SizedBox(height: CoeloSpacing.space5),
        ],
        _buildReservations(context),
      ],
    );
  }

  Widget _buildReservations(BuildContext context) {
    if (!_allowed) {
      return const CoeloStatePanel(
        key: Key('consumer-reservations-denied'),
        title: 'Reservas indisponíveis',
        message: 'É necessário acesso ao registro e aos seus locais para consultar reservas.',
        icon: Icons.lock_outline,
      );
    }
    final owner = _owner ?? _ownerKey(widget.scopes.first.scope);
    final scope = widget.scopes.firstWhere((option) => _ownerKey(option.scope) == owner).scope;
    final generation = _generation;
    final location = _location;
    return Column(
      key: const Key('consumer-reservations'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            widget.consumer.kind == LocationReservationConsumerKind.group
                ? 'Reservas desta turma'
                : 'Reservas desta atividade',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: CoeloSpacing.space2),
        const Text('Escolha um local do catálogo para consultar seus horários e reservas.'),
        const SizedBox(height: CoeloSpacing.space4),
        if (widget.scopes.length > 1) ...[
          CoeloAdminSingleSelectField<String>(
            key: const Key('reservation-catalog-owner'),
            label: 'Catálogo',
            value: owner,
            options: widget.scopes.map((option) => _ownerKey(option.scope)).toList(),
            optionLabel: (value) =>
                widget.scopes.firstWhere((option) => _ownerKey(option.scope) == value).label,
            onChanged: (value) {
              if (!mounted ||
                  generation != _generation ||
                  !_allowed ||
                  value == owner ||
                  !widget.scopes.any((option) => _ownerKey(option.scope) == value)) {
                return;
              }
              setState(() {
                _owner = value;
                _location = null;
                ++_generation;
              });
            },
          ),
          const SizedBox(height: CoeloSpacing.space4),
        ],
        LocationSelectionField(
          key: ValueKey('consumer-location-$generation-$owner'),
          scope: scope,
          source: _source,
          catalogOnly: true,
          sessionAvailable: widget.sessionAvailable,
          contextRevision: widget.contextRevision,
          onChanged: (selection) {
            if (!mounted || generation != _generation || !_allowed) return;
            final snapshot = selection is CataloguedLocationSelection ? selection.snapshot : null;
            setState(
              () => _location = snapshot != null && sameLocationScope(snapshot.scope, scope)
                  ? snapshot
                  : null,
            );
          },
        ),
        const SizedBox(height: CoeloSpacing.space5),
        LocationConsumerBindingsSection(
          key: const Key('consumer-bindings-section'),
          consumer: widget.consumer,
          scopes: widget.scopes.map((option) => option.scope).toList(),
          reader: widget.bindingsReader,
          sessionAvailable: widget.sessionAvailable,
          canRead: widget.canRead,
          contextRevision: widget.contextRevision,
          onSelected: (binding) {
            if (!mounted ||
                generation != _generation ||
                !_allowed ||
                !widget.scopes.any(
                  (option) => sameLocationScope(option.scope, binding.location.scope),
                )) {
              return;
            }
            setState(() {
              _owner = _ownerKey(binding.location.scope);
              _location = binding.location;
              ++_generation;
            });
          },
        ),
        if (location != null) ...[
          const SizedBox(height: CoeloSpacing.space5),
          Semantics(
            header: true,
            child: Text(
              'Reservas em ${location.label}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: CoeloSpacing.space3),
          LocationReservationPanel(
            key: ValueKey('consumer-reservation-$generation-${location.id}'),
            locationId: location.id,
            scope: location.scope,
            consumer: widget.consumer,
            gateway: widget.gateway,
            sessionAvailable: widget.sessionAvailable,
            contextRevision: widget.contextRevision,
            canRead: widget.canRead,
            canManage: widget.canManage,
            canOverride: widget.canOverride,
          ),
        ],
      ],
    );
  }
}

String _ownerKey(LocationScope scope) => switch (scope) {
  InstitutionLocationScope(:final institutionId) => 'institution:$institutionId',
  UnitLocationScope(:final institutionId, :final unitId) => 'unit:$institutionId:$unitId',
};
