import 'dart:async';

import 'package:coelo_domain/locations.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../domain/location_catalog_reader.dart';
import '../domain/location_selection_source.dart';
import 'location_read_widgets.dart';
import 'location_selection_controller.dart';

enum LocationSelectionMode { catalogued, oneOff }

/// Field a consumer embeds to choose a location for one owner scope.
///
/// Turmas, Atividades, Eventos and Formulários all need this choice, so it
/// lives once here instead of once per consumer. It offers catalogued options
/// for the scope or a one-off text, and it says plainly that a one-off stays in
/// the record that created it.
///
/// It does not offer to save a one-off into the catalog: that write is a
/// separate, server-authorized operation which does not exist yet, and a
/// control for it would promise something the product cannot do. The hook is
/// [onSaveToCatalogRequested]; while it is null the field states the limit
/// instead of hiding it.
class LocationSelectionField extends StatefulWidget {
  const LocationSelectionField({
    required this.scope,
    required this.onChanged,
    this.source = const UnavailableLocationSelectionSource(),
    this.initialSelection,
    this.sessionAvailable = false,
    this.contextRevision = 0,
    this.enabled = true,
    this.onSaveToCatalogRequested,
    super.key,
  });

  final LocationScope scope;
  final ValueChanged<LocationSelection?> onChanged;
  final LocationSelectionSource source;
  final LocationSelection? initialSelection;
  final bool sessionAvailable;
  final int contextRevision;
  final bool enabled;

  /// Reserved for the authorized write that promotes a one-off to the catalog.
  final ValueChanged<String>? onSaveToCatalogRequested;

  @override
  State<LocationSelectionField> createState() => _LocationSelectionFieldState();
}

