import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../chat_controller.dart';
import '../chat_models.dart';
import 'superadmin_chat_hierarchy_selector.dart';
import 'superadmin_chat_surface_primitives.dart';

enum SuperadminChatMessageFlow { single, bulk }

final class SuperadminChatMessageDialog extends StatefulWidget {
  const SuperadminChatMessageDialog({required this.controller, required this.options, super.key});

  final SuperadminChatController controller;
  final List<SuperadminChatContextOption> options;

  @override
  State<SuperadminChatMessageDialog> createState() => _SuperadminChatMessageDialogState();
}

final class _SuperadminChatMessageDialogState extends State<SuperadminChatMessageDialog> {
  final _message = TextEditingController();
  final _selected = <String>{};
  final _attachments = <ChatAttachmentKind>{};
  var _mode = SuperadminChatMessageFlow.single;
  var _step = 0;

  List<_Recipient> get _recipients => _flatten(widget.options);

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SuperadminChatDialogFrame(
      title: _step == 2 ? 'Revisar envio privado' : 'Nova mensagem',
      subtitle: 'Demonstração local',
      onClose: () => Navigator.pop(context),
      footer: _footer(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_step == 0)
            SegmentedButton<SuperadminChatMessageFlow>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: SuperadminChatMessageFlow.single,
                  label: Text('Mensagem individual'),
                ),
                ButtonSegment(value: SuperadminChatMessageFlow.bulk, label: Text('Envio em massa')),
              ],
              selected: {_mode},
              onSelectionChanged: (value) => setState(() {
                _mode = value.first;
                _selected.clear();
              }),
            ),
          const SizedBox(height: CoeloSpacing.space3),
          if (_mode == SuperadminChatMessageFlow.single) ..._singleContent(),
          if (_mode == SuperadminChatMessageFlow.bulk) ..._bulkContent(),
        ],
      ),
    );
  }

  List<Widget> _singleContent() {
    if (_step == 0) {
      return [
        Text('Escolha com quem quer falar', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: CoeloSpacing.space2),
        SuperadminChatHierarchySelector(
          options: widget.options,
          selectedIds: _selected,
          selection: SuperadminChatHierarchySelection.single,
          showSelectAll: false,
          onChanged: (value) => setState(() {
            _selected
              ..clear()
              ..addAll(value);
          }),
        ),
      ];
    }
    return [
      Text(
        'Escreva para ${_labelFor(_selected.first)}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: CoeloSpacing.space2),
      _composer(),
    ];
  }

  List<Widget> _bulkContent() {
    if (_step == 0) {
      return [
        Text(
          'Escreva antes de escolher os destinatários.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: CoeloSpacing.space2),
        _composer(),
      ];
    }
    if (_step == 1) {
      return [
        Text(
          '${_selected.length} destinatários selecionados',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: CoeloSpacing.space2),
        SuperadminChatHierarchySelector(
          options: widget.options,
          selectedIds: _selected,
          onChanged: (value) => setState(() {
            _selected
              ..clear()
              ..addAll(value);
          }),
        ),
      ];
    }
    return [
      Text(
        '${_selected.length} entregas privadas independentes',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: CoeloSpacing.space2),
      Text(_message.text),
      if (_attachments.isNotEmpty) ...[
        const SizedBox(height: CoeloSpacing.space2),
        Text('${_attachments.length} anexos simulados'),
      ],
      const SizedBox(height: CoeloSpacing.space2),
      const Text('Nada será enviado, persistido ou auditado nesta demonstração local.'),
    ];
  }

  Widget _composer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('superadmin-chat-flow-message'),
          controller: _message,
          minLines: 5,
          maxLines: 8,
          decoration: const InputDecoration(labelText: 'Mensagem', alignLabelWithHint: true),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: CoeloSpacing.space2),
        Wrap(
          spacing: CoeloSpacing.space2,
          children: [
            _attachmentButton(ChatAttachmentKind.file, Icons.attach_file, 'Arquivo'),
            _attachmentButton(ChatAttachmentKind.image, Icons.image_outlined, 'Imagem'),
            _attachmentButton(ChatAttachmentKind.video, Icons.video_file_outlined, 'Vídeo'),
          ],
        ),
      ],
    );
  }

  Widget _attachmentButton(ChatAttachmentKind kind, IconData icon, String label) {
    return FilterChip(
      selected: _attachments.contains(kind),
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onSelected: (_) => setState(() {
        _attachments.contains(kind) ? _attachments.remove(kind) : _attachments.add(kind);
      }),
    );
  }

  Widget _footer() {
    if (_mode == SuperadminChatMessageFlow.single) {
      if (_step == 0) {
        return FilledButton(
          onPressed: _selected.length == 1 ? () => setState(() => _step = 1) : null,
          child: const Text('Continuar'),
        );
      }
      return FilledButton(
        onPressed: _hasContent ? _simulateSingle : null,
        child: const Text('Simular conversa'),
      );
    }
    if (_step == 0) {
      return FilledButton(
        onPressed: _hasContent ? () => setState(() => _step = 1) : null,
        child: const Text('Continuar'),
      );
    }
    if (_step == 1) {
      return FilledButton(
        onPressed: _selected.isNotEmpty ? () => setState(() => _step = 2) : null,
        child: const Text('Revisar'),
      );
    }
    return FilledButton(onPressed: _simulateBulk, child: const Text('Simular envio'));
  }

  bool get _hasContent => _message.text.trim().isNotEmpty || _attachments.isNotEmpty;

  void _simulateSingle() {
    widget.controller.startSingleConversation(
      recipientId: _selected.first,
      body: _message.text,
      attachments: _attachments,
    );
    Navigator.pop(context, true);
  }

  void _simulateBulk() {
    widget.controller.simulateBulkSend(
      recipientIds: _selected,
      body: _message.text,
      attachments: _attachments,
    );
    Navigator.pop(context, true);
  }

  String _labelFor(String id) => _recipients.firstWhere((item) => item.id == id).label;
}

