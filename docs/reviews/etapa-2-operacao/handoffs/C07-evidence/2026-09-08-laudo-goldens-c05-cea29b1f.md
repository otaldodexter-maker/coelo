---
title: "C07 — laudo das 61 divergências visuais da C05 no commit fixado cea29b1f (código de 7810e7c5)"
source: "failures/ gerados por flutter test em C:/Users/adrie/Documents/Coelo.worktrees/e2-r01-c07 (17:46–17:50, código cea29b1f = 7810e7c5); seis laudos de subagentes somente-leitura revisados por C07; specs/050-principal-ui-ux-closure.md; specs/036-principal-now-publication-mvp.md; docs/superpowers/plans/2026-09-01-principal-ui-ux-closure.md; docs/superpowers/specs/2026-08-20-coelo-happens-publication-design.md; .agents/skills/coelo-ui/references (C00); git log dos masters e dos arquivos de feature"
status: "evidence-review;errata-1;errata-2"
generated_at: "2026-09-08T18:20:00-03:00"
timezone: "America/Sao_Paulo"
---

# Laudo — 61 divergências da C05 (60 goldens + 1 assertiva)

Critério único por caso:

- **A** — master desatualizado: a diferença é explicada por fonte aprovada **posterior** ao master.
  Exige decisão nominal de atualização de master (C00/Owner); não exige correção de código.
- **B** — defeito real no render atual (corte, overflow, sobreposição, elemento faltando sem fonte,
  quebra indevida): exige correção de código no arquivo indicado.
- **C** — diferença de ambiente/renderização (antialiasing, fonte) sem mudança de composição.
- **D** — indeterminado: a fonte aprovada não decide; precisa decisão do Owner/C00.

Um caso pode ser A e ainda carregar um **sinal B** (defeito visível independente da decisão de
master). Nenhuma imagem de `failures/` é referência; nenhum master foi regenerado.

## Resumo executivo

| Família | Casos | A | B | C | D | Sinais B adicionais | Decisão pendente |
|---|---|---|---|---|---|---|---|
| Acontece | 10 | 10 | 0 | 0 | 0 | nenhum | D1 ação circular invisível em repouso; D2 golden de hover prova pouco |
| Perfil | 10 | 10 | 0 | 0 | 0 | nenhum | nenhuma; observação sobre Localização/Fundação/Colaboradores |
| Momentos | 11 | 11 | 0 | 0 | 0 | nenhum | recorte `cover` em ≥768 exibe 25–47 % da mídia |
| Chat | 9 | 4 (1024/1440) | 0 | 0 | 5 (375/768) | **2 reais**: contorno do card sob a paginação; inset do cabeçalho compacto | app bar compacto `d9232a94` sem aprovação visual localizada |
| Comunicações + formulário | 4 | 0 | 0 | 0 | 4 | nenhum novo | indicador de status no card compacto; rodapé do formulário dentro da rolagem |
| Circulares | 3 | 3 | 0 | 0 | 0 | nenhum | nenhuma |
| Publicar no Agora | 13 + 1 | 0 | 0 | 0 | 13 (+1 assertiva desatualizada) | **1 condicional**: ramo `wide` morto em 1440 | ratificar `3419a89e` (sem rail) ou restaurar contrato 2026-08-31 |
| **Total** | **61** | **38** | **0** | **0** | **22 + 1** | **3** | **6 decisões** |

Leituras que mudam o próximo passo:

1. **Nenhum caso é defeito puro (B) e nenhum é ambiente (C).** Todas as 60 comparações de pixel
   divergem por composição; a única assertiva é teste desatualizado. A frase "golden desatualizado"
   da C05 é correta em 38 casos e **insuficiente** em 22: nesses, a fonte aprovada não decide e a
   regeneração exige decisão do Owner.
2. **Três sinais B reais/condicionais** foram encontrados dentro de casos A/D e continuam válidos
   independentemente da decisão de master: contorno do card do inbox do Chat pintado por baixo do
   rodapé de paginação; cabeçalho compacto do shell centralizado/com inset quando há
   `compactActions`; ramo `wide` da página Publicar no Agora inalcançável (palco 260 px em 1440).
3. **Achado transversal:** `d9232a94` (2026-09-01) mudou o app bar compacto e o `_PageHeader` do
   `SuperadminShell` sem regenerar goldens nem registrar aprovação visual; o anexo 31 aprovado ainda
   mostra hambúrguer + marca central. Isso explica o Chat em 375/768 e, por hipótese a confirmar, os
   77 goldens de Estruturas que já divergem no baseline R01 `479d1bd1`.

