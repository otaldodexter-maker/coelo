import 'dart:math';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/shell/superadmin_shell.dart';
import '../../auth/domain/logout_action.dart';
import '../domain/student_link.dart';

/// Gestão do vínculo de um aluno: onde ele está e as quatro ações que mudam
/// isso.
///
/// Até aqui a rota `/students/:childContextId/manage` abria uma tela de
/// indisponível, embora as quatro ações estejam no MVP. A tela mostra o estado
/// atual primeiro — ninguém transfere ou revoga sem ver de onde — e só então
/// oferece as ações, cada uma sobre um vínculo concreto.
///
/// Nada aqui autoriza. `canManage` decide o que desenhar; quem decide o que
/// acontece é o servidor, que refaz ator, capacidade, tenant e hierarquia em
/// cada comando. Um `canManage` forjado no cliente não move criança nenhuma.
final class StudentManagePage extends StatefulWidget {
  const StudentManagePage({
    required this.repository,
    required this.childContextId,
    required this.logout,
    this.onBack,
    this.loadGroupOptions,
    super.key,
  });

  final StudentLinkRepository repository;
  final String childContextId;
  final LogoutAction logout;
  final VoidCallback? onBack;

  /// Turmas da instituição para vincular/transferir (P36). Sem loader, só
  /// revogar e editar vigência ficam disponíveis.
  final StudentGroupOptionsLoader? loadGroupOptions;

  @override
  State<StudentManagePage> createState() => _StudentManagePageState();
}