final class SuperadminChatCreateGroupDialog extends StatefulWidget {
  const SuperadminChatCreateGroupDialog({
    required this.controller,
    required this.options,
    this.initialSelectedIds = const {},
    super.key,
  });

  final SuperadminChatController controller;
  final List<SuperadminChatContextOption> options;
  final Set<String> initialSelectedIds;

  @override
  State<SuperadminChatCreateGroupDialog> createState() => _SuperadminChatCreateGroupDialogState();
}

final class _SuperadminChatCreateGroupDialogState extends State<SuperadminChatCreateGroupDialog> {
  final _name = TextEditingController();
  final _selected = <String>{};
  var _reviewing = false;

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.initialSelectedIds);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SuperadminChatDialogFrame(
      title: _reviewing ? 'Revisar grupo' : 'Criar grupo',
      subtitle: 'Demonstração local · Superadmin',
      onClose: () => Navigator.pop(context),
      footer: FilledButton(
        onPressed: _reviewing
            ? _create
            : _name.text.trim().isNotEmpty && _selected.isNotEmpty
            ? () => setState(() => _reviewing = true)
            : null,
        child: Text(_reviewing ? 'Criar grupo local' : 'Revisar'),
      ),
      child: _reviewing
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_name.text, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: CoeloSpacing.space2),
                Text('${_selected.length} membros de múltiplas origens permitidos'),
                const SizedBox(height: CoeloSpacing.space2),
                for (final recipient in _flatten(
                  widget.options,
                ).where((item) => _selected.contains(item.id)))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(recipient.label),
                    subtitle: Text(recipient.detail),
                  ),
                const Text('Este fio coletivo existe somente nesta demonstração local.'),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const Key('superadmin-chat-group-name'),
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nome do grupo'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: CoeloSpacing.space3),
                SuperadminChatHierarchySelector(
                  options: widget.options,
                  selectedIds: _selected,
                  onChanged: (value) => setState(() {
                    _selected
                      ..clear()
                      ..addAll(value);
                  }),
                ),
              ],
            ),
    );
  }

  void _create() {
    final recipients = _flatten(widget.options)
        .where((item) => _selected.contains(item.id))
        .map((item) {
          return widget.controller.conversations
              .where(
                (conversation) =>
                    conversation.id == item.id ||
                    conversation.title == item.label ||
                    conversation.institution == item.label,
              )
              .firstOrNull
              ?.id;
        })
        .whereType<String>()
        .toSet();
    widget.controller.createGroup(_name.text, recipients);
    Navigator.pop(context, true);
  }
}