## 1. Acontece — `principal_happens_preview_golden_test.dart` (10 casos, todos A)

Master: `50bf7b0c` (2026-08-31 19:11). Fonte posterior: spec 050 §"Entrada Publicar agora"
(2026-09-01) e plano 2026-09-01 Task 4 Step 3; commits `b9c75c7e` (15:46) e `3fd605b8` (16:01),
que não regeneraram goldens. `e7985f31`/`1ec8efc4` (C05, hoje) devolveram e reverteram a anatomia
antiga; o HEAD segue a spec.

Diferença única em todos os casos, confirmada com medição de bounding box: **zero pixel diverge fora
do card "Publicar agora"**. Master: borda sólida 1 px + círculo 44 px `primary` com "+" branco.
Atual: borda tracejada 1,5 px + "+" `primary` sobre círculo pintado em `surface`. Header, carrossel,
feed, dock, FAB, launcher e coluna lateral (1440) idênticos.

| Caso | Diff | Classe | Observação |
|---|---|---|---|
| light/dark 375 | 0,63 % | A | — |
| light/dark 768 | 0,28 % | A | — |
| light/dark 1024 | 0,24 % | A | — |
| light/dark 1440 | 0,15 % | A | coluna lateral 0 px de diff |
| dark_375_text_200 | 0,65 % | A | rótulo em 2 linhas sem corte nos dois; sem defeito a 200 % |
| now_hover_light_1440 | 0,15 % | A | hover em "Beatriz L." renderiza igual nos dois; a falha é só o card Publicar agora |

Decisões antes de regenerar (para não regenerar duas vezes):

- **D1** — a "ação circular central" da spec é pintada em `colors.surface`, igual ao interior do card
  e ao fundo: **invisível em repouso** nos dois temas (`principal_happens_preview_page.dart`
  `_PublishNowCard` L723–793, L764 `color: active ? primary : surface`). Segue literalmente o plano;
  a spec fala em ação circular como parte da anatomia. Os "anexos 1 e 2" citados pela spec não
  foram localizados no repositório.
- **D2** — o golden `now_hover` prova pouco: hover-vs-repouso do card difere em 79 px (Δ máx.
  32/255) porque `ClipRRect` + imagem cobrem a `side` de 2 px do `TextButton` (`_NowCard`
  L828–856, inferência de código).

## 2. Perfil — `principal_profile_preview_golden_test.dart` (10 casos, todos A)

Master: `50bf7b0c` (9) e `21e0ed09` (`text_200_dark_1440`), ambos 2026-08-31. Fonte posterior: spec
050 §"Perfil" ("não introduz seguidores públicos") e plano 2026-09-01 Task 4 Step 4 (remover
`Seguidores`, `Seguindo`, `principal-profile-follow`; métricas Publicações/Momentos/Circulares);
implementado em `b9c75c7e`, sem regenerar goldens. `f413c2dc` (hoje) só afeta `_ProfileMomentCard`
na aba Momentos, sem efeito nestes casos.

Padrão comum: master tem `Acompanhar` + `Mensagem` e 6 métricas (`1,2 mil Seguidores`,
`286 Seguindo`, `128 Publicações`, `Localização`, `Fundação`, `Colaboradores`); atual tem só
`Mensagem` e 3 métricas (`128 Publicações`, `42 Momentos`, `12 Circulares`). Capa, avatar,
identidade, bio, Destaques, Vínculos, evento, abas, dock, FAB e "Contexto atual" idênticos. Nenhum
"0" nem vazio: os valores vêm da fixture `horizon`. O diff sobe em 375/200 % porque o card de
métricas encolhe de 2 para 1 linha e tudo abaixo sobe.

| Caso | Diff | Classe |
|---|---|---|
| light/dark 375 | 22,12 / 22,14 % | A |
| light/dark 768 | 1,33 / 1,35 % | A |
| light/dark 1024 | 0,99 / 1,00 % | A |
| light/dark 1440 | 0,73 / 0,74 % | A |
| text_200_light_375 | 10,77 % | A |
| text_200_dark_1440 | 11,55 % | A |

`editorial_light_375` e `moments_dark_1440` passam porque `ensureVisible` rola até a linha de abas e
a seção identidade+métricas fica fora do quadro. Observações sem defeito: os masters 375/768/1024
truncavam ("São Paul…", "Desde 1…"); o atual não trunca. `Localização` sobrevive em "Contexto atual"
e na aba Sobre; `Fundação` e `Colaboradores` não aparecem em mais nenhum lugar — a remoção se apoia
no plano, não na spec; se o Owner considerar o plano insuficiente para esses três, essa parte vira D.

