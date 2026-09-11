---
title: "R04 · Operações — validação da entrega ao coordenador e proposta de atualização das skills"
source: "comunicacao/operacoes.json rev 14–19; coordenacao.json rev 30 (origin/dev 0376a0446); inventario-etapa-2.json em dev; commits da branch work/etapa2-r04-operacoes"
status: "handoff; o coordenador aplica deltas e edita skills/rastreadores"
generated_at: "2026-09-11"
group: "operacoes"
---

# 1. Validação da entrega (11/09/2026, 08:40)

| Item | Estado |
| --- | --- |
| Branch `work/etapa2-r04-operacoes` | publicada; `git cherry origin/dev` = 0 commits fora de `dev` (tudo integrado por conteúdo) |
| Worktree `e2-r04-operacoes` | limpa, sem stash, avançada para `origin/dev` (`0376a0446`) |
| JSON do grupo | rev 18 (subagente do coordenador, 03:00) + rev 19 (esta validação) |
| Pacotes SQL do grupo | `20260910210000_support_create_internal_scope_v1` e `20260910210100_superadmin_internal_audit_read_v2` **em produção** (lote 10), movidos para `migrations/` |
| Deltas aplicados no inventário | 22 (`deltas-r04-ops.json`): support.create/table/kanban/detail/reply/close FE verified · BE done · E2E verified-e2e; account.profile idem; account.settings FE verified |
| Deltas ainda não aplicados | 3 (`deltas-r04-ops-audit-plans.json`): audit.list/filter/detail FE `local-green` (composto + goldens); inventário ainda diz "Revalidar" |
| Recibos do coordenador | rev 14 (22:58) e rev 17/18 pelos subagentes dele; rev 15/16 (22:34 e 23:26) foram lidas por merge (conteúdo em dev), sem recibo próprio |

Commits da frente, todos em `dev` (por conteúdo, após dois rebases):
`e96b640c8` abertura rev 14 · `480728d7f` candidato 210000 + pgTAP 17/17 · `a208e1d6c` entrypoint do driver (substituído por `qa_main.dart` em `f0549d62c`) · `d040f3bb6`/`03df0769d` rev 15 · `786749658` AUDIT-READ-V2 renumerado · `b5474a80a` Suporte honesto na rota real · `26c7fcc01` remoção do diagnóstico temporário · `0a23882cd` goldens de Conta · `f9ddaf90a` Auditoria no composto · `9123c6e09` rev 16 · `6360c93b5`/`00c57bc42` goldens de Planos dentro da shell · `af294783f`/`1ad67a2e3`/`2bcddb469` Suporte no composto (subagente) · `66e23040a`/`94c705576` rota real de Conta/Suporte (subagente).

Resumo por família (estado oficial no inventário de `dev`):

| Família | Ações | FE | BE | E2E |
| --- | --- | --- | --- | --- |
| support | 6 | verified 6 | done 6 | verified-e2e 6 |
| account | 6 | verified 2 (profile, settings) | done 1 (profile); settings/theme not-applicable | verified-e2e 1; settings flutter-only |
| audit | 4 | pending (deltas de composto propostos → local-green 3) | local-green 3 (210100 em produção); export adiada | pending |
| plans | 5 | local-green 1 (list) | pending | pending |

# 2. Pendências (nada se perde)

Registradas na rev 18 (`pendencias_registradas_rev18`) e nesta validação:

