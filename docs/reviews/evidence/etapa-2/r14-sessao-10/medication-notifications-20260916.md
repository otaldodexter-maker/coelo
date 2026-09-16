---
source: "Sessão 10 da R14 (Opus 5, frontend+backend, trabalho local), 16/09/2026; ADR 0041 B8; owner.r12-33; specs/053-superadmin-medication-in-app-notifications.md"
status: evidence
lifecycle: current
generated_at: 2026-09-16
---

# Medicação › sino in-app (`owner.r12-33`, ADR 0041 B8) — fatia 3, local (16/09/2026)

Ambiente: **nenhuma escrita em produção**, nenhuma rota real (incidente PostgREST 504). Espelho
próprio `coelo_mirror_r14_historico` (dump de schema de 16/09, SHA-256 `f1f677ca…`).

## O que já existia (confirmado no dump)

- Sino in-app: `context_notification_events` + `context_notification_recipients` com policies de
  destinatário; leitor no Superadmin (`ContextNotificationFeed`/`SupabaseContextNotificationRepository`,
  `SuperadminActivityCenter`), que grava `read_at` ao abrir o centro.
- Trigger `medication_plans_care_notify_v1` (criar plano e mudanças de status) →
  `notify_child_care_event_v1` (equipe da unidade + hierarquia + responsáveis, por política).
- Faltavam: **editar plano** (nova versão) e **dose registrada**.

## Backend (espelho) — `20260916190000_medication_in_app_notifications_v1.sql`

- `app_private.medication_notification_recipients_v1`: equipe administrativa da unidade
  (memberships com escopo unidade/instituição, exceto representante legal) ∪ educadores da turma
  da criança (memberships com escopo nas turmas ativas + profissionais atribuídos), respeitando
  `unit_care_policies.notify_unit/notify_child_hierarchy`; sem responsáveis; nunca o ator.
- `app_private.medication_notify_v1(plan, code, type, id, payload, actor)`: evento + destinatários;
  unidade do plano ou unidade ativa da criança; `medication_mode='not_tracked'` silencia.
- Triggers: `medication_plan_versions_notify_v1` (AFTER INSERT, `version > 1`) →
  `medication.plan.updated {version}`; `medication_plan_evidence_notify_v1` (AFTER INSERT) →
  `medication.dose.recorded {outcome, occurred_at, plan_id, plan_version_id}` — sem texto livre/PII.
- Aplicada **2×** no espelho (idempotente).
- pgTAP `medication_in_app_notifications_v1_test.sql`: **29/29** — grants/SECURITY DEFINER;
  destinatários (admin da unidade e educador da turma sim; responsável, ator, admin de outra
  unidade, educador de outra turma e representante legal não); versão 1 não duplica; versão 2
  emite `plan.updated` só com `{version: 2}` na unidade da criança para exatamente admin + educador;
  cada dose emite `dose.recorded` com `outcome`, sem `note/reason`; dose registrada pela educadora
  notifica os administradores (instituição/unidade), não ela; `notify_unit=false` deixa só os
  educadores; `not_tracked` silencia; pelo sino (policies) o admin da unidade vê 3 itens não lidos e
  marca como lidos; admin de outra unidade não vê eventos nem destinatários.
- **Não aplicada em produção**; sem e-mail/push (`delivery_state` fica `pending` como hoje).

## Front-end (local)

- `ContextNotificationFeed.subjectFor/summaryFor`: rótulos "Medicação · plano criado/atualizado/
  ativo/suspenso/encerrado/em rascunho", "Medicação · dose registrada" e resumo por `outcome`
  ("Dose administrada/não administrada/recusada") ou "Versão N do plano".
- Teste `context_notification_feed_test.dart` 4/4 (novo caso de rótulos); `flutter analyze` sem
  novos avisos.

## Separação FE / BE / E2E

- FE: local-green (só rótulos; o leitor do sino já existia). BE: local-green (espelho).
- E2E pendente: aplicar a migration, editar um plano real e registrar uma dose com
  `qa-r06-operacoes`, e observar o sino com uma identidade da unidade / educador da turma.
- Nenhum `action_id` mudou de estado.