## 3. Momentos — `principal_moments_preview_golden_test.dart` (11 casos, todos A)

Master: `50bf7b0c` (2026-08-31 19:11), viewer em janela: `AspectRatio` 0,355 centrado,
`ClipRRect`, letterbox preto e, em ≥1200, aside "Em alta na escola" + CTA "Enviar momento". Fonte
posterior: spec 050 §"Agora e Momentos" ("a mídia ocupa a tela inteira em mobile, tablet e desktop
e todo chrome externo é suspenso"; critério L169); implementado em `e1cf1be3` (2026-09-01 15:04,
"make principal moments fullscreen"), sem regenerar goldens. `cea29b1f` (`momentos.remove`) não
altera a composição do golden (o botão só aparece com `onRemove` concedido; fixture renderiza "⋯").

Atual: mídia edge-to-edge `BoxFit.cover`, gradientes, retorno "‹ Momentos", mudo, rail
curtir/comentar/compartilhar/salvar/⋯, legenda no rodapé. Sem overflow, corte de texto, controle
ilegível ou elemento exigido faltando.

| Caso | Diff | Classe | Sinal |
|---|---|---|---|
| light/dark 375 | 99,53 % | A | tile exibe ≈85 %; sem corte |
| light/dark 768 | 99,99 % | A | D: cover exibe ≈47 %, topo da cabeça cortado |
| light/dark 1024 | 99,99 % | A | D: cover exibe ≈35 % |
| light/dark 1440 | 99,93 / 100 % | A | D: cover exibe ≈25 % |
| text_200_light_375 | 99,17 % | A | legenda e rail disjuntos; sem overflow |
| text_200_dark_1440 | 100 % | A | o **master** tinha títulos truncados e CTA cortado a 200 %; o atual não |
| like_hover_light_1440 | 99,93 % | A | hover preservado (círculo `primaryContainer` + coração `primary`) |

Decisão D antes de regenerar: recorte `cover` em paisagem (≥768) exibe 25–47 % da mídia
(`_SpriteImage` ≈L735–775 e `_MomentFrame` ≈L493–560 de `principal_moments_preview_page.dart`). Não
há aprovação explícita do Owner sobre cover vs contain/pillarbox em desktop. Conflito documental a
registrar: a projeção `docs/knowledge/team/principal-moments-viewer.md` (validated, 2026-08-31)
ainda diz que "o desktop pode manter contexto auxiliar compacto"; a spec 050 diz "todo chrome
externo é suspenso". O CTA "Enviar momento" saiu do viewer com o aside.

## 4. Chat — `superadmin_chat_page_golden_test.dart` (9 casos: 4 A, 5 D, 2 sinais B)

Master: `7ed598cf` (2026-09-01 14:48). Três causas raiz, todas em commits de branches paralelas
mescladas às 17:09–17:24 de 2026-09-01 e todas no HEAD:

1. **App bar compacto + cabeçalho de página** — `d9232a94` (2026-09-01 12:46) em
   `superadmin_shell.dart`: `_CompactAppBar` troca hambúrguer + marca central por marca à esquerda +
   "Coelo ›" (`toolbarHeight: space16`, `leadingWidth: 148`); `_PageHeader` ganha ramo
   `compact && visibleActions.isNotEmpty` com `Stack(alignment: topEnd)`. Coberto por
   `superadmin_shell_test.dart` L938–947, **sem aprovação visual localizada**: a matriz de baselines
   (2026-08-04) não o menciona; o anexo 31 `institution_form_create_light_375.png` (`d8800300`)
   ainda mostra hambúrguer + marca central e a matriz diz que "o shell, o menu atual e o chat
   exibidos nesses goldens também pertencem à referência".
2. **Circulares sai de Comunicação** — `52735a18` (15:23) move o nó para o grupo Principal
   (`superadmin_navigation.dart`); fonte: spec 050 L43–44/174. Correção ao relato da C05:
   Circulares não foi para Governança; Governança apenas passou a ocupar a linha.
3. **Paginação no inbox** — `2d193ba1` (16:33) adiciona `SuperadminListingPaginationFooter`; fonte:
   baseline 2026-08-04 `pattern.directory-pagination`.