1. **Auditoria rota real** (`audit.list/filter/detail`): leitura v2 em produção e diretório no composto; falta abrir `/audit` com `qa-r03`, filtrar, abrir detalhe e recarregar → propor verified/done/E2E. Primeiro gate: uma sessão com Chrome.
2. **Planos rota real** (`plans.list/create/edit`): `superadmin_plans_list/get/save` usam `assert_plan_permission` (`current_person_id`, agora alcançável pela ponte 220400); falta a prova com sessão. `plans.activate`/`plans.assign`: decisão de semântica (arquivar/restaurar da spec 051; atribuição não é comando aprovado) — pergunta ao Owner.
3. **Goldens de Suporte (32)**: divergentes após o composto; decisão A do Owner com observações MENU/TABELA/CHAT. Montar página lado a lado (R referência, A atual, diferença) e regravar no SDK 3.44.2 após a observação. `support_detail_light_1024` é R.
4. **account.profile (cliente)**: sigla derivada pelo servidor (`O4`) reprova no validador do cliente (1–2 letras) e a sigla não é persistida (`p_avatar_initials` só validado); e-mail vazio na projeção quando a pessoa da ponte não tem `person_auth_links`; celular obrigatório (7–40) só no servidor sem validador no cliente; balão Mensagens sobre "Salvar alterações" em 1440×1000 (Decisão 7).
5. **support.detail**: balão Mensagens sobre Histórico/compositor em 1440×1000.
6. **support.close**: Responsáveis vêm de `defaultTeamMembers` (lista fixa) e `setAssignees` não persiste (sem RPC); "Em andamento" exige responsável dessa lista.
7. **support.kanban**: preferência cards/tabela não persiste após reload; Status é dropdown, não abas (conferir com a regra "abas de estado, o conjunto de cada tela").
8. **Resíduos sintéticos em produção** (P37 ao Owner): chamado `48e02ab0-fa60-4e7c-86b6-78f75565dc57` (sem RPC de exclusão), `people.mobile_phone` da pessoa de serviço `007a4ca5-…`, pedido de e-mail cancelado + 3 recibos. Limpeza por SQL pelo coordenador.
9. **Suítes pgTAP legadas com drift** (não regressão): `audit_production_test` usa `has_column` de 3 argumentos (forma sem schema) e fixture de unidade sem o tipo canônico; `superadmin_internal_auth_context_test` #8 (grants dos wrappers). Corrigir na revisão profunda.
10. **Tipo do callback do Bug**: shell usa `SuperadminBugReportSubmit` (`FutureOr<void>`); 13 páginas de outras frentes ainda declaram `ValueChanged<SupportReportDraft>` (compila; alinhar quando tocarem o arquivo).
11. **Composto** (notas do subagente): rodapé compacto sem chaves `coelo-admin-pagination-previous/next`; `CoeloAdminListingToolbar` recria os filtros ao abrir o detalhe (perde foco); estado `loading` não mostra o Criar.
12. **Ferramenta**: `tap` do Flutter Driver trava no build release; no `flutter run` debug o `tap` trava com cursor piscando (usar `set_frame_sync false`) e o Chrome pausa frames quando a janela fica oculta (flags `--disable-backgrounding-occluded-windows`, `--disable-renderer-backgrounding`).
13. **Ambiente**: o classificador da sessão bloqueou `supabase db query --linked` (leitura) para a frente; medição de produção vem do coordenador ou do app na rota real.
14. Adiados por decisão: `audit.export`, `account.mfa` (Decisão 12), `account.sessions` (tela inexistente), `account.logout` (ID distinto de `auth.logout`).

# 3. Proposta de atualização das skills (o coordenador edita)

## coelo-backend (`.agents/skills/coelo-supabase/SKILL.md`)

- **pgTAP estrutural não prova o RPC.** O lote 7 de Suporte passou 23/23 só com `has_column`/`function_returns`, mas `superadmin_support_create` nunca conseguiu inserir: `support_sessions.reason_code` é NOT NULL sem default na baseline e o cliente envia `p_institution_id` nulo. Regra: todo pacote com RPC de escrita entrega pgTAP comportamental (fixture de ator, chamada real, negativa 28000/42501, idempotência por `request_id`, reload por `list`), como `superadmin_support_create_internal_scope_test.sql`.
- **pgTAP `has_column` com três argumentos é a forma sem schema** (`has_column(table, column, description)`); a forma com schema tem quatro. `audit_production_test.sql` tem esse erro e falha por drift, não por regressão; listar as suítes legadas com falha conhecida em vez de reexecutá-las como gate.
- **Leitores de Auditoria v2 em produção** (`20260910210100`): `audit_list_events_for_superadmin` e `audit_get_event_for_superadmin` resolvem o ator por `require_superadmin_internal_context('audit.read')`, devolvem envelope `ok/data/error` com `can_export=false`, e os três entrypoints de exportação perderam o grant de `authenticated` (exportação adiada). Cliente já consome o envelope.
- **Suporte em produção**: `superadmin_support_create` aceita chamado interno sem instituição (`scope_kind=platform`, `reason_code='internal_report'`); não existe RPC de exclusão — chamado sintético vira resíduo que o coordenador remove por SQL (`support_sessions`, `support_messages`, `audit.support_session_actions`, `support_command_receipts`). Responsáveis (`assigned_to_membership_id`) não têm comando; pendência.
- **Conta em produção**: `superadmin_account_profile_save` exige celular de 7–40 caracteres e sigla `^[[:alpha:]]{1,2}$` (não persistida); a projeção deriva a sigla das iniciais e pode gerar dígito quando o sobrenome é numérico (pessoa de serviço da ponte). E-mail vem de `person_auth_links` ativo: a pessoa de serviço da ponte 220400 não o tem, então o campo chega vazio.
- **Dado sintético**: registrar no JSON id, tabela e RPC de cada resíduo criado na rota real; o coordenador limpa por SQL ao fim da rodada (P37).

## coelo-frontend (`.agents/skills/coelo-flutter-review/SKILL.md`)

