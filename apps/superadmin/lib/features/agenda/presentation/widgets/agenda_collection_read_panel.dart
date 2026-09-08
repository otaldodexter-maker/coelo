import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../domain/agenda_repository.dart';

/// Shared read states for the two views backed by the same requests channel.
final class AgendaCollectionReadPanel extends StatelessWidget {
  const AgendaCollectionReadPanel({required this.status, required this.onRetry, super.key});

  final AgendaReadStatus status;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => switch (status) {
    AgendaReadStatus.loading => Semantics(
      key: const Key('agenda-collection-loading'),
      label: 'Carregando retornos da Agenda',
      liveRegion: true,
      child: const CoeloStatePanel(
        title: 'Carregando retornos da Agenda',
        message: 'Aguarde enquanto consultamos os registros autorizados.',
        loading: true,
      ),
    ),
    AgendaReadStatus.unauthorized => const CoeloStatePanel(
      key: Key('agenda-collection-unauthorized'),
      title: 'Acesso não autorizado',
      message: 'Você não possui autorização para consultar estes retornos.',
      icon: Icons.lock_outline,
    ),
    AgendaReadStatus.failure || AgendaReadStatus.notFound => CoeloStatePanel(
      key: const Key('agenda-collection-failure'),
      title: 'Não foi possível carregar os retornos',
      message: 'Tente novamente para consultar os registros da Agenda.',
      icon: Icons.error_outline,
      actionLabel: 'Tentar novamente',
      onAction: onRetry,
    ),
    AgendaReadStatus.idle => CoeloStatePanel(
      key: const Key('agenda-collection-idle'),
      title: 'Retornos ainda não carregados',
      message: 'Consulte os registros da Agenda para continuar.',
      icon: Icons.refresh,
      actionLabel: 'Carregar retornos',
      onAction: onRetry,
    ),
    AgendaReadStatus.ready => const CoeloStatePanel(
      key: Key('agenda-collection-empty'),
      title: 'Nenhum retorno encontrado',
      message: 'Não há registros disponíveis nesta consulta da Agenda.',
      icon: Icons.inbox_outlined,
    ),
  };
}