class _StudentManagePageState extends State<StudentManagePage> {
  StudentLinks? _links;
  String? _failure;
  bool _loading = true;
  String? _busyUnitLinkId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final links = await widget.repository.fetchLinks(widget.childContextId);
      if (!mounted) return;
      setState(() {
        _links = links;
        _loading = false;
      });
    } on StudentLinkException catch (error) {
      if (!mounted) return;
      setState(() {
        _failure = error.message;
        _loading = false;
      });
    }
  }

  /// Revogar tira a criança da unidade e encerra as turmas dela ali. Pede
  /// motivo porque o motivo vai para a auditoria, e confirma porque o efeito
  /// alcança presença, rotina e cuidado daquela unidade.
  Future<void> _revoke(StudentUnitLink unitLink) async {
    final reason = await _askReason(
      title: 'Revogar o vínculo com ${unitLink.unitName}?',
      body:
          'A criança deixa de pertencer a esta unidade e às turmas dela. '
          'O histórico é preservado: presença, rotina e cuidado já registrados '
          'continuam apontando para este vínculo.',
      confirmLabel: 'Revogar',
      dialogKey: const Key('student-revoke-dialog'),
    );
    if (reason == null || !mounted) return;
    setState(() => _busyUnitLinkId = unitLink.unitLinkId);
    try {
      await widget.repository.revoke(
        requestId: newStudentRequestId(),
        childContextId: widget.childContextId,
        unitId: unitLink.unitId,
        reason: reason,
      );
      if (!mounted) return;
      await _load();
      if (mounted) _notify('Vínculo revogado.');
    } on StudentLinkException catch (error) {
      if (mounted) _notify(error.message);
    } finally {
      if (mounted) setState(() => _busyUnitLinkId = null);
    }
  }

  /// Vincular a criança a uma turma (e à unidade dela). P36: nunca solta.
  Future<void> _link() async {
    final links = _links;
    final loader = widget.loadGroupOptions;
    if (links == null || loader == null) return;
    final choice = await showDialog<_GroupChoice>(
      context: context,
      builder: (_) => _GroupChoiceDialog(
        dialogKey: const Key('student-link-dialog'),
        title: 'Vincular a uma turma',
        body: 'A criança passa a pertencer à unidade da turma escolhida.',
        confirmLabel: 'Vincular',
        options: loader(links.institutionId),
        askReason: false,
      ),
    );
    if (choice == null || !mounted) return;
    setState(() => _busyUnitLinkId = 'link');
    try {
      await widget.repository.link(
        requestId: newStudentRequestId(),
        childContextId: widget.childContextId,
        unitId: choice.option.unitId,
        groupId: choice.option.groupId,
      );
      if (!mounted) return;
      await _load();
      if (mounted) _notify('Vínculo criado.');
    } on StudentLinkException catch (error) {
      if (mounted) _notify(error.message);
    } finally {
      if (mounted) setState(() => _busyUnitLinkId = null);
    }
  }

  /// Transferir para uma turma de outra unidade, com motivo (auditoria).
  Future<void> _transfer(StudentUnitLink unitLink) async {
    final links = _links;
    final loader = widget.loadGroupOptions;
    if (links == null || loader == null) return;
    final choice = await showDialog<_GroupChoice>(
      context: context,
      builder: (_) => _GroupChoiceDialog(
        dialogKey: const Key('student-transfer-dialog'),
        title: 'Transferir de ${unitLink.unitName}',
        body: 'As turmas da unidade atual encerram e a criança passa à turma escolhida.',
        confirmLabel: 'Transferir',
        options: loader(
          links.institutionId,
        ).then((options) => options.where((option) => option.unitId != unitLink.unitId).toList()),
        askReason: true,
      ),
    );
    if (choice == null || !mounted) return;
    setState(() => _busyUnitLinkId = unitLink.unitLinkId);
    try {
      await widget.repository.transfer(
        requestId: newStudentRequestId(),
        childContextId: widget.childContextId,
        fromUnitId: unitLink.unitId,
        toUnitId: choice.option.unitId,
        toGroupId: choice.option.groupId,
        reason: choice.reason,
      );
      if (!mounted) return;
      await _load();
      if (mounted) _notify('Criança transferida.');
    } on StudentLinkException catch (error) {
      if (mounted) _notify(error.message);
    } finally {
      if (mounted) setState(() => _busyUnitLinkId = null);
    }
  }

  /// Ajustar a vigência da criança numa turma (início e fim).
  Future<void> _edit(StudentUnitLink unitLink, StudentGroupLink groupLink) async {
    final period = await showDialog<_PeriodChoice>(
      context: context,
      builder: (_) => _PeriodDialog(groupLink: groupLink),
    );
    if (period == null || !mounted) return;
    setState(() => _busyUnitLinkId = unitLink.unitLinkId);
    try {
      await widget.repository.edit(
        requestId: newStudentRequestId(),
        childContextId: widget.childContextId,
        unitId: unitLink.unitId,
        groupId: groupLink.groupId,
        startsAt: period.startsAt,
        endsAt: period.endsAt,
        clearEndsAt: period.clearEndsAt,
      );
      if (!mounted) return;
      await _load();
      if (mounted) _notify('Vigência atualizada.');
    } on StudentLinkException catch (error) {
      if (mounted) _notify(error.message);
    } finally {
      if (mounted) setState(() => _busyUnitLinkId = null);
    }
  }

  /// O controlador do campo vive DENTRO do diálogo, não aqui.
  ///
  /// Descartá-lo assim que `showDialog` retorna parece certo e não é: a
  /// animação de saída ainda reconstrói o diálogo depois disso, e o campo
  /// tenta ouvir um controlador já descartado.
  Future<String?> _askReason({
    required String title,
    required String body,
    required String confirmLabel,
    required Key dialogKey,
  }) => showDialog<String>(
    context: context,
    builder: (dialogContext) =>
        _ReasonDialog(dialogKey: dialogKey, title: title, body: body, confirmLabel: confirmLabel),
  );

  void _notify(String message) =>
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    currentDestination: 'students',
    title: _links?.displayName ?? 'Aluno',
    subtitle: 'Unidades, turmas e vigência do vínculo.',
    child: ColoredBox(color: Theme.of(context).colorScheme.surface, child: _body()),
  );

  Widget _body() {
    if (_loading) {
      return const CoeloStatePanel(
        key: Key('student-manage-loading'),
        title: 'Carregando vínculo',
        message: 'Aguarde enquanto os dados autorizados são carregados.',
        loading: true,
      );
    }
    final failure = _failure;
    if (failure != null) {
      return CoeloStatePanel(
        key: const Key('student-manage-unavailable'),
        title: 'Vínculo indisponível',
        message: failure,
        icon: Icons.lock_outline_rounded,
        actionLabel: 'Tentar novamente',
        onAction: _load,
      );
    }
    final links = _links!;
    final canLink = links.canManage && widget.loadGroupOptions != null;
    if (links.unitLinks.isEmpty) {
      return CoeloStatePanel(
        key: const Key('student-manage-empty'),
        title: 'Sem vínculo nesta instituição',
        message: 'Esta criança ainda não foi vinculada a nenhuma unidade.',
        icon: Icons.link_off_rounded,
        actionLabel: canLink ? 'Vincular a uma turma' : null,
        onAction: canLink ? _link : null,
      );
    }
    return ListView(
      key: const Key('student-manage-scroll'),
      padding: const EdgeInsets.all(CoeloSpacing.space5),
      children: [
        if (canLink) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const Key('student-link-button'),
              onPressed: _busyUnitLinkId == null ? _link : null,
              icon: const Icon(Icons.add_link_rounded),
              label: const Text('Vincular a uma turma'),
            ),
          ),
          const SizedBox(height: CoeloSpacing.space4),
        ],
        for (final unitLink in links.unitLinks) ...[
          _UnitLinkCard(
            unitLink: unitLink,
            canManage: links.canManage,
            busy: _busyUnitLinkId == unitLink.unitLinkId,
            onRevoke: () => _revoke(unitLink),
            onTransfer: canLink ? () => _transfer(unitLink) : null,
            onEditGroup: (groupLink) => _edit(unitLink, groupLink),
          ),
          const SizedBox(height: CoeloSpacing.space4),
        ],
      ],
    );
  }
}

