---
source: "Solicitação aprovada em 2026-07-27 e decisão aprovada em 2026-07-28; docs/design/design-system.md; specs/013-ui-packages-componentization.md"
status: "approved"
generated_at: "2026-07-28"
---

# Ajustes do chat do Superadmin

## Objetivo

Evoluir o protótipo existente de conversas do Superadmin sem trocar sua
arquitetura, preservando dados locais simulados. A experiência deve ganhar
filtros contextuais previsíveis, mais espaço útil, resumo granular do
destinatário e composição de mensagens operável por mouse e teclado.

## Escopo

- manter o launcher de mensagens em todas as telas renderizadas pelo
  `SuperadminShell`;
- aplicar laranja principal no hover e foco do launcher, com conteúdo branco;
- melhorar alinhamento, tamanho e espaçamento do cabeçalho compacto;
- separar filtros de contextos institucionais e filtros de pessoas;
- condicionar os níveis seguintes à seleção anterior;
- manter a busca textual abaixo da classificação contextual;
- agrupar conversas em seções recolhíveis e permitir recolher toda a inbox;
- acrescentar painel contextual direito recolhível;
- simular criação de grupos, seleção individual, seleção total e envio em
  massa com revisão e confirmação;
- habilitar envio por botão e `Enter`, reservando `Shift+Enter` para nova linha;
- manter emoji, áudio e imagem quando já suportados localmente;
- exibir o contexto ativo no rodapé do compositor;
- padronizar menus, hover, foco, modal e fechamento pelos contratos Coelo;
- preservar funcionamento responsivo em 375, 768, 1024 e 1440 px.
- promover o padrão-base administrativo de chat e apenas as APIs públicas
  neutras aprovadas nesta decisão.

## Fora de escopo

- persistência de mensagens, grupos ou seleções;
- envio real, fila, notificações ou integração com backend;
- criação de autorização, RLS, RPC, Edge Function ou trilha de auditoria real;
- chamadas e videochamadas;
- um `CoeloAdminChatLayout` monolítico;
- promoção de filtros, recipient picker ou regras de envio para pacote público;
- alteração da experiência social do app Principal.

## Decisão aprovada: padrão institucional de chat administrativo

Em 2026-07-28, `pattern.chat-admin` foi aprovado como padrão-base de chat
institucional administrativo para Admin e Superadmin. Sua anatomia é: launcher
global, toolbar e filtros, inbox ou rail, fio, resumo contextual e compositor.
O catálogo é a referência executável dessa composição; ele demonstra o padrão,
mas não é importado pelos apps consumidores.

As variantes responsivas aprovadas são:

- compact: navegação empilhada entre inbox, fio e contexto;
- medium: rail e fio, com contexto aberto sob demanda;
- expanded/large: laterais recolhíveis e três áreas quando houver espaço.

As medidas do padrão são inbox de 336 px, rail de 80 px, contexto expandido de
288 px, contexto recolhido de 64 px, launcher com máximo de 460 × 600 px,
avatar de inbox/cabeçalho de até 48 px e foto contextual 1:1 de até 64 × 64
px. A inbox aproxima os 339–340 px dos anexos e equivale a sete alvos de 48
px. O rail usa `CoeloSpacing.space20`; o contexto expandido usa seis alvos de
48 px; o recolhido combina alvo de 48 px com 16 px de padding. O launcher
preserva margens de 16 px e respiro inferior de 96 px. A foto de 64 px passa a
usar `CoeloSize.avatarXl`, pertencente à escala oficial de avatares.

O pacote público mínimo é limitado a `CoeloAdminChatMetric` (`label` e
`value`), `CoeloAdminChatContextSummary` e `CoeloSize.avatarXl = 64`. O painel
contextual local do Superadmin migra para `CoeloAdminChatContextSummary`.
Não se promove um layout monolítico, filtros, recipient picker ou regra de
envio: esses elementos continuam no feature enquanto dependerem de domínio e
autorização.

A implementação atualiza o Design System e seu índice, e registra
`pattern.chat-admin` no catálogo como referência executável. A cobertura inclui
API pública, widget, foco, semântica, duas a seis métricas, texto a 200%, temas
claro/escuro, 375/768/1024/1440 px e goldens mobile claro e desktop escuro.
Depois de atualizar esta spec e o Design System, a memória durável é projetada
para `team`, sem dados identificáveis.

