---
title: "Deltas propostos às skills coelo-frontend, coelo-backend e coelo-frontend-backend pelo grupo principal-chat-sistema (R04)"
source: "JSON do grupo (revisões 8 a 18), handoff, deltas-r04.json, capturas em rota-real/ e rota-real-r04b/, conferência de produção por supabase db query --linked somente leitura em 11/09/2026 08:30"
status: "proposta ao coordenador (escritor central de dev, inventário, rastreadores e skills); nada aqui foi aplicado às skills por este grupo"
generated_at: "2026-09-11"
---

# Deltas para as skills — grupo principal-chat-sistema, Rodada 4

Pedido do Owner em 11/09/2026 (manhã): validar a entrega ao coordenador e passar
o que precisa entrar nas três skills de revisão. As regras gerais da R04 já
estão nas skills (entrypoint único de driver, memória da máquina, estado vazio,
formato dos deltas, método de rota real, ordem real de aplicação em produção,
ponte de ator, dado sintético por RPC/migration). Abaixo fica **só o que este
grupo mediu e ainda não consta**, mais as pendências por skill.

## 0. Validação da entrega ao coordenador (coelo-04)

| Item | Estado conferido em 11/09 08:30 |
| --- | --- |
| Commits da retomada (7322260c5, 1e34eb9f4, dcfcb9e41, 03c0ff34d, b5841e018, 92146a56d, 31632cd1c, 889e289a8) | todos em `origin/dev` (dev em 0376a0446); coordenador registrou `launcherDecisao7` e `finalizados/principal-chat-sistema` na coordenacao.json rev 30 |
| Worktree `Coelo.worktrees/e2-r04-principal-chat-sistema` | limpa, sem stash, HEAD = origin; pode ser arquivada pelo coordenador quando fechar a rodada |
| JSON do grupo | rev 17 integrada; rev 18 (este documento + ferramentas) publicada na branch |
| deltas-r04.json | aplicados pelo coordenador: `shell.load`, `meal-plans.list`, `chat.create-group` FE verified; Principal `blocked-environment` com o gate |
| Rastreadores (três md) | já mostram os deltas (`shell.load` com a regressão do launcher; `chat.create-group` com o estado honesto da criação pela UI) |
| Candidato 20260910191000 (contextos do Principal) | pgTAP 13/13 no espelho do coordenador; **em produção (lote 22)**: `list_my_principal_contexts` existe, `authenticated` executa, `anon` não |
| Ferramentas de prova (só existiam no scratchpad) | preservadas em `ferramentas/` nesta pasta, com README; sem credencial |
| Pergunta de produto sobre o contexto da pessoa de serviço | registrada pelo coordenador como P35 e levada ao Owner |
| Ambiente | Chrome 9409, servidor 3009 e processos dart deste grupo encerrados |

Nada deste grupo ficou fora de `origin`. O que segue são propostas.

## 1. Coelo Front-end (`coelo-frontend`, diretório `coelo-flutter-review`)

### 1.1 Regras medidas a acrescentar

- **Mecanismo do launcher (Decisão 7).** A regra "o balão respeita
  `showChatLauncher=false`" já está na skill; falta dizer **onde** a regra vive
  para a próxima tela não reinventar:
  - `SuperadminFormFrame` registra uma supressão no shell hospedeiro enquanto
    está montado (`SuperadminShell.suppressChatLauncher`) e libera no dispose.
    Toda tela de criar/editar/publicar que usa o frame fica sem balão em
    qualquer largura sem passar flag alguma.
  - Telas do Principal não embutem shell próprio: o hospedeiro decide por
    `SuperadminShell.chatLauncherHiddenDestinations` (`conversations`,
    `principal-chat`, `principal-now`, `principal-now-publish`,
    `principal-happens-publish`, `principal-moments`, `principal-moments-publish`).
  - Formulário próprio fora do frame (Circulares) passa `showChatLauncher:
    false` em `productionOperationalPage`/`operationalPage`.
  - Teste canônico: `test/app/shell/superadmin_shell_chat_visibility_test.dart`
    (12 casos). Tela nova de criar/editar/publicar: usar o frame **ou** passar a
    flag, e acrescentar o destino ao teste.
