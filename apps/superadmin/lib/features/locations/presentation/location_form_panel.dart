import 'dart:math' as math;

import 'package:coelo_api/locations.dart';
import 'package:coelo_domain/locations.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../domain/location_catalog_reader.dart';
import '../domain/location_catalog_writer.dart';
import 'location_read_widgets.dart';

/// Creates one location in the catalog of a single owner.
///
/// The owner is fixed by the screen, never typed: a form that let an actor
/// choose the institution would be asking the client to decide ownership. The
/// server revalidates the scope anyway.
///
/// Saving is idempotent by request id. The id is minted once per attempt, so a
/// second tap or a retry after a timeout returns the location already created
/// instead of creating another one.
class LocationFormPanel extends StatefulWidget {
  const LocationFormPanel({
    required this.scope,
    required this.onCancel,
    required this.onCreated,
    this.writer = const UnavailableLocationCatalogWriter(),
    this.sessionAvailable = false,
    this.requestIdFactory,
    super.key,
  });

  final LocationScope scope;
  final VoidCallback onCancel;
  final ValueChanged<LocationCatalogEntry> onCreated;
  final LocationCatalogWriter writer;
  final bool sessionAvailable;
  final String Function()? requestIdFactory;

  @override
  State<LocationFormPanel> createState() => _LocationFormPanelState();
}

String newLocationRequestId() {
  final random = math.Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final value = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${value.substring(0, 8)}-${value.substring(8, 12)}-${value.substring(12, 16)}-'
      '${value.substring(16, 20)}-${value.substring(20)}';
}

