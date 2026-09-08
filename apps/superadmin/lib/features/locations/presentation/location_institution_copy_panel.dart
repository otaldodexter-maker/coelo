import 'dart:async';

import 'package:coelo_api/locations.dart';
import 'package:coelo_domain/locations.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../domain/location_catalog_writer.dart';
import '../domain/location_selection_source.dart';
import 'location_form_panel.dart' show newLocationRequestId;

/// Brings a location from the institution's catalog down into one unit.
///
/// This is the one cross-owner copy the product asks for, and it is the one
/// that needs no picker of owners: the target is the unit whose catalog is open.
/// The source list is the institution's own catalog, read through the published
/// selection contract, so only what is selectable there can be brought down.
///
/// What lands in the unit is a new location, not a link. Editing the copy later
/// does not touch the institution's entry, and that is deliberate: a unit that
/// adapts a shared room must not rewrite the shared room.
///
/// A panel and not a dialog, for a reason worth keeping written down: the shared
/// single-select field opens its options in an overlay taken from the nearest
/// Overlay, and inside a dialog route that overlay is painted behind the dialog.
/// The options end up visible and untappable. The page already swaps between
/// directory, detail and form, so a panel is also the shape this screen speaks.
class LocationInstitutionCopyPanel extends StatefulWidget {
  const LocationInstitutionCopyPanel({
    required this.target,
    required this.source,
    required this.writer,
    required this.onCancel,
    required this.onCopied,
    this.requestIdFactory,
    super.key,
  });

  final VoidCallback onCancel;

  /// A copy is a new location, so the page decides where to go next.
  final ValueChanged<LocationCatalogEntry> onCopied;

  /// The unit catalog receiving the copy.
  final UnitLocationScope target;

  final LocationSelectionSource source;
  final LocationCatalogWriter writer;
  final String Function()? requestIdFactory;

  @override
  State<LocationInstitutionCopyPanel> createState() => _LocationInstitutionCopyPanelState();
}

class _LocationInstitutionCopyPanelState extends State<LocationInstitutionCopyPanel> {
  final _search = TextEditingController();
  final _name = TextEditingController();

  List<LocationReferenceSnapshot>? _options;
  LocationReferenceSnapshot? _selected;
  bool _truncated = false;
  bool _loading = false;
  bool _saving = false;
  String? _error;
  String? _requestId;