final class _UnitLinkCard extends StatelessWidget {
  const _UnitLinkCard({
    required this.unitLink,
    required this.canManage,
    required this.busy,
    required this.onRevoke,
    required this.onTransfer,
    required this.onEditGroup,
  });

  final StudentUnitLink unitLink;
  final bool canManage;
  final bool busy;
  final VoidCallback onRevoke;
  final VoidCallback? onTransfer;
  final ValueChanged<StudentGroupLink> onEditGroup;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      key: Key('student-unit-link-${unitLink.unitLinkId}'),
      padding: const EdgeInsets.all(CoeloSpacing.space5),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(unitLink.unitName, style: text.titleMedium),
          const SizedBox(height: CoeloSpacing.space1),
          Text(
            // Um vínculo revogado continua na lista, porque revogar não apaga.
            // Dizer o estado por texto, e não só por cor, é o contrato do
            // design system.
            switch (unitLink.status) {
              'active' => 'Vínculo ativo',
              'awaiting_allocation' => 'Aguardando alocação em turma',
              'revoked' => 'Vínculo revogado',
              'inactive' => 'Vínculo encerrado',
              _ => 'Vínculo pendente',
            },
            style: text.bodyMedium,
          ),
          if (unitLink.groupLinks.isNotEmpty) ...[
            const SizedBox(height: CoeloSpacing.space4),
            Text('Turmas', style: text.labelLarge),
            const SizedBox(height: CoeloSpacing.space2),
            for (final groupLink in unitLink.groupLinks)
              Padding(
                padding: const EdgeInsets.only(bottom: CoeloSpacing.space1),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        groupLink.isActive
                            ? '${groupLink.groupName}${_period(groupLink)}'
                            : '${groupLink.groupName} — encerrada',
                        style: text.bodyMedium,
                      ),
                    ),
                    if (canManage && unitLink.isCurrent && groupLink.isActive)
                      IconButton(
                        key: Key('student-edit-${groupLink.groupLinkId}'),
                        tooltip: 'Editar vigência',
                        onPressed: busy ? null : () => onEditGroup(groupLink),
                        icon: const Icon(Icons.edit_calendar_outlined),
                      ),
                  ],
                ),
              ),
          ],
          if (canManage && unitLink.isCurrent) ...[
            const SizedBox(height: CoeloSpacing.space4),
            Wrap(
              spacing: CoeloSpacing.space2,
              children: [
                if (onTransfer != null)
                  TextButton.icon(
                    key: Key('student-transfer-${unitLink.unitLinkId}'),
                    onPressed: busy ? null : onTransfer,
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: const Text('Transferir'),
                  ),
                TextButton.icon(
                  key: Key('student-revoke-${unitLink.unitLinkId}'),
                  onPressed: busy ? null : onRevoke,
                  icon: const Icon(Icons.link_off_rounded),
                  label: Text(busy ? 'Revogando…' : 'Revogar vínculo'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

final class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.dialogKey,
    required this.title,
    required this.body,
    required this.confirmLabel,
  });

  final Key dialogKey;
  final String title;
  final String body;
  final String confirmLabel;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reason = _controller.text.trim();
    return CoeloAdminDialogShell(
      dialogKey: widget.dialogKey,
      title: widget.title,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.body),
          const SizedBox(height: CoeloSpacing.space4),
          CoeloFormTextField(
            fieldKey: const Key('student-reason-field'),
            controller: _controller,
            labelText: 'Motivo',
            prefixIcon: Icons.notes_rounded,
            hintText: 'Registre por que o vínculo está mudando.',
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      secondaryAction: OutlinedButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      primaryAction: FilledButton(
        key: const Key('student-reason-confirm'),
        // O motivo é obrigatório no servidor; desabilitar aqui evita uma ida
        // ao banco que voltaria como erro de validação.
        onPressed: reason.isEmpty ? null : () => Navigator.of(context).pop(reason),
        child: Text(widget.confirmLabel),
      ),
    );
  }
}

String _period(StudentGroupLink link) {
  if (link.startsAt == null && link.endsAt == null) return '';
  final start = link.startsAt == null ? '' : ' de ${_formatDate(link.startsAt!)}';
  final end = link.endsAt == null ? '' : ' até ${_formatDate(link.endsAt!)}';
  return ' —$start$end';
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year}';
}