class _LocationFormPanelState extends State<LocationFormPanel> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _floor = TextEditingController();
  final _postalCode = TextEditingController();
  final _state = TextEditingController();
  final _city = TextEditingController();
  final _district = TextEditingController();
  final _street = TextEditingController();
  final _number = TextEditingController();
  final _complement = TextEditingController();

  LocationKind _kind = LocationKind.internal;
  LocationVisibility _visibility = LocationVisibility.team;
  bool _saving = false;
  String? _error;
  String? _nameError;

  /// Kept across retries so a repeated attempt cannot create a second location.
  String? _requestId;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _description,
      _floor,
      _postalCode,
      _state,
      _city,
      _district,
      _street,
      _number,
      _complement,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, String?>? _address() {
    if (_kind == LocationKind.internal) return null;
    return {
      'country': 'Brasil',
      'postal_code': _postalCode.text,
      'state': _state.text,
      'city': _city.text,
      'district': _district.text,
      'street': _street.text,
      'number': _number.text,
      'complement': _complement.text,
    };
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_name.text.trim().isEmpty) {
      setState(() {
        _nameError = 'Informe o nome do local.';
        _error = null;
      });
      return;
    }
    final requestId = _requestId ??= (widget.requestIdFactory ?? newLocationRequestId)();
    setState(() {
      _saving = true;
      _error = null;
      _nameError = null;
    });
    try {
      final entry = await widget.writer.create(
        draft: LocationWriteDraft(
          scope: widget.scope,
          kind: _kind,
          name: _name.text,
          visibility: _visibility,
          description: _description.text,
          floor: _floor.text,
          address: _address(),
        ),
        requestId: requestId,
      );
      if (!mounted) return;
      widget.onCreated(entry);
    } on LocationWriteRejectedException {
      // The payload is wrong, so a new attempt is a new request.
      _requestId = null;
      _fail('Revise os dados do local. O endereço é obrigatório para local externo.');
    } on LocationWriteDeniedException {
      _fail('Você não tem permissão para criar locais neste catálogo.');
    } on LocationWriteConflictException {
      _fail('Este envio já foi usado com outros dados. Recomece o cadastro.');
    } on Object {
      _fail('Não foi possível salvar. Tente novamente.');
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
      final padding = compact ? CoeloSpacing.space4 : CoeloSpacing.space6;
      final theme = Theme.of(context);
      return ColoredBox(
        color: theme.colorScheme.surface,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                key: const Key('location-form-content'),
                padding: EdgeInsets.all(padding),
                children: [
                  Semantics(
                    header: true,
                    child: Text('Novo local', style: theme.textTheme.headlineSmall),
                  ),
                  Text(locationScopeLabel(widget.scope), style: theme.textTheme.bodyLarge),
                  const SizedBox(height: CoeloSpacing.space4),
                  if (!widget.sessionAvailable)
                    const LocationReadStatePanel(
                      state: LocationReadState.denied,
                      prefix: 'location-form',
                    )
                  else ...[
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: CoeloSpacing.space4),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            key: const Key('location-form-error'),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                    CoeloFormTextField(
                      fieldKey: const Key('location-form-name'),
                      controller: _name,
                      labelText: 'Nome do local',
                      prefixIcon: Icons.place_outlined,
                      enabled: !_saving,
                      maxLength: 120,
                      errorText: _nameError,
                    ),
                    const SizedBox(height: CoeloSpacing.space3),
                    CoeloAdminSingleSelectField<LocationKind>(
                      key: const Key('location-form-kind'),
                      label: 'Tipo',
                      value: _kind,
                      options: LocationKind.values,
                      optionLabel: locationKindLabel,
                      onChanged: _saving ? (_) {} : (value) => setState(() => _kind = value),
                      prefixIcon: Icons.category_outlined,
                      enabled: !_saving,
                    ),
                    const SizedBox(height: CoeloSpacing.space3),
                    CoeloAdminSingleSelectField<LocationVisibility>(
                      key: const Key('location-form-visibility'),
                      label: 'Visibilidade',
                      value: _visibility,
                      options: LocationVisibility.values,
                      optionLabel: locationVisibilityLabel,
                      onChanged: _saving ? (_) {} : (value) => setState(() => _visibility = value),
                      prefixIcon: Icons.visibility_outlined,
                      enabled: !_saving,
                    ),
                    const SizedBox(height: CoeloSpacing.space3),
                    CoeloFormTextField(
                      fieldKey: const Key('location-form-floor'),
                      controller: _floor,
                      labelText: 'Andar (opcional)',
                      prefixIcon: Icons.stairs_outlined,
                      enabled: !_saving,
                      maxLength: 120,
                    ),
                    const SizedBox(height: CoeloSpacing.space3),
                    CoeloFormTextField(
                      fieldKey: const Key('location-form-description'),
                      controller: _description,
                      labelText: 'Descrição (opcional)',
                      prefixIcon: Icons.notes_outlined,
                      enabled: !_saving,
                      maxLines: 3,
                      maxLength: 500,
                    ),
                    if (_kind == LocationKind.external) ...[
                      const SizedBox(height: CoeloSpacing.space5),
                      Text('Endereço', style: theme.textTheme.titleMedium),
                      Text('Obrigatório para local externo.', style: theme.textTheme.bodySmall),
                      const SizedBox(height: CoeloSpacing.space3),
                      for (final field
                          in <({Key key, TextEditingController controller, String label})>[
                            (
                              key: const Key('location-form-postal-code'),
                              controller: _postalCode,
                              label: 'CEP (somente números)',
                            ),
                            (
                              key: const Key('location-form-state'),
                              controller: _state,
                              label: 'Estado',
                            ),
                            (
                              key: const Key('location-form-city'),
                              controller: _city,
                              label: 'Cidade',
                            ),
                            (
                              key: const Key('location-form-district'),
                              controller: _district,
                              label: 'Bairro',
                            ),
                            (
                              key: const Key('location-form-street'),
                              controller: _street,
                              label: 'Logradouro',
                            ),
                            (
                              key: const Key('location-form-number'),
                              controller: _number,
                              label: 'Número',
                            ),
                            (
                              key: const Key('location-form-complement'),
                              controller: _complement,
                              label: 'Complemento',
                            ),
                          ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: CoeloSpacing.space3),
                          child: CoeloFormTextField(
                            fieldKey: field.key,
                            controller: field.controller,
                            labelText: field.label,
                            prefixIcon: Icons.home_outlined,
                            enabled: !_saving,
                          ),
                        ),
                    ],
                  ],
                ],
              ),
            ),
            SuperadminFormActionFooter(
              tertiaryAction: TextButton(
                key: const Key('location-form-cancel'),
                onPressed: _saving ? null : widget.onCancel,
                child: const Text('Cancelar'),
              ),
              continuationActions: [
                FilledButton(
                  key: const Key('location-form-save'),
                  onPressed: _saving || !widget.sessionAvailable ? null : _save,
                  child: _saving
                      ? const SizedBox.square(
                          dimension: CoeloSize.iconSm,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Criar local'),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
