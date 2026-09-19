/// Texto do tour do menu do Superadmin (rascunho aprovado pelo Owner em
/// 18/09/2026, `tour-menu-rascunho-20260918.md`). Uma constante por passo, na
/// ordem em que aparecem; para ajustar título ou texto, edite só este arquivo.
/// `anchorId` é o `id` do nó em `coeloSuperadminNavigation` ou uma das âncoras
/// do shell: `tour-button`, `navigation-search`, `notifications`, `account`.
/// Passos cujo nó está oculto por ambiente ou capacidade são pulados sem aviso.
library;

import 'package:coelo_ui_core/coelo_ui_core.dart';

/// Âncoras do shell que não são nós do menu.
const superadminTourShellAnchors = <String>{
  'tour-button',
  'navigation-search',
  'report-bug',
  'notifications',
  'account',
  'account-profile',
  'account-settings',
  'account-logout',
};

/// Passos que apontam itens do menu da conta: o shell abre o menu antes.
const superadminTourAccountMenuAnchors = <String>{
  'account-profile',
  'account-settings',
  'account-logout',
};

/// Limite do rascunho: 220 caracteres por passo.
const superadminTourStepMaxLength = 220;

/// Passo 1 — botão "Fazer tour".
const tourButtonTourStep = CoeloTourStep(
  anchorId: 'tour-button',
  title: 'Bem-vindo ao Coelo',
  text:
      'Este tour mostra o que cada parte do menu faz. Leva menos de dois minutos e você pode sair quando quiser.',
);

/// Passo 2 — Home.
const homeTourStep = CoeloTourStep(
  anchorId: 'home',
  title: 'Sua página inicial',
  text:
      'Aqui você vê o que precisa de atenção hoje e volta sempre que quiser pelo ícone da casa. Nosso Chat te ajuda a tirar duvidas sobre o Coelo',
);

/// Passo 3 — Estrutura.
const structureTourStep = CoeloTourStep(
  anchorId: 'structure',
  title: 'Como a instituição é organizada',
  text:
      'Instituição, unidades, turmas e atividades. Tudo o que você cadastra aqui organiza o resto do sistema.',
);

/// Passo 4 — Estrutura › Instituições.
const institutionsTourStep = CoeloTourStep(
  anchorId: 'institutions',
  title: 'Instituições',
  text:
      'Cadastro de cada cliente do Coelo: dados, situação e responsável pela instituição. A instituição é sempre unica, mas pode ter várias unidades gerenciada por ela.',
);

/// Passo 5 — Estrutura › Unidades.
const unitsTourStep = CoeloTourStep(
  anchorId: 'units',
  title: 'Unidades',
  text:
      'Cada escola, sede ou filial que a instituição administra. Turmas, equipe e famílias sempre pertencem a uma unidade.',
);

/// Passo 6 — Estrutura › Turmas.
const groupsTourStep = CoeloTourStep(
  anchorId: 'groups',
  title: 'Turmas',
  text: 'Os grupos de crianças ou alunos dentro de uma unidade, com seus educadores.',
);

/// Passo 7 — Estrutura › Atividades.
const activitiesTourStep = CoeloTourStep(
  anchorId: 'activities',
  title: 'Atividades',
  text:
      'Aulas, oficinas e projetos vinculados a unidades e turmas. Aqui também ficam o lançamento e o fechamento de avaliações.',
);

/// Passo 8 — Acompanhamento.
const monitoringTourStep = CoeloTourStep(
  anchorId: 'monitoring',
  title: 'O dia a dia das crianças',
  text: 'Assiduidade, rotina diária e o acompanhamento individual de cada aluno.',
);

/// Passo 9 — Acompanhamento › Assiduidade.
const attendanceTourStep = CoeloTourStep(
  anchorId: 'attendance',
  title: 'Assiduidade',
  text: 'Faça a chamada de hoje, corrija presenças e consulte o histórico de chamadas com filtros.',
);

/// Passo 10 — Acompanhamento › Rotina diária.
const dailyRoutineTourStep = CoeloTourStep(
  anchorId: 'daily-routine',
  title: 'Rotina diária',
  text:
      'Modelos de rotina (sono, alimentação, higiene) usados nas chamadas e no diário das famílias.',
);