final class SuperadminChatInviteToGroupDialog extends StatelessWidget {
  const SuperadminChatInviteToGroupDialog({
    required this.controller,
    required this.conversation,
    super.key,
  });

  final SuperadminChatController controller;
  final SuperadminChatConversation conversation;

  @override
  Widget build(BuildContext context) {
    final groups = controller.conversations
        .where(
          (item) => item.kind == ChatContextKind.conversationGroup && item.id != conversation.id,
        )
        .toList(growable: false);
    return SuperadminChatDialogFrame(
      title: 'Convidar para grupo',
      subtitle: 'Demonstração local',
      compact: true,
      onClose: () => Navigator.pop(context, false),
      footer: OutlinedButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancelar'),
      ),
      child: groups.isEmpty
          ? const Text('Crie um grupo antes de convidar esta conversa.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Escolha o grupo que receberá o convite.'),
                const SizedBox(height: CoeloSpacing.space2),
                for (final group in groups)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.spaceHalf),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(CoeloRadius.md),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        key: Key('superadmin-chat-invite-group-${group.id}'),
                        minTileHeight: CoeloSize.touchMin,
                        hoverColor: Theme.of(context).colorScheme.primaryContainer,
                        splashColor: Colors.transparent,
                        leading: const Icon(Icons.group_outlined),
                        title: Text(group.title),
                        subtitle: Text(group.preview),
                        onTap: () {
                          controller.inviteToGroup(group.id, {conversation.id});
                          Navigator.pop(context, true);
                        },
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

final class SuperadminChatDialogFrame extends StatelessWidget {
  const SuperadminChatDialogFrame({
    required this.title,
    required this.subtitle,
    required this.onClose,
    required this.child,
    required this.footer,
    this.compact = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final VoidCallback onClose;
  final Widget child;
  final Widget footer;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(CoeloSpacing.space3),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: CoeloSize.touchMin * 10,
          maxHeight: CoeloSize.touchMin * 14,
        ),
        child: Material(
          key: const Key('superadmin-chat-dialog-frame'),
          color: colors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CoeloRadius.lg),
            side: BorderSide(color: colors.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  CoeloSpacing.space4,
                  CoeloSpacing.space3,
                  CoeloSpacing.space2,
                  CoeloSpacing.space2,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: Theme.of(context).textTheme.titleLarge),
                          Text(
                            subtitle,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    SuperadminChatCloseButton(tooltip: 'Fechar', onPressed: onClose),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space4),
                child: Divider(
                  key: const Key('superadmin-chat-dialog-header-divider'),
                  height: 1,
                  color: colors.outlineVariant,
                ),
              ),
              if (compact)
                Padding(padding: const EdgeInsets.all(CoeloSpacing.space4), child: child)
              else
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(CoeloSpacing.space4),
                    child: child,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  CoeloSpacing.space4,
                  0,
                  CoeloSpacing.space4,
                  CoeloSpacing.space4,
                ),
                child: SizedBox(width: double.infinity, child: footer),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _Recipient {
  const _Recipient({required this.id, required this.label, required this.detail});

  final String id;
  final String label;
  final String detail;
}

List<_Recipient> _flatten(List<SuperadminChatContextOption> options, {String parent = ''}) {
  return [
    for (final option in options) ...[
      _Recipient(
        id: option.id,
        label: option.label,
        detail: [_kindLabel(option.kind), if (parent.isNotEmpty) parent].join(' · '),
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
  ChatContextKind.group => 'Grupo (Turma)',
  ChatContextKind.activity => 'Atividade',
  ChatContextKind.person => 'Pessoa',
  ChatContextKind.child => 'Criança',
  ChatContextKind.conversationGroup => 'Grupo de conversa',
};
