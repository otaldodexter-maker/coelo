import 'package:coelo_api/locations.dart';
import 'package:coelo_domain/locations.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../domain/location_catalog_writer.dart';
import 'location_form_panel.dart' show newLocationRequestId;

/// Duplicates one catalog entry under a new name, in the same catalog.
///
/// Everything except the name comes from the source, server-side, so a copy
/// cannot drift from what it copied. Copying into another unit is possible in
/// the catalog but not offered here: choosing a target unit needs a unit list
/// this screen does not read, and a picker fed by guesswork would be worse than
/// its absence.
class LocationCopyDialog extends StatefulWidget {
  const LocationCopyDialog({
    required this.source,
    required this.writer,
    this.requestIdFactory,
    super.key,
  });

  final LocationCatalogEntry source;
  final LocationCatalogWriter writer;
  final String Function()? requestIdFactory;

  @override
  State<LocationCopyDialog> createState() => _LocationCopyDialogState();
}

class _LocationCopyDialogState extends State<LocationCopyDialog> {
  late final TextEditingController _name = TextEditingController(
    text: _suggested(widget.source.name),
  );
  bool _saving = false;
  String? _error;
  String? _requestId;

  /// A copy needs a name of its own, and the catalog refuses one that matches a
  /// live sibling. Suggesting the obvious variant saves a refusal, and the
  /// suggestion stays editable because it is a suggestion.
  static String _suggested(String name) {
    const suffix = ' (cópia)';
    final candidate = '$name$suffix';
    return candidate.length <= 120 ? candidate : name.substring(0, 120 - suffix.length) + suffix;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    if (_saving) return;
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Informe o nome da cópia.');
      return;
    }
    final requestId = _requestId ??= (widget.requestIdFactory ?? newLocationRequestId)();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final entry = await widget.writer.copy(
        sourceId: widget.source.id,
        sourceInstitutionId: widget.source.scope.institutionId,
        targetScope: widget.source.scope,
        name: _name.text,
        requestId: requestId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(entry);
    } on LocationWriteRejectedException {
      // The name is the only thing this dialog sends, so a rejection is about
      // the name and the next attempt is a new request.
      _requestId = null;
      _fail('Já existe um local ativo com esse nome. Escolha outro.');
    } on LocationWriteDeniedException {
      _fail('Você não tem permissão para duplicar locais neste catálogo.');
    } on LocationWriteConflictException {
      _fail('Este envio já foi usado com outros dados. Feche e tente de novo.');
    } on Object {
      _fail('Não foi possível duplicar. Tente novamente.');
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
    return AlertDialog(
      key: const Key('location-copy-dialog'),
      title: const Text('Duplicar local'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A cópia nasce ativa, no mesmo catálogo, com o tipo, o andar, o endereço e a '
            'visibilidade de "${widget.source.name}". Só o nome muda.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: CoeloSpacing.space4),
          CoeloFormTextField(
            fieldKey: const Key('location-copy-name'),
            controller: _name,
            labelText: 'Nome da cópia',
            prefixIcon: Icons.copy_rounded,
            maxLength: 120,
            enabled: !_saving,
          ),
          if (_error case final message?) ...[
            const SizedBox(height: CoeloSpacing.space2),
            Semantics(
              liveRegion: true,
              child: Text(
                message,
                key: const Key('location-copy-error'),
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          key: const Key('location-copy-cancel'),
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('location-copy-confirm'),
          onPressed: _saving ? null : _copy,
          child: Text(_saving ? 'Duplicando…' : 'Duplicar'),
        ),
      ],
    );
  }
}
