import '../domain/access_profile.dart';

/// Rótulos de produto para módulo → tela → ação de uma permissão.
///
/// O catálogo real (`superadmin_access_profile_detail`) devolve os códigos e
/// `module_label`, `screen_label` e `action_label`. A tradução local curada do
/// código real tem prioridade (o servidor ainda devolve rótulos em inglês ou
/// com codificação errada para alguns itens); sem tradução local vale o rótulo
/// do servidor, desde que ele não seja só o código humanizado (ex.:
/// `directory` → "Directory"); por último, o código humanizado. Nenhum código
/// técnico cru aparece no texto principal da tela.
String permissionModuleLabel(AccessPermission permission) =>
    _resolve(permission.moduleLabel, permission.module, _moduleLabels[permission.module]);

String permissionScreenLabel(AccessPermission permission) => _resolve(
  permission.screenLabel,
  permission.screenCode,
  permission.screenCode == 'general'
      ? permissionModuleLabel(permission)
      : _screenLabels[permission.screenCode],
);

String permissionActionLabel(AccessPermission permission) =>
    _resolve(permission.actionLabel, permission.actionCode, _actionLabels[permission.actionCode]);

/// Texto "Ação em Tela" usado por semântica e tooltip.
String permissionActionInScreen(AccessPermission permission) =>
    '${permissionActionLabel(permission)} em ${permissionScreenLabel(permission)}';

/// Caminho completo "Módulo → Tela → Ação" da revisão e do detalhe. Quando o
/// nome do catálogo é mais específico que o rótulo da ação (ex.: "Criar
/// modelos Admin." em vez de só "Criar"), ele é usado no último segmento.
String permissionPath(AccessPermission permission) {
  final action = permission.name == permission.code
      ? permissionActionLabel(permission)
      : permission.name;
  return '${permissionModuleLabel(permission)} → ${permissionScreenLabel(permission)} → $action';
}

/// Uma linha da matriz: normalmente uma tela; quando a mesma tela tem mais de
/// uma permissão com a mesma ação (ex.: Modelos de perfil × Admin/Superadmin/
/// Principal), a tela é desdobrada por alvo (prefixo do código) para que cada
/// permissão tenha a própria célula e nenhuma fique invisível.
final class PermissionMatrixRow {
  const PermissionMatrixRow({
    required this.screenCode,
    required this.label,
    required this.permissions,
  });

  final String screenCode;
  final String label;
  final List<AccessPermission> permissions;
}

List<PermissionMatrixRow> permissionMatrixRows(List<AccessPermission> permissions) {
  final screens = <String, List<AccessPermission>>{};
  for (final permission in permissions) {
    screens.putIfAbsent(permission.screenCode, () => []).add(permission);
  }
  final rows = <PermissionMatrixRow>[];
  for (final entry in screens.entries) {
    final actions = entry.value.map((item) => item.actionCode).toSet();
    if (actions.length == entry.value.length) {
      rows.add(
        PermissionMatrixRow(
          screenCode: entry.key,
          label: permissionScreenLabel(entry.value.first),
          permissions: entry.value,
        ),
      );
      continue;
    }
    final targets = <String, List<AccessPermission>>{};
    for (final permission in entry.value) {
      targets.putIfAbsent(_targetOf(permission.code), () => []).add(permission);
    }
    for (final target in targets.entries) {
      rows.add(
        PermissionMatrixRow(
          screenCode: entry.key,
          label: '${permissionScreenLabel(target.value.first)} · ${_targetLabel(target.key)}',
          permissions: target.value,
        ),
      );
    }
  }
  return rows;
}

String _targetOf(String code) {
  final dot = code.indexOf('.');
  return dot <= 0 ? code : code.substring(0, dot);
}

String _targetLabel(String target) {
  for (final domain in AccessProfileDomain.values) {
    if (domain.databaseValue == target) return domain.label;
  }
  return humanizePermissionCode(target);
}

String _resolve(String? serverLabel, String code, String? localLabel) {
  if (localLabel != null) return localLabel;
  final humanized = humanizePermissionCode(code);
  if (serverLabel != null && serverLabel != humanized) return serverLabel;
  return humanized;
}