- **`pumpAndSettle` no shell hospedeiro em largura desktop não assenta**
  (alguma animação do hospedeiro não para). Um `flutter_tester` ficou 10 minutos
  a 3,3 GB antes de ser morto, o que fere a regra de memória. Em testes que
  montam `SuperadminShell.host`, usar pumps fixos (`pump()`, `pump(400 ms)`),
  nunca `pumpAndSettle` sem timeout. Causa fica como pendência pós-MVP.
- **Rota real, sintomas do `.env.local`.** Em debug (`flutter run`) sem
  `--dart-define-from-file=.env.local`, `lib/main.dart` acessa
  `Supabase.instance` antes do `initialize`, o assert mata o boot (tela branca)
  e `window.$flutterDriver` existe mas não responde. Em release o assert é
  omitido: a tela abre, mas o driver fica indefinido. Mesma causa, dois sintomas;
  `cdp_console.dart` mostra o assert.
- **Origem da prova.** `localhost` mapeado por `--host-resolver-rules` não
  boota o app em debug; usar `127.0.0.1`. O CORS do R2 só libera
  `http://localhost:3000`: upload direto ao R2 a partir de `127.0.0.1` ou de
  outra porta será negado; provas de mídia precisam da origem certa.
- **Texto na rota real.** `Input.insertText` por CDP não entra em campo de texto
  Flutter; focar por clique CDP e digitar com `enter_text` do driver
  (`qa_drive.dart cmd command=enter_text text=...`). Cliques por
  `Input.dispatchMouseEvent` funcionam; o `tap` do driver trava no release.
- **Interromper `flutter run` pela ferramenta deixa `dart` e Chrome vivos**
  segurando a porta; encerrar por `Stop-Process` antes de relançar (a porta 3000
  ficou presa por isso em 03:05).
- **`DropdownButtonFormField` com `initialValue`**: a seleção automática
  programática (uma única instituição) não aparece no campo até o usuário abrir
  o menu. Usar `value` controlado ou `key` por seleção (caso do diálogo Criar
  grupo).
- **A mensagem "Não conseguimos validar seu contexto agora" cobre qualquer erro
  do resolvedor de contexto** (42501, PGRST202, formato). Antes de atribuir à
  autorização, ler a resposta da RPC na aba Network (`cdp_net.dart`).

### 1.2 Evolução do grupo na Etapa 2 (R03 rev 8 → R04 rev 18)

Launcher "Mensagens" com contagem e iniciais e círculo claro no mobile; ARQUIVO
nos cards de Cardápios e Planos (Duplicar de volta no menu); véu do Destaque do
Para você em orange950 a 16%; D3 sem "prévia" em 14 textos e no Catálogo;
Momentos com a composição larga aprovada (moldura a partir de 840, aside a
partir de 1200, mídia contain sobre o preto); Agora enviando mídia pelo envelope
R2; Criar grupo (P8) com diálogo, repositório e `CHAT_MEMBER_INVALID`; goldens
regravados após observação (launcher 5, Cardápios 5, Planos 8, Para você 8,
Chat 6, Momentos 11, Importações 1); imagens candidatas do erro 409; launcher
da Decisão 7 fechado no componente compartilhado; na rota real com `qa-r03`:
auth 2 ações e shell 5 ações verified, chat 6 ações verified (E2E), Cardápios
abre (verified FE), diálogo Criar grupo carrega instituição e pessoas de
produção (verified FE).

### 1.3 Pendências FE abertas, com o primeiro gate

| Pendência | Primeiro gate |
| --- | --- |
| `chat.create-group` pela UI até o fim (diálogo fechou sem grupo novo, capturas 67b/67c) | repetir com `enter_text` + checkbox confirmado pelo driver e a resposta da RPC pela Network; a RPC já está provada |
| `meal-plans.create/edit/model-create/model-edit/publish` pela UI | só tempo; ambiente documentado em `ferramentas/README.md` |
| Acontece, Momentos, Agora, Para você, Perfil na rota real | P35 (membership da pessoa de serviço); o 191000 já está em produção |
| Perfil: Acompanhar/Seguidores/Seguindo consumindo D1 `follow_links` (lote 12 em produção) | FE deste grupo; depende do Perfil abrir (P35) |
| Perfil FOTO (qual foto recorta: capa ou avatar) | pergunta P-FOTO ao Owner com página de imagens |
| Goldens abertos: `principal_profile_*` (FOTO/SHELL), `principal_happens_gallery` mobile (redesenho sem direção), `imports` hub wizard 375 (FUNDO) | decisão visual do Owner por página lado a lado |
| Erro 409 como golden oficial | P-409 (imagens em `erro-409-candidatos.html`) |
| Duplicar de Cardápios como ícone ARQUIVO e no menu | P-CHAT-DUP: manter os dois ou só o ícone |
| `shell.switch-context` | não há segundo contexto para `qa-r03` |

