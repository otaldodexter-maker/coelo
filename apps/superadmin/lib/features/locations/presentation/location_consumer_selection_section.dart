import 'dart:async';

import 'package:coelo_domain/locations.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../domain/location_catalog_reader.dart';
import '../domain/location_consumer_selection_reader.dart';

/// The persisted choice is displayed independently of reservation history.
class LocationConsumerSelectionSection extends StatefulWidget {
  const LocationConsumerSelectionSection({
    required this.consumer,
    required this.scopes,
    required this.sessionAvailable,
    required this.contextRevision,
    this.reader = const UnavailableLocationConsumerSelectionReader(),
    this.canRead = false,
    super.key,
  });
  final LocationReservationConsumer consumer;
  final List<LocationScope> scopes;
  final LocationConsumerSelectionReader reader;
  final bool sessionAvailable;
  final bool canRead;
  final int contextRevision;
  @override
  State<LocationConsumerSelectionSection> createState() => _LocationConsumerSelectionSectionState();
}

class _LocationConsumerSelectionSectionState extends State<LocationConsumerSelectionSection> {
  LocationReadState _state = LocationReadState.loading;
  LocationConsumerCurrentSelection? _selection;
  int _generation = 0;
  bool get _authorized =>
      widget.sessionAvailable &&
      widget.canRead &&
      validLocationId(widget.consumer.id) &&
      const {
        LocationReservationConsumerKind.group,
        LocationReservationConsumerKind.activity,
      }.contains(widget.consumer.kind) &&
      widget.scopes.isNotEmpty &&
      widget.scopes.every(
        (scope) =>
            validLocationScope(scope) && scope.institutionId == widget.scopes.first.institutionId,
      );
  bool get _allowed => _authorized && widget.reader.available;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant LocationConsumerSelectionSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.consumer != widget.consumer ||
        oldWidget.contextRevision != widget.contextRevision ||
        oldWidget.sessionAvailable != widget.sessionAvailable ||
        oldWidget.canRead != widget.canRead ||
        !identical(oldWidget.reader, widget.reader) ||
        oldWidget.scopes.length != widget.scopes.length ||
        !oldWidget.scopes.every(
          (old) => widget.scopes.any((scope) => sameLocationScope(old, scope)),
        )) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _selection = null;
      _state = !_authorized
          ? LocationReadState.denied
          : !widget.reader.available
          ? LocationReadState.unavailable
          : LocationReadState.loading;
    });
    if (!_allowed) return;
    try {
      final selection = await widget.reader.fetchSelection(consumer: widget.consumer);
      if (!mounted || generation != _generation || !_allowed) return;
      final location = selection.location;
      if (selection.consumer != widget.consumer ||
          (location == null) != (selection.status == null) ||
          location != null &&
              (!validLocationId(location.id) ||
                  location.label.trim().isEmpty ||
                  !widget.scopes.any((scope) => sameLocationScope(scope, location.scope)))) {
        throw const FormatException('Invalid current selection');
      }
      setState(() {
        _selection = selection;
        _state = location == null ? LocationReadState.empty : LocationReadState.ready;
      });
    } on Object catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _selection = null;
        _state = error is LocationCatalogAccessDeniedException
            ? LocationReadState.denied
            : LocationReadState.unavailable;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selection = _selection;
    final location = selection?.location;
    final generation = _generation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text('Local selecionado', style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: CoeloSpacing.space2),
        const Text(
          'Esta \u00e9 a escolha gravada no registro. A escolha de um local n\u00e3o reserva um hor\u00e1rio.',
        ),
        const SizedBox(height: CoeloSpacing.space3),
        if (_state == LocationReadState.ready && location != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(CoeloSpacing.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(location.label, style: Theme.of(context).textTheme.titleSmall),
                  Text(location.kind == LocationKind.internal ? 'Local interno' : 'Local externo'),
                  Text(_statusLabel(selection!.status!)),
                ],
              ),
            ),
          )
        else
          CoeloStatePanel(
            key: Key('consumer-selection-${_state.name}'),
            loading: _state == LocationReadState.loading,
            title: switch (_state) {
              LocationReadState.loading => 'Carregando local selecionado',
              LocationReadState.empty => 'Nenhum local selecionado',
              LocationReadState.denied => 'Consulta n\u00e3o autorizada',
              _ => 'Local selecionado indispon\u00edvel',
            },
            message: _state == LocationReadState.empty
                ? 'Este registro n\u00e3o tem uma escolha de local gravada.'
                : _state == LocationReadState.loading
                ? 'Aguarde a consulta do registro.'
                : 'N\u00e3o foi poss\u00edvel consultar o local deste registro.',
          ),
        if (_allowed)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('consumer-selection-reload'),
              onPressed: _state == LocationReadState.loading
                  ? null
                  : () {
                      if (!mounted || generation != _generation || !_allowed) return;
                      unawaited(_load());
                    },
              child: const Text('Recarregar local selecionado'),
            ),
          ),
      ],
    );
  }
}

String _statusLabel(LocationCatalogStatus status) => switch (status) {
  LocationCatalogStatus.active => 'Ativo',
  LocationCatalogStatus.inactive => 'Inativo',
  LocationCatalogStatus.archived => 'Arquivado',
  LocationCatalogStatus.draft => 'Rascunho',
  LocationCatalogStatus.suspended => 'Suspenso',
};