| Caso | Diff | Diferenças | Classe | Sinal B |
|---|---|---|---|---|
| light/dark 375, reduced_motion_light_375 (byte-idêntico ao light) | 3,61 / 3,77 / 3,61 % | app bar; título "Conversas" x 20→40; legenda 2→1 linha; ícone da ação compacta reposicionado; card desce 16 px | **D** (causa 1) | **sim** — inset do título 40 px enquanto páginas sem `compactActions` ficam em 20 px e o card começa em 16 px |
| light/dark 768 | 4,45 / 5,69 % | app bar; bloco título+legenda **centralizado** (x 20→236); ícone junto ao título; rodapé "‹ Página 1 de 1 ›" novo; borda esquerda do card termina em y≈800 e o canto inferior-esquerdo some sob o rodapé | **D** (causas 1 e 3) | **sim (2)** — contorno do card quebrado sob o rodapé; cabeçalho centralizado por causa do `Stack` |
| light/dark 1024, light/dark 1440 | 0,20 / 0,20 / 0,14 / 0,14 % | sidebar: "Circulares" sob Comunicação → "Governança"; rodapé de paginação novo; linha vertical x=308 (y 790–865) e borda inferior marcadas no diff = contorno oculto | **A** (causas 2 e 3) | **sim** — contorno esquerdo/inferior do card oculto pelo rodapé |

Arquivos dos sinais B (reportados, não corrigidos por C07):

- Contorno sob a paginação: `apps/superadmin/lib/features/chat/presentation/screens/superadmin_chat_page.dart`
  L617–624 (`DecoratedBox` com `Border.all` + radius, sem `ClipRRect`), L700–716 (`_workspace`,
  inbox 336 px), L798–815 (footer dentro de `_inbox`); e
  `apps/superadmin/lib/shared/presentation/widgets/superadmin_listing_pagination_footer.dart`
  L42–56 (`ClipRect` + `BackdropFilter` + `Container` opaco em largura total, pintando sobre a borda
  de 1 px e o canto arredondado — o widget nasceu para rodapé fora de card).
- Cabeçalho compacto: `apps/superadmin/lib/app/shell/superadmin_shell.dart` `_PageHeader`
  L1535–1566 (ramo compacto com `Stack`), montado por `Column` sem `crossAxisAlignment.stretch`
  (L302–316, L443–457); o ramo não compacto usa `Row` + `Expanded` e ocupa a largura.

Observação: a coluna de 336 px do inbox sempre cai na variante compacta "Página X de Y", mesmo em
desktop; não há spec específica do chat para isso.

## 5. Comunicações e Circulares em 375 + formulário (7 casos: 3 A, 4 D)

Cronologia confirmada: masters `fe73cd11` (Comunicações, 2026-09-01 14:13), `5e714c16`
(Circulares, 15:58), `9be3ccdb` (formulário, 2026-08-20). Posteriores: `d4374e39` (15:08, rodapé do
formulário para dentro da rolagem no compacto, `superadmin_form_frame.dart`, sem spec); `2d193ba1`
(16:33, rodapé compacto de paginação em notices/circulars — o widget não mudou desde `d8800300`
e Instituições já o usava); `a0be1abe` (2026-09-08 01:04, `ConstrainedBox(minWidth/minHeight: 48)`
no indicador de status, com evidência própria dizendo "não se declara aprovação visual integral dos
consumidores"); `116231bd` (C05, 14:52, indicador movido para a linha de descritores no card
compacto, sem spec/baseline).

Corroboração: `docs/reviews/evidence/etapa-2/comunicacao/2026-09-07-notice-visual-baseline.md`
registrou em 07/09 os três goldens de Comunicações em 0,20/0,20/0,47 % (só rodapé); hoje estão em
5,31/4,88/7,50 %. O acréscimo é exatamente `a0be1abe` + `116231bd`.

| Caso | Diff | Diferenças | Classe |
|---|---|---|---|
| communication_directory light/dark 375 | 5,31 / 4,88 % | título continua em 1 linha; ponto de status sai da linha do título para a linha de descritores; essa linha cresce +16 px (caixa de 48 px); card seguinte desce e o título dele fica cortado ao meio pelo rodapé sticky (no master estava inteiro); rodapé em `labelLarge` com chevrons de 48 px | **D** (parte do rodapé, isolada, é A) |
| communication_directory_text_200_375 | 7,50 % | quebra do título muda de posição; ponto na linha do chip; 2.º card cortado pelo rodapé; chip "♡ Para…" truncado **já existia no master** | **D** |
| notice_form_initial_mobile_light_375 | 37,69 % | único delta: o card do rodapé (Continuar/Salvar rascunho/Cancelar) sai do fundo fixo da viewport e passa a ficar logo após o campo Prioridade, dentro da rolagem; campos, stepper e hierarquia idênticos | **D** |
| circular_directory light/dark 375 | 0,20 / 0,20 % | **somente o rodapé**: "Página 1 de 1" em `labelLarge`, chevrons arredondados em botões de 48 px | **A** |
| circular_directory_text_200_375 | 0,47 % | só o rodapé a 200 %, sem truncamento | **A** |

