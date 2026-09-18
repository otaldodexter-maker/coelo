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

## 3. Limite da prova: admin da unidade e educador da turma

As 11 memberships ativas da instituição sintética QA R04 Cuidado são todas `owner/institution` de **pessoas de serviço**
(`person_type = 'service'`: Operador interno …, Dextec SaaS), que por regra nunca são destinatárias de sino. Não existe
pessoa adulta humana com membership de unidade/turma nesse tenant, logo o caminho "admin da unidade e educador da
turma recebem" **não pode ser observado em produção** sem uma fixture de membership (SQL fora dos itens a–d
autorizados) — fica como bloqueio registrado no handoff. Esse caminho está provado no espelho fiel (pgTAP v2 27/27,
v1 29/29) e é o mesmo predicado da v1, apenas com a exclusão de família.

**Resultado:** `owner.r12-33` → **partial** (FE verified: sino lê os eventos; BE done: v2 em produção no lote 82;
E2E: responsável observada em produção; admin/educador só no espelho por falta de massa humana de equipe).
`recipients-bug` → concluído (lote 82). Nenhum `action_id` muda.