String humanizePermissionCode(String value) {
  final words = value.replaceAll('_', ' ').replaceAll('.', ' ').trim();
  if (words.isEmpty) return 'Geral';
  return '${words[0].toUpperCase()}${words.substring(1)}';
}

const _moduleLabels = <String, String>{
  'access': 'Acessos',
  'activities': 'Atividades',
  'agenda': 'Agenda',
  'analytics': 'Indicadores',
  'attendance': 'Assiduidade',
  'audit': 'Auditoria',
  'child_safety': 'Segurança infantil',
  'communication': 'Comunicação',
  'forms': 'Formulários',
  'groups': 'Turmas',
  'health_care': 'Saúde e cuidado',
  'imports': 'Importações',
  'institutions': 'Instituições',
  'locations': 'Locais',
  'meal_plans': 'Cardápios',
  'notices': 'Avisos',
  'people': 'Pessoas',
  'plans': 'Planos',
  'platform': 'Plataforma',
  'profiles': 'Perfis',
  'routine': 'Rotina diária',
  'structure': 'Estrutura',
  'support': 'Suporte',
  'units': 'Unidades',
};

const _screenLabels = <String, String>{
  'activities': 'Atividades',
  'activation': 'Ativação',
  'access_profiles': 'Perfis e permissões',
  'access_profile_models': 'Modelos de perfil',
  'attendance': 'Frequência',
  'audit': 'Auditoria',
  'chat': 'Conversas',
  'child_contexts': 'Contextos da criança',
  'create': 'Cadastro',
  'directory': 'Listagem',
  'edit': 'Edição',
  'files': 'Arquivos',
  'forms': 'Formulários',
  'groups': 'Turmas',
  'hierarchy': 'Hierarquia',
  'identity': 'Identidade',
  'institutions': 'Instituições',
  'management': 'Gestão',
  'members': 'Usuários internos',
  'memberships': 'Vínculos',
  'people': 'Pessoas',
  'permissions': 'Permissões',
  'plans': 'Planos',
  'platform': 'Plataforma',
  'processing': 'Processamento',
  'relationships': 'Relações',
  'roles': 'Perfis e permissões',
  'sessions': 'Sessões',
  'status': 'Status',
  'structure': 'Estrutura',
  'subscription': 'Assinatura',
  'support': 'Suporte',
  'taxonomy': 'Taxonomia',
  'templates': 'Modelos',
  'types': 'Tipos',
  'units': 'Unidades',
};

const _actionLabels = <String, String>{
  'read': 'Ver',
  'view': 'Ver',
  'list': 'Ver',
  'create': 'Criar',
  'update': 'Editar',
  'edit': 'Editar',
  'delete': 'Excluir',
  'manage': 'Gerenciar',
  'moderate': 'Moderar',
  'access': 'Acessar',
  'assign': 'Atribuir',
  'edit_own': 'Editar próprias',
  'edit_all': 'Editar todas',
  'export': 'Exportar',
  'import': 'Importar',
  'publish': 'Publicar',
  'invite': 'Convidar',
  'status': 'Alterar status',
  'transfer': 'Transferir',
  'request': 'Solicitar',
  'review': 'Revisar',
  'send': 'Enviar',
  'respond': 'Responder',
  'record': 'Registrar',
  'correct': 'Corrigir',
  'copy': 'Copiar',
  'schedule': 'Agendar',
  'override': 'Sobrepor',
  'cancel_restore': 'Cancelar/restaurar',
  'manage_responses': 'Gerenciar respostas',
  'override_reservation': 'Sobrepor reserva',
  'anonymous_export': 'Exportar anônimo',
  'anonymous_read': 'Ver anônimo',
  'record_evidence': 'Registrar evidência',
  'assign_children': 'Vincular crianças',
  'manage_applications': 'Gerenciar aplicações',
  'manage_models': 'Gerenciar modelos',
  'update_official_data': 'Atualizar dados oficiais',
};
