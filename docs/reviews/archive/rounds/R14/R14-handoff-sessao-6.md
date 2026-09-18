---
title: "R14 — handoff da Sessão 6 (Formulários › Arquivos/Editor/Localização e Chat › Anexo)"
source: "briefing comum R14 de 16/09; R14-pendencias.md; ADR 0041; inventario-etapa-2.json"
status: "active"
lifecycle: "current"
generated_at: "2026-09-16"
updated_at: "2026-09-16"
audience: "team"
---

# R14 — handoff da Sessão 6

Sessão 6 (Opus 5), worktree `C:\Users\adrie\Documents\Coelo.worktrees\r14-formularios-chat`, branch
`r14/formularios-chat`, base `dev dbe518101`, servidor `127.0.0.1:3017`, Chrome CDP `9417`,
espelho `Coelo-backups/mirror-r14-formularios` (`coelo_mirror_r14_formularios`, portas 616xx).
Só a Sessão 6 escreve aqui. A coordenadora integra por cherry-pick.

## Reivindicações

| Tela | action_ids | Desde |
|---|---|---|
| (nenhuma — Sessão 6 parada às 14:20 BRT por bloqueio de ambiente; as quatro fatias abaixo ficam liberadas para retomada por esta ou outra sessão) | forms.expire-file, forms.delete-file, forms.create, forms.edit, forms.location-answer, chat.attach; owner.r12-39/40/52 | — |

## Fatias entregues

| SHA | action_ids → estados | Owner items | Evidência |
|---|---|---|---|
| 9820d5e3b | BE de forms.expire-file: lote 73 (`20260915203000_forms_question_media_expire_audit_v1`) aplicado em produção pelo rito completo (espelho próprio, pgTAP 34/34 + 7/7 + 9/9, dump prévio, dry-run exato, ledger 304); `plan(33→34)` corrigido no teste. Nenhum estado por action_id alterado (sem prova de rota). | — | r14-sessao-6/forms-expire-delete-file-20260916.md |

## Avisos para as outras sessões

- **Lote 73 em produção às 12:20 BRT (16/09)**: `20260915203000_forms_question_media_expire_audit_v1`
  aplicada por `supabase db push --linked` (dry-run listou só ela; ledger remoto 304). Função alterada:
  `public.form_media_expire_question_r2_v1(integer)` (service_role; agora grava `forms.media.expire` em
  `audit.audit_logs`). Nenhuma tabela/grant novo. `ordem-de-aplicacao-producao.txt` atualizado.
- **PostgREST de produção saturado das ~12:30 às 14:20 BRT (pelo menos)**: `504 PGRST003` para qualquer
  chamada. `pg_stat_activity` (só-leitura, D1) mostra as 10 conexões do pool ocupadas em laço por RPCs de
  outras sessões: `child_safety_change_lifecycle` (6 conexões), Agora remove/purge `p_post_id` (3) e
  Momentos/Acontece `p_publication_id` (1), muitas em `idle in transaction (aborted)` = chamadas que falham
  e são reemitidas sem espera. **Quem estiver rodando prova de concorrência/retry nessas famílias precisa
  parar ou espaçar**; enquanto isso nenhuma rota real funciona para ninguém.
- O teste `forms_question_media_r2_v1_test.sql` tinha `plan(33)` com 34 asserções desde `0481384f5`; corrigido.
- Achado de contrato para `owner.r12-52`: `superadmin_chat_attachment_prepare_v1` cria **uma mensagem por
  anexo** (`insert into public.messages … 'attachment'`) e o compositor da tela envia um arquivo por vez
  (`FilePicker … files.files.single`). O mosaico "múltiplas mídias da mesma mensagem" não é alcançável pela
  rota normal em produção; só o tile único e o anexo não visual podem ser provados. Classificação sugerida:
  RPC/contrato (decisão de produto: agrupar anexos por envio ou manter 1 mensagem por anexo).
- Observação para quem retomar Formulários: o card "Expirar acesso"/"Excluir arquivo" em `/forms/:id/files`
  é fixture de desenvolvimento; a exclusão real é "Excluir imagem N" no diálogo "Imagens da pergunta" do
  editor (EF `form-media` `delete` → `superadmin_form_media_delete_v2`) e a expiração é o worker do cron.

## Sobra para a R15

- As quatro fatias inteiras (nenhuma certificada): `forms.expire-file`/`forms.delete-file` (roteiro de
  retomada no md de evidência), `forms.create`/`forms.edit` + `owner.r12-39/40`, `forms.location-answer`,
  `chat.attach` + `owner.r12-52` (com o achado de contrato acima).
- Ambiente pronto para retomar sem retrabalho: build QA em `apps/superadmin/build/web` desta worktree,
  espelho `mirror-r14-formularios` (parado ao sair; `supabase start` recria), scripts de direção no
  scratchpad (`batch.dart` com passos `driver/clickxy/upload/block/reload/shot`), PNG 64×64 e PDF sintéticos.

## Bloqueios

- **Ambiente** (gate E2E de todas as fatias): pool do PostgREST de produção saturado por laço de RPCs de
  outras sessões (ver Avisos). Sondado a cada 20 s de 12:30 a 14:20 BRT sem recuperação. Nenhuma mutação
  desta sessão em produção além do lote 73 (função de auditoria da expiração).
- **RPC/contrato** (owner.r12-52, parcial): mosaico exige vários anexos na mesma mensagem; o contrato
  produtivo cria uma mensagem por anexo.

## Contadores

`node docs/reviews/validate-trackers.cjs` em `9820d5e3b`: PASS — actions 232, FE 186/232, BE 168/219,
E2E 159/186 ativo; Owner 21/53. Sem alteração por esta sessão.
