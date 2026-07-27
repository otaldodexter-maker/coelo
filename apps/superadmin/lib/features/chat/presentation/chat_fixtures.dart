import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';

final class SuperadminChatMetric {
  const SuperadminChatMetric(this.label, this.value);

  final String label;
  final int value;
}

final class SuperadminChatConversation {
  const SuperadminChatConversation({
    required this.id,
    required this.title,
    required this.initials,
    required this.preview,
    required this.timestamp,
    required this.context,
    required this.institution,
    required this.targetKind,
    required this.metrics,
    this.unit,
    this.group,
    this.activity,
    this.state,
    this.personRole,
    this.children = const [],
    this.unreadCount = 0,
    this.nowState = CoeloNowState.none,
    this.presence = CoeloChatPresence.none,
  });

  final String id;
  final String title;
  final String initials;
  final String preview;
  final String timestamp;
  final String context;
  final String institution;
  final CoeloAdminContextKind targetKind;
  final List<SuperadminChatMetric> metrics;
  final String? unit;
  final String? group;
  final String? activity;
  final String? state;
  final String? personRole;
  final List<String> children;
  final int unreadCount;
  final CoeloNowState nowState;
  final CoeloChatPresence presence;
}

const superadminChatConversations = [
  SuperadminChatConversation(
    id: 'girassol',
    title: 'Turma Girassol',
    initials: 'TG',
    preview: 'Marina enviou uma mensagem.',
    timestamp: '2 min',
    context: 'Centro Horizonte · Unidade Cambuí',
    institution: 'Centro Horizonte',
    targetKind: CoeloAdminContextKind.group,
    metrics: [
      SuperadminChatMetric('Professores', 3),
      SuperadminChatMetric('Crianças', 18),
      SuperadminChatMetric('Responsáveis', 27),
      SuperadminChatMetric('Atividades', 4),
    ],
    state: 'CE',
    personRole: 'Professores',
    unit: 'Unidade Cambuí',
    group: 'Turma Girassol',
    children: ['Lia'],
    unreadCount: 3,
    nowState: CoeloNowState.unseen,
    presence: CoeloChatPresence.available,
  ),
  SuperadminChatConversation(
    id: 'cambui',
    title: 'Unidade Cambuí',
    initials: 'UC',
    preview: 'Documento recebido.',
    timestamp: '1 h',
    context: 'Centro Horizonte',
    institution: 'Centro Horizonte',
    targetKind: CoeloAdminContextKind.unit,
    metrics: [
      SuperadminChatMetric('Grupos', 8),
      SuperadminChatMetric('Funcionários', 34),
      SuperadminChatMetric('Crianças', 126),
      SuperadminChatMetric('Atividades', 12),
    ],
    state: 'CE',
    personRole: 'Outros',
    unit: 'Unidade Cambuí',
  ),
  SuperadminChatConversation(
    id: 'natacao',
    title: 'Atividade Natação',
    initials: 'AN',
    preview: 'A atividade começa às 16h.',
    timestamp: 'Ontem',
    context: 'Turma Girassol · Lia',
    institution: 'Centro Horizonte',
    targetKind: CoeloAdminContextKind.activity,
    metrics: [
      SuperadminChatMetric('Grupos', 2),
      SuperadminChatMetric('Professores', 2),
      SuperadminChatMetric('Crianças', 14),
      SuperadminChatMetric('Responsáveis', 20),
    ],
    state: 'CE',
    personRole: 'Respons\u00e1veis',
    unit: 'Unidade Cambuí',
    group: 'Turma Girassol',
    activity: 'Natação',
    children: ['Lia'],
    nowState: CoeloNowState.seen,
  ),
  SuperadminChatConversation(
    id: 'aurora',
    title: 'Instituto Aurora',
    initials: 'IA',
    preview: 'A coordenação enviou um aviso.',
    timestamp: '2 d',
    context: 'Instituto Aurora · Unidade Jardins',
    institution: 'Instituto Aurora',
    targetKind: CoeloAdminContextKind.institution,
    metrics: [
      SuperadminChatMetric('Unidades', 3),
      SuperadminChatMetric('Grupos', 14),
      SuperadminChatMetric('Atividades', 21),
      SuperadminChatMetric('Pessoas', 284),
    ],
    state: 'SP',
    personRole: 'Crian\u00e7as',
    unit: 'Unidade Jardins',
    group: 'Grupo Azul',
    activity: 'Arte',
    children: ['Miguel'],
  ),
];

const superadminChatContextOptions = [
  CoeloAdminContextOption(
    id: 'centro-horizonte',
    label: 'Centro Horizonte',
    kind: CoeloAdminContextKind.institution,
    subtitle: 'Instituição ativa',
    children: [
      CoeloAdminContextOption(
        id: 'cambui',
        label: 'Unidade Cambuí',
        kind: CoeloAdminContextKind.unit,
        children: [
          CoeloAdminContextOption(
            id: 'girassol',
            label: 'Turma Girassol',
            kind: CoeloAdminContextKind.group,
            children: [
              CoeloAdminContextOption(
                id: 'natacao',
                label: 'Natação',
                kind: CoeloAdminContextKind.activity,
                subtitle: 'Terças e quintas',
              ),
            ],
          ),
        ],
      ),
    ],
  ),
];
