---
source: sessao Claude R13 de 14/09/2026; ADR 0038 (R12-51); packages/coelo_database/migrations/ordem-de-aplicacao-producao.txt
status: evidence
generated_at: 2026-09-14
---

# Lotes 63 e 64 — aplicação em produção e provas por RPC (14/09/2026)

Ambiente: Supabase de produção (`evvbomzejfijozbtgvpt`), sessão `qa-r06-estrutura@coelo.me`
via `packages/coelo_database/scripts/r13-rpc-proof.mjs` (PostgREST, sem chave de serviço).
Espelho: projeto descartável `coelo_mirror_r13` (portas 613xx) = baseline + seed +
167 arquivos da ordem real por psql, depois os candidatos.
Base Git antes das provas: 8e33db805.

## Lote 63 (12:45) — owner.r12-51: quatro candidatos R11

- Dump lógico fora do Git: `Coelo-backups/schema-producao-20260914-r13-lote63.sql`
  (SHA-256 778d4f37ec443a5fe16f068e8ed5e682ed2f389289e12ec51a7d61b03d82c777) e
  `dados-producao-20260914-r13-lote63.sql` (63801fa3231166afce5e73efe404aafe0484655e263aa188eb76cf33d738de6d).
- pgTAP no espelho: assessment-update-isolation 8/8, group-directory-counts 10/10,
  account-avatar-access 9/9, gradebook-all-participants 13/13.
- Ledger 283 → 287 (20260913143441, 143659, 144142, 145023). md5 de
  `pg_get_functiondef` das seis funções: produção == espelho.
- ACL: funções `app_private` só `postgres`; wrappers públicos `authenticated`
  (+`service_role` nos legados). Sem grant novo a `anon`.

## Lote 64 (13:05) — hotfix groups.list busca

- Defeito pré-existente na baseline: `escape '\'` (dois caracteres) devolvia
  `22025 invalid escape string` em produção para qualquer `p_search` não vazio.
- Teste vermelho antes (4/4 com `not ok 1`), verde depois; counts 10/10 preservado.
- Dump `schema-producao-20260914-r13-lote64.sql` (SHA-256 dc9c43bc554654e0…); ledger 288.

## Provas por action_id em produção (Back-end)

| action_id | Prova | Negativa |
|---|---|---|
| groups.list | `superadmin_group_directory` devolve turma 4214106c com `student_count=1` e 3 `activity_ids` (antes zeros); busca `R05` encontra a turma. | `p_institution_ids=[0000…]` → `items: []`; id inexistente não enumerável. |
| activities.assessment | `superadmin_assessment_save_configuration` UPDATE da configuração retida b04c879e (expected_version 1) → `version: 2`; `configuration_read_by_id` relê instrumento "Instrumento R08 (R13 update)". | `read_by_id` de id inexistente → `data: null`. |
| assessments.gradebook / assessments.detail | `superadmin_assessment_gradebook_read` do diário d2c945d8 lista a participante "Crianca QA R04" (antes ausente), eventos e configuração ativa. | Escopo por `has_platform_permission` provado no pgTAP 13/13. |
| account.profile | `superadmin_account_profile_save_v2` grava sigla `QE` + cor `#D63C00` + celular; `superadmin_account_profile_get` relê os mesmos valores (`avatar_contract_version: 2`). | Celular vazio → `22023 invalid_account_profile`. Foto R2 continua não implementada → BE `remote-green`, não `done`. |

Não exercitado: `assessments.entry/close/reopen` (save/submit/publish do diário),
`activities.publish` (já `done`). FE e E2E dessas telas continuam pendentes de
rota real no Chrome.

## Lote 65 (13:35) — H06: revogar proibido em conversa somente leitura

- `20260914133000_r13_chat_revoke_read_only_v1.sql`: `superadmin_chat_revoke_message_v2`
  lê `is_read_only` e devolve `CHAT_READ_ONLY` antes de qualquer alteração; revoke
  explícito de `public`/`anon` e grant só a `authenticated`.
