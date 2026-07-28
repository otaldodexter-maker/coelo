import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

final class SuperadminChatRecipientPicker extends StatefulWidget {
  const SuperadminChatRecipientPicker({
    required this.options,
    required this.onConfirmed,
    super.key,
  });

  final List<CoeloAdminContextOption> options;
  final ValueChanged<List<CoeloAdminContextOption>> onConfirmed;

  @override
  State<SuperadminChatRecipientPicker> createState() => _SuperadminChatRecipientPickerState();
}

final class _SuperadminChatRecipientPickerState extends State<SuperadminChatRecipientPicker> {
  final _reviewFocusNode = FocusNode(debugLabel: 'Revisar envio em massa');
  final _selectedIds = <String>{};

  List<({int depth, CoeloAdminContextOption option})> get _recipients =>
      _flattenOptions(widget.options);

  @override
  void dispose() {
    _reviewFocusNode.dispose();
    super.dispose();
  }

  void _toggle(CoeloAdminContextOption option, {required bool selected}) {
    setState(() {
      if (selected) {
        _selectedIds.add(option.id);
      } else {
        _selectedIds.remove(option.id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(_recipients.map((recipient) => recipient.option.id));
    });
  }

  Future<void> _review() async {
    final selected = _recipients
        .map((recipient) => recipient.option)
        .where((option) => _selectedIds.contains(option.id))
        .toList(growable: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colors = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          backgroundColor: colors.surface,
          surfaceTintColor: Colors.transparent,
          scrollable: true,
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(child: Text('Revisar envio em massa')),
              IconButton(
                tooltip: 'Fechar revisão',
                onPressed: () => Navigator.of(dialogContext).pop(false),
                style:
                    IconButton.styleFrom(
                      foregroundColor: colors.error,
                      minimumSize: const Size.square(CoeloSize.touchMin),
                      maximumSize: const Size.square(CoeloSize.touchMin),
                      shape: const CircleBorder(),
                    ).copyWith(
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (states) =>
                            states.contains(WidgetState.hovered) ||
                                states.contains(WidgetState.focused)
                            ? colors.errorContainer
                            : Colors.transparent,
                      ),
                      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                    ),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: CoeloSize.touchMin * 9),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Demonstração local', style: Theme.of(dialogContext).textTheme.titleMedium),
                const SizedBox(height: CoeloSpacing.space2),
                const Text('Nenhuma mensagem será enviada fora deste protótipo.'),
                const SizedBox(height: CoeloSpacing.space3),
                Text(_selectionLabel(selected.length)),
                const SizedBox(height: CoeloSpacing.space2),
                for (final option in selected)
                  ListTile(
                    minTileHeight: CoeloSize.touchMin,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(option.kind.icon),
                    title: Text(option.label),
                    subtitle: Text(option.kind.label),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirmar demonstração'),
            ),
          ],
        );
      },
    );

    if (!mounted) {
      return;
    }
    if (confirmed == true) {
      widget.onConfirmed(List.unmodifiable(selected));
      return;
    }
    _reviewFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final recipients = _recipients;
    final allSelected = recipients.isNotEmpty && _selectedIds.length == recipients.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: CoeloSpacing.space3,
          runSpacing: CoeloSpacing.space1,
          children: [
            Text(
              _selectionLabel(_selectedIds.length),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            TextButton(
              onPressed: allSelected ? null : _selectAll,
              child: const Text('Selecionar todos'),
            ),
          ],
        ),
        const SizedBox(height: CoeloSpacing.space2),
        Expanded(
          child: ListView.separated(
            itemCount: recipients.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final recipient = recipients[index];
              final option = recipient.option;
              final selected = _selectedIds.contains(option.id);
              return CheckboxListTile(
                key: Key('superadmin-chat-recipient-${option.id}'),
                value: selected,
                onChanged: (value) => _toggle(option, selected: value ?? false),
                minTileHeight: CoeloSize.touchMin,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsetsDirectional.only(
                  start: CoeloSpacing.space3 + recipient.depth * CoeloSpacing.space4,
                  end: CoeloSpacing.space3,
                ),
                title: Text(option.label),
                subtitle: Text(
                  [
                    option.kind.label,
                    if (option.subtitle case final subtitle? when subtitle.isNotEmpty) subtitle,
                  ].join(' · '),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: CoeloSpacing.space3),
        FilledButton(
          focusNode: _reviewFocusNode,
          onPressed: _selectedIds.isEmpty ? null : _review,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(CoeloSize.touchMin)),
          child: const Text('Revisar envio'),
        ),
      ],
    );
  }
}

List<({int depth, CoeloAdminContextOption option})> _flattenOptions(
  List<CoeloAdminContextOption> options, {
  int depth = 0,
}) {
  return [
    for (final option in options) ...[
      (depth: depth, option: option),
      ..._flattenOptions(option.children, depth: depth + 1),
    ],
  ];
}

String _selectionLabel(int count) =>
    count == 1 ? '1 destinatário selecionado' : '$count destinatários selecionados';
