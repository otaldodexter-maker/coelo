import 'package:coelo_domain/locations.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../locations/domain/location_catalog_reader.dart';
import '../../locations/domain/location_selection_source.dart';
import '../../locations/presentation/location_selection_field.dart';

/// Candidate create-draft selection. Availability is a deployment/composition
/// gate, never authorization; the transaction rechecks the actual catalog owner.
class ActivityCataloguedLocationSection extends StatefulWidget {
  const ActivityCataloguedLocationSection({
    required this.scopes,
    required this.reader,
    required this.onChanged,
    required this.sessionAvailable,
    required this.contextRevision,
    this.available = false,
    this.selection,
    super.key,
  });
  final List<({LocationScope scope, String label})> scopes;
  final LocationCatalogReader reader;
  final ValueChanged<CataloguedLocationSelection?> onChanged;
  final bool sessionAvailable;
  final int contextRevision;
  final bool available;
  final CataloguedLocationSelection? selection;
  @override
  State<ActivityCataloguedLocationSection> createState() =>
      _ActivityCataloguedLocationSectionState();
}

class _ActivityCataloguedLocationSectionState extends State<ActivityCataloguedLocationSection> {
  late LocationSelectionSource _source;
  String? _owner;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _source = CatalogLocationSelectionSource(widget.reader);
  }

  bool get _allowed =>
      widget.available &&
      widget.sessionAvailable &&
      widget.scopes.isNotEmpty &&
      widget.scopes.every(
        (o) =>
            validLocationScope(o.scope) &&
            o.scope.institutionId == widget.scopes.first.scope.institutionId,
      ) &&
      widget.scopes.map((o) => _key(o.scope)).toSet().length == widget.scopes.length;
  @override
  void didUpdateWidget(covariant ActivityCataloguedLocationSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final invalidated =
        oldWidget.contextRevision != widget.contextRevision ||
        oldWidget.sessionAvailable != widget.sessionAvailable ||
        oldWidget.available != widget.available ||
        !identical(oldWidget.reader, widget.reader);
    final ownerRemoved = _owner != null && !widget.scopes.any((o) => _key(o.scope) == _owner);
    if (invalidated || ownerRemoved) {
      _owner = null;
      final generation = ++_generation;
      _source = CatalogLocationSelectionSource(widget.reader);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && generation == _generation) widget.onChanged(null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_allowed) {
      return const CoeloStatePanel(
        key: Key('activity-catalogued-location-unavailable'),
        title: 'Local da atividade',
        message:
            'A sele\u00e7\u00e3o de local ao criar esta atividade est\u00e1 indispon\u00edvel no momento.',
        icon: Icons.location_off_outlined,
      );
    }
    final selection = widget.selection;
    final selectionOwner = selection == null ? null : _key(selection.snapshot.scope);
    final owner =
        _owner ??
        (widget.scopes.any((o) => _key(o.scope) == selectionOwner) ? selectionOwner : null) ??
        _key(widget.scopes.first.scope);
    final scope = widget.scopes.firstWhere((o) => _key(o.scope) == owner).scope;
    final generation = _generation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Escolha um local existente no cat\u00e1logo da institui\u00e7\u00e3o ou de uma unidade selecionada. A escolha n\u00e3o reserva um hor\u00e1rio.',
        ),
        const SizedBox(height: CoeloSpacing.space3),
        if (widget.scopes.length > 1) ...[
          CoeloAdminSingleSelectField<String>(
            key: const Key('activity-location-owner'),
            label: 'Cat\u00e1logo',
            value: owner,
            options: widget.scopes.map((o) => _key(o.scope)).toList(),
            optionLabel: (value) => widget.scopes.firstWhere((o) => _key(o.scope) == value).label,
            onChanged: (value) {
              if (!mounted ||
                  generation != _generation ||
                  !_allowed ||
                  value == owner ||
                  !widget.scopes.any((o) => _key(o.scope) == value)) {
                return;
              }
              setState(() {
                _owner = value;
                ++_generation;
              });
              widget.onChanged(null);
            },
          ),
          const SizedBox(height: CoeloSpacing.space3),
        ],
        LocationSelectionField(
          key: ValueKey('activity-catalog-$generation-$owner'),
          scope: scope,
          source: _source,
          sessionAvailable: widget.sessionAvailable,
          contextRevision: widget.contextRevision,
          catalogOnly: true,
          initialSelection: selection != null && sameLocationScope(selection.snapshot.scope, scope)
              ? selection
              : null,
          onChanged: (value) {
            if (!mounted ||
                generation != _generation ||
                !_allowed ||
                !widget.scopes.any((owner) => sameLocationScope(owner.scope, scope))) {
              return;
            }
            if (value != null &&
                (value is! CataloguedLocationSelection ||
                    !sameLocationScope(value.snapshot.scope, scope))) {
              return;
            }
            widget.onChanged(value as CataloguedLocationSelection?);
          },
        ),
      ],
    );
  }
}

String _key(LocationScope scope) => switch (scope) {
  InstitutionLocationScope(:final institutionId) => 'institution:$institutionId',
  UnitLocationScope(:final unitId) => 'unit:$unitId',
};
