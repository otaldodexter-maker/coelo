import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';

final class CatalogChatConversation {
  const CatalogChatConversation({
    required this.id,
    required this.title,
    required this.initials,
    required this.preview,
    required this.timestamp,
    required this.context,
    this.unreadCount = 0,
    this.nowState = CoeloNowState.none,
    this.presence = CoeloChatPresence.none,
    this.official = false,
  });

  final String id;
  final String title;
  final String initials;
  final String preview;
  final String timestamp;
  final String context;
  final int unreadCount;
  final CoeloNowState nowState;
  final CoeloChatPresence presence;
  final bool official;
}

const catalogChatConversations = [
  CatalogChatConversation(
    id: 'coelo',
    title: 'Coelo',
    initials: 'C',
    preview: 'Assistente oficial · Em breve',
    timestamp: '',
    context: 'Ajuda sobre o Coelo',
    official: true,
  ),
  CatalogChatConversation(
    id: 'girassol',
    title: 'Turma Girassol',
    initials: 'TG',
    preview: 'Marina enviou uma mensagem.',
    timestamp: '2 min',
    context: 'Centro Horizonte · Unidade Cambuí',
    unreadCount: 3,
    nowState: CoeloNowState.unseen,
    presence: CoeloChatPresence.available,
  ),
  CatalogChatConversation(
    id: 'natacao',
    title: 'Natação',
    initials: 'NA',
    preview: 'A atividade começa às 16h.',
    timestamp: '1 h',
    context: 'Turma Girassol · Lia',
    nowState: CoeloNowState.seen,
  ),
  CatalogChatConversation(
    id: 'taquaral',
    title: 'Unidade Taquaral',
    initials: 'UT',
    preview: 'Documento recebido.',
    timestamp: 'Ontem',
    context: 'Centro Horizonte',
  ),
];

const catalogAdminContextOptions = [
  CoeloAdminContextOption(
    id: 'centro-horizonte',
    label: 'Centro Horizonte',
    kind: CoeloAdminContextKind.institution,
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