### 1.4 Só depois do MVP

- Investigar a animação do hospedeiro que impede `pumpAndSettle`.
- Curtir e comentar no Acontece (não existem no banco; visíveis e inertes por D3).
- Galeria mobile do Acontece "mais Instagram" (redesenho).
- Provas exaustivas por ação (ADR 0034): sessões concorrentes, ID adulterado por
  tela, golden por estado.

## 2. Coelo Back-end (`coelo-backend`, diretório `coelo-supabase`)

### 2.1 Regras medidas a acrescentar

- **Histórica que o cliente chama e nunca chegou à baseline.**
  `public.list_my_principal_contexts` (migração histórica `20260901161700`, em
  `migrations-historico/`) não existia em produção: PostgREST devolvia
  `PGRST202` e as cinco telas do Principal paravam com a mensagem genérica de
  contexto. Entrou como recarimbo idêntico `20260910191000` (lote 22). Regra:
  para cada família do recorte, `grep -rn "\.rpc(" apps/superadmin/lib/features/<família>`
  lista as RPCs que o cliente chama; conferir cada nome em `pg_proc`
  (`supabase db query --linked`, somente leitura) **antes** de atribuir a falha
  à autorização ou à ponte de ator. `PGRST202` é ausência de função, não
  negativa; a regra "presença de objeto decide" vale também para o que o
  cliente consome, não só para o que o pacote cria.
- **`supabase db query --linked` só resolve o projeto a partir do checkout
  principal.** `packages/coelo_database/supabase/.temp/` não é versionado e não
  existe nas worktrees; da worktree o comando falha com
  `LegacyProjectNotLinkedError`. Rodar do checkout principal ou copiar
  `.temp/project-ref` para a worktree sem commitar.
- **Recarimbo idêntico de histórica é o caminho padrão** quando o corpo já foi
  revisado e as tabelas/colunas conferem em produção (`pg_class`,
  `information_schema.columns`); comentar no cabeçalho o motivo, a data da
  medição e o pgTAP que cobre.

### 2.2 Evolução do grupo na Etapa 2 (backend)

Agora tinha 0/17 objetos em produção e ganhou a fundação inteira (190300),
hardening de audiência (190400), expiração (190500) e mídia em R2 (190600);
Acontece com mídia em R2 sobre `media_assets` (190700) e retirada no feed direto
e misto com `can_withdraw` (190800); `anon` sem EXECUTE em 199 funções security
definer de `public` e privilégio padrão corrigido (190900); contextos do
Principal (191000). Tudo em produção (lotes 9, 11 e 22). pgTAP dos pacotes:
194 + 7 + 13 casos. Achados que viraram regra: `anon` executava security
definer por privilégio padrão; `db reset` com as 45 migrations não reproduz
produção (170100 exige o catálogo antes do seed); presença do nome não prova o
corpo (`list_visible_happens_feed` constava 1/1 sem retirada nem
`can_withdraw`).

### 2.3 Pendências BE abertas, com o primeiro gate

| Pendência | Primeiro gate |
| --- | --- |
| P35: membership institucional ativa para a pessoa de serviço de `qa-r03` (`institution_memberships`, escopo instituição, na instituição sintética QA R04 Cuidado) | decisão do Owner; sem ela `list_my_principal_contexts` devolve vazio e o Principal mostra "Nenhum contexto disponível" para todos em produção. Caminho: migration idempotente com pgTAP (regra de dado sintético), nunca `insert` direto |
| Agendador da expiração do Agora (pg_cron ou worker) | coordenador; hoje `agora.expire` só transiciona por `expire_due_now_publications` acionada |
| `happens-media` e `now-media` implantadas no lote 9 | confirmar pela tela quando o Principal abrir (upload real por `127.0.0.1` será negado pelo CORS; usar `localhost:3000`) |
| `chat.attach` | sem gateway `chat-media` (blocked-environment) |
| Stream HOT do Agora (D2, até 24 h) | só quando a publicação exigir; não implementado |

