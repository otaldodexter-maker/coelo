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
| Formulários › Arquivos (expirar/excluir imagem de pergunta) | forms.expire-file, forms.delete-file | 16/09 12:00 |
| Formulários › Editor (/forms/new, /forms/:id/edit) | forms.create, forms.edit, owner.r12-39, owner.r12-40 | 16/09 12:00 |
| Formulários › Resposta com Local | forms.location-answer | 16/09 12:00 |
| Chat › Anexo | chat.attach, owner.r12-52 | 16/09 12:00 |

## Fatias entregues

| SHA | action_ids → estados | Owner items | Evidência |
|---|---|---|---|
| (em andamento) | — | — | — |

## Avisos para as outras sessões

- **Lote 73 em produção às 12:20 BRT (16/09)**: `20260915203000_forms_question_media_expire_audit_v1`
  aplicada por `supabase db push --linked` (dry-run listou só ela; ledger remoto 304). Função alterada:
  `public.form_media_expire_question_r2_v1(integer)` (service_role; agora grava `forms.media.expire` em
  `audit.audit_logs`). Nenhuma tabela/grant novo. `ordem-de-aplicacao-producao.txt` atualizado.
- Entre 12:30 e 12:50 BRT o PostgREST de produção devolveu `504 PGRST003` (pool de 10 conexões saturado por
  chamadas concorrentes de `child_safety`/`agora`/`momentos` de outras sessões, observado em `pg_stat_activity`
  só-leitura). Não é defeito do código de Formulários; considerar espaçar provas de concorrência.

## Sobra para a R15

- (a preencher)

## Bloqueios

- (a preencher)

## Contadores

- (a preencher após `validate-trackers`)
