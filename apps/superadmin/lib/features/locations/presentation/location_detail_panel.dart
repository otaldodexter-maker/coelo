import 'dart:async';
import 'package:coelo_domain/locations.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import '../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../../shared/presentation/widgets/superadmin_location_map_preview.dart';
import '../domain/location_capabilities.dart';
import '../domain/location_catalog_reader.dart';
import '../domain/location_catalog_writer.dart';
import 'location_copy_dialog.dart';
import 'location_detail_controller.dart';
import 'location_read_widgets.dart';
import 'location_schedule_section.dart';
import 'location_status_actions.dart';

/// Isolated content; normal routing and authorization composition are not wired.
class LocationDetailPanel extends StatefulWidget {
  const LocationDetailPanel({
    required this.id,
    required this.scope,
    required this.onBack,
    this.writer,
    this.capabilities = LocationCapabilities.all,
    this.onEdit,
    this.onCopied,
    this.requestIdFactory,
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

  /// Opt-in. Without a writer the detail is exactly the read-only panel it was,
  /// down to the pixel, and no control appears that the composition cannot back.
  final LocationCatalogWriter? writer;

  /// Which of the writes to draw, once a writer is present.
  ///
  /// Defaults to everything so that composing a writer behaves as it did before
  /// the capabilities had names. Status, copy and schedule used to share the
  /// writer's presence as their only gate, which meant granting one granted all
  /// three.
  final LocationCapabilities capabilities;

  /// Opt-in. The panel does not own the form, so it asks the page to open it.
  final ValueChanged<LocationCatalogEntry>? onEdit;

  /// Opt-in. A copy is a new location, so the page decides where to go next.
  final ValueChanged<LocationCatalogEntry>? onCopied;

  final String Function()? requestIdFactory;
  @override
  State<LocationDetailPanel> createState() => _LocationDetailPanelState();
}

class _LocationDetailPanelState extends State<LocationDetailPanel> {
  late final LocationDetailController _controller;
  NavigatorState? _copyDialogNavigator;
  Route<dynamic>? _copyDialogRoute;
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
    final contextChanged =
        oldWidget.id != widget.id ||
        !sameLocationScope(oldWidget.scope, widget.scope) ||
        !identical(oldWidget.reader, widget.reader) ||
        !identical(oldWidget.writer, widget.writer) ||
        oldWidget.sessionAvailable != widget.sessionAvailable ||
        oldWidget.contextRevision != widget.contextRevision;
    if (contextChanged || oldWidget.capabilities.copy && !widget.capabilities.copy) {
      _dismissCopyDialog();
    }
    if (contextChanged) {
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
    _dismissCopyDialog();
    _controller.dispose();
    super.dispose();
  }

  void _dismissCopyDialog() {
    final navigator = _copyDialogNavigator;
    final route = _copyDialogRoute;
    _copyDialogNavigator = null;
    _copyDialogRoute = null;
    if (navigator == null || route == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator.mounted && route.isActive) navigator.removeRoute(route);
    });
  }

  Future<void> _copy(LocationCatalogEntry item) async {
    final writer = widget.writer;
    final onCopied = widget.onCopied;
    if (writer == null || onCopied == null || !widget.capabilities.copy) return;
    final created = await showDialog<LocationCatalogEntry>(
      context: context,
      builder: (dialogContext) {
        _copyDialogNavigator = Navigator.of(dialogContext);
        _copyDialogRoute = ModalRoute.of(dialogContext);
        return LocationCopyDialog(
          source: item,
          writer: writer,
          requestIdFactory: widget.requestIdFactory,
        );
      },
    );
    _copyDialogNavigator = null;
    _copyDialogRoute = null;
    if (!mounted || created == null) return;
    onCopied(created);
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
                      if (widget.capabilities.schedule)
                        if (widget.writer case final writer?)
                          LocationScheduleSection(
                            entry: item,
                            writer: writer,
                            enabled: widget.sessionAvailable,
                            requestIdFactory: widget.requestIdFactory,
                            onPublished: () => unawaited(_controller.load()),
                          ),
                      if (widget.capabilities.status)
                        if (widget.writer case final writer?)
                          LocationStatusActions(
                            entry: item,
                            writer: writer,
                            enabled: widget.sessionAvailable,
                            requestIdFactory: widget.requestIdFactory,
                            // The catalog moved, so what this panel holds is one
                            // version behind. Reading again is cheaper than being
                            // subtly wrong about the version the next command needs.
                            onChanged: (_) => unawaited(_controller.load()),
                          ),
                      if (item.address case final address?) ...[
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
                        // Only an external location has an address of its own,
                        // so only it gets a map. The preview is the shared
                        // painted placeholder: no key, no network, no claim of
                        // geographic authority over the stored address.
                        if (item.kind == LocationKind.external)
                          Padding(
                            padding: const EdgeInsets.only(bottom: CoeloSpacing.space3),
                            child: SuperadminLocationMapPreview(
                              address: [
                                address['street'],
                                address['number'],
                                address['district'],
                                address['city'],
                                address['state'],
                              ].whereType<String>().where((part) => part.isNotEmpty).join(', '),
                            ),
                          ),
                      ],
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
                  if (widget.onCopied != null && widget.writer != null && widget.capabilities.copy)
                    if (_controller.data case final item?)
                      OutlinedButton.icon(
                        key: const Key('location-detail-copy'),
                        onPressed: widget.sessionAvailable ? () => unawaited(_copy(item)) : null,
                        icon: const Icon(Icons.copy_rounded),
                        label: const Text('Duplicar'),
                      ),
                  if (widget.capabilities.update)
                    if (widget.onEdit case final onEdit?)
                      if (_controller.data case final item?)
                        FilledButton.icon(
                          key: const Key('location-detail-edit'),
                          onPressed: widget.sessionAvailable ? () => onEdit(item) : null,
                          icon: const Icon(Icons.edit_rounded),
                          label: const Text('Editar local'),
                        ),
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
