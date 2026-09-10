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
    super.key,
  });

  final StudentLinkRepository repository;
  final String childContextId;
  final LogoutAction logout;
  final VoidCallback? onBack;

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
    builder: (dialogContext) => _ReasonDialog(
      dialogKey: dialogKey,
      title: title,
      body: body,
      confirmLabel: confirmLabel,
    ),
  );

  void _notify(String message) => ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    currentDestination: 'students',
    title: _links?.displayName ?? 'Aluno',
    subtitle: 'Unidades, turmas e vigência do vínculo.',
    child: ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: _body(),
    ),
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
    if (links.unitLinks.isEmpty) {
      return const CoeloStatePanel(
        key: Key('student-manage-empty'),
        title: 'Sem vínculo nesta instituição',
        message: 'Esta criança ainda não foi vinculada a nenhuma unidade.',
        icon: Icons.link_off_rounded,
      );
    }
    return ListView(
      key: const Key('student-manage-scroll'),
      padding: const EdgeInsets.all(CoeloSpacing.space5),
      children: [
        for (final unitLink in links.unitLinks) ...[
          _UnitLinkCard(
            unitLink: unitLink,
            canManage: links.canManage,
            busy: _busyUnitLinkId == unitLink.unitLinkId,
            onRevoke: () => _revoke(unitLink),
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
  });

  final StudentUnitLink unitLink;
  final bool canManage;
  final bool busy;
  final VoidCallback onRevoke;

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
                child: Text(
                  groupLink.isActive
                      ? groupLink.groupName
                      : '${groupLink.groupName} — encerrada',
                  style: text.bodyMedium,
                ),
              ),
          ],
          if (canManage && unitLink.isCurrent) ...[
            const SizedBox(height: CoeloSpacing.space4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: Key('student-revoke-${unitLink.unitLinkId}'),
                onPressed: busy ? null : onRevoke,
                icon: const Icon(Icons.link_off_rounded),
                label: Text(busy ? 'Revogando…' : 'Revogar vínculo'),
              ),
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
