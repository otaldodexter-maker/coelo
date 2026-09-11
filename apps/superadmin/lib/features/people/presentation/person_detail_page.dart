import 'dart:async';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import '../../../app/shell/superadmin_shell.dart';
import '../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../auth/domain/logout_action.dart';
import '../domain/person_detail_reader.dart';
import '../domain/person_directory.dart';
import 'person_detail_controller.dart';

final class PersonDetailPage extends StatefulWidget {
  const PersonDetailPage({
    required this.reader,
    required this.id,
    required this.logout,
    required this.onBack,
    this.onEdit,
    this.onDestinationSelected,
    super.key,
  });
  final PersonDetailReader reader;
  final String id;
  final LogoutAction logout;
  final VoidCallback onBack;

  /// Abre o editor da pessoa quando a composicao autoriza escrita.
  final VoidCallback? onEdit;
  final ValueChanged<String>? onDestinationSelected;
  @override
  State<PersonDetailPage> createState() => _PersonDetailPageState();
}

final class _PersonDetailPageState extends State<PersonDetailPage> {
  late final PersonDetailController _controller;
  double _footerHeight = 0;
  @override
  void initState() {
    super.initState();
    _controller = PersonDetailController(reader: widget.reader, id: widget.id);
    unawaited(_controller.load());
  }

  @override
  void didUpdateWidget(covariant PersonDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id || !identical(oldWidget.reader, widget.reader)) {
      unawaited(_controller.load(id: widget.id, reader: widget.reader));
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
      title: 'Detalhes da pessoa',
      subtitle: 'Consulta dos dados autorizados.',
      currentDestination: 'people',
      logout: widget.logout,
      onDestinationSelected: widget.onDestinationSelected,
      chatLauncherBottomInset: _footerHeight + CoeloSpacing.space4,
      child: LayoutBuilder(
        builder: (context, constraints) => ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: EdgeInsets.all(
              constraints.maxWidth < CoeloBreakpoints.medium.minWidth
                  ? CoeloSpacing.space4
                  : CoeloSpacing.space6,
            ),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    key: const Key('person-detail-content'),
                    children: [
                      if (_controller.detail case final detail?) ...[
                        _section(context, 'Identidade', {
                          'Nome de exibição': detail.displayName,
                          'Primeiro nome': _text(detail.firstName),
                          'Sobrenome': _text(detail.lastName),
                          'Nome legal': _text(detail.legalName),
                          'Tipo': detail.type.label,
                          'Status cadastral': detail.status.label,
                          'Vínculo Auth': detail.authLink.label,
                        }),
                        if (detail.type == PersonType.adult) ...[
                          if (detail.memberships.isEmpty)
                            _section(context, 'Vínculos institucionais', {
                              'Consulta autorizada': 'Nenhum vínculo retornado.',
                            }),
                          for (final membership in detail.memberships)
                            _section(context, 'Vínculo institucional', {
                              'Instituição': _text(membership.institutionName),
                              'Unidade': _text(membership.unitName),
                              'Grupo': _text(membership.groupName),
                              'Papel contextual': membership.role,
                            }),
                        ],
                        if (detail.type == PersonType.child) ...[
                          if (detail.childContexts.isEmpty)
                            _section(context, 'Contextos da criança', {
                              'Consulta autorizada': 'Nenhum contexto retornado.',
                            }),
                          for (final childContext in detail.childContexts)
                            _section(context, 'Contexto da criança', {
                              'Instituição': _text(childContext.institutionName),
                              'Unidade': _text(childContext.unitName),
                              'Grupo': _text(childContext.groupName),
                            }),
                        ],
                      ] else
                        Semantics(
                          liveRegion: true,
                          label: _controller.state == PersonDetailState.loading
                              ? 'Carregando detalhes'
                              : null,
                          child: CoeloStatePanel(
                            key: Key('person-detail-${_controller.state.name}'),
                            loading: _controller.state == PersonDetailState.loading,
                            title: switch (_controller.state) {
                              PersonDetailState.loading => 'Carregando detalhes',
                              PersonDetailState.denied => 'Acesso não autorizado',
                              _ => 'Não foi possível carregar os detalhes',
                            },
                            message: switch (_controller.state) {
                              PersonDetailState.loading =>
                                'Aguarde a consulta dos dados autorizados.',
                              PersonDetailState.denied =>
                                'Você não tem permissão para consultar este registro.',
                              _ => 'Tente recarregar os dados.',
                            },
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
                    key: const Key('person-detail-back'),
                    onPressed: widget.onBack,
                    child: const Text('Voltar'),
                  ),
                  continuationActions: [
                    if (widget.onEdit case final onEdit?)
                      FilledButton.icon(
                        key: const Key('person-detail-edit'),
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Editar'),
                      ),
                    OutlinedButton.icon(
                      key: const Key('person-detail-reload'),
                      onPressed: _controller.state == PersonDetailState.loading
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
        ),
      ),
    ),
  );
}

String _text(String? value) => value == null || value.isEmpty ? 'Não informado' : value;

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
