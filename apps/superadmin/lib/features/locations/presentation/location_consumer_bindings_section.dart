import 'dart:async';

import 'package:coelo_domain/locations.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../domain/location_catalog_reader.dart';
import '../domain/location_consumer_bindings_reader.dart';

/// Historical references are explicitly opened, never adopted as a form value.
class LocationConsumerBindingsSection extends StatefulWidget {
  const LocationConsumerBindingsSection({
    required this.consumer,
    required this.scopes,
    required this.sessionAvailable,
    required this.contextRevision,
    required this.onSelected,
    this.reader = const UnavailableLocationConsumerBindingsReader(),
    this.canRead = false,
    super.key,
  });
  final LocationReservationConsumer consumer;
  final List<LocationScope> scopes;
  final LocationConsumerBindingsReader reader;
  final bool sessionAvailable;
  final bool canRead;
  final int contextRevision;
  final ValueChanged<LocationConsumerBinding> onSelected;
  @override
  State<LocationConsumerBindingsSection> createState() => _LocationConsumerBindingsSectionState();
}

class _LocationConsumerBindingsSectionState extends State<LocationConsumerBindingsSection> {
  LocationReadState _state = LocationReadState.loading;
  LocationConsumerBindingPage? _page;
  int _generation = 0;
  bool get _allowed =>
      widget.sessionAvailable &&
      widget.canRead &&
      validLocationId(widget.consumer.id) &&
      const {
        LocationReservationConsumerKind.group,
        LocationReservationConsumerKind.activity,
      }.contains(widget.consumer.kind) &&
      widget.scopes.isNotEmpty &&
      widget.scopes.every(validLocationScope);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant LocationConsumerBindingsSection oldWidget) {
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

  Future<void> _load({String? after}) async {
    final generation = ++_generation;
    setState(() {
      _page = null;
      _state = _allowed ? LocationReadState.loading : LocationReadState.denied;
    });
    if (!_allowed) return;
    try {
      final page = await widget.reader.fetchPage(consumer: widget.consumer, afterLocationId: after);
      if (!mounted || generation != _generation || !_allowed) return;
      if (!_validPage(page, after)) throw const FormatException('Invalid consumer bindings');
      setState(() {
        _page = page;
        _state = page.items.isEmpty ? LocationReadState.empty : LocationReadState.ready;
      });
    } on Object catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _page = null;
        _state = error is LocationCatalogAccessDeniedException
            ? LocationReadState.denied
            : LocationReadState.unavailable;
      });
    }
  }

  bool _validPage(LocationConsumerBindingPage page, String? after) {
    if (page.consumer != widget.consumer || page.items.length > 20) return false;
    String? previous = after;
    for (final entry in page.items) {
      final location = entry.location;
      if (!validLocationId(location.id) ||
          previous != null && location.id.compareTo(previous) <= 0 ||
          !widget.scopes.any((scope) => sameLocationScope(scope, location.scope))) {
        return false;
      }
      previous = location.id;
    }
    return page.nextLocationId == null ||
        page.items.length == 20 && page.nextLocationId == page.items.last.location.id;
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    final generation = _generation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Histórico de locais com reservas',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: CoeloSpacing.space2),
        const Text(
          'Inclui vínculos anteriores, mesmo sem reservas ativas. Abra um local para consultar as reservas deste registro.',
        ),
        const SizedBox(height: CoeloSpacing.space3),
        if (_state == LocationReadState.ready && page != null)
          for (final entry in page.items)
            Padding(
              padding: const EdgeInsets.only(bottom: CoeloSpacing.space3),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(CoeloSpacing.space4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(entry.location.label, style: Theme.of(context).textTheme.titleSmall),
                      Text(_statusLabel(entry.status)),
                      const SizedBox(height: CoeloSpacing.space2),
                      OutlinedButton(
                        key: Key('consumer-binding-open-${entry.location.id}'),
                        onPressed: () {
                          if (!mounted || generation != _generation || !_allowed || _page != page) {
                            return;
                          }
                          widget.onSelected(entry);
                        },
                        child: const Text('Consultar reservas'),
                      ),
                    ],
                  ),
                ),
              ),
            )
        else
          CoeloStatePanel(
            key: Key('consumer-bindings-${_state.name}'),
            loading: _state == LocationReadState.loading,
            title: switch (_state) {
              LocationReadState.loading => 'Carregando histórico',
              LocationReadState.empty => 'Nenhum local com reservas registrado',
              LocationReadState.denied => 'Histórico não autorizado',
              _ => 'Histórico indisponível',
            },
            message: _state == LocationReadState.empty
                ? 'Novas reservas podem ser criadas a partir do catálogo.'
                : _state == LocationReadState.loading
                ? 'Aguarde a consulta dos vínculos.'
                : 'Não foi possível consultar os vínculos deste registro.',
          ),
        if (_allowed)
          Wrap(
            spacing: CoeloSpacing.space3,
            runSpacing: CoeloSpacing.space2,
            children: [
              TextButton(
                key: const Key('consumer-bindings-reload'),
                onPressed: _state == LocationReadState.loading ? null : () => unawaited(_load()),
                child: const Text('Recarregar histórico'),
              ),
              if (page?.nextLocationId case final next?)
                OutlinedButton(
                  key: const Key('consumer-bindings-next'),
                  onPressed: () {
                    if (!mounted || generation != _generation || !_allowed || _page != page) return;
                    unawaited(_load(after: next));
                  },
                  child: const Text('Mais locais'),
                ),
            ],
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
