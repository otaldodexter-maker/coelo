import 'dart:async';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import '../../../app/shell/superadmin_shell.dart';
import '../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../auth/domain/logout_action.dart';
import '../domain/unit_detail.dart';
import 'unit_detail_controller.dart';

final class UnitDetailPage extends StatefulWidget {
  const UnitDetailPage({
    required this.repository,
    required this.id,
    required this.logout,
    required this.onBack,
    this.onDestinationSelected,
    this.onOpenLocationCatalog,
    super.key,
  });
  final UnitDetailRepository repository;
  final String id;
  final LogoutAction logout;
  final VoidCallback onBack;
  final ValueChanged<String>? onDestinationSelected;

  /// Opens the catalog of this unit; absent when no route is composed for the
  /// caller, and then no control is offered.
  final VoidCallback? onOpenLocationCatalog;
  @override
  State<UnitDetailPage> createState() => _UnitDetailPageState();
}

final class _UnitDetailPageState extends State<UnitDetailPage> {
  late final UnitDetailController _controller;
  double _footerHeight = 0;
  @override
  void initState() {
    super.initState();
    _controller = UnitDetailController(repository: widget.repository, id: widget.id);
    unawaited(_controller.load());
  }

  @override
  void didUpdateWidget(covariant UnitDetailPage oldWidget) {
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
      title: 'Detalhes da unidade',
      subtitle: 'Consulta dos dados autorizados.',
      currentDestination: 'units',
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
                      key: const Key('unit-detail-content'),
                      children: [
                        if (_controller.detail case final detail?) ...[
                          _section(context, 'Dados da unidade', {
                            'Nome': detail.name,
                            'Identificador': detail.slug,
                            'Instituição': detail.institutionName,
                            'Tipo da instituição': detail.institutionType?.name ?? 'Não informado',
                            'Tipo da unidade': detail.unitType.name,
                            'Status': _statusLabel(detail.status),
                          }),
                          _section(
                            context,
                            'Endereço',
                            detail.address == null
                                ? {'Endereço': 'Não informado'}
                                : {
                                    'País': detail.address!['country'] ?? 'Não informado',
                                    'Estado': detail.address!['state'] ?? 'Não informado',
                                    'Cidade': detail.address!['city'] ?? 'Não informado',
                                    'Bairro': detail.address!['district'] ?? 'Não informado',
                                    'Logradouro': detail.address!['street'] ?? 'Não informado',
                                    'Número': detail.address!['number'] ?? 'Não informado',
                                    'Complemento': detail.address!['complement'] ?? 'Não informado',
                                    'CEP': detail.address!['postal_code'] ?? 'Não informado',
                                  },
                          ),
                          _section(
                            context,
                            'Contato',
                            detail.contact == null
                                ? {'Contato': 'Não informado'}
                                : {
                                    'E-mail': detail.contact!['email'] ?? 'Não informado',
                                    'Telefone': detail.contact!['phone'] ?? 'Não informado',
                                    'Celular': detail.contact!['mobile_phone'] ?? 'Não informado',
                                  },
                          ),
                          _section(context, 'Plano efetivo', {
                            'Plano': detail.effectivePlan?.name ?? 'Não informado',
                            if (detail.effectivePlan != null)
                              'Origem': detail.effectivePlan!.inherited
                                  ? 'Herdado da instituição'
                                  : 'Definido na unidade',
                          }),
                        ] else
                          Semantics(
                            liveRegion: true,
                            label: _controller.state == UnitDetailState.loading
                                ? 'Carregando detalhes'
                                : null,
                            child: CoeloStatePanel(
                              key: Key('unit-detail-${_controller.state.name}'),
                              loading: _controller.state == UnitDetailState.loading,
                              title: _controller.state == UnitDetailState.denied
                                  ? 'Acesso não autorizado'
                                  : 'Não foi possível carregar os detalhes',
                              message: _controller.state == UnitDetailState.denied
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
                      key: const Key('unit-detail-back'),
                      onPressed: widget.onBack,
                      child: const Text('Voltar'),
                    ),
                    continuationActions: [
                      if (widget.onOpenLocationCatalog != null && _controller.detail != null)
                        OutlinedButton.icon(
                          key: const Key('unit-detail-locations'),
                          onPressed: widget.onOpenLocationCatalog,
                          icon: const Icon(Icons.place_outlined),
                          label: const Text('Mapa e locais'),
                        ),
                      OutlinedButton.icon(
                        key: const Key('unit-detail-reload'),
                        onPressed: _controller.state == UnitDetailState.loading
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
