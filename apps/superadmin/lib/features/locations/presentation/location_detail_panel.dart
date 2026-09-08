import 'dart:async';
import 'package:coelo_domain/locations.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import '../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../domain/location_catalog_reader.dart';
import 'location_detail_controller.dart';
import 'location_read_widgets.dart';

/// Isolated content; normal routing and authorization composition are not wired.
class LocationDetailPanel extends StatefulWidget {
  const LocationDetailPanel({
    required this.id,
    required this.scope,
    required this.onBack,
    this.reader = const UnavailableLocationCatalogReader(),
    this.sessionAvailable = false,
    this.contextRevision = 0,
    super.key,
  });
  final String id;
  final LocationScope scope;
  final VoidCallback onBack;
  final LocationCatalogReader reader;
  final bool sessionAvailable;
  final int contextRevision;
  @override
  State<LocationDetailPanel> createState() => _LocationDetailPanelState();
}

class _LocationDetailPanelState extends State<LocationDetailPanel> {
  late final LocationDetailController _controller;
  @override
  void initState() {
    super.initState();
    _controller = LocationDetailController(
      id: widget.id,
      scope: widget.scope,
      reader: widget.reader,
      sessionAvailable: widget.sessionAvailable,
      contextRevision: widget.contextRevision,
    );
    unawaited(_controller.load());
  }

  @override
  void didUpdateWidget(covariant LocationDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id ||
        !sameLocationScope(oldWidget.scope, widget.scope) ||
        !identical(oldWidget.reader, widget.reader) ||
        oldWidget.sessionAvailable != widget.sessionAvailable ||
        oldWidget.contextRevision != widget.contextRevision) {
      unawaited(
        _controller.load(
          id: widget.id,
          scope: widget.scope,
          reader: widget.reader,
          sessionAvailable: widget.sessionAvailable,
          contextRevision: widget.contextRevision,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) => ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: EdgeInsets.all(
            constraints.maxWidth < CoeloBreakpoints.medium.minWidth
                ? CoeloSpacing.space4
                : CoeloSpacing.space6,
          ),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  key: const Key('location-detail-content'),
                  children: [
                    if (_controller.data case final item?) ...[
                      locationTextSection(context, 'Detalhes do local', {
                        'Nome': item.name,
                        'Catálogo': locationScopeLabel(item.scope),
                        'Tipo': locationKindLabel(item.kind),
                        'Descrição': locationOptionalText(item.description),
                        'Andar': locationOptionalText(item.floor),
                        'Visibilidade': locationVisibilityLabel(item.visibility),
                        'Status': locationStatusLabel(item.status),
                      }),
                      if (item.address case final address?)
                        locationTextSection(context, 'Endereço próprio', {
                          'País': locationOptionalText(address['country']),
                          'CEP': locationOptionalText(address['postal_code']),
                          'Estado': locationOptionalText(address['state']),
                          'Cidade': locationOptionalText(address['city']),
                          'Bairro': locationOptionalText(address['district']),
                          'Logradouro': locationOptionalText(address['street']),
                          'Número': locationOptionalText(address['number']),
                          'Complemento': locationOptionalText(address['complement']),
                        }),
                    ] else
                      LocationReadStatePanel(state: _controller.state, prefix: 'location-detail'),
                  ],
                ),
              ),
              const SizedBox(height: CoeloSpacing.space4),
              SuperadminFormActionFooter(
                tertiaryAction: TextButton(
                  key: const Key('location-detail-back'),
                  onPressed: widget.onBack,
                  child: const Text('Voltar'),
                ),
                continuationActions: [
                  OutlinedButton.icon(
                    key: const Key('location-detail-reload'),
                    onPressed: _controller.state == LocationReadState.loading
                        ? null
                        : () => unawaited(_controller.load()),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Recarregar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
