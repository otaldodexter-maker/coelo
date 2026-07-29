---
title: "Redesenho Local Do Chat Institucional Do Superadmin"
source: "Referências visuais e refinamentos aprovados pelo usuário em 2026-07-28 e 2026-07-29; docs/design/design-system.md; decisions/0012-contextual-experiences-and-conversation-history.md; Fluent 2 Tree; Material Menus; GitLab Drag and Drop"
status: "approved-for-local-prototype"
generated_at: "2026-07-29"
---

# Redesenho Local Do Chat Institucional Do Superadmin

## Objetivo

Substituir a composição visual rejeitada do chat institucional por um protótipo
local, leve e responsivo no Superadmin. A entrega usa somente dados simulados e
não constitui padrão, componente ou contrato público do Coelo UI.

## Direção Visual Aprovada

A experiência usa três áreas contínuas quando houver espaço: inbox à esquerda,
conversa como foco central e contexto institucional à direita. Divisores ficam
restritos às fronteiras funcionais; busca e filtros pertencem à inbox; o fio
mantém cabeçalho enxuto, mensagens com largura controlada e composer fixo; o
contexto é secundário, recolhível e granular.

As medidas locais são derivadas de tokens existentes:

- inbox: `7 × CoeloSize.touchMin` (336 px);
- centro: mínimo de `10 × CoeloSize.touchMin` (480 px);
- contexto: `6 × CoeloSize.touchMin` (288 px);
- rail: `CoeloSize.touchMin + CoeloSpacing.space4` (64 px);
- foto contextual: `CoeloSize.touchMin + CoeloSpacing.space4` (64 px).

Em 1440 px as três áreas ficam visíveis. Em 1024 px a conversa é priorizada,
com rail local e contexto sobreposto. Em 768 px lista e contexto abrem sob
demanda. Em 375 px inbox, conversa e contexto formam telas ou sheets separados.
As decisões usam as constraints disponíveis e os breakpoints oficiais.

## Inbox E Organização

- a faceta inicial é `Todos`, acompanhada de `Institucional` e `Pessoas`;
- `Institucional` é o termo oficial desta experiência e substitui
  `Acadêmico` e `Contextos`;
- busca usa o campo canônico existente no Coelo UI;
- `Criar grupo`, `Nova mensagem` e `Filtrar` formam uma faixa local separada
  das facetas;
- itens fixados aparecem em seção própria e respeitam a faceta atual;
- grupos manuais recém-criados aparecem primeiro em uma seção `Grupos` e não
  nascem fixados;
- a seção `Fixados` pode conter conversas e grupos escolhidos explicitamente;
- fixados podem ser reordenados por arraste e por teclado, sem alterar a ordem
  dos demais itens;
- cada conversa ou grupo possui uma bandeira pessoal com estados vazio,
  vermelho, amarelo e verde; o marcador é visível somente para quem o definiu,
  não fixa o item e não altera a ordem automaticamente;
- grupos manuais mistos aparecem nas facetas representadas por seus membros;
- linhas de conversa usam hover e foco laranja, com raio e respiro do padrão
  de submenu Coelo;
- o menu neutro oferece `Criar grupo com…`, `Convidar para grupo`,
  `Fixar/Desfixar`, divisor e a ação destrutiva `Excluir conversa` ou
  `Excluir grupo`;
- `Criar grupo com…` pré-seleciona os participantes do fio atual;
- `Convidar para grupo` lista somente grupos manuais simulados nos quais o
  usuário atual pode convidar;
- exclusão permanece disponível apenas quando o protótipo possui estado local
  removível correspondente.

## Seleção Hierárquica

Os fluxos de `Criar grupo`, `Nova mensagem` e `Filtrar` compartilham a mesma
composição hierárquica privada:

- chips `Todos`, `Instituições`, `Unidades`, `Grupos`, `Atividades`, `Pessoas`,
  `Responsáveis` e `Crianças` filtram a visualização e não selecionam itens;
