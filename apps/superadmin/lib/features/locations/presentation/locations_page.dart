import 'package:coelo_domain/locations.dart';
import 'package:flutter/material.dart';

import '../../../app/shell/superadmin_shell.dart';
import '../../auth/domain/logout_action.dart';
import '../../units/domain/unit_directory.dart';
import '../domain/location_capabilities.dart';
import '../domain/location_catalog_reader.dart';
import '../domain/location_catalog_writer.dart';
import '../domain/location_selection_source.dart';
import 'location_detail_panel.dart';
import 'location_directory_panel.dart';
import 'location_form_panel.dart';
import 'location_institution_copy_panel.dart';
import 'location_institution_units_section.dart';
import 'location_read_widgets.dart';

/// Route target for the location catalog of one institution or unit.
///
/// The catalog belongs to a scope, so the page never renders without one: an
/// institution and a unit keep independent catalogs and the page must not blur
/// them. Selection may come from the URL, which keeps a direct link to a
/// location working, and the page reports every change back so the caller can
/// keep the address bar in sync.
///
/// Nothing here authorizes anything. The reader talks to a server that
/// re-checks actor, session, tenant and ownership on every read, and the
/// default reader is unavailable rather than a fixture.
final class LocationsPage extends StatefulWidget {
  const LocationsPage({
    required this.scope,
    required this.logout,
    this.reader = const UnavailableLocationCatalogReader(),
    this.sessionAvailable = false,
    this.contextRevision = 0,
    this.selectedLocationId,
    this.onLocationOpened,
    this.onLocationClosed,
    this.onDestinationSelected,
    this.currentDestination = 'institutions',
    this.writer = const UnavailableLocationCatalogWriter(),
    this.canCreate = false,
    this.canManage,
    this.capabilities,
    this.requestIdFactory,
    this.unitDirectoryRepository,
    this.onUnitLocationsOpened,
    super.key,
  });

  final LocationScope scope;
  final LogoutAction logout;
  final LocationCatalogReader reader;
  final bool sessionAvailable;

  /// Bumped by the composition whenever the session context changes.
  final int contextRevision;

  /// Location taken from the route, when the caller deep-links into a detail.
  final String? selectedLocationId;

  final ValueChanged<String>? onLocationOpened;
  final VoidCallback? onLocationClosed;
  final ValueChanged<String>? onDestinationSelected;

  /// Menu entry that stays highlighted; the catalog hangs off its owner.
  final String currentDestination;

  final LocationCatalogWriter writer;

  /// Whether this actor may create; the server authorizes the write anyway.
  final bool canCreate;

  /// Whether this actor may edit, change status, copy or schedule.
  ///
  /// Null falls back to [canCreate]. This is the coarse pair the catalog was
  /// born with, kept because callers still pass it; [capabilities] is what to
  /// pass once the grants stop moving together.
  final bool? canManage;

  /// The four writes, granted one at a time.
  ///
  /// Null derives them from [canCreate] and [canManage] exactly as before, so a
  /// caller that has not been updated behaves to the pixel as it did. Passing
  /// this wins over both flags.
  ///
  /// Still only a render gate: the server authorizes each command on its own,
  /// and a location the actor may not touch comes back as a refusal whatever
  /// this says.
  final LocationCapabilities? capabilities;

  final String Function()? requestIdFactory;

  /// Unidades da instituicao, listadas depois dos grupos de locais quando o
  /// escopo e uma instituicao (pendencia da R03 aprovada pelo Owner). Nulo nao
  /// mostra o grupo; num escopo de unidade ele nunca aparece.
  final UnitDirectoryRepository? unitDirectoryRepository;

  /// Chamado com o id da unidade cujo card foi tocado, para o chamador abrir o
  /// catalogo de Locais daquela unidade pela rota que ja existe. Nulo deixa os
  /// cards inertes.
  final ValueChanged<String>? onUnitLocationsOpened;

  @override
  State<LocationsPage> createState() => _LocationsPageState();
}

