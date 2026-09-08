import 'package:coelo_domain/locations.dart';
import 'package:flutter/material.dart';

import '../../../app/shell/superadmin_shell.dart';
import '../../auth/domain/logout_action.dart';
import '../domain/location_catalog_reader.dart';
import '../domain/location_catalog_writer.dart';
import 'location_detail_panel.dart';
import 'location_directory_panel.dart';
import 'location_form_panel.dart';
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
  /// Null falls back to [canCreate]. Today the catalog grants every location
  /// capability to the same role, so the actor who may create is the actor who
  /// may manage. This is a hint for what to draw and never an authorization:
  /// the server checks each capability on its own, and a refusal is shown as a
  /// refusal. Pass it explicitly once the grants stop moving together.
  final bool? canManage;

  @override
  State<LocationsPage> createState() => _LocationsPageState();
}

final class _LocationsPageState extends State<LocationsPage> {
  String? _selected;
  bool _creating = false;
  LocationCatalogEntry? _editing;

  bool get _canManage => widget.canManage ?? widget.canCreate;

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
      _selected = null;
      _creating = false;
      _editing = null;
      return;
    }
    if (oldWidget.selectedLocationId != widget.selectedLocationId) {
      _selected = _accepted(widget.selectedLocationId);
    }
  }

  /// A malformed identifier never becomes a read.
  String? _accepted(String? id) => id != null && validLocationId(id) ? id : null;

  void _open(LocationCatalogEntry item) {
    if (!mounted) return;
    setState(() {
      _creating = false;
      _editing = null;
      _selected = item.id;
    });
    widget.onLocationOpened?.call(item.id);
  }

  void _close() {
    if (!mounted) return;
    setState(() {
      _creating = false;
      _editing = null;
      _selected = null;
    });
    widget.onLocationClosed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = _selected;
    // Creating is offered by the page, not by the directory panel: the panel is
    // a read surface and adding an action to it would change every screen that
    // renders it.
    final editing = _editing;
    final canCreate =
        widget.canCreate &&
        widget.sessionAvailable &&
        !_creating &&
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
        actions: [
          if (canCreate)
            FilledButton.icon(
              key: const Key('locations-create'),
              onPressed: () => setState(() => _creating = true),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Novo local'),
            ),
        ],
        child: _creating || editing != null
            ? LocationFormPanel(
                // The create form keeps the key it has always had; an edit gets
                // its own so switching between two locations rebuilds the state
                // instead of carrying the previous one's text along.
                key: editing == null ? const Key('locations-form') : Key('locations-form-${editing.id}'),
                scope: widget.scope,
                initial: editing,
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
              )
            : LocationDetailPanel(
                key: Key('locations-detail-$selected'),
                id: selected,
                scope: widget.scope,
                reader: widget.reader,
                sessionAvailable: widget.sessionAvailable,
                contextRevision: widget.contextRevision,
                writer: _canManage ? widget.writer : null,
                onEdit: _canManage ? (item) => setState(() => _editing = item) : null,
                // A copy is a different location, so the page opens it rather
                // than leaving the actor looking at the one they duplicated.
                onCopied: _canManage ? _open : null,
                onBack: _close,
              ),
      ),
    );
  }
}