- pgTAP vermelho→verde: `supabase/tests/r13/chat-revoke-read-only-test.sql` 14/14;
  suíte base `superadmin_internal_chat_receipts_edit_revoke_baseline_test.sql` 36/36.
- Dump `schema-producao-20260914-r13-lote65.sql` (SHA-256 d3c7e00a444bd8c8…); ledger 289;
  `pg_get_functiondef` em produção contém o guard. Produção não tem conversa
  somente leitura (0 linhas), por isso a negativa de runtime foi por id inexistente
  (`CHAT_NOT_FOUND`, sessão `qa-r06-principal`). `chat.revoke` já era `verified-e2e`.

## Lote 66 (14:25) — H17: políticas de cuidado só por capacidade

- `20260914140000_r13_care_policies_manage_capability_v1.sql`: `care_policies.manage` em
  `platform_permissions` (Owner) e `institution_permissions` (Administrador da instituição,
  `application_code = admin`); `superadmin_unit_care_policy_set_v1` troca `units.update` +
  papel owner/operations pela capacidade; revoke `public/anon/service_role`, grant `authenticated`.
- pgTAP vermelho→verde `supabase/tests/r13/care-policies-manage-capability-test.sql` 15/15
  (papel sem a capacidade negado mesmo com `units.update`; conceder só a capacidade libera);
  suíte base `unit_care_policies_notifications_v1_test.sql` 20/20.
- Produção (sessão `qa-r06-operacoes`, Owner): get → set `notify_unit` (management_version 0→2)
  → get relê; unidade inexistente → `SAI_PERMISSION_DENIED`. Dump lote66 SHA-256 8464db0497191447…; ledger 290.
- Nenhum cliente Flutter consome esta RPC ainda; não há `action_id` próprio.

## Lote 67 (14:55) — 10 anexos por envio no Chat

- `20260914143000_r13_chat_attachment_limit_per_send_v1.sql`: `prepare_v1` conta os anexos
  pendentes do autor na conversa (ticket vivo, `upload_status = pending`) e recusa o 11º com
  `CHAT_ATTACHMENT_LIMIT`; envelope ganha o código (422). Replay idempotente e ticket expirado
  não contam. Revoke `public/anon/service_role`, grant `authenticated`.
- pgTAP `supabase/tests/r13/chat-attachment-limit-per-send-test.sql` 9/9 (vermelho antes);
  base `superadmin_internal_chat_attachments_v1_test.sql` 28/28.
- Produção (sessão `qa-r06-principal`, conversa 355a3403): 10 `prepare` aceitos, 11º
  `CHAT_ATTACHMENT_LIMIT`; os 10 rascunhos sintéticos foram arquivados com o mesmo efeito do
  `expire_v1` (tickets usados, `upload_status = failed`, mensagens `archived`).
- Cliente Superadmin: `ChatAttachmentLimitException` mapeada de `chat_attachment_limit` na
  Edge Function `chat-media`, mensagem no diálogo de upload; `flutter test test/features/chat`
  243/243, `flutter analyze` limpo. Dump lote67 SHA-256 306de5fc649dac8c…; ledger 291.

## Lote 68 (15:20) — H21: Circular 4.000 no total

- `20260914150000_r13_circular_total_text_4000_v1.sql`: `superadmin_circular_save_draft_v2`
  limita a soma dos blocos de texto a 4.000 (antes 10.000); constraint
  `circular_revisions_body_length_check` acompanha (maior corpo em produção: 83).
- pgTAP `supabase/tests/r13/circular-total-text-4000-test.sql` 10/10 (2.000+2.000 aceito;
  2.000+2.001 recusado; só a revisão válida gravada). Produção (sessão `qa-r06-publicacoes`):
  4.001 somados → `CIRCULAR_INVALID_INPUT` 422. Dump lote68 SHA-256 78572d65c3fff32e…; ledger 292.