/// Passo 11 — Acompanhamento › Acompanhamento de alunos.
const studentsTourStep = CoeloTourStep(
  anchorId: 'students',
  title: 'Acompanhamento de alunos',
  text: 'Visão individual do aluno: presença, rotina, avaliações e observações em um só lugar.',
);

/// Passo 12 — Acessos.
const accessTourStep = CoeloTourStep(
  anchorId: 'access',
  title: 'Quem entra e o que pode fazer',
  text: 'Pessoas, segurança da criança, usuários internos e perfis de permissão.',
);

/// Passo 13 — Acessos › Pessoas.
const peopleTourStep = CoeloTourStep(
  anchorId: 'people',
  title: 'Pessoas',
  text: 'O cadastro único de cada pessoa: responsáveis, equipe e alunos, com seus vínculos.',
);

/// Passo 14 — Acessos › Segurança da criança.
const safetyTourStep = CoeloTourStep(
  anchorId: 'safety',
  title: 'Segurança da criança',
  text:
      'Quem está autorizado a buscar cada criança, com documento e vigência. Sem autorização aqui, não há liberação.',
);

/// Passo 15 — Acessos › Usuários internos.
const internalUsersTourStep = CoeloTourStep(
  anchorId: 'internal-users',
  title: 'Usuários internos',
  text: 'A equipe do Coelo que opera este painel.',
);

/// Passo 16 — Acessos › Perfis e permissões.
const profilesTourStep = CoeloTourStep(
  anchorId: 'profiles',
  title: 'Perfis e permissões',
  text: 'Modelos de acesso por módulo, tela e ação. Um perfil define o que cada pessoa vê e faz.',
);

/// Passo 16a — Acessos › Acesso de funcionários (Etapa 3 F7, ADR 0035).
const staffAccessTourStep = CoeloTourStep(
  anchorId: 'staff-access',
  title: 'Acesso de funcionários',
  text:
      'Horário, vigência e superfícies por vínculo profissional. A restrição vale no servidor; o popup só avisa.',
);

/// Passo 16b — Acessos › Afastamentos (Etapa 3 F7, ADR 0035).
const staffLeavesTourStep = CoeloTourStep(
  anchorId: 'staff-leaves',
  title: 'Afastamentos',
  text: 'Períodos em que o funcionário não entra no app por aquele vínculo. Prevalece sobre o horário.',
);

/// Passo 17 — Saúde e Cuidado.
const healthCareTourStep = CoeloTourStep(
  anchorId: 'health-care',
  title: 'Cuidado com cada criança',
  text: 'Alergias, restrições, orientações e planos de medicação, visíveis só para quem cuida.',
);

/// Passo 18 — Saúde e Cuidado › Perfis de cuidado.
const healthCareProfilesTourStep = CoeloTourStep(
  anchorId: 'health-care-profiles',
  title: 'Perfis de cuidado',
  text: 'Alergias alimentares, restrições e o que fazer em caso de contato, por criança.',
);

/// Passo 19 — Saúde e Cuidado › Planos de medicação.
const healthMedicationPlansTourStep = CoeloTourStep(
  anchorId: 'health-medication-plans',
  title: 'Planos de medicação',
  text:
      'Medicamentos autorizados, horários e o registro de cada dose aplicada. A equipe e a família recebem aviso.',
);

/// Passo 20 — Operação.
const operationsTourStep = CoeloTourStep(
  anchorId: 'operations',
  title: 'Ferramentas do dia',
  text: 'Cardápios, formulários e agenda.',
);

/// Passo 21 — Operação › Cardápios.
const mealPlansTourStep = CoeloTourStep(
  anchorId: 'meal-plans',
  title: 'Cardápios',
  text: 'Modelos de cardápio e a publicação semanal para as famílias, com foto.',
);

/// Passo 22 — Operação › Formulários.
const formsTourStep = CoeloTourStep(
  anchorId: 'forms',
  title: 'Formulários',
  text: 'Crie perguntas, escolha quem responde e acompanhe as respostas. Exporte quando precisar.',
);