### 2.4 Só depois do MVP

- Coletor de órfãos no R2 para Agora e Acontece (substituir ativo gera chave nova
  e deixa o objeto anterior); Momentos já tem o seu.
- Curtir e comentar do Acontece: sem tabela.
- Paginação `20260910150000` do feed direto fica histórica (produção usa o feed
  misto, que já pagina).
- Grants CRUD de `authenticated` sem policy correspondente (levantado pelo
  realm-interno; revisão profunda).
- Escopo por unidade/turma/atividade no Criar grupo: o servidor aceita; a tela
  só pede quando o produto pedir.

## 3. Coelo Front-end + Back-end (`coelo-frontend-backend`, diretório `coelo-flutter-supabase-review`)

### 3.1 Regras medidas a acrescentar

- **Três causas para a mesma tela bloqueada.** "Não conseguimos validar seu
  contexto agora" e "Acesso não autorizado" cobrem: (a) autorização (42501 em
  `has_platform_permission`; Cardápios, resolvido pela ponte de ator, lote 10);
  (b) função ausente (PGRST202; Principal, resolvido pelo 191000, lote 22); (c)
  dado ausente (lista vazia; Principal continua sem contexto até P35). A prova
  integrada nomeia a causa pela resposta da RPC na aba Network, nunca pela
  mensagem da tela; cada causa tem um gate diferente e um dono diferente.
- **Complementos ao método de rota real já registrado:**
  `--dart-define-from-file=.env.local` é obrigatório também no build release
  (sem ele a tela abre e o driver não registra); texto por `enter_text` do
  driver, cliques por CDP; `127.0.0.1` em vez de `localhost` para o boot, com a
  consequência do CORS do R2 para provas de mídia; ferramentas em
  `evidence/etapa-2/r04-principal-chat-sistema/ferramentas/` (`cdp_net.dart`
  captura as respostas REST sem cabeçalhos, `cdp_sem.dart` dirige por
  semântica).
- **Leitura só não fecha E2E.** Cardápios abriu e recarregou (integrated
  `local-green`), mas `verified-e2e` continua exigindo CRUD em produção pela UI
  e RLS negando outro tenant; não promover por "abriu".

### 3.2 Evolução do grupo na Etapa 2 (integrado)

Primeiro E2E da Etapa 2 (rev 12): `chat.list/open/send/receipts`; depois
`chat.edit/revoke` (rev 13); `auth.login/logout` verified-e2e; shell 5 ações;
Cardápios leitura em produção com reload; Criar grupo carregando instituição e
pessoas de produção. Provas de RPC em produção: negativa cross-tenant
`CHAT_NOT_FOUND`, `CHAT_MEMBER_INVALID`, replay idempotente, janela de edição
de 15 min (`CHAT_EDIT_WINDOW_CLOSED`), `42501` fail-closed em Acontece/Agora
antes da ponte.

### 3.3 Pendências integradas abertas, com o primeiro gate

| Pendência | Primeiro gate |
| --- | --- |
| Principal: `acontece.feed/create/publish/remove`, `agora.view/create/publish/expire`, `momentos.view/create/publish/remove`, `principal_profile.view` e Acompanhar/Seguidores/Seguindo, `principal.for-you` | P35; depois rota real + CRUD em produção + reload, deploy das funções de mídia conferido pela tela |
| `meal-plans.*` E2E | CRUD pela UI com `qa-r03` |
| `chat.create-group` integrated | repetir criação pela UI e conferir a inbox após reload |
| `chat.attach` | gateway `chat-media` |
| Perfil D1 | FE consumir `follow_links` (lote 12) e provar com o Perfil aberto |

### 3.4 Só depois do MVP

Provas exaustivas por ação (ADR 0034: sessões concorrentes, ID adulterado por
tela, auditoria com retry, golden por estado); coletor de órfãos do R2; Stream
HOT do Agora; revisão dos grants CRUD de `authenticated`.