- **Rota normal nunca abre com fixture.** Controllers de protótipo (caso `SupportPrototypeController`) só usam o seed quando não há repositório produtivo; com repositório nascem vazios, expõem `loadState` (loading/ready/failure) e a página mostra falha honesta com "Tentar novamente", mantendo toolbar e o card Criar à frente. Em 10/09 `/support` em produção exibia SUP-001/SUP-002 fictícios porque o controller engolia a falha do backend.
- **Botão de Bug**: a shell aguarda `onBugReportSubmitted` (`SuperadminBugReportSubmit = FutureOr<void> Function(SupportReportDraft)`) e avisa "Não foi possível enviar o relato" em vez de confirmar antes do backend; o router de produção passa `submitReportToBackend`. Páginas que ainda declaram `ValueChanged<SupportReportDraft>` compilam, mas o tipo canônico é o da shell.
- **Composto**: Auditoria e Suporte migrados ao `CoeloAdminDirectory` (allowlist do teste de arquitetura reduzida: enum de display de Auditoria, `SupportFilterToolbar`/`SupportTicketTable`). Regras aprendidas: filtros de domínio não têm largura (o composto aplica 160 px; rótulos curtos, ex.: Período "Todos/Hoje/7 dias/30 dias"); paginação por cursor mapeia `onPageSelected` andando um passo por vez; kanban entra por `bodyOverride`; no estado `unauthorized` o composto não expõe toolbar.
- **Goldens dentro da shell (FUNDO)**: o harness de golden de diretório monta a página dentro do `SuperadminShell` como a rota real, nunca em `Scaffold` avulso (fundo cinza, sem menu/Bug). Planos foi corrigido assim (16 goldens); goldens de Suporte (32) aguardam página lado a lado.
- **Flutter Driver no `flutter run` debug**: `tap` trava com cursor piscando (enviar `set_frame_sync false` antes); Chrome pausa frames se a janela ficar oculta atrás de outras (lançar com `--web-browser-flag=--disable-backgrounding-occluded-windows` e `--disable-renderer-backgrounding`); `screenshot`/`waitForAbsent` do driver não funcionam na web (usam stderr) — capturar por CDP. Navegar em-app sem recarregar: `history.pushState` + `PopStateEvent`. No release o `tap` trava sempre: cliques por CDP (método do coordenador).

## coelo-frontend-backend (`.agents/skills/coelo-flutter-supabase-review/SKILL.md`)

- **Prova E2E confere a origem do dado**: a tela aberta com dados não prova E2E; a captura de rede (RPC 200 na aba Network) e a ausência de fixture no runtime são parte da prova. Suporte "abria" com chamados do protótipo enquanto o backend negava.
- **Estado das famílias de Operações após a R04**: Suporte 6/6 e `account.profile` verified-e2e; `account.settings` FE verified (persistência local por desenho); Auditoria com backend v2 em produção e diretório no composto, rota real pendente; Planos com goldens na shell, rota real pendente; `plans.activate/assign`, `audit.export`, `account.mfa/sessions/logout` adiados ou à espera de decisão.
- **Achado transversal**: RPCs por `current_person_id()`/`has_platform_permission` só alcançam usuários do realm interno pela ponte de ator (220400); pacote novo prefere `require_superadmin_internal_context`. Frente que encontrar bloqueio de ator não escreve helper próprio: registra no JSON e o coordenador entrega pacote único (foi o que aconteceu em 10/09 às 22:12).
- **Resíduos e limpeza** fazem parte do fechamento da prova E2E (P37), com id/tabela/RPC no JSON.

# 4. O que evoluiu na Etapa 2 pelo recorte de Operações

- Suporte saiu de "tabela/kanban de protótipo com backend que negava" para 6 ações verified-e2e sobre RPCs de produção, diretório no composto e botão de Bug conectado ao backend com resultado real.
- Conta: perfil editável e persistido em produção (E2E), configurações verificadas no cliente.
- Auditoria: leitor v2 (identidade interna, exportação adiada) em produção; diretório e filtros no padrão do composto; goldens regravados após a observação do Owner.
- Planos: goldens na rota real (shell), cards com ARQUIVO do grupo principal-chat.
- Dois defeitos do lote 7 corrigidos em produção (chamado interno sem instituição; `reason_code`).

# 5. O que fica para depois (pós-MVP ou decisão)

`audit.export` (exportação geral), `account.mfa` (Decisão 12), `account.sessions` (tela inexistente), `plans.activate`/`plans.assign` (semântica da spec 051), responsáveis do Suporte (comando e lista real), persistência da preferência cards/tabela, revisão profunda das suítes pgTAP legadas com drift, alinhamento do tipo `SuperadminBugReportSubmit` nas 13 páginas, revogação/limpeza de resíduos sintéticos (P37).