/// dd/mm/aaaa -> data local; nulo quando vazio ou inválido.
DateTime? _parseDate(String raw) {
  final match = RegExp(r'^\s*(\d{2})/(\d{2})/(\d{4})\s*$').firstMatch(raw);
  if (match == null) return null;
  final day = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final year = int.parse(match.group(3)!);
  final value = DateTime(year, month, day);
  return value.month == month && value.day == day ? value : null;
}

final class _GroupChoice {
  const _GroupChoice(this.option, this.reason);
  final StudentGroupOption option;
  final String reason;
}

/// Escolha de turma (com unidade) para vincular ou transferir.
final class _GroupChoiceDialog extends StatefulWidget {
  const _GroupChoiceDialog({
    required this.dialogKey,
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.options,
    required this.askReason,
  });

  final Key dialogKey;
  final String title;
  final String body;
  final String confirmLabel;
  final Future<List<StudentGroupOption>> options;
  final bool askReason;

  @override
  State<_GroupChoiceDialog> createState() => _GroupChoiceDialogState();
}

class _GroupChoiceDialogState extends State<_GroupChoiceDialog> {
  final _reason = TextEditingController();
  List<StudentGroupOption>? _options;
  String? _failure;
  StudentGroupOption? _selected;

  @override
  void initState() {
    super.initState();
    widget.options.then(
      (options) {
        if (mounted) setState(() => _options = options);
      },
      onError: (Object error) {
        if (mounted) setState(() => _failure = 'Não foi possível listar as turmas.');
      },
    );
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  bool get _canConfirm =>
      _selected != null && (!widget.askReason || _reason.text.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final options = _options;
    return CoeloAdminDialogShell(
      dialogKey: widget.dialogKey,
      title: widget.title,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.body),
          const SizedBox(height: CoeloSpacing.space4),
          if (_failure case final failure?)
            Text(failure, key: const Key('student-group-options-failure'))
          else if (options == null)
            const Text('Carregando turmas…')
          else if (options.isEmpty)
            const Text('Nenhuma turma disponível.', key: Key('student-group-options-empty'))
          else
            DropdownButtonFormField<StudentGroupOption>(
              key: const Key('student-group-select'),
              isExpanded: true,
              initialValue: _selected,
              decoration: const InputDecoration(labelText: 'Turma'),
              items: [
                for (final option in options)
                  DropdownMenuItem(
                    value: option,
                    child: Text(option.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) => setState(() => _selected = value),
            ),
          if (widget.askReason) ...[
            const SizedBox(height: CoeloSpacing.space4),
            CoeloFormTextField(
              fieldKey: const Key('student-reason-field'),
              controller: _reason,
              labelText: 'Motivo',
              prefixIcon: Icons.notes_rounded,
              hintText: 'Registre por que o vínculo está mudando.',
              onChanged: (_) => setState(() {}),
            ),
          ],
        ],
      ),
      secondaryAction: OutlinedButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      primaryAction: FilledButton(
        key: const Key('student-group-confirm'),
        onPressed: _canConfirm
            ? () => Navigator.of(context).pop(_GroupChoice(_selected!, _reason.text.trim()))
            : null,
        child: Text(widget.confirmLabel),
      ),
    );
  }
}