- a ação contextual muda com o filtro, como `Selecionar todas as unidades` ou
  `Selecionar todos os responsáveis`;
- pais apresentam estado vazio, parcial ou completo conforme os descendentes;
- busca preserva os ancestrais necessários para contexto, sem selecionar itens
  invisíveis automaticamente;
- seleções de níveis e ramos diferentes podem ser combinadas;
- um resumo persistente apresenta as quantidades selecionadas por categoria;
- `Crianças` representa o contexto da criança e resolve somente responsáveis
  autorizados simulados; a criança não é tratada como destinatária;
- responsáveis repetidos em mais de uma criança são deduplicados no envio, sem
  perder a associação com os contextos selecionados.

A revisão segue a ordem `Instituições`, `Unidades`, `Grupos`, `Atividades`,
`Pessoas`, `Responsáveis` e `Crianças`, com títulos de seção e itens listados
abaixo. A revisão não achata caminhos diferentes em uma lista sem contexto.

## Interações Simuladas

- filtros são rascunhados em modal multi-select e só alteram a inbox após
  `Aplicar`; opções incompatíveis com a faceta são removidas;
- criação de grupo aceita nome, busca e membros de múltiplas instituições,
  passa por revisão e cria um fio coletivo somente em memória;
- nova mensagem seleciona exatamente uma pessoa ou um contexto institucional
  antes da composição; a exceção explícita é a seleção de várias crianças;
- quando uma ou mais crianças são selecionadas, cada criança cria um fio
  próprio no qual seus responsáveis autorizados simulados participam; cada
  mensagem identifica o responsável real que falou;
- somente `Criar grupo` pode reunir várias crianças, responsáveis e demais
  contextos em um único fio coletivo;
- envio em massa compõe antes da seleção, aceita vários ramos da hierarquia,
  deduplica destinatários, revisa e simula entregas privadas independentes;
- arquivo, imagem e vídeo são somente anexos simulados;
- mensagem, emoji, áudio e imagem do fio têm feedback explícito de
  demonstração local;
- Enter envia, Shift+Enter cria nova linha;
- contexto e exclusões usam painel/menu e confirmação acessíveis.

As bolhas de mensagem encolhem conforme o conteúdo até um teto responsivo.
Mensagens longas quebram linhas dentro desse teto, preservando alinhamento de
remetente e destinatário sem transformar o fio em colunas de largura fixa.

## Launcher

O launcher pertence ao shell autenticado, não aparece na rota Conversas e não
depende de flags de páginas individuais. Em repouso é uma cápsula com badge,
“Mensagens”, avatares e menu; hover e foco usam `primary/onPrimary`. Seu
conteúdo é uma experiência compacta própria, aberta em painel ancorado a partir
do breakpoint expanded e em modal ou sheet abaixo dele. O painel compacto tem
cabeçalho laranja, expandir/fechar, busca, as três facetas e lista. O gatilho
fica alinhado ao espaçamento inferior canônico da viewport. Ao lado das facetas
existe uma ação compacta de `Nova conversa`, que reutiliza o fluxo de nova
mensagem. Criação de grupo e filtros completos permanecem exclusivos da página
completa.

## Painel Contextual

Cards de métricas usam ícone pequeno, conteúdo centralizado,
`surfaceContainerLow`, borda `outlineVariant` e raio semântico, preservando a
separação em light e dark. A matriz local cobre:

- instituição: localização, tipo, plano, unidades, grupos, atividades,
  funcionários, responsáveis e alunos;
- unidade: instituição, localização, tipo, plano, grupos, atividades,
  funcionários, responsáveis e alunos;
- grupo/turma: unidade, instituição, localização, tipo, plano, atividades,
  funcionários, responsáveis e alunos;
- atividade: grupo, unidade, instituição, localização, tipo, plano,
  funcionários, responsáveis e alunos;