- Cliente: `CircularLimits.bodyCharacters = 4000` (o compositor já subtraía os outros blocos);
  teste de domínio atualizado. Os 18 goldens de Circular falhavam antes e depois desta
  mudança (H04 — regravação após o host seguir a referência).

## Lote 69 (15:50) — OQ-028: status de Suporte, mapeamento A

- `20260914153000_r13_support_status_mapping_v1.sql`: `superadmin_support_set_status` grava
  Novo=`open`, Em andamento/Aguardando=`pending` (o `ticket_status` é a flag), Concluído=`resolved`;
  trigger `support_session_ticket_status_sync` projeta `resolved/closed/expired/revoked` como
  Concluído; `superadmin_support_get`/`_list` expõem `closure_reason` (`expired`/`revoked`).
  Reconciliação idempotente dos registros existentes (1 chamado, já coerente).
- pgTAP `supabase/tests/r13/support-status-mapping-test.sql` 13/13; bases 23/23, 28/28, 17/17.
- Produção (sessão `qa-r06-operacoes`): chamado 6c5eb791 criado (open) → `waiting_requester`
  (enum `pending`) → `completed` (enum `resolved`), `closure_reason` nulo. Dump esquema+dados
  lote69 SHA-256 c95bcfa9e9931b85… / 655cd22296c6856f…; ledger 293.
- Cliente: `SupportTicket.closureReason` + `supportStatusLabel()`; chip do detalhe mostra
  “Concluído · Expirado/Revogado”; testes de Suporte verdes exceto o golden que já falhava
  (cabeçalho global, R12-10).

## Rota real no Chrome (14/09, 15:00–15:30) — Estrutura e Conta

Build `flutter build web --release -t test_driver/qa_main.dart --dart-define-from-file=.env.local
--dart-define=COELO_QA_TEXT_ENTRY_EMULATION=true`, servido por `serve.py` em `127.0.0.1:3013`;
Chrome CDP (porta 9413, SwiftShader, perfil próprio); login `qa-r06-estrutura` pelo `qa_drive.dart login`;
comandos do driver por `Runtime.evaluate` (`set_frame_sync=false` após cada carga); cliques por
coordenada. Nota de método: no Windows o `dart run` passa por `cmd`, que corta URLs em `&` —
montar a query string em JS (`String.fromCharCode(38)`). Capturas em `capturas/`.

| action_id | Rota normal | CRUD em produção | Reload | Negativa |
|---|---|---|---|---|
| groups.list | `/groups` lista turmas reais; "Turma R05 Estrutura" com Alunos 1 / Atividades 3 (antes zeros); busca "R05" filtra (hotfix do lote 64). | leitura | mantém lista e contadores | pgTAP 10/10 + RPC com instituição alheia vazia |
| activities.assessment | `/activities/95b98978…/assessment-settings?institutionId&unitId&configurationId=b04c879e` carrega o rascunho retido (Anual, período "R08 sintético", instrumento). | "Salvar rascunho" após renomear o instrumento → `management_version` 2→3 em `activity_assessment_configurations`. | relê "Instrumento R08 (rota real R13)" | pgTAP 8/8 + `read_by_id` inexistente → `data: null` |
| assessments.entry / gradebook / detail | `/assessments/gradebooks/d2c945d8…/edit` lista "Crianca QA R04" (antes ausente). | nota 8.5 + "Salvar rascunho" → `assessment_gradebooks.management_version` 1→2. | relê 8.5, média 8.50, situação Pendente | pgTAP 13/13 (escopo/tenant) |
| account.profile | `/profile` mostra sigla/cor/celular gravados no lote 63. | sigla QE→QR + "Salvar alterações" → "Perfil atualizado"; `people.account_avatar_initials = QR`. | relê QR no avatar, cabeçalho e campo | `22023` sem celular; ator = self (`assert_account_actor`) |

Não exercitado na rota real: `assessments.close/reopen` (fechamento/reabertura), foto R2 da Conta
(sem persistência implementada — `account.profile` BE segue `remote-green`, E2E aberto).
