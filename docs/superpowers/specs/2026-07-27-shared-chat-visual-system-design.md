---
title: "Sistema Visual Compartilhado De Chat"
source: "Referências visuais fornecidas pelo usuário; docs/design/design-system.md; decisions/0012-contextual-experiences-and-conversation-history.md; decisions/0015-contextual-people-authorizations-attendance.md"
status: "approved"
generated_at: "2026-07-27"
---

# Sistema Visual Compartilhado De Chat

## Objetivo

Criar uma experiência de chat responsiva e navegável para Superadmin, Admin e
Principal usando componentes Flutter reais e fixtures locais. A primeira
entrega valida UX, acessibilidade e composição visual sem integrar backend,
Realtime, mídia, chamadas ou IA.

## Anatomia Aprovada

A experiência usa uma caixa única `Conversas`, formada por avatar contextual,
linha de conversa, cabeçalho, histórico, mensagens e composer. No Principal, a
conversa oficial `Coelo` fica fixa no topo e informa que o assistente chegará
futuramente, sem simular respostas.

O avatar diferencia perfil, presença e Now:

- o anel duplo sólido representa Now não visto;
- o anel neutro representa Now visto;
- presença possui rótulo semântico e nunca depende apenas de cor;
- avatar com Now abre o preview; nome e cabeçalho abrem o perfil contextual;
- sem Now, avatar e nome abrem o perfil.

Mensagens recebidas usam superfície neutra e mensagens enviadas usam
`primaryContainer`. Cada mensagem mostra autoria real, papel, contexto,
horário, estado e, quando aplicável, as crianças relacionadas.

## Contexto, Hierarquia E Privacidade

Cada conversa pertence a um contexto único. Alterar grupo ou atividade abre
outro fio; os históricos não são misturados. Dentro do fio, uma mensagem pode
referenciar nenhuma, uma ou várias crianças autorizadas.

O início de conversa administrativa segue:

`instituição → unidade → grupo/turma → atividade`.

Cada nível mostra breadcrumb, subtipo e quantidade de descendentes. A busca
filtra somente o nível atual. No Superadmin, pesquisa de pessoa é uma ação
separada, exige motivo e só permite iniciar conversa depois da escolha de um
vínculo válido.

O painel de perfil mostra somente os vínculos autorizados. Superadmin vê o mapa
permitido à plataforma; instituição e unidade enxergam apenas a própria
subárvore. Contatos pessoais não aparecem por padrão.

## Responsividade

- `compact` (0–599): inbox e conversa são telas empilhadas.
- `medium` (600–839): rail de conversas e conteúdo lado a lado.
- `expanded+` (840+): inbox e conversa em duas colunas; perfil entra como
  painel lateral.
- no web, um pill no canto inferior direito abre a inbox compacta e pode
  expandir para a rota completa;
- o botão temporário do Coelinho permanece no canto inferior esquerdo.

Admin e Superadmin usam seus shells administrativos. O Principal usa sua
linguagem social, rail no tablet/web e navegação inferior no mobile.

## Componentes Aprovados

| Componente | Package | Responsabilidade |
| --- | --- | --- |
| `CoeloChatAvatar` | `coelo_ui_core` | Identidade, fallback, Now e presença. |
| `CoeloConversationTile` | `coelo_ui_core` | Resumo, horário, não lidas e seleção. |
| `CoeloConversationHeader` | `coelo_ui_core` | Identidade, perfil e ações permitidas. |
| `CoeloMessageBubble` | `coelo_ui_core` | Direção, autoria, contexto, horário e entrega. |
| `CoeloChatComposer` | `coelo_ui_core` | Texto, envio e ações opcionais/desabilitadas. |
| `CoeloAdminContextPicker` | `coelo_ui_admin` | Navegação e seleção hierárquica administrativa. |

Composições de tela, rotas, permissões e busca auditada permanecem nos apps.
Nenhum pacote novo é necessário.

## Estados

Cobrir conteúdo, loading, vazio, erro recuperável, offline, bloqueado, somente
leitura, revogado e IA indisponível. Áudio, mídia, ligação e vídeo aparecem
somente quando permitidos e ficam desabilitados com `Em breve` até a integração.
Não existem callbacks vazios.

## Refinamento Aprovado Do Launcher

- launcher recolhido usa superfície branca no tema claro, sombra leve, avatares
  sobrepostos e hover/foco em `primaryContainer`;
- popup compacto usa cabeçalho em `primary`, busca imediatamente abaixo e
  acomoda filtro de conceito, instituição, unidade, grupo/turma, atividade e
  criança;
- selecionar uma conversa no popup abre o fio compacto sem abandonar a tela;
- o fio compacto mantém voltar, expandir, fechar, histórico e composer;
- a página completa mantém a mesma filtragem contextual em todos os
  breakpoints;
- `Voltar à tela anterior` fica fixado na parte inferior da caixa de conversas
  e preserva a origem conhecida, com fallback para Instituições;
- ligação e videochamada não aparecem nesta etapa, nem mesmo desabilitadas.

Este refinamento substitui a previsão anterior de mostrar ligação e vídeo como
ações futuras. Áudio e mídia do composer ficam habilitados na demonstração
local e expõem estados de gravação, carregamento e envio.

### Hierarquia E Destinatário

- `Todas` é a visão inicial da caixa de entrada;
- o filtro de conceito diferencia `Instituições e unidades`, `Turmas` e
  `Atividades`;
- instituição, unidade, grupo/turma e atividade formam uma cascata: alterar um
  ancestral limpa seleções descendentes incompatíveis;
- criança permanece em um filtro separado e só apresenta vínculos compatíveis
  com o contexto ativo;
- no seletor de nova conversa, qualquer nível autorizado pode ser o
  destinatário final; o controle de selecionar o nível e o controle de
  aprofundar na hierarquia são ações distintas;
- o diálogo usa `surface` como base, barreira e fechamento conforme o contrato
  oficial de superfícies.

### Presença, Now E Simulação Local

- o ponto de presença aumenta sem substituir o rótulo semântico;
- o anel duplo de Now recebe traços mais espessos e sombra laranja discreta no
  estado não visto, sem gradiente;
- texto enviado pelo composer entra no histórico local e demonstra envio,
  leitura e resposta simulada;
- áudio e mídia demonstram, em memória, `Gravando áudio`, `Enviando áudio`,
  `Carregando mídia` e `Enviando mídia`, sem upload, arquivo ou persistência.

## Acessibilidade

- alvos mínimos de 48 px;
- foco visível e ordem coerente;
- `Esc` fecha overlays e devolve foco ao acionador;
- tooltips para ações por ícone;
- semântica anuncia Now, presença, contexto, não lidas e entrega;
- suporte a texto em 200%, light/dark e reduced motion;
- cor nunca é o único indicador de estado.

## Fora De Escopo

Supabase, repositories, RLS adicional, persistência, Realtime, envio real,
Cloudflare R2, upload, áudio, ligação, videochamada, viewer completo de Now,
notificações e IA.

## Critérios De Aceite

- componentes e seletor possuem widget tests;
- catálogo demonstra Superadmin/Admin e Principal em 375, 768, 1024 e 1440;
- Superadmin possui `Comunicação > Conversas`, rota protegida e launcher;
- índice e catálogo permanecem sincronizados;
- análise estática, testes focados e suite relevante passam;
- imports respeitam as fronteiras públicas dos packages.