  LocationScope get _institutionScope =>
      LocationScope.institution(institutionId: widget.target.institutionId);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _search.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.source.fetchOptions(
        LocationSelectionRequest(
          scope: _institutionScope,
          search: _search.text.trim().isEmpty ? null : _search.text,
          limit: locationSelectionMaxLimit,
        ),
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _options = result.options;
        _truncated = result.truncated;
        // A list that changed under the actor must not keep a selection that is
        // no longer in it.
        if (_selected != null && !result.options.any((option) => option.id == _selected!.id)) {
          _selected = null;
          _name.text = '';
        }
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _options = const [];
        _error = 'Não foi possível listar os locais da instituição.';
      });
    }
  }

  void _select(LocationReferenceSnapshot option) {
    setState(() {
      _selected = option;
      // The unit catalog is a namespace of its own, so the institution's name is
      // free here and is the name the actor expects to see.
      _name.text = option.label;
      _error = null;
      _requestId = null;
    });
  }

  Future<void> _copy() async {
    final selected = _selected;
    if (_saving || selected == null) return;
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Informe o nome do local na unidade.');
      return;
    }
    final requestId = _requestId ??= (widget.requestIdFactory ?? newLocationRequestId)();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final entry = await widget.writer.copy(
        sourceId: selected.id,
        sourceInstitutionId: widget.target.institutionId,
        targetScope: widget.target,
        name: _name.text,
        requestId: requestId,
      );
      if (!mounted) return;
      widget.onCopied(entry);
    } on LocationWriteRejectedException {
      _requestId = null;
      _fail('Já existe um local ativo com esse nome nesta unidade. Escolha outro.');
    } on LocationWriteDeniedException {
      _fail('Você não tem permissão para trazer locais da instituição.');
    } on LocationWriteConflictException {
      _fail('Este envio já foi usado com outros dados. Feche e tente de novo.');
    } on Object {
      _fail('Não foi possível trazer o local. Tente novamente.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final options = _options;
    final selected = _selected;
    return LayoutBuilder(
      key: const Key('location-institution-copy-panel'),
      builder: (context, constraints) => Padding(
        padding: EdgeInsets.all(
          constraints.maxWidth < CoeloBreakpoints.medium.minWidth
              ? CoeloSpacing.space4
              : CoeloSpacing.space6,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trazer local da instituição', style: theme.textTheme.headlineSmall),
            const SizedBox(height: CoeloSpacing.space3),
            Text(
              'O local escolhido é copiado para esta unidade. A cópia é independente: '
              'editar aqui não muda o local da instituição.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: CoeloSpacing.space3),
            Row(
              children: [
                Expanded(
                  child: CoeloFormTextField(
                    fieldKey: const Key('location-institution-copy-search'),
                    controller: _search,
                    labelText: 'Buscar na instituição',
                    prefixIcon: Icons.search_rounded,
                    enabled: !_saving,
                    maxLength: 120,
                  ),
                ),
                const SizedBox(width: CoeloSpacing.space2),
                OutlinedButton(
                  key: const Key('location-institution-copy-search-run'),
                  onPressed: _loading || _saving ? null : () => unawaited(_load()),
                  child: const Text('Buscar'),
                ),
              ],
            ),
            const SizedBox(height: CoeloSpacing.space3),
            if (options == null || _loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: CoeloSpacing.space4),
                child: Center(
                  child: SizedBox(
                    key: Key('location-institution-copy-loading'),
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (options.isEmpty)
              Text(
                'Nenhum local ativo na instituição para trazer.',
                key: const Key('location-institution-copy-empty'),
                style: theme.textTheme.bodyMedium,
              )
            else ...[
              CoeloAdminSingleSelectField<String>(
                key: const Key('location-institution-copy-option'),
                label: 'Local da instituição',
                value: selected?.id ?? '',
                options: ['', for (final option in options) option.id],
                optionLabel: (id) {
                  for (final option in options) {
                    if (option.id == id) return option.label;
                  }
                  return 'Selecione';
                },
                onChanged: (id) {
                  if (_saving) return;
                  if (id.isEmpty) {
                    setState(() {
                      _selected = null;
                      _name.text = '';
                    });
                    return;
                  }
                  _select(options.firstWhere((option) => option.id == id));
                },
              ),
              if (_truncated)
                Padding(
                  padding: const EdgeInsets.only(top: CoeloSpacing.space2),
                  child: Text(
                    // Saying so beats letting the actor conclude the missing one
                    // does not exist.
                    'A instituição tem mais locais do que cabe nesta lista. Use a busca.',
                    key: const Key('location-institution-copy-truncated'),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
            if (selected != null) ...[
              const SizedBox(height: CoeloSpacing.space3),
              CoeloFormTextField(
                fieldKey: const Key('location-institution-copy-name'),
                controller: _name,
                labelText: 'Nome nesta unidade',
                prefixIcon: Icons.place_outlined,
                enabled: !_saving,
                maxLength: 120,
              ),
            ],
            if (_error case final message?) ...[
              const SizedBox(height: CoeloSpacing.space2),
              Semantics(
                liveRegion: true,
                child: Text(
                  message,
                  key: const Key('location-institution-copy-error'),
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            ],
            const Spacer(),
            SuperadminFormActionFooter(
              tertiaryAction: TextButton(
                key: const Key('location-institution-copy-cancel'),
                onPressed: _saving ? null : widget.onCancel,
                child: const Text('Cancelar'),
              ),
              continuationActions: [
                FilledButton(
                  key: const Key('location-institution-copy-confirm'),
                  onPressed: selected == null || _saving ? null : () => unawaited(_copy()),
                  child: Text(_saving ? 'Trazendo…' : 'Trazer para a unidade'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