/// Passo 22b — Operação › Importações (pedido do Owner em 18/09; texto
/// provisório desta sessão, para o Owner ajustar).
const importTourStep = CoeloTourStep(
  anchorId: 'import',
  title: 'Importações',
  text: 'Acompanhe as importações de dados em lote da plataforma e o resultado de cada arquivo.',
);

/// Passo 23 — Operação › Agenda.
const agendaTourStep = CoeloTourStep(
  anchorId: 'agenda',
  title: 'Agenda',
  text: 'Eventos da instituição, solicitações das famílias e aprovações.',
);

/// Passo 24 — Comunicação.
const communicationTourStep = CoeloTourStep(
  anchorId: 'communication',
  title: 'Falar com as famílias e a equipe',
  text: 'Conversas, convites e comunicações oficiais.',
);

/// Passo 25 — Comunicação › Conversas.
const conversationsTourStep = CoeloTourStep(
  anchorId: 'conversations',
  title: 'Conversas',
  text: 'Atendimento por chat, com anexos e registro de leitura.',
);

/// Passo 26 — Comunicação › Convites.
const invitesTourStep = CoeloTourStep(
  anchorId: 'invites',
  title: 'Convites',
  text: 'Convide responsáveis e equipe para entrar no Coelo e acompanhe quem já aceitou.',
);

/// Passo 27 — Comunicação › Comunicações.
const noticesTourStep = CoeloTourStep(
  anchorId: 'notices',
  title: 'Comunicações',
  text: 'Avisos do Coelo para instituições, unidades ou perfis, com prazo de exibição.',
);

/// Passo 28 — Governança.
const governanceTourStep = CoeloTourStep(
  anchorId: 'governance',
  title: 'Suporte e auditoria',
  text: 'Atendimento de suporte e o registro de todas as ações sensíveis.',
);

/// Passo 29 — Governança › Suporte e implantação.
const supportTourStep = CoeloTourStep(
  anchorId: 'support',
  title: 'Suporte e implantação',
  text: 'Chamados de suporte e o acompanhamento da implantação de cada instituição.',
);

/// Passo 30 — Governança › Auditoria.
const auditTourStep = CoeloTourStep(
  anchorId: 'audit',
  title: 'Auditoria',
  text: 'Quem fez o quê, quando. Toda ação sensível fica registrada aqui.',
);

/// Passo 30b — Governança › Catálogo (pedido do Owner em 18/09; texto
/// provisório desta sessão, para o Owner ajustar).
const catalogTourStep = CoeloTourStep(
  anchorId: 'catalog',
  title: 'Catálogo',
  text:
      'Os fundamentos, componentes e padrões visuais aprovados do Coelo, para consulta da equipe.',
);

/// Passo 31 — Coelo (Principal).
const principalTourStep = CoeloTourStep(
  anchorId: 'principal',
  title: 'O aplicativo das famílias',
  text: 'Aqui você vê e publica o que as famílias recebem no aplicativo.',
);

/// Passo 32 — Coelo › Acontece.
const principalHappensTourStep = CoeloTourStep(
  anchorId: 'principal-happens',
  title: 'Acontece',
  text: 'O mural da instituição: posts, fotos e comunicados com confirmação de leitura.',
);

/// Passo 33 — Coelo › Para você.
const principalForYouTourStep = CoeloTourStep(
  anchorId: 'principal-for-you',
  title: 'Para você',
  text: 'Conteúdo escolhido para cada família, conforme a criança e a turma.',
);

/// Passo 34 — Coelo › Momentos.
const principalMomentsTourStep = CoeloTourStep(
  anchorId: 'principal-moments',
  title: 'Momentos',
  text: 'Vídeos curtos e privados do dia das crianças.',
);

/// Passo 35 — Coelo › Agora.
const principalNowTourStep = CoeloTourStep(
  anchorId: 'principal-now',
  title: 'Agora',
  text: 'Fotos e vídeos rápidos que somem em 24 horas.',
);

/// Passo 36 — Coelo › Chat.
const principalChatTourStep = CoeloTourStep(
  anchorId: 'principal-chat',
  title: 'Chat',
  text: 'A conversa da família com a instituição, do lado de quem recebe.',
);