## Composição

### Launcher global

O launcher permanece composto uma vez pelo `SuperadminShell`, o que o torna
presente nas telas atuais e nas futuras que reutilizarem o shell. Em repouso
usa superfície neutra. Hover e foco usam `colorScheme.primary`; texto, ícones
e elementos internos usam `colorScheme.onPrimary`. A mudança de estado não
altera dimensões ou posição.

Na referência executável do catálogo, larguras abaixo de `large` abrem o
launcher como modal com barreira, margem mínima de 16 px e limite de
460 × 600 px. A partir de `large`, ele ocupa uma faixa irmã reservada de 460 px,
sem sobrepor fio ou contexto; enquanto aberto, a inbox usa rail de 80 px e o
resumo contextual usa a variante recolhida de 64 px. A ação de fechar usa
`close_rounded`, alvo mínimo de 48 px, `error` em repouso e
`errorContainer` em hover ou foco.

Os filtros administrativos usam superfície neutra em repouso. Seleção, hover
e foco usam `primaryContainer`, conteúdo e contorno `primary`, com contorno de
2 px e overlay transparente.

### Inbox esquerda

A inbox organiza conversas em seções como `Grupos`, `Pessoas` e contextos
institucionais. Cada seção pode expandir e recolher. Em layout amplo, a coluna
inteira pode virar um rail estreito e restaurar sua largura sem perder a
conversa selecionada.

O botão de nova conversa não possui fundo laranja em repouso. Hover, foco e
seleção usam os tokens semânticos de destaque definidos pelo contrato Coelo.
Não existe divisor redundante acima da ação de voltar.

### Conversa central

O fio ocupa todo o espaço restante entre as laterais visíveis. O contorno da
superfície é contínuo. Divisores aparecem apenas quando separam regiões
semânticas e não comprimem o cabeçalho ou o compositor.

### Painel contextual direito

O painel identifica o destinatário e mostra de dois a seis indicadores simples
e relevantes à sua granularidade. Ele também pode ser recolhido.

Quando houver foto contextual, o recorte permanece 1:1 e limitado a 64 px. A
imagem é anunciada como `Imagem de contexto de {título}` e exclui a semântica
interna do widget visual, sem adicionar parâmetro ou classe à API pública.

Exemplos:

- instituição: localização, unidades, grupos, atividades e pessoas;
- unidade: localização, grupos, funcionários, crianças e atividades;
- grupo ou turma: professores, crianças, responsáveis e atividades;
- responsável: instituições, unidades, turmas e crianças vinculadas;
- criança: responsáveis, turmas, atividades e instituições vinculadas.

Os valores são fixtures locais e não representam dados reais.

## Filtros e busca

A classificação principal separa `Contextos` de `Pessoas`.

- Contextos: UF, instituição, unidade, grupo/turma e atividade.
- Pessoas: responsável, criança, professor e outros.

Cada seleção limita as opções descendentes e limpa seleções incompatíveis. Os
painéis usam superfície neutra, borda, elevação e abertura a 4 px do gatilho.
As opções são linhas contínuas de no mínimo 48 px. Seleção, hover e foco usam
`primaryContainer` com conteúdo em `primary`, sem camada cinza adicional.

A busca textual filtra o resultado já delimitado pelos filtros contextuais.

## Nova conversa, grupos e envio em massa simulado

O fluxo local permite:

1. escolher conversa individual ou grupo;
2. percorrer a hierarquia disponível;
3. selecionar itens individualmente ou usar `Selecionar todos`;
4. revisar escopo, destinatários e quantidade;
5. confirmar o envio simulado;
6. apresentar confirmação local e inserir a mensagem no protótipo.

A ação nunca sugere que houve comunicação real. A confirmação identifica
explicitamente `Demonstração local`. O fluxo mantém a indicação de acesso
auditado apenas como representação visual, sem afirmar que existe auditoria
persistida.

## Compositor

O compositor não possui linha superior redundante. Possui campo de mensagem,
emoji, áudio, imagem e botão Enviar. O botão usa `primary` e `onPrimary` quando
habilitado e o estado desabilitado do tema quando vazio.