- profissional: hierarquia autorizada e sete métricas;
- responsável: crianças e quatro métricas;
- perfil duplo: alternância `Profissional | Responsável`;
- grupo manual: membros, papéis, instituições e origens.

Nos contextos institucionais, `Tipo` e `Plano` usam o rótulo em negrito e o
valor em peso normal. A nomenclatura local do tipo passa de `Grupo/Turma` para
`Grupo (Turma)`.

## Grupos, Convites E Administração Local

- o criador do grupo torna-se administrador do grupo;
- o Superadmin criador entra automaticamente;
- administradores podem promover outros membros a administrador;
- membros comuns podem sair;
- quando o último administrador deseja sair, deve promover outro membro antes;
- administradores com permissão simulada podem escolher entre promover alguém
  e sair ou excluir o grupo;
- usuários convidados por outras hierarquias permanecem pendentes até aceitar;
- exclusão usa vermelho semântico e confirmação compacta com a mensagem:
  `O grupo e todo o histórico desta demonstração serão excluídos. Esta ação não
  pode ser desfeita.`;
- todos esses estados existem apenas em memória e não representam autorização,
  notificação, auditoria ou revogação produtiva.

## Modais E Rodapés

- `Criar grupo`, `Nova mensagem` e `Filtrar` reutilizam o frame inspirado no
  popup de bug e a seleção hierárquica aprovada;
- superfícies são neutras, com divisor somente sob o cabeçalho e conteúdo
  rolável;
- hover e foco de opções usam laranja sem overlay cinza;
- composição usa campo delineado, anexos simulados abaixo e ação principal
  estável;
- o rodapé de filtros divide igualmente `Limpar` e `Aplicar`;
- confirmações destrutivas são compactas e usam vermelho semântico.

## Evoluções Fora De Escopo

Instagram e WhatsApp podem futuramente aparecer como canais externos
identificados por origem e associados a um upgrade de plano. Esta entrega
registra somente a direção de roadmap. Qualquer integração exige spec própria
para identidade, consentimento, opt-in, autorização, auditoria, retenção,
limites, custos e operação; nenhum canal ou entitlement é implementado agora.

## Limites De Autorização

No protótipo do Superadmin, um grupo manual pode reunir membros de instituições
diferentes e fica visível aos participantes simulados. Um Admin futuro só pode
criar grupos dentro da própria instituição. O envio em massa nunca cria um fio
compartilhado: cada destinatário recebe uma entrega privada independente.

Essas regras são decisões de produto e UX, não autorização técnica. Produção
permanece bloqueada até existir spec aprovada para autorização física,
auditoria, convites e aceite, administração de grupo, revogação, derivação de
responsáveis por criança, notificações, retenção e proteção cross-tenant. Esta
entrega não altera banco, RLS, API, mídia ou persistência.

## Fronteira Do Design System

O pacote público, catálogo, memória e seção administrativa criados para o chat
anterior serão retirados. Nenhum substituto será promovido nesta fase. Após a
avaliação visual do protótipo, qualquer proposta pública será pequena,
reutilizável e dependerá de nova aprovação explícita.

## Critérios De Aceite

- goldens light/dark em 375, 768, 1024 e 1440 px;
- teclado, foco, semântica, alvos de 48 px e texto a 200%;
- análise estática e testes focados sem falhas;
- nenhuma persistência, entrega, auditoria ou autorização real sugerida;
- contorno e clip arredondado da superfície principal preservados, com divisas
  apenas entre regiões funcionais;
- grupo manual nasce fora de `Fixados`;
- seleção hierárquica suporta estado parcial, combinação de níveis e filtro por
  crianças;
- fixados têm reordenação acessível e bandeira pessoal independente;
- menu contextual, revisão agrupada, exclusão compacta e rodapé de filtros
  seguem a composição aprovada;
- bolhas curtas encolhem conforme o conteúdo e mensagens longas respeitam o
  teto responsivo;
- screenshots e localhost apresentados antes de qualquer promoção.