/// Passo 37 — Coelo › Perfil.
const principalProfileTourStep = CoeloTourStep(
  anchorId: 'principal-profile',
  title: 'Perfil',
  text: 'Como a família vê as crianças, os vínculos e as preferências dela.',
);

/// Passo 38 — Coelo › Circulares.
const circularsTourStep = CoeloTourStep(
  anchorId: 'circulars',
  title: 'Circulares',
  text: 'Documentos oficiais para as famílias, com versão e confirmação de leitura.',
);

/// Passo 39 — busca do menu.
const navigationSearchTourStep = CoeloTourStep(
  anchorId: 'navigation-search',
  title: 'Procure em vez de navegar',
  text: 'Digite o nome de qualquer tela na busca do menu para chegar direto nela.',
);

/// Passo 39b — botão Bug (pedido do Owner em 18/09; texto provisório desta
/// sessão, para o Owner ajustar).
const reportBugTourStep = CoeloTourStep(
  anchorId: 'report-bug',
  title: 'Reportar bug',
  text: 'Encontrou algo errado? Relate aqui, dizendo a tela e o que aconteceu, e a equipe recebe.',
);

/// Passo 40 — sino.
const notificationsTourStep = CoeloTourStep(
  anchorId: 'notifications',
  title: 'Notificações',
  text: 'Aqui chegam os avisos do sistema: doses registradas, solicitações, convites aceitos.',
);

/// Passo 41 — avatar / Conta.
const accountTourStep = CoeloTourStep(
  anchorId: 'account',
  title: 'Sua conta',
  text: 'Foto, celular, senha e a opção de sair.',
);

/// Passos 41b–41d — itens do menu da conta (pedido do Owner em 18/09;
/// textos provisórios desta sessão, para o Owner ajustar).
const accountProfileTourStep = CoeloTourStep(
  anchorId: 'account-profile',
  title: 'Perfil',
  text: 'Seus dados: nome, foto, celular e senha.',
);

const accountSettingsTourStep = CoeloTourStep(
  anchorId: 'account-settings',
  title: 'Configurações',
  text: 'Preferências da sua conta neste dispositivo, como aparência e notificações.',
);

const accountLogoutTourStep = CoeloTourStep(
  anchorId: 'account-logout',
  title: 'Sair',
  text: 'Encerra sua sessão neste dispositivo. O Coelo pede confirmação antes.',
);

/// Passo 42 — botão "Fazer tour".
const tourButtonFinalTourStep = CoeloTourStep(
  anchorId: 'tour-button',
  title: 'Pronto',
  text: 'Você pode refazer este tour ou pedir o tour de uma tela específica quando quiser.',
);

/// Todos os passos, na ordem do rascunho.
const superadminMenuTourSteps = <CoeloTourStep>[
  tourButtonTourStep,
  homeTourStep,
  structureTourStep,
  institutionsTourStep,
  unitsTourStep,
  groupsTourStep,
  activitiesTourStep,
  monitoringTourStep,
  attendanceTourStep,
  dailyRoutineTourStep,
  studentsTourStep,
  accessTourStep,
  peopleTourStep,
  safetyTourStep,
  internalUsersTourStep,
  profilesTourStep,
  staffAccessTourStep,
  staffLeavesTourStep,
  healthCareTourStep,
  healthCareProfilesTourStep,
  healthMedicationPlansTourStep,
  operationsTourStep,
  mealPlansTourStep,
  formsTourStep,
  importTourStep,
  agendaTourStep,
  communicationTourStep,
  conversationsTourStep,
  invitesTourStep,
  noticesTourStep,
  governanceTourStep,
  supportTourStep,
  auditTourStep,
  catalogTourStep,
  principalTourStep,
  principalHappensTourStep,
  principalForYouTourStep,
  principalMomentsTourStep,
  principalNowTourStep,
  principalChatTourStep,
  principalProfileTourStep,
  circularsTourStep,
  navigationSearchTourStep,
  reportBugTourStep,
  notificationsTourStep,
  accountTourStep,
  accountProfileTourStep,
  accountSettingsTourStep,
  accountLogoutTourStep,
  tourButtonFinalTourStep,
];