final class _LocationsPageState extends State<LocationsPage> {
  String? _selected;
  bool _creating = false;
  /// Tipo com que a criacao abre. O card Criar do grupo manda o tipo dele.
  LocationKind _creatingKind = LocationKind.internal;
  LocationCatalogEntry? _editing;
  bool _bringing = false;
  int _contextGeneration = 0;

  static LocationCapabilities _capabilitiesOf(LocationsPage page) =>
      page.capabilities ??
      LocationCapabilities.fromLegacyFlags(canCreate: page.canCreate, canManage: page.canManage);

  LocationCapabilities get _can => _capabilitiesOf(widget);

  @override
  void initState() {
    super.initState();
    _selected = _accepted(widget.selectedLocationId);
  }

  @override
  void didUpdateWidget(covariant LocationsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new context or a lost session must not keep the previous detail on
    // screen, even for the frame before the panel reloads.
    if (oldWidget.contextRevision != widget.contextRevision ||
        oldWidget.sessionAvailable != widget.sessionAvailable ||
        !sameLocationScope(oldWidget.scope, widget.scope)) {
      ++_contextGeneration;
      _selected = null;
      _creating = false;
      _editing = null;
      _bringing = false;
      return;
    }
    if (oldWidget.selectedLocationId != widget.selectedLocationId) {
      // The route now points at a different location, so whatever was open here
      // was about the previous one. Keeping the edit form alive across that
      // change is how an unsaved edit of A ends up saved over B: the panel
      // still holds A's id and version while the URL already says B.
      ++_contextGeneration;
      _selected = _accepted(widget.selectedLocationId);
      _creating = false;
      _editing = null;
      _bringing = false;
    }
    // A grant taken away has to take its surface with it. A form left standing
    // after its capability is gone still holds a writer and still has a save
    // button, and the only thing stopping the write is the server - which is
    // the right last line and the wrong first one.
    //
    // Each grant closes only what it was holding open: the selected detail is a
    // read and survives all of this, and losing the right to copy is no reason
    // to shut an edit.
    final can = _can;
    if (!can.create) _creating = false;
    if (!can.update) _editing = null;
    if (!can.copy) _bringing = false;
  }

  bool _current(int generation) =>
      mounted && widget.sessionAvailable && generation == _contextGeneration;

  bool get _directoryOpen => !_creating && !_bringing && _editing == null && _selected == null;

  /// A malformed identifier never becomes a read.
  String? _accepted(String? id) => id != null && validLocationId(id) ? id : null;

  void _open(LocationCatalogEntry item) {
    if (!mounted) return;
    setState(() {
      _creating = false;
      _editing = null;
      _bringing = false;
      _selected = item.id;
    });
    widget.onLocationOpened?.call(item.id);
  }