- `Enter`: envia texto não vazio;
- `Shift+Enter`: insere nova linha;
- botão Enviar: executa a mesma ação de `Enter`;
- áudio e imagem: mantêm as simulações existentes;
- contexto ativo: aparece alinhado à extrema direita abaixo das ações.

## Modais e menus

Modais usam `colorScheme.surface`, barreira preta translúcida, raio, borda e
elevação oficiais. O fundo-base não usa laranja-claro. Fechar usa
`Icons.close_rounded`, ícone em `error`, fundo transparente e
`errorContainer` no hover ou foco, com alvo mínimo de 48 px, tooltip e retorno
do foco à origem.

Menus e itens da inbox usam hover e foco em `primaryContainer`, nunca cinza.

## Responsividade

As decisões dependem de `LayoutBuilder` e das restrições recebidas.

- 1440 px e demais larguras amplas: inbox, conversa e painel contextual;
- 1024 px: conversa com laterais recolhíveis; o painel direito inicia recolhido
  quando necessário;
- 768 px: rail da inbox e conversa; detalhes contextuais abrem sob demanda;
- 375 px: navegação empilhada entre inbox, conversa e contexto.

Recolher uma lateral preserva seleção e foco. O layout suporta texto a 200% sem
rolagem horizontal não intencional.

## Acessibilidade

- alvos interativos com no mínimo 48 px;
- foco visível equivalente ao hover;
- semântica para expansão, recolhimento, seleção total, quantidade selecionada,
  contexto e envio;
- operação equivalente por mouse, teclado e toque;
- `Esc` fecha menus e modais permitidos e restaura o foco;
- cores resolvidas por tokens nos temas claro e escuro;
- movimento reduzido respeitado nas transições.

## Arquitetura e fronteiras

As mudanças reutilizam `CoeloChatComposer`, componentes de chat existentes,
tokens e padrões administrativos. `CoeloAdminChatMetric`,
`CoeloAdminChatContextSummary` e `CoeloSize.avatarXl` são a superfície pública
mínima aprovada. Composição de domínio, fixtures, agrupamento, filtros,
destinatários e regras de envio permanecem locais ao feature de chat do
Superadmin. Nenhuma nova dependência será adicionada.

## Testes exigidos

- teste unitário da cascata e limpeza de filtros;
- widget tests para grupos recolhíveis e laterais;
- widget test do launcher global e seus estados de hover e foco;
- widget test de `Enter`, `Shift+Enter` e botão Enviar;
- widget test de seleção individual, seleção total, revisão e confirmação local;
- widget tests do painel contextual por tipo;
- testes de API pública, widget, foco e semântica de
  `CoeloAdminChatContextSummary`, incluindo duas a seis métricas;
- widget tests de menus e modal com tokens canônicos;
- verificação em 375, 768, 1024 e 1440 px e texto a 200%;
- análise estática e formatação apenas dos arquivos afetados;
- validação visual em temas claro e escuro, com goldens mobile claro e desktop
  escuro.

## Riscos e limites

- `Selecionar todos` pode parecer uma ação real; toda confirmação deve declarar
  que é uma demonstração local.
- Os indicadores contextuais são amostras e não devem ser interpretados como
  modelo de dados aprovado.
- A seleção em massa futura exigirá spec própria para autorização por tenant,
  limites, auditoria, consentimento, fila, falhas parciais e prevenção de abuso.

## Critérios de aceite

- o launcher aparece em qualquer destino do shell e usa hover/foco da marca;
- os filtros distinguem contexto institucional de pessoa e condicionam níveis;
- inbox e painel contextual recolhem sem perder o fio selecionado;
- o painel mostra entre dois e seis indicadores compatíveis com o destinatário;
- a demonstração permite seleção individual e total, revisão e confirmação;
- o compositor envia por botão ou `Enter`, aceita nova linha por `Shift+Enter`
  e mostra o contexto ativo;
- superfícies, menus e modais respeitam os contratos Coelo;
- `pattern.chat-admin` demonstra a anatomia e variantes aprovadas no catálogo;
- o painel contextual do Superadmin usa a API pública mínima aprovada, sem
  promover layout, filtros, destinatários ou regras de envio;
- não existe persistência, envio real ou nova dependência;
- testes focados, análise estática e validação responsiva passam.