class _LocationSelectionFieldState extends State<LocationSelectionField> {
  late final LocationSelectionController _controller;
  late final TextEditingController _oneOff;
  final _search = TextEditingController();
  late LocationSelectionMode _mode;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSelection;
    _mode = initial is OneOffLocationSelection
        ? LocationSelectionMode.oneOff
        : LocationSelectionMode.catalogued;
    _oneOff = TextEditingController(text: initial is OneOffLocationSelection ? initial.text : '');
    _controller = LocationSelectionController(
      source: widget.source,
      scope: widget.scope,
      sessionAvailable: widget.sessionAvailable,
      contextRevision: widget.contextRevision,
      initial: initial,
    );
    _controller.addListener(_publish);
    unawaited(_controller.load());
  }

  @override
  void didUpdateWidget(covariant LocationSelectionField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!sameLocationScope(oldWidget.scope, widget.scope) ||
        !identical(oldWidget.source, widget.source) ||
        oldWidget.sessionAvailable != widget.sessionAvailable ||
        oldWidget.contextRevision != widget.contextRevision) {
      _search.clear();
      unawaited(
        _controller.load(
          source: widget.source,
          scope: widget.scope,
          sessionAvailable: widget.sessionAvailable,
          contextRevision: widget.contextRevision,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_publish);
    _controller.dispose();
    _oneOff.dispose();
    _search.dispose();
    super.dispose();
  }

  LocationSelection? _published;

  void _publish() {
    final selection = _controller.selection;
    if (identical(selection, _published)) return;
    _published = selection;
    widget.onChanged(selection);
  }

  void _changeMode(LocationSelectionMode mode) {
    if (mode == _mode) return;
    setState(() => _mode = mode);
    // Switching mode drops the previous choice: a catalogued reference and a
    // one-off text are different things and one never becomes the other.
    if (mode == LocationSelectionMode.oneOff) {
      _controller.setOneOff(_oneOff.text);
    } else {
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final theme = Theme.of(context);
      final selection = _controller.selection;
      final selected = selection is CataloguedLocationSelection ? selection.snapshot : null;
      final ready = _controller.state == LocationReadState.ready;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(header: true, child: Text('Local', style: theme.textTheme.titleMedium)),
          Text(locationScopeLabel(widget.scope), style: theme.textTheme.bodyMedium),
          const SizedBox(height: CoeloSpacing.space3),
          SegmentedButton<LocationSelectionMode>(
            key: const Key('location-selection-mode'),
            segments: const [
              ButtonSegment(
                value: LocationSelectionMode.catalogued,
                label: Text('Do catálogo'),
                icon: Icon(Icons.place_outlined),
              ),
              ButtonSegment(
                value: LocationSelectionMode.oneOff,
                label: Text('Pontual'),
                icon: Icon(Icons.edit_location_alt_outlined),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: widget.enabled ? (values) => _changeMode(values.first) : null,
          ),
          const SizedBox(height: CoeloSpacing.space3),
          if (_mode == LocationSelectionMode.catalogued) ...[
            CoeloSearchField(
              key: const Key('location-selection-search'),
              controller: _search,
              hintText: 'Buscar local do catálogo',
              semanticLabel: 'Buscar local do catálogo',
              onChanged: (value) => unawaited(_controller.setSearch(value)),
            ),
            const SizedBox(height: CoeloSpacing.space3),
            if (ready)
              CoeloAdminSingleSelectField<String>(
                key: const Key('location-selection-option'),
                label: 'Local do catálogo',
                value: selected?.id ?? '',
                options: [
                  '',
                  for (final option in _controller.options) option.id,
                  // A stored choice the catalog no longer offers still has to
                  // be shown, or the field would silently change the record.
                  if (selected != null && !_controller.options.any((o) => o.id == selected.id))
                    selected.id,
                ],
                optionLabel: (id) {
                  if (id.isEmpty) return 'Selecione';
                  for (final option in _controller.options) {
                    if (option.id == id) return option.label;
                  }
                  return selected != null && selected.id == id ? selected.label : 'Selecione';
                },
                onChanged: widget.enabled
                    ? (id) {
                        if (id.isEmpty) {
                          _controller.clear();
                          return;
                        }
                        _controller.selectCatalogued(
                          _controller.options.firstWhere((option) => option.id == id),
                        );
                      }
                    : (_) {},
                prefixIcon: Icons.place_outlined,
                enabled: widget.enabled,
                searchHintText: 'Buscar local',
              )
            else
              LocationReadStatePanel(state: _controller.state, prefix: 'location-selection'),
            if (_controller.truncated)
              Padding(
                padding: const EdgeInsets.only(top: CoeloSpacing.space2),
                child: Text(
                  'Há mais locais neste catálogo. Refine a busca para encontrar o desejado.',
                  key: const Key('location-selection-truncated'),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (_controller.selectionStale)
              Padding(
                padding: const EdgeInsets.only(top: CoeloSpacing.space2),
                child: Text(
                  'O local escolhido antes não está mais disponível para novas escolhas. '
                  'Ele continua registrado, mas selecione outro para seguir.',
                  key: const Key('location-selection-stale'),
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ] else ...[
            CoeloFormTextField(
              fieldKey: const Key('location-selection-one-off'),
              controller: _oneOff,
              labelText: 'Local pontual',
              hintText: 'Descreva o local desta ocasião',
              prefixIcon: Icons.edit_location_alt_outlined,
              enabled: widget.enabled,
              maxLength: 160,
              onChanged: _controller.setOneOff,
            ),
            Padding(
              padding: const EdgeInsets.only(top: CoeloSpacing.space2),
              child: Text(
                widget.onSaveToCatalogRequested == null
                    ? 'Um local pontual fica somente neste registro. Ele não entra no '
                          'catálogo, não tem mapa, foto, vínculos nem agenda.'
                    : 'Um local pontual fica somente neste registro até ser salvo no '
                          'catálogo de forma explícita.',
                key: const Key('location-selection-one-off-limit'),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ],
      );
    },
  );
}