final class _PeriodChoice {
  const _PeriodChoice({this.startsAt, this.endsAt, this.clearEndsAt = false});
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool clearEndsAt;
}

/// Vigência da criança na turma: início e fim em dd/mm/aaaa; fim vazio limpa.
final class _PeriodDialog extends StatefulWidget {
  const _PeriodDialog({required this.groupLink});
  final StudentGroupLink groupLink;

  @override
  State<_PeriodDialog> createState() => _PeriodDialogState();
}

class _PeriodDialogState extends State<_PeriodDialog> {
  late final TextEditingController _start;
  late final TextEditingController _end;

  @override
  void initState() {
    super.initState();
    final link = widget.groupLink;
    _start = TextEditingController(text: link.startsAt == null ? '' : _formatDate(link.startsAt!));
    _end = TextEditingController(text: link.endsAt == null ? '' : _formatDate(link.endsAt!));
  }

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  String? _error(TextEditingController controller) =>
      controller.text.trim().isNotEmpty && _parseDate(controller.text) == null
      ? 'Use dd/mm/aaaa.'
      : null;

  bool get _valid => _error(_start) == null && _error(_end) == null;

  @override
  Widget build(BuildContext context) => CoeloAdminDialogShell(
    dialogKey: const Key('student-edit-dialog'),
    title: 'Vigência em ${widget.groupLink.groupName}',
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          key: const Key('student-edit-starts'),
          controller: _start,
          decoration: InputDecoration(labelText: 'Início (dd/mm/aaaa)', errorText: _error(_start)),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: CoeloSpacing.space3),
        TextField(
          key: const Key('student-edit-ends'),
          controller: _end,
          decoration: InputDecoration(
            labelText: 'Fim (dd/mm/aaaa, vazio = sem fim)',
            errorText: _error(_end),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    ),
    secondaryAction: OutlinedButton(
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('Cancelar'),
    ),
    primaryAction: FilledButton(
      key: const Key('student-edit-confirm'),
      onPressed: _valid
          ? () => Navigator.of(context).pop(
              _PeriodChoice(
                startsAt: _parseDate(_start.text),
                endsAt: _parseDate(_end.text),
                clearEndsAt: _end.text.trim().isEmpty && widget.groupLink.endsAt != null,
              ),
            )
          : null,
      child: const Text('Salvar'),
    ),
  );
}

/// Identificador de intenção para os comandos de vínculo.
///
/// Os quatro comandos reconhecem repetição pelo recibo do servidor, então uma
/// chave por tentativa é suficiente: repetir a mesma intenção com chave nova
/// é recusado pela hierarquia e pelo estado, não pela chave.
String newStudentRequestId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}