  void _close() {
    if (!mounted) return;
    setState(() {
      _creating = false;
      _editing = null;
      _bringing = false;
      _selected = null;
    });
    widget.onLocationClosed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = _selected;
    final generation = _contextGeneration;
    // Creating is offered by the page, not by the directory panel: the panel is
    // a read surface and adding an action to it would change every screen that
    // renders it.
    final editing = _editing;
    final can = _can;
    final canCreate =
        can.create &&
        widget.sessionAvailable &&
        !_creating &&
        !_bringing &&
        editing == null &&
        selected == null;
    // Bringing one down lands on a new location, so it must not compete with a
    // form or a detail already on screen. It is a copy, and asks for exactly
    // that grant rather than for management in general.
    final canBring =
        can.copy &&
        widget.sessionAvailable &&
        !_creating &&
        !_bringing &&
        editing == null &&
        selected == null;
    return Theme(
      data: theme.copyWith(scaffoldBackgroundColor: theme.colorScheme.surface),
      child: SuperadminShell(
        logout: widget.logout,
        title: 'Mapa e locais',
        subtitle: locationScopeLabel(widget.scope),
        currentDestination: widget.currentDestination,
        onDestinationSelected: widget.onDestinationSelected,
        // Decisao 7: sem balao de chat em criar/editar. Na rota real o balao
        // cobria o botao Salvar do formulario de local (11/09, R04).
        showChatLauncher: _directoryOpen,
        actions: [
          if (widget.scope is UnitLocationScope && canBring)
            OutlinedButton.icon(
              key: const Key('locations-bring-from-institution'),
              onPressed: () {
                if (!_current(generation) || !_can.copy || !_directoryOpen) return;
                setState(() => _bringing = true);
              },
              icon: const Icon(Icons.south_rounded),
              label: const Text('Trazer da instituição'),
            ),
          // O botao Novo local do cabecalho saiu: criar agora e o card Criar
          // dentro do grupo, que ja diz se o local e interno ou externo.
          // Decisao do Owner de 10/09/2026 sobre a estrutura de Locais.
          // O card existe tambem nos estados vazio e sem resultados, entao
          // nenhum estado ficou sem forma de criar.
        ],
        child: _bringing && widget.scope is UnitLocationScope
            ? LocationInstitutionCopyPanel(
                key: const Key('locations-bring-panel'),
                target: widget.scope as UnitLocationScope,
                source: CatalogLocationSelectionSource(widget.reader),
                writer: widget.writer,
                requestIdFactory: widget.requestIdFactory,
                onCancel: () => setState(() => _bringing = false),
                onCopied: _open,
              )
            : _creating || editing != null
            ? LocationFormPanel(
                // The create form keeps the key it has always had; an edit gets
                // its own so switching between two locations rebuilds the state
                // instead of carrying the previous one's text along.
                key: editing == null
                    ? const Key('locations-form')
                    : Key('locations-form-${editing.id}'),
                scope: widget.scope,
                initial: editing,
                initialKind: _creatingKind,
                writer: widget.writer,
                sessionAvailable: widget.sessionAvailable,
                onCancel: () => setState(() {
                  _creating = false;
                  _editing = null;
                }),
                // Editing returns to the detail of the same location, which
                // reads again and therefore holds the version the next command
                // will need.
                onCreated: _open,
              )
            : selected == null
            ? LocationDirectoryPanel(
                key: const Key('locations-directory'),
                scope: widget.scope,
                reader: widget.reader,
                sessionAvailable: widget.sessionAvailable,
                contextRevision: widget.contextRevision,
                onOpen: _open,
                onCreate: canCreate
                    ? (kind) {
                        if (!_current(generation) || !_can.create || !_directoryOpen) return;
                        setState(() {
                          _creatingKind = kind;
                          _creating = true;
                        });
                      }
                    : null,
                trailing: switch ((widget.scope, widget.unitDirectoryRepository)) {
                  (InstitutionLocationScope(:final institutionId), final units?) =>
                    LocationInstitutionUnitsSection(
                      key: const Key('locations-units'),
                      institutionId: institutionId,
                      repository: units,
                      sessionAvailable: widget.sessionAvailable,
                      contextRevision: widget.contextRevision,
                      onOpen: widget.onUnitLocationsOpened == null
                          ? null
                          : (unitId) {
                              if (!_current(generation) || !_directoryOpen) return;
                              widget.onUnitLocationsOpened?.call(unitId);
                            },
                    ),
                  _ => null,
                },
              )
            : LocationDetailPanel(
                key: Key('locations-detail-$selected'),
                id: selected,
                scope: widget.scope,
                reader: widget.reader,
                sessionAvailable: widget.sessionAvailable,
                contextRevision: widget.contextRevision,
                // A panel with no granted write must not hold a writer, so that
                // a bug cannot turn into a request.
                writer: can.writesAnything ? widget.writer : null,
                capabilities: can,
                onEdit: can.update
                    ? (item) {
                        if (!_current(generation) ||
                            !_can.update ||
                            _selected != item.id ||
                            !sameLocationScope(widget.scope, item.scope)) {
                          return;
                        }
                        setState(() => _editing = item);
                      }
                    : null,
                // A copy is a different location, so the page opens it rather
                // than leaving the actor looking at the one they duplicated.
                onCopied: can.copy ? _open : null,
                onBack: _close,
              ),
      ),
    );
  }
}
