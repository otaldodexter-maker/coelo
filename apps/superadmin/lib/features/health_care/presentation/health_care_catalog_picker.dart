import 'dart:async';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../shared/presentation/widgets/superadmin_owned_dialogs.dart';
import '../domain/health_care.dart';

String healthCareCollectionLabel(HealthCareCatalogCollection collection) => switch (collection) {
  HealthCareCatalogCollection.food => 'alimento',
  HealthCareCatalogCollection.restriction => 'restrição',
  HealthCareCatalogCollection.guidance => 'orientação',
};

/// Abre o catálogo categorizado de uma coleção (spec 065 §5.3): busca,
/// seleção única e "Outro" com texto obrigatório. Sem [loadCatalog] só o
/// "Outro" é oferecido (ambiente sem servidor).
Future<HealthCareCatalogChoice?> showHealthCareCatalogPicker(
  BuildContext context, {
  required HealthCareCatalogCollection collection,
  HealthCareCatalogLoad? loadCatalog,
}) => Navigator.of(context, rootNavigator: true).push(
  superadminDialogRoute<HealthCareCatalogChoice>(
    context,
    builder: (_) => HealthCareCatalogPickerDialog(collection: collection, loadCatalog: loadCatalog),
  ),
);

final class HealthCareCatalogPickerDialog extends StatefulWidget {
  const HealthCareCatalogPickerDialog({super.key, required this.collection, this.loadCatalog});

  final HealthCareCatalogCollection collection;
  final HealthCareCatalogLoad? loadCatalog;

  @override
  State<HealthCareCatalogPickerDialog> createState() => _HealthCareCatalogPickerDialogState();
}

final class _HealthCareCatalogPickerDialogState extends State<HealthCareCatalogPickerDialog> {
  final _search = TextEditingController();
  final _otherText = TextEditingController();
  Timer? _debounce;
  int _generation = 0;
  List<HealthCareProfileCatalogGroup> _groups = const [];
  bool _loading = false;
  bool _otherSelected = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _otherText.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final loadCatalog = widget.loadCatalog;
    if (loadCatalog == null) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalog = await loadCatalog(widget.collection, _search.text);
      if (!mounted || generation != _generation) return;
      setState(() {
        _groups = catalog.groups;
        _loading = false;
      });
    } on Object {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = 'Não foi possível carregar o catálogo.';
        _loading = false;
      });
    }
  }

  void _pick(HealthCareProfileCatalogItem item) =>
      Navigator.of(context).pop(HealthCareCatalogChoice(catalogItemId: item.id, label: item.label));

  void _confirmOther() {
    final text = _otherText.text.trim();
    if (text.isEmpty) return;
    Navigator.of(
      context,
    ).pop(HealthCareCatalogChoice(catalogItemId: 'other', label: text, otherText: text));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final noun = healthCareCollectionLabel(widget.collection);
    return AlertDialog(
      key: const Key('health-care-catalog-picker'),
      title: Text('Adicionar $noun'),
      content: SizedBox(
        width: 520,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.loadCatalog != null) ...[
              CoeloSearchField(
                key: const Key('health-care-catalog-search'),
                controller: _search,
                hintText: 'Buscar por nome',
                semanticLabel: 'Buscar $noun por nome',
                onChanged: (_) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 300), _load);
                },
              ),
              const SizedBox(height: CoeloSpacing.space3),
            ],
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      children: [
                        ListTile(
                          key: const Key('health-care-catalog-item-other'),
                          dense: true,
                          leading: Icon(
                            _otherSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                          ),
                          title: const Text('Outro'),
                          subtitle: const Text('Descreva com suas palavras'),
                          onTap: () => setState(() => _otherSelected = true),
                        ),
                        if (_otherSelected)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space3),
                            child: CoeloFormTextField(
                              key: const Key('health-care-catalog-other-text'),
                              controller: _otherText,
                              labelText: 'Qual $noun?',
                              prefixIcon: Icons.edit_outlined,
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        const Divider(),
                        if (_error case final message?)
                          Padding(
                            padding: const EdgeInsets.all(CoeloSpacing.space3),
                            child: Text(message, style: theme.textTheme.bodyMedium),
                          ),
                        for (final group in _groups) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              CoeloSpacing.space3,
                              CoeloSpacing.space3,
                              CoeloSpacing.space3,
                              CoeloSpacing.space1,
                            ),
                            child: Text(
                              group.label,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          for (final item in group.items)
                            ListTile(
                              key: Key('health-care-catalog-item-${item.id}'),
                              dense: true,
                              title: Text(item.label),
                              onTap: () => _pick(item),
                            ),
                        ],
                        if (_groups.isEmpty && widget.loadCatalog != null && _error == null)
                          Padding(
                            padding: const EdgeInsets.all(CoeloSpacing.space3),
                            child: Text('Nenhum resultado', style: theme.textTheme.bodyMedium),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        if (_otherSelected)
          FilledButton(
            key: const Key('health-care-catalog-confirm-other'),
            onPressed: _otherText.text.trim().isEmpty ? null : _confirmOther,
            child: const Text('Adicionar'),
          ),
      ],
    );
  }
}
