---
title: "Deltas propostos às skills coelo-backend, coelo-frontend e coelo-frontend-backend — R04 publicacoes-agenda"
source: "comunicacao/publicacoes-agenda.json rev 29; handoff.md; prova-producao-*.md; capturas ui/; commits da branch work/etapa2-r04-publicacoes-agenda (todos em dev)"
status: "proposta ao coordenador (único escritor das skills); nada aqui edita skill"
generated_at: "2026-09-11"
---

# Deltas de skills — R04 publicacoes-agenda

Validação de entrega (11/09 03:20): branch `work/etapa2-r04-publicacoes-agenda` = `f0b3b72e4`, 0 commits fora de
`origin/dev`, árvore limpa; os 6 pacotes estão em `packages/coelo_database/migrations/` e
`candidatos/publicacoes-agenda/` ficou vazio; `coordenacao.json` rev 30 registra a rev 28; o inventário traz os 24
action_ids do recorte (FE verified 16, BE done 20, E2E verified-e2e 16). Worktree
`C:/Users/adrie/Documents/Coelo.worktrees/e2-r04-publicacoes-agenda` sem WIP: pode ser removida pelo coordenador
(branch preservada). Nenhum Chrome, servidor ou projeto descartável meu ficou rodando.

## O que evoluiu na Etapa 2 por este recorte

| Camada | Antes da R04 (fechamento R03) | Recorte ao fim da R04 (24 ações) |
| --- | --- | --- |
| Back-end SQL em produção | 0 das 3 famílias (notices 0/16, circulars 0/14, agenda people-based) | 6 pacotes aplicados (200000–200500) |
| Back-end `done` | 0 | 20 (agenda.request/location e circulars.attach local-green; circulars.respond pendente) |
| Front-end `verified` | 0 (notices/circulars local-green) | 16 |
| E2E `verified-e2e` | 0 | 16 |

Totais da Etapa 2 informados pelo coordenador após integrar a rev 28: FE verified 48, BE done 48, E2E 32/199.

## coelo-backend (`.claude/skills/coelo-supabase/SKILL.md`)

Regras medidas que valem daqui em diante:

1. **Aplicação em produção:** `supabase db query -f` roda o arquivo inteiro numa transação; `ALTER TYPE … ADD VALUE`
   precisa ir em arquivo próprio, aplicado antes do corpo (lote 9, 200000). Pacote com enum novo = dois arquivos.
2. **`audit_logs.reason_code` exige `^[A-Z][A-Z0-9_]{0,79}$`.** Toda cadeia histórica que passava texto livre ou
   minúsculo (`'saved'`, motivo do operador) caía em `SAI_INTERNAL_ERROR`. O helper de auditoria da família normaliza
   (`upper(regexp_replace(...))`) e o motivo livre vai para o registro de negócio (ex.: `silencing_policy.inactive_reason`).
3. **Forma de produção a conferir antes de reentregar cadeia histórica:** `platform_permissions` com
   `module_label/screen_label/action_label`; `circular_audience_rules.revision_id NOT NULL`;
   `circulars_check1 (status = 'draft' or publish_at is not null)` (rascunho excluído mantém status e usa `deleted_at`);
   `units.unit_type_id`; `public.notice_events` não existe (é `analytics.notice_events`); `row_security_active()` não
   existe em PG 17; `proconfig` grava `search_path=""` (não `search_path=`). Testes históricos que assumem o contrário
   precisam ser reescritos, não são regressão do pacote.
4. **Defeitos de plpgsql que só aparecem com dados** (por isso pgTAP comportamental é obrigatório, o estrutural do
   `circular_delete_v1` não os pegava): variável com o mesmo nome da coluna (`circular_id`, 42702); `record` não
   atribuído lido dentro de `case` (`next_row` no diretório de Avisos); CTE com coluna extra (`page_row`) não converte
   para o rowtype no `jsonb_agg(fn(page))`.
5. **Grants default do Supabase:** tabelas e funções criadas antes do endurecimento ficam com SELECT/INSERT para
   anon/authenticated (mesmo com RLS forçado sem policy) e EXECUTE para PUBLIC — medido em `agenda_*` e nas 7
   `superadmin_agenda_*`. Todo pacote fecha com `revoke … from public, anon, authenticated, service_role` + grant
   mínimo, e a varredura do mesmo padrão nas outras famílias fica recomendada.
6. **Realm interno em RPC people-based:** a compatibilização (Agenda, 200300) é colunas `*_internal_identity_id`
   nas tabelas com ator, trigger BEFORE INSERT/UPDATE que roteia o uuid interno, `agenda_actor_id()` e um
   `agenda_has_permission()` que soma o membership interno de plataforma ao `has_platform_permission` (intocado, é
   do grupo acessos-pessoas), e as RPCs recriadas do texto de produção. Nunca criar `public.people` para funcionário
   interno (ADR 0019/spec 039). Membership interno com escopo de instituição continua sem Agenda (deny-by-default).
7. **Catálogo de concessões:** produção não tinha nenhuma concessão de `agenda.*` a papel algum; conferir
   `platform_role_permissions` por família antes de declarar "capacidade existe".
8. **Projeto descartável por conversa:** `supabase db reset` aplica o seed depois das migrations e a 170100 exige o
   catálogo — reset só com a baseline (baseline → seed) e as demais migrations + candidatos por `psql` na ordem;
   portas próprias (603xx); script de prova limpa (reset + seed + migrations/ + candidatos + pgTAP) como evidência.
