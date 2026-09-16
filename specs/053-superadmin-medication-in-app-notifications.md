---
title: "Medicação › sino in-app para a equipe da unidade e educadores da turma"
source: "decisions/0041-owner-decisions-r14-mesa-20260916.md (B8); docs/reviews/etapa-2-operacao/next-round/R14-pendencias.md (owner.r12-33); dump de produção 20260916 (medication_plan_care_notify_v1, notify_child_care_event_v1, child_care_notification_recipients_v1, context_notification_events/recipients); apps/superadmin/lib/app/activity/context_notification_feed.dart"
status: "approved-contract; implementação local R14 Sessão 10"
lifecycle: "current"
generated_at: "2026-09-16"
updated_at: "2026-09-16"
audience: "team"
---

# Medicação › sino in-app (ADR 0041 B8, `owner.r12-33`)

## 1. Decisão do Owner

Ao **criar/editar um plano de medicação** e a **cada dose registrada**, os
**administradores da unidade** e os **educadores da turma da criança** recebem
uma notificação **in-app** (sino). Sem e-mail/push no MVP.

## 2. O que já existe em produção (dump de 16/09)

- Sino: `context_notification_events` + `context_notification_recipients`
  (policies `*_recipient_read`/`*_own_read`/`*_own_update`), lidos pelo
  Superadmin em `ContextNotificationFeed` (`SupabaseContextNotificationRepository`)
  e exibidos no `SuperadminActivityCenter`; abrir o centro grava `read_at`.
- Trigger `medication_plans_care_notify_v1` (INSERT / UPDATE OF status) →
  `notify_child_care_event_v1` → destinatários de
  `child_care_notification_recipients_v1` (equipe da unidade, hierarquia da
  criança e demais responsáveis, conforme `unit_care_policies`). Cobre
  **criar** e mudanças de status; não cobre **editar** (nova versão) nem **dose**.

## 3. Contrato novo (migration `20260916190000_medication_in_app_notifications_v1`)

- `app_private.medication_notification_recipients_v1(p_institution_id,
  p_unit_id, p_child_context_id, p_actor_person_id) returns setof uuid`:
  equipe administrativa da unidade (memberships ativas com escopo na unidade ou
  na instituição, exceto `legal_representative`) ∪ educadores da turma da
  criança (memberships com escopo nas turmas ativas da criança e profissionais
  atribuídos), respeitando `unit_care_policies.notify_unit` /
  `notify_child_hierarchy`; **sem responsáveis** (audiência do B8); só
  pessoas adultas ativas; nunca o próprio ator.
- `app_private.medication_notify_v1(...)`: cria o evento e os destinatários
  (mesma anatomia de `notify_child_care_event_v1`), sem PII no payload.
- Trigger `medication_plan_versions_notify_v1` (AFTER INSERT, `version > 1`)
  → `medication.plan.updated` (`payload: {version}`); a versão 1 já gera
  `medication.plan.created` pelo trigger existente.
- Trigger `medication_plan_evidence_notify_v1` (AFTER INSERT) →
  `medication.dose.recorded` (`payload: {outcome, occurred_at, plan_version_id}`).
- Unidade do evento: `medication_plans.unit_id` ou, no escopo de instituição,
  a unidade ativa da criança (mesma regra do trigger existente); `medication_mode
  = 'not_tracked'` silencia, como hoje.
- Fora de escopo: e-mail/push, worker de entrega (`delivery_state` fica
  `pending` como nos demais eventos), mudança da audiência de
  `medication.plan.created` (mantida), Principal.

## 4. Front-end

`ContextNotificationFeed.subjectFor` ganha rótulos: `medication.plan.created` /
`medication.plan.updated` / `medication.plan.<status>` → "Medicação · plano
(criado | atualizado | ativo | suspenso | encerrado)"; `medication.dose.recorded`
→ "Medicação · dose registrada"; `summaryFor` traduz `outcome`
(administrada / não administrada / recusada) quando não há título.

## 5. Testes

- pgTAP (espelho): destinatários (admin da unidade e educador da turma sim;
  responsável e ator não; unidade sem política → padrões; `notify_unit=false`
  exclui a equipe); editar plano (versão 2) gera `medication.plan.updated`
  e a versão 1 não duplica; cada dose gera `medication.dose.recorded` com o
  `outcome`; `not_tracked` silencia; eventos legíveis só pelo destinatário
  (policy) e não pelo terceiro.
- Flutter: rótulos e resumo do sino para os códigos novos.

## 6. Aceite

BE `local-green` (espelho) e FE `local-green`; `done`/`verified-e2e` exigem a
migration em produção, plano/dose reais e sino observado com a identidade de
um administrador da unidade e de um educador da turma (`qa-r06-operacoes` e
outra identidade da unidade).
