import 'dart:async';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import '../../../app/shell/superadmin_shell.dart';
import '../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../auth/domain/logout_action.dart';
import '../domain/group_detail.dart';
import 'group_detail_controller.dart';

final class GroupDetailPage extends StatefulWidget {
  const GroupDetailPage({
    required this.repository,
    required this.id,
    required this.logout,
    required this.onBack,
    this.onDestinationSelected,
    this.reservationBuilder,
    super.key,
  });
  final GroupDetailRepository repository;
  final String id;
  final LogoutAction logout;
  final VoidCallback onBack;
  final ValueChanged<String>? onDestinationSelected;
  final Widget Function(BuildContext, GroupDetail)? reservationBuilder;
  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

final class _GroupDetailPageState extends State<GroupDetailPage> {
  late final GroupDetailController _controller;
  double _footerHeight = 0;
  @override
  void initState() {
    super.initState();
    _controller = GroupDetailController(repository: widget.repository, id: widget.id);
    unawaited(_controller.load());
  }

  @override
  void didUpdateWidget(covariant GroupDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id || !identical(oldWidget.repository, widget.repository)) {
      unawaited(_controller.load(id: widget.id, repository: widget.repository));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => SuperadminShell(
      title: 'Detalhes da turma',
      subtitle: 'Consulta dos dados autorizados.',
      currentDestination: 'groups',
      logout: widget.logout,
      onDestinationSelected: widget.onDestinationSelected,
      chatLauncherBottomInset: _footerHeight + CoeloSpacing.space4,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final padding = constraints.maxWidth < CoeloBreakpoints.medium.minWidth
              ? CoeloSpacing.space4
              : CoeloSpacing.space6;
          return ColoredBox(
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: EdgeInsets.all(padding),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      key: const Key('group-detail-content'),
                      children: [
                        if (_controller.detail case final detail?) ...[
                          _section(context, 'Dados da turma', {
                            'Nome': detail.name,
                            'Instituição': detail.institutionName,
                            'Unidade': detail.unitName,
                            'Tipo': detail.groupType == 'class' ? 'Turma' : detail.groupType,
                            if (detail.groupTypeOtherText != null)
                              'Complemento do tipo': detail.groupTypeOtherText!,
                            'Status': _statusLabel(detail.status),
                          }),
                          _section(context, 'Configuração de herança', {
                            'Aparência': detail.inheritAppearance ? 'Herdada' : 'Própria',
                            'Acessos': detail.inheritAccess ? 'Herdados' : 'Próprios',
                            'Atividades': detail.inheritActivities ? 'Herdadas' : 'Próprias',
                          }),
                          if (widget.reservationBuilder != null)
                            widget.reservationBuilder!(context, detail),
                        ] else
                          Semantics(
                            liveRegion: true,
                            label: _controller.state == GroupDetailState.loading
                                ? 'Carregando detalhes'
                                : null,
                            child: CoeloStatePanel(
                              key: Key('group-detail-${_controller.state.name}'),
                              loading: _controller.state == GroupDetailState.loading,
                              title: _controller.state == GroupDetailState.denied
                                  ? 'Acesso não autorizado'
                                  : 'Não foi possível carregar os detalhes',
                              message: _controller.state == GroupDetailState.denied
                                  ? 'Você não tem permissão para consultar este registro.'
                                  : 'Tente recarregar os dados.',
                            ),
                          ),
                        const SizedBox(height: CoeloSpacing.space4),
                      ],
                    ),
                  ),
                  const SizedBox(height: CoeloSpacing.space4),
                  SuperadminFormActionFooter(
                    onHeightChanged: (height) {
                      if (mounted && _footerHeight != height) {
                        setState(() => _footerHeight = height);
                      }
                    },
                    tertiaryAction: TextButton(
                      key: const Key('group-detail-back'),
                      onPressed: widget.onBack,
                      child: const Text('Voltar'),
                    ),
                    continuationActions: [
                      OutlinedButton.icon(
                        key: const Key('group-detail-reload'),
                        onPressed: _controller.state == GroupDetailState.loading
                            ? null
                            : () => unawaited(_controller.load()),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Recarregar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

Widget _section(BuildContext context, String title, Map<String, String> fields) => Card(
  margin: const EdgeInsets.only(bottom: CoeloSpacing.space3),
  child: Padding(
    padding: const EdgeInsets.all(CoeloSpacing.space4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
        const SizedBox(height: CoeloSpacing.space4),
        for (final entry in fields.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: CoeloSpacing.space3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.key, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: CoeloSpacing.space1),
                SelectableText(entry.value, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
      ],
    ),
  ),
);

String _statusLabel(String status) => switch (status) {
  'draft' => 'Rascunho',
  'active' => 'Ativo',
  'inactive' => 'Inativo',
  'suspended' => 'Suspenso',
  'archived' => 'Arquivado',
  _ => 'Não informado',
};
