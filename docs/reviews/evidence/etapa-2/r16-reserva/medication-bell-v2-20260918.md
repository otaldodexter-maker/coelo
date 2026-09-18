---
source: "Sessão RESERVA da R16 (Opus 5, coelo-8d), 18/09/2026; R16-prompt-reserva-20260918.md (Bloco 1 item 3, lote 82 item a); ADR 0042 E7 = b; ADR 0044 (recipients-bug); spec 053; r14-sessao-10/medication-notifications-20260916.md; OQ-048"
status: evidence
lifecycle: current
generated_at: 2026-09-18
owner_items: "owner.r12-33"
---

# Medicação › sino in-app v2 (responsável destinatária; `recipients-bug`) — lote 82 e prova em produção (18/09/2026)

## 1. Contrato e lote

- `20260916190000_medication_in_app_notifications_v1` está em produção desde o lote 74 (fato corrigido em 18/09).
- `20260918120000_medication_in_app_notifications_v2` (lote 82, item a, 14:45:13 UTC): `app_private.medication_notification_recipients_v2`
  inclui o responsável por `guardian_links` ativo (sujeito a `unit_care_policies.notify_other_guardians`, como nos demais
  eventos de cuidado) e exclui memberships de família (`role_code` `guardian`/`student`) da "equipe da unidade" e dos
  "educadores da turma"; a mesma exclusão entra em `app_private.child_care_notification_recipients_v1` (mesma assinatura —
  é o `recipients-bug`); `medication_notify_v1` passa a usar a v2; triggers e assinaturas inalterados; sem grants a
  clientes. pgTAP no espelho fiel `mirror-r16-reserva` (dump `9bb98a47`): `medication_in_app_notifications_v2_test`
  **27/27** (admin, educador e responsável destinatários; membership `guardian` sem vínculo e `student` não são equipe;
  `notify_other_guardians=false` exclui o responsável; `not_tracked` silencia; leitura pelo sino via policies), v1
  **29/29** (alinhada ao contrato novo), `unit_care_policies_notifications_v1` 20/20. Pós-verificação em produção: funções
  presentes/usadas, sem 40001, sem execute a `anon`/`authenticated`.

## 2. Prova na rota real (produção, 3014, `qa-r06-operacoes` como atriz)

Massa: plano novo `2ecf267e-b5cb-45a8-9ade-ebe5b41fe760` "QA R15 Ibuprofeno R16" (5 ml, oral, seg/qua 08:00) para
**QA R15 Crianca 1** (contexto `1a6158fe…`, Turma QA R04, Unidade QA R04), criado por `superadmin_medication_plan_save`
com o mesmo contrato da tela (a tela de criação exige seleção de criança por busca; o plano foi criado por RPC e as
ações seguintes foram pela tela). A responsável da criança é `qa-r15-responsavel` (fixture AP-1).

| Passo | Resultado | Captura |
|---|---|---|
| Editar plano pela tela (`/health-care/medication-plans/2ecf267e…/edit`): dose 5 → **7 ml** › Revisão › Salvar alterações | `superadmin_medication_plan_detail`: `management_version 2`, `current_version.version 2`, `dose_amount 7`; evento `medication.plan.updated` 14:59:45 UTC | `medication-01-editar-plano-dose-7.png` |
| Registrar dose pela tela (Revisão › Registrar dose › Administrada › Registrar) | evidência `8bb68ccc…` `administered` 15:01:54 UTC; evento `medication.dose.recorded` | `medication-02-registrar-dose.png` |
| Sino da responsável (`qa-r15-responsavel`, PostgREST `context_notification_recipients` + `context_notification_events`, RLS própria — a conta só-responsável não abre tela, OQ-048) | **3 itens não lidos do plano: `medication.plan.created`, `medication.plan.updated`, `medication.dose.recorded`** (E7 = b) | — |
| Sino das seis identidades internas `qa-r06-*` (mesma leitura) | 0 itens do plano — a atriz nunca se notifica; as demais são pessoas de serviço | — |
| Leitura (só leitura, `db query --linked`) dos destinatários gravados para os 3 eventos | apenas "QA R15 Responsavel" (`is_guardian true`, sem membership) | — |

## 3. Admin da unidade e educador da turma — lote 83 (autorizado pelo Owner em 18/09)

O tenant sintético não tinha pessoa humana de equipe (as 11 memberships eram pessoas de serviço). O Owner autorizou a
fixture: `20260918170000_qa_r15_care_staff_fixture_v1` (lote 83, 16:13 UTC; dump prévio `7968c13a`; pgTAP
`qa_r15_care_staff_fixture_v1_test` **14/14**) criou "QA R15 Admin Unidade" (`086a70e1…`, `institution_admin/unit` na
Unidade QA R04) e "QA R15 Educadora Turma" (`bf68aea5…`, `teacher/group` na Turma QA R04 Estrutura), adultas ativas, sem
conta de login (contas são criadas só pelo Owner na Auth Admin).

| Passo | Resultado |
|---|---|
| Editar plano `2ecf267e` (dose 7 → **8 ml**, `superadmin_medication_plan_save`, mesmo contrato da tela) | `version 3`, `management_version 3`; evento `medication.plan.updated` 16:14:21 UTC |
| Registrar dose (`superadmin_medication_plan_record_evidence`, `refused`) | evidência `a96ac881…`; evento `medication.dose.recorded` 16:14:22 UTC |
| Destinatários gravados em produção (leitura como postgres) para os dois eventos | **QA R15 Admin Unidade** (`institution_admin/unit`), **QA R15 Educadora Turma** (`teacher/group`) e **QA R15 Responsavel** (guardian) — cada uma em `plan.updated` e `dose.recorded`; a atriz (`qa-r06-operacoes`) ausente |

Leitura pelo sino com as sessões da admin/educadora não é possível sem conta de login (não criada; fora da convenção do
projeto); a leitura por policies está provada no pgTAP v2 e, em produção, pela responsável.

**Resultado:** `owner.r12-33` → **done** (FE verified; BE done — lotes 82 e 83; E2E: os três destinatários observados em
produção, responsável também pelo sino via RLS). `recipients-bug` concluído.