Decisões:

- **Indicador de status no card compacto** (`coelo_admin_expandable_status_indicator.dart`,
  central, 17 consumidores; `notice_directory_page.dart` `_noticeCard` L633–700): (a) aceitar o
  indicador na linha de descritores e regenerar os 3 masters 375; ou (b) exigir posição de cabeçalho
  com alvo 48 px **sem consumir layout** (hit-test/semântica em vez de `ConstrainedBox`), o que
  devolve o título a uma linha sem mover o indicador. Inconsistência a registrar: a baseline
  Instituições usa indicador **local** de 24 × 24 sem alvo 48
  (`institution_status_presentation.dart`), então a referência visual não sofreu a mudança que os
  consumidores sofreram.
- **Rodapé do formulário compacto** (`superadmin_form_frame.dart`, central, 18 consumidores): o
  golden aprovado do anexo 31 `institution_form_create_light_375.png` mostra rodapé fixo no fundo
  **e também falha hoje** (assim como `unit_form_create_light_375`); nenhum golden compacto de
  formulário foi regenerado após `d4374e39`. (a) aceitar rodapé dentro da rolagem → atualizar
  `form-layout-contracts.md` e regenerar todos os masters 375 de formulários; ou (b) restaurar rodapé
  fixo com inset de rolagem igual à altura do rodapé. Até lá, não regenerar.

## 6. Publicar no Agora — `principal_now_publication_golden_test.dart` (13 goldens D + 1 assertiva)

Masters: `50bf7b0c` (11) e `21e0ed09` (375, ambos 2026-08-31). Rail lateral de 2 etapas entrou em
`fa293a6d` (2026-08-27). `3419a89e` (C05, 2026-09-08 14:25) removeu rail, cabeçalho "Sua
publicação", card "Prévia do Agora" (1440) e `Continuar`/`Anterior`; adicionou barra de 3 segmentos
e coluna editorial na mesma tela; palco 300→260 px em ≥600. Sem `RenderFlex overflowed` no log; o
que parece cortado em 375/200 % é a borda do viewport rolável (rodapé é irmão do `Expanded` no
`PrincipalPublicationFrame` L55–78; `page_test` alcança os campos por `ensureVisible`).

| Caso | Diff | Classe | Sinal |
|---|---|---|---|
| light/dark 375 | 49,10 / 52,68 % | D | chip "Imagem" pouco legível no escuro — pré-existente no master |
| light/dark 768 | 34,76 / 37,46 % | D | — |
| light/dark 1024 | 35,09 / 38,01 % | D | — |
| light/dark 1440 | 32,73 / 35,86 % | D | **B condicional**: palco 260 px, igual ao de 1024; coluna editorial mais larga que a zona de mídia |
| light_375_200 | 51,91 % | D | — |
| dark_1440_200 | 28,73 % | D | rótulos Texto/Música/Cortar/Capa com 8 px entre si, apertados sem sobreposição |
| audience_hover_light_1440 | 23,81 % | D | hover preservado; B condicional |
| cover_open_light_1440 | 32,03 % | D | bottom sheet idêntico; B condicional |
| crop_open_light_1440 | 32,37 % | D | bottom sheet idêntico; B condicional |

**Por que D e não A.** O master foi lançado como "estágio visual aprovado" e o mesmo `21e0ed09`
gravou em `docs/knowledge/team/now-publication-mvp.md` (validated) que o Agora "preserva literalmente
a anatomia comum de Publicar no Acontece e Publicar em Momentos" e que "o preview lateral e o rodapé
permanecem contidos nessa superfície". `principal-visual-surfaces.md` (C00, 2026-09-08 12:11) manda
"preservar essa geometria e as etapas existentes… nem eliminar etapas". As linhas da spec 036 citadas
por `3419a89e` são de 2026-08-20, **anteriores** ao master; a PNG `call_Xf4KknVH3c3XUaOk6VWaITXM.png`
que a spec e o commit invocam **não existe** em nenhum worktree nem no repositório. A spec 050
("Desktop usa área editorial e preview proporcionais") é compatível com as duas leituras. A C05 r16
relata que o Owner disse "o estilo de publicações é diferente, não tem wizard lateral" e apontou
imagens em `.codex/generated_images/…` (fora do repositório; 3 de 19 abertas pela C05). Há conflito
documental não registrado em `docs/open-questions.md`. A decisão é binária: **ratificar `3419a89e`**
(os 13 viram A; regenerar após corrigir o ramo `wide`) ou **restaurar o contrato de 2026-08-31**
(`3419a89e` vira regressão a reverter; masters ficam).

