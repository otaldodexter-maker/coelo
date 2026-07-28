import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../chat_controller.dart';
import '../chat_models.dart';

final class SuperadminChatRecipientPicker extends StatefulWidget {
  const SuperadminChatRecipientPicker({
    required this.controller,
    required this.options,
    required this.onConfirmed,
    super.key,
  });

  final SuperadminChatController controller;
  final List<SuperadminChatContextOption> options;
  final ValueChanged<Set<String>> onConfirmed;

  @override
  State<SuperadminChatRecipientPicker> createState() => _SuperadminChatRecipientPickerState();
}

final class _SuperadminChatRecipientPickerState extends State<SuperadminChatRecipientPicker> {
  late final List<_Recipient> _recipients = [
    ..._flatten(widget.options),
    ...widget.controller.conversations
        .where((item) => item.kind == ChatContextKind.person)
        .map(
          (item) => _Recipient(
            id: item.id,
            label: item.title,
            detail: 'Pessoa · ${item.context}',
            icon: Icons.person_outline_rounded,
          ),
        ),
  ];

  @override
  Widget build(BuildContext context) {
    final selected = widget.controller.selectedRecipientIds;
    return SafeArea(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: CoeloSize.touchMin * 9),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(CoeloSpacing.space4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Nova mensagem', style: Theme.of(context).textTheme.titleLarge),
                        Text(
                          'Envio em massa · demonstração local',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar destinatários',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${selected.length} destinatários selecionados',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      widget.controller.selectAllRecipients(_recipients.map((item) => item.id));
                      setState(() {});
                    },
                    child: const Text('Selecionar todos'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _recipients.length,
                itemBuilder: (context, index) {
                  final recipient = _recipients[index];
                  return CheckboxListTile(
                    key: Key('superadmin-chat-recipient-${recipient.id}'),
                    value: selected.contains(recipient.id),
                    onChanged: (_) {
                      widget.controller.toggleRecipient(recipient.id);
                      setState(() {});
                    },
                    secondary: Icon(recipient.icon),
                    title: Text(recipient.label),
                    subtitle: Text(recipient.detail),
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(CoeloSpacing.space4),
              child: FilledButton.icon(
                onPressed: selected.isEmpty
                    ? null
                    : () => widget.onConfirmed(Set.unmodifiable(selected)),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(CoeloSize.touchMin),
                ),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Revisar envio'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _Recipient {
  const _Recipient({
    required this.id,
    required this.label,
    required this.detail,
    required this.icon,
  });

  final String id;
  final String label;
  final String detail;
  final IconData icon;
}

List<_Recipient> _flatten(List<SuperadminChatContextOption> options, {String parent = ''}) {
  return [
    for (final option in options) ...[
      _Recipient(
        id: option.id,
        label: option.label,
        detail: [_kindLabel(option.kind), if (parent.isNotEmpty) parent].join(' · '),
        icon: _kindIcon(option.kind),
      ),
      ..._flatten(
        option.children,
        parent: parent.isEmpty ? option.label : '$parent / ${option.label}',
      ),
    ],
  ];
}

String _kindLabel(ChatContextKind kind) => switch (kind) {
  ChatContextKind.institution => 'Instituição',
  ChatContextKind.unit => 'Unidade',
  ChatContextKind.group => 'Grupo/Turma',
  ChatContextKind.activity => 'Atividade',
  ChatContextKind.person => 'Pessoa',
};

IconData _kindIcon(ChatContextKind kind) => switch (kind) {
  ChatContextKind.institution => Icons.account_balance_outlined,
  ChatContextKind.unit => Icons.apartment_outlined,
  ChatContextKind.group => Icons.groups_outlined,
  ChatContextKind.activity => Icons.local_activity_outlined,
  ChatContextKind.person => Icons.person_outline_rounded,
};