9. **Prova BE em produção por RPC com a sessão sintética:** login por senha no GoTrue + PostgREST com o JWT do
   usuário, mesmas assinaturas que os repositórios chamam (`prova-producao.js` na evidência). Conta como CRUD + RLS
   (anon 401) + reload; a UI é prova separada. Nunca imprimir token; dados sintéticos com prefixo `[R04-QA]`.
10. **Worker de Avisos v2 (200500):** `claim_notice_publication_jobs_for_worker(p_worker, p_limit)` e
    `run_notice_publication_job_for_worker(p_job_id, p_limit)` só para service_role; materialização gera recibos sem
    mudar o status (o v2 decide scheduled/active e `refresh_lifecycle` promove na leitura); "superado" não usa
    `management_version`. Disparo (secret `COELO_NOTICE_WORKER_SECRET`, Vault, cron) = P30 do Owner.

## coelo-frontend (`.claude/skills/coelo-flutter-review/SKILL.md`)

1. **Rota real quando o dwds não sobe (memória):** `flutter build web --profile -t test_driver/qa_main.dart
   --dart-define-from-file=.env.local` + servidor estático (`python -m http.server 3006 --bind 127.0.0.1`) + Chrome
   com `--remote-debugging-port` e `--disable-extensions`; `window.$flutterDriver` responde via CDP. Deep link com
   servidor estático dá 404: navegar `/` e depois `history.pushState` + `popstate`. Login pelo `qa_drive.dart` com
   `QA_EMAIL/QA_PASSWORD` só no ambiente do processo; "Manter sessão aberta" sobrevive à recarga completa.
   Cada conversa usa porta CDP própria e declara no JSON (o 9333 foi tomado por outra sessão no meio da prova).
2. **Dirigir a UI:** preferir `tap` por `ByValueKey`; clique por coordenada erra quando o rodapé muda (Anterior no
   lugar de Continuar) — o falso "Revisão sem salvar" de `agenda.edit` veio daí. `set_frame_sync=false` quando há
   animação contínua. O balão de chat intercepta toques: a 1440 cobre o botão Publicar da Circular (Decisão 7),
   corrigido pelo principal-chat em `dcfcb9e41` (SuperadminFormFrame suprime o balão) — confirmar na base.
3. **Composto `CoeloAdminDirectory`:** a primeira medição do rodapé faz `setState` no primeiro frame, então testes
   de widget fazem `pumpAndSettle` antes de interagir; página migrada não renderiza título (é do shell); Arquivos
   honesto (importar/exportar indisponíveis). A regra do Owner do estado vazio (busca, filtros, toggle, Arquivos,
   abas e Criar sempre) tem teste de widget por diretório (`*_directory_empty_state_test.dart`) como padrão.
4. **Correções que viram regra de tela:** diretório relê o servidor ao voltar de mutação (router entrega `extra`
   novo → `ValueKey(state.extra)` no host); ação só é oferecida quando o servidor aceita (Editar oculto em Circular
   Encerrada/Arquivada); detalhe carrega contextos quando vazios (deep link mostrava UUID).
5. **Goldens:** decisões A/R aplicadas (calendário 375 com células compactas; 48/48 do recorte); FUNDO de
   `agenda_create_375`, `agenda_detail_*` e `notice_form_initial_mobile_375` depende do `SuperadminFormFrame`;
   dúvidas P33/P34 com página lado a lado (`duvidas-visuais.html`, R referência × A atual).
6. **Memória:** um `flutter test <arquivo> --concurrency=1` por vez; rodar a família inteira derrubou a VM.

## coelo-frontend-backend (`.claude/skills/coelo-flutter-supabase-review/SKILL.md`)

1. **Régua do MVP aplicada por action_id** e a sequência que funcionou: pacote verde no descartável → coordenador
   aplica (dump por lote) → prova por RPC com a sessão (BE done) → UI com captura + reload (FE verified) →
   `verified-e2e` só com os dois; deltas propostos por action_id no JSON, o coordenador aplica no inventário.
2. **Instituição sintética é pré-requisito** para Circulares e Agenda (produção não tinha nenhuma); a
   `9f040000-0000-4000-8000-000000000010` foi criada pelo realm-interno. Dados sintéticos deixados em produção:
   avisos `[R04-QA]`/`[R04-QA UI]` inativos (o v2 não exclui), circulares excluídas/encerradas, eventos
   cancelados/publicados — limpeza pelo coordenador ao fim da rodada.
3. **Achados abertos do recorte** (gate registrado no JSON): balão de chat em criar/editar/publicar (principal-chat);
   deep link frio de `/agenda/events/:id` fica em spinner até passar pelo calendário; picker de agendamento da
   Circular não acionado pela tela; `circulars.respond`/`attach` (caminho do Principal e upload real R2);
   `agenda.request`/`permissions`/`location` sem dados sintéticos (unidade); `notices.schedule` pela tela.

## Pendências que só resolveremos depois (pós-MVP / revisão profunda)

- Cadeia legada people-based de Avisos (003000/204824/212340/220500) e métricas por geração (191100): fora até
  existir consumidor no Principal; o v2 não depende delas.
- Disparo do worker de Avisos (P30) e prova de `reach > 0` no diretório.
- Reescrita dos pgTAP históricos `superadmin_agenda_production_test` e `superadmin_agenda_contexts_test` para a forma
  de produção.
- Revisão profunda de segurança (ADR 0034): concorrência com duas sessões, ID adulterado por tela, auditoria com
  retry, varredura de grants default nas famílias fora deste recorte.
- Membership interno escopado por instituição na Agenda (hoje deny-by-default; decisão de produto).
- Cleanup de jobs concluídos do worker e `available_at` quando `starts_at` muda após publicar.