**Assertiva `now-media-unavailable` (linha 120 do golden test).** Espera 2 widgets; encontra 1.
Causa: em `21e0ed09` a página instanciava `_MediaPreview` duas vezes em ≥600 (palco + "Prévia do
Agora"); `3419a89e` removeu a Prévia e o parâmetro `readOnly` sem atualizar a linha 120 (só mexeu no
teste de hover). O `page_test` já espera `findsOneWidget`. **Teste desatualizado, não defeito**: o
fail-closed está íntegro (1 placeholder, sem fixture demo). Corrigir a asserção apenas expõe a
comparação com `media_unavailable_light_1440.png` (rail + Prévia), que cairá na mesma decisão — é o
14.º golden preso a ela. Se a decisão for reverter `3419a89e`, `findsNWidgets(2)` volta a ser correto.

**B condicional — ramo `wide` morto.** `principal_now_publication_page.dart` L429
`wide = maxWidth >= CoeloBreakpoints.large.minWidth` (1200), mas a página passa `bodyMaxWidth: 1120`
(L320) e o frame envolve o corpo em `ConstrainedBox(maxWidth: bodyMaxWidth)`
(`principal_publication_frame.dart` L61–62). `wide` nunca é verdadeiro: o palco de 320 px
(L431–434) e a distribuição `flex 5/4` (L459–462) são código morto; em 1440 o palco fica em 260 px
(x≈244–504), igual ao de 1024 — contrário a "mídia vertical ampla… coluna editorial enxuta" (spec
036). Menor: `Wrap(spacing: space2)` L671 aperta rótulos a 200 %.

## 7. O que este laudo não prova

- Não executei nada além da suíte de reprodução; os laudos usaram os PNGs de `failures/` e o git.
  Percentuais são do comparador do Flutter; coordenadas são leituras dos PNGs (±2 px) e bounding
  boxes dos `isolatedDiff` (exatas em linha/coluna).
- Fixtures `/dev` e sprites estáticos: nada aqui prova mídia remota, vídeo, estados de
  carregamento/erro nem rota produtiva. Nenhuma promoção FE/BE/E2E.
- "Fonte aprovada" foi inferida de documentação versionada (specs, plano, matriz de baselines,
  design-system, evidências), não de declaração direta do Owner. Os anexos 1–2 da spec 050 e a PNG de
  referência da spec 036 não foram localizados.
- Não verifiquei hover/foco, 768/1024/1440 de Comunicações/Circulares (passam) nem o efeito de
  `a0be1abe` nos outros 16 consumidores do indicador.
- O laudo revisou os seis relatórios por amostragem (casos B/D e um caso A por família) e corrigiu
  onde eles se contradiziam; o restante é a leitura dos subagentes, atribuída a eles.

---

## Errata 1 — 2026-09-08T18:42-03:00: o cabeçalho mobile administrativo TEM aprovação

A decisão `R01-VISUAL-1835` da C00 (18:33:32) apontou uma fonte aprovada que o laudo original não
encontrou, e eu a verifiquei diretamente antes de aceitar:

`docs/superpowers/specs/2026-09-01-superadmin-estruturas-finalizacao-design.md`, frontmatter
`status: approved-design`, `updated_at: 2026-09-02`, linhas 52–54:

> No mobile, o cabeçalho usa logo completa Coelo com respiro superior e chevron: direita quando
> fechado, baixo quando o drawer está aberto. Não há hambúrguer. O acionador de Bug permanece
> acessível.

Isso descreve exatamente o que `d9232a94` implementou no `_CompactAppBar` e que o master
`7ed598cf` (2026-09-01 14:48) não acompanha. **A afirmação do laudo de que o app bar compacto estava
"sem aprovação visual localizada" está errada e fica retirada.** O subagente da família Chat
declarou honestamente esse limite ("pode existir em conversa/anexo não versionado"); a fonte estava
versionada, num caminho de spec que a busca dele não cobriu.

### Reclassificação dos cinco casos de Chat

| Caso | Classificação original | Classificação corrigida |
|---|---|---|
| `superadmin_chat_light_375` | D | **A** (spec de Estruturas, linhas 52–54) |
| `superadmin_chat_dark_375` | D | **A** |
| `superadmin_chat_reduced_motion_light_375` | D | **A** |
| `superadmin_chat_light_768` | D | **A** (mais o rodapé de paginação, já A) |
| `superadmin_chat_dark_768` | D | **A** |

**Resumo corrigido: 43 A, 17 D, 0 B puro, 0 C, 1 assertiva desatualizada.** Os 17 D restantes são os
4 de Comunicações e formulário e os 13 de Publicar no Agora.

