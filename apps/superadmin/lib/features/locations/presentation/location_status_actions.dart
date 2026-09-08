import 'dart:async';

import 'package:coelo_api/locations.dart';
import 'package:coelo_domain/locations.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../domain/location_catalog_writer.dart';
import 'location_form_panel.dart' show newLocationRequestId;

/// Puts a place in service, out of service, or out of the catalog.
///
/// Composed only when a writer is injected, so a screen without the capability
/// keeps exactly the pixels it had. Nothing here decides whether the actor may
/// do it: the server does, and a refusal is shown as a refusal.
class LocationStatusActions extends StatefulWidget {
  const LocationStatusActions({
    required this.entry,
    required this.writer,
    required this.onChanged,
    this.enabled = true,
    this.requestIdFactory,
    super.key,
  });

  final LocationCatalogEntry entry;
  final LocationCatalogWriter writer;

  /// The catalog moved. The detail reloads instead of trusting what it holds,
  /// because the version it holds is now one behind.
  final ValueChanged<LocationCatalogEntry> onChanged;

  final bool enabled;
  final String Function()? requestIdFactory;

  @override
  State<LocationStatusActions> createState() => _LocationStatusActionsState();
}

class _LocationStatusActionsState extends State<LocationStatusActions> {
  LocationCatalogStatus? _running;
  String? _error;

  /// One id per intent, kept across retries of that intent so a retry is the
  /// same request and not a second one. A rejection means the intent itself was
  /// wrong, so the next attempt starts a new request.
  final _requestIds = <LocationCatalogStatus, String>{};

  @override
  void didUpdateWidget(LocationStatusActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different location, or a version that moved, means every pending intent
    // was about something else.
    if (oldWidget.entry.id != widget.entry.id ||
        oldWidget.entry.managementVersion != widget.entry.managementVersion) {
      _requestIds.clear();
      _error = null;
    }
  }

  /// What can be asked for from where the place is now.
  ///
  /// Asking for the status it already has is refused by the catalog, so it is
  /// not offered here either.
  List<LocationCatalogStatus> get _available => switch (widget.entry.status) {
    LocationCatalogStatus.active => const [
      LocationCatalogStatus.inactive,
      LocationCatalogStatus.archived,
    ],
    LocationCatalogStatus.inactive => const [
      LocationCatalogStatus.active,
      LocationCatalogStatus.archived,
    ],
    LocationCatalogStatus.archived => const [LocationCatalogStatus.active],
    // A location never reaches these, but the shared enum can hold them and
    // guessing a transition out of one would be inventing product behaviour.
    LocationCatalogStatus.draft || LocationCatalogStatus.suspended => const [],
  };

  static String _label(LocationCatalogStatus status) => switch (status) {
    LocationCatalogStatus.active => 'Reativar local',
    LocationCatalogStatus.inactive => 'Desativar local',
    LocationCatalogStatus.archived => 'Arquivar local',
    LocationCatalogStatus.draft || LocationCatalogStatus.suspended => 'Indisponível',
  };

  static String _key(LocationCatalogStatus status) => 'location-status-${status.name}';

  Future<void> _change(LocationCatalogStatus status) async {
    if (_running != null) return;
    if (status == LocationCatalogStatus.archived && !await _confirmArchive()) return;
    if (!mounted) return;
    final requestId = _requestIds[status] ??= (widget.requestIdFactory ?? newLocationRequestId)();
    setState(() {
      _running = status;
      _error = null;
    });
    try {
      final updated = await widget.writer.setStatus(
        locationId: widget.entry.id,
        status: status,
        expectedVersion: widget.entry.managementVersion,
        requestId: requestId,
      );
      if (!mounted) return;
      setState(() => _running = null);
      widget.onChanged(updated);
    } on LocationWriteRejectedException {
      _requestIds.remove(status);
      _fail('Este local não aceita essa mudança agora. Recarregue e tente de novo.');
    } on LocationWriteDeniedException {
      _fail('Você não tem permissão para mudar o status deste local.');
    } on LocationWriteConflictException {
      _fail('Alguém mudou este local enquanto a tela estava aberta. Recarregue antes de tentar.');
    } on Object {
      _fail('Não foi possível mudar o status. Tente novamente.');
    }
  }

  /// Archiving takes a place out of every list that offers it. It is reversible,
  /// but not invisible, so it is asked about rather than assumed.
  Future<bool> _confirmArchive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('location-status-archive-confirm'),
        title: const Text('Arquivar este local?'),
        content: Text(
          'O local "${widget.entry.name}" deixa de aparecer para escolha. '
          'Você pode reativar depois, se o nome ainda estiver livre.',
        ),
        actions: [
          TextButton(
            key: const Key('location-status-archive-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Manter como está'),
          ),
          FilledButton(
            key: const Key('location-status-archive-accept'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Arquivar'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _running = null;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final available = _available;
    if (available.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      key: const Key('location-status-actions'),
      padding: const EdgeInsets.only(bottom: CoeloSpacing.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Situação do local', style: theme.textTheme.titleSmall),
          const SizedBox(height: CoeloSpacing.space2),
          Wrap(
            spacing: CoeloSpacing.space2,
            runSpacing: CoeloSpacing.space2,
            children: [
              for (final status in available)
                OutlinedButton(
                  key: Key(_key(status)),
                  onPressed: widget.enabled && _running == null ? () => unawaited(_change(status)) : null,
                  child: Text(_running == status ? 'Aguarde…' : _label(status)),
                ),
            ],
          ),
          if (_error case final message?) ...[
            const SizedBox(height: CoeloSpacing.space2),
            // A live region: the refusal is the answer to a button the actor
            // just pressed, so a screen reader must not have to go looking.
            Semantics(
              liveRegion: true,
              child: Text(
                message,
                key: const Key('location-status-error'),
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