### O que a errata NÃO muda

1. **O defeito do `_PageHeader` continua real e independente.** A aprovação do app bar não aprova o
   deslocamento do título compacto quando há ações. A C00 confirmou isso no item 2 da mesma decisão
   e mantém a reserva de `superadmin_shell.dart`. A reprodução em
   `repro/shell_compact_page_header_inset_test.dart` segue válida: dx 20,0 sem ações contra 39,17
   em 375 e 235,67 em 768.
2. **A aprovação não cobre todos os pixels, o conteúdo nem os 77 goldens de Estruturas.** A
   anterioridade dos 77 no baseline R01 `479d1bd1` é medição minha e continua de pé; atribuir todos
   eles causalmente a `d9232a94` era e continua sendo **hipótese**, como o laudo já dizia. A C00
   registrou a mesma ressalva.
3. Os outros dois defeitos permanecem: borda do card do Chat coberta pelo rodapé (a corrigir no
   consumidor, por C05) e ramo `wide` do Publicar no Agora inalcançável (a corrigir no consumidor,
   por C05, conforme os itens 3 e 4 da decisão).

### Lição de método que registro contra mim

Um subagente não encontrar a fonte não é o mesmo que a fonte não existir. O laudo deveria ter
escrito "não localizei aprovação nos caminhos X, Y e Z" em vez de tratar a ausência de resultado
como ausência de aprovação — que é exatamente o erro que o próprio AGENTS.md adverte ("Falta de
resultado no índice não significa ausência de implementação"). A busca cobriu
`.agents/skills/coelo-ui/references` e `docs/reviews`, mas não `docs/superpowers/specs/`.

---

## Errata 2 — 2026-09-08T19:00-03:00: os 4 casos de Comunicações e formulário saem de D

Busca dirigida em `docs/superpowers/specs/` (66), `docs/superpowers/plans/` (78),
`docs/superpowers/checkpoints/`, `specs/`, `decisions/` (34 ADRs), `docs/knowledge/`,
`docs/design/design-system.md` e as 18 referências de `coelo-ui` na C00 — o caminho que a Errata 1
mostrou que eu não havia coberto. **Conferi na fonte cada citação abaixo antes de reclassificar.**

### Caso do formulário — de D para DEFEITO (regressão da baseline aprovada)

`notice_form_initial_mobile_light_375`, 37,69 %. `d4374e39` moveu o rodapé para dentro da rolagem no
compacto, em `superadmin_form_frame.dart`. **Não há fonte que aprove isso, e há três fontes
posteriores ao master que exigem o contrário:**

1. `docs/superpowers/plans/2026-08-05-superadmin-health-care-ui-correction.md`, linha 149 — o plano
   que **criou** o `SuperadminFormFrame`, derivado de spec com `status: "approved"`:
   "Keep the measured SuperadminFormActionFooter below the scroll area."
2. `docs/superpowers/specs/2026-08-28-coelo-visual-completion-stage-design.md`
   (`status: "approved-design"`, `updated_at: 2026-08-31`), linha 129: "**Rodapé universal:** aplicar
   o rodapé de Criar/Editar Instituição a todas as criações e edições atingidas por esta etapa."
3. `docs/superpowers/specs/2026-09-01-superadmin-communication-finish-design.md`
   (`status: "approved"`), linha 21: "Criar/Editar Instituição é a baseline dos formulários e de
   seus rodapés."

**Agravante de alcance:** `institution_form_page.dart:317` consome o mesmo `SuperadminFormFrame`.
`d4374e39` alterou **a própria baseline dos anexos 31–32**, o que explica o golden aprovado
`institution_form_create_light_375.png` falhar hoje, e o mesmo em Unidades.

**Origem do commit:** corpo vazio, sem citar fonte. O único motivador visível no diff é um teste de
widget de Saúde e Cuidado que passou a alcançar Continuar — ou seja, a composição aprovada foi
alterada para destravar um teste.

**Contra-argumento examinado e descartado:** `form-layout-contracts.md` diz que em mobile as demais
ações continuam acessíveis sem cobrir conteúdo permanentemente. Não serve como aprovação: a busca
histórica mostra que essa frase é de 2026-07-27, **anterior** ao master de 2026-08-20, que foi
produzido sob esse mesmo texto com rodapé fixo.

### Caso do indicador de status — divide-se em dois vereditos

**(a) Alvo de 48 px: APROVADO, mas com o impacto de layout declarado NÃO aprovado.** A correção
`a0be1abe` nasceu do plano `docs/superpowers/plans/2026-09-08-location-shared-status-accessibility.md`
(`status: "approved-local-implementation"`), que já dizia, linhas 21-22, que a caixa interativa maior
pode mudar ocupação de layout e que isso seria reportado, não mascarado. A evidência correspondente
registra que não se declara aprovação visual integral dos consumidores. Logo os diffs de 4,88–7,50 %
**não são indeterminados**: são efeito colateral conhecido e admitido por escrito de uma correção
aprovada. O caminho é rebaseline visual pelo Owner, não decisão do zero.

*Ressalva de cronologia que eu quase deixei passar:* o texto do design-system que distingue
"dimensão visual 24 × 24" de "alvo interativo 48 × 48" **não é fonte prévia** — a busca histórica
mostra que ele foi escrito pelo próprio `a0be1abe`. Um commit não se autoriza citando a documentação
que ele mesmo escreveu.

**(b) Mover o indicador para a linha de descritores: REJEITADO por fonte posterior — de D para
DEFEITO.** `116231bd` (C05) tirou o indicador da linha do título no card compacto de Comunicações.
Nenhuma fonte aprova; três exigem o oposto:

- `docs/superpowers/specs/2026-08-05-superadmin-notices-mvp-design.md`
  (`status: "approved-design"`, `updated_at: 2026-08-31`), linhas 76-79: "A lista compacta mobile e a
  tabela reutilizam **literalmente** as anatomias correspondentes de Instituições, incluindo
  alinhamento horizontal e vertical, baseline tipográfica, alturas, paddings, gaps, estados..."
- `2026-09-01-superadmin-communication-finish-design.md` (`status: "approved"`), linha 21:
  "Instituições é a baseline obrigatória para toolbar, ações de arquivo, criação, tabela, **cards** e
  paginação."
- `docs/knowledge/team/superadmin-notices-mvp.md` (`status: validated`): "Toolbar, filtros, respiro,
  tabela, status e paginação reutilizam literalmente Instituições."

**Fato de código que fecha:** Instituições mantém o indicador na linha do título
(`institution_directory_cards.dart:209`), e Turmas faz igual. Comunicações é o **único** consumidor
que moveu. `116231bd` tocou 2 arquivos e nenhuma documentação.

### O achado que decide a implementação, e corrige uma retratação da C05

A doutrina aprovada mais próxima sobre como construir 24 visual com 48 de alvo está em
`docs/superpowers/specs/2026-07-21-superadmin-import-activity-theme-prototype-design.md`
(`status: "approved"`), linha 46:

> O indicador de status da atividade é um único círculo centralizado dentro de uma **área interativa
> invisível** de pelo menos 48 px; não haverá um círculo decorativo externo.

**Área interativa invisível** não é `ConstrainedBox(minWidth: 48)` no fluxo de layout, que consome
48 px de largura. É alvo sobreposto, que não rouba largura. Isso importa muito:

1. A implementação de `a0be1abe` diverge dessa doutrina, e é a causa raiz de **todos** os 375
   quebrados nos consumidores, não só Comunicações.
2. A proposta original da C05 na r3 — preservar a área de toque ampliada sem reservar largura de
   layout quando o indicador está colapsado — estava **certa**, e a retratação dela na r5, de que um
   alvo de 48 × 48 precisa mesmo de 48 px de largura, contradiz a fonte aprovada.
3. Corrigir no componente devolve o layout de **todos** os consumidores sem mover nada e sem golden
   novo, e torna `116231bd` desnecessário.

Ressalva honesta: essa spec fala do indicador de Atividades no protótipo e não nomeia o componente
compartilhado. É a doutrina aprovada mais próxima que existe, não uma regra escrita para este
componente. Registro como evidência forte, não como decisão fechada — quem decide é a C00 com o
Owner.

### Resumo corrigido do laudo, após as duas erratas

| Classe | Original | Errata 1 | Errata 2 |
|---|---|---|---|
| A — master desatualizado | 38 | 43 | 43 |
| D — precisa decisão | 22 | 17 | **13** |
| Defeito a corrigir | 0 | 0 | **4** |
| C — ambiente | 0 | 0 | 0 |
| assertiva desatualizada | 1 | 1 | 1 |

Os 13 D restantes são todos de Publicar no Agora, sob investigação separada. Os 4 defeitos novos
são: o rodapé do formulário no compacto (`superadmin_form_frame.dart`, dono C00, atinge os
consumidores de formulário e derruba a baseline aprovada dos anexos 31–32) e os 3 casos de 375 de
Comunicações, cuja causa raiz é o alvo que consome largura, com o agravante da mudança de posição
não aprovada.
