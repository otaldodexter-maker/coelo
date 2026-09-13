---
source: Owner 2026-09-13; R12-owner-items.json; R12-apontamentos-owner.md
status: sincronização documental; execução R12 não iniciada
generated_at: 2026-09-13
---

# R12 — Incorporação nos três rastreadores

Pedido explícito do Owner: incorporar todos os apontamentos nas camadas FE, BE e
FE+BE. 45 compromissos registrados, mantendo itens correlatos sem contar avanço
ou criar ações novas. Quatro itens de diretório/aprovações ainda sem action_id
específico confirmado permanecem abaixo, sem desaparecer nem mudar denominador.

Aplicação feita com apply-tracker-delta.cjs sobre notas e certificações vigentes,
sem usar os snapshots antigos dos deltas de captura. Nenhum status funcional foi
promovido/rebaixado por esta manutenção documental; avanços e notas R11 preservados.
Os arquivos R12-*-delta.json anteriores são propostas históricas: NÃO reaplicar,
pois contêm notas de captura antigas. Usar inventário vigente para futuros deltas.

As menções anteriores a integração central pendente nos registros de captura são
históricas: esta sincronização incorpora notas nas três matrizes, catálogo abaixo,
manifesto de entrega e referências das três skills. Implementações e decisões
permanecem pendentes R12. Nenhum deploy, SQL, runtime ou R12 iniciado aqui.

| Item | action_ids / lacuna de mapeamento | Fonte e primeiro gate |
|---|---|---|
| R12-01 | daily-routine.list | [R12-apontamentos-owner](R12-apontamentos-owner.md) — Ler R12-01 no registro, reconciliar fontes e reproduzir após abertura explícita da R12. |
| R12-02 | activities.list, daily-routine.list | [R12-apontamentos-owner](R12-apontamentos-owner.md) — Ler R12-02 no registro, reconciliar fontes e reproduzir após abertura explícita da R12. |
| R12-03 | activities.list | [R12-apontamentos-owner](R12-apontamentos-owner.md) — Ler R12-03 no registro, reconciliar fontes e reproduzir após abertura explícita da R12. |
| R12-04 | daily-routine.list, attendance.dashboard | [R12-apontamentos-owner](R12-apontamentos-owner.md) — Ler R12-04 no registro, reconciliar fontes e reproduzir após abertura explícita da R12. |
| R12-05 | attendance.create | [R12-apontamentos-owner](R12-apontamentos-owner.md) — Ler R12-05 no registro, reconciliar fontes e reproduzir após abertura explícita da R12. |
| R12-06 | attendance.create, daily-routine.apply | [R12-apontamentos-owner](R12-apontamentos-owner.md) — Ler R12-06 no registro, reconciliar fontes e reproduzir após abertura explícita da R12. |
| R12-07 | attendance.mark, attendance.correct, attendance.finish | [R12-apontamentos-owner](R12-apontamentos-owner.md) — Ler R12-07 no registro, reconciliar fontes e reproduzir após abertura explícita da R12. |
| R12-08 | attendance.mark, attendance.correct, attendance.finish, daily-routine.apply | [R12-apontamentos-owner](R12-apontamentos-owner.md) — Ler R12-08 no registro, reconciliar fontes e reproduzir após abertura explícita da R12. |
| R12-09 | child-safety.list | [R12-seguranca-perfis-owner](R12-seguranca-perfis-owner.md) — Ler R12-09, reconciliar decisão/mapeamento e executar somente na R12 autorizada. |
| R12-10 | child-safety.list | [R12-seguranca-perfis-owner](R12-seguranca-perfis-owner.md) — Ler R12-10, reconciliar decisão/mapeamento e executar somente na R12 autorizada. |
| R12-11 | Mapeamento pendente; não criar ID por inferência | [R12-seguranca-perfis-owner](R12-seguranca-perfis-owner.md) — Ler R12-11, reconciliar decisão/mapeamento e executar somente na R12 autorizada. |
| R12-12 | child-safety.child | [R12-seguranca-perfis-owner](R12-seguranca-perfis-owner.md) — Ler R12-12, reconciliar decisão/mapeamento e executar somente na R12 autorizada. |
| R12-13 | child-safety.create, child-safety.edit | [R12-seguranca-perfis-owner](R12-seguranca-perfis-owner.md) — Ler R12-13, reconciliar decisão/mapeamento e executar somente na R12 autorizada. |
| R12-14 | child-safety.child | [R12-seguranca-perfis-owner](R12-seguranca-perfis-owner.md) — Ler R12-14, reconciliar decisão/mapeamento e executar somente na R12 autorizada. |
| R12-15 | child-safety.child, child-safety.edit, child-safety.suspend | [R12-seguranca-perfis-owner](R12-seguranca-perfis-owner.md) — Ler R12-15, reconciliar decisão/mapeamento e executar somente na R12 autorizada. |
| R12-16 | child-safety.create | [R12-seguranca-perfis-owner](R12-seguranca-perfis-owner.md) — Ler R12-16, reconciliar decisão/mapeamento e executar somente na R12 autorizada. |
| R12-17 | child-safety.create, child-safety.edit | [R12-seguranca-perfis-owner](R12-seguranca-perfis-owner.md) — Ler R12-17, reconciliar decisão/mapeamento e executar somente na R12 autorizada. |
| R12-18 | child-safety.create | [R12-seguranca-perfis-owner](R12-seguranca-perfis-owner.md) — Ler R12-18, reconciliar decisão/mapeamento e executar somente na R12 autorizada. |
| R12-19 | Mapeamento pendente; não criar ID por inferência | [R12-perfis-permissoes-owner](R12-perfis-permissoes-owner.md) — Reconciliar R12-19 e fontes antes de executar na R12 autorizada. |
| R12-20 | Mapeamento pendente; não criar ID por inferência | [R12-perfis-permissoes-owner](R12-perfis-permissoes-owner.md) — Reconciliar R12-20 e fontes antes de executar na R12 autorizada. |
| R12-21 | access-profiles.detail | [R12-perfis-permissoes-owner](R12-perfis-permissoes-owner.md) — Reconciliar R12-21 e fontes antes de executar na R12 autorizada. |
| R12-22 | access-profiles.create, access-profiles.edit | [R12-perfis-permissoes-owner](R12-perfis-permissoes-owner.md) — Reconciliar R12-22 e fontes antes de executar na R12 autorizada. |
| R12-23 | access-profiles.create | [R12-perfis-permissoes-owner](R12-perfis-permissoes-owner.md) — Reconciliar R12-23 e fontes antes de executar na R12 autorizada. |
| R12-24 | access-profiles.create, access-profiles.edit | [R12-perfis-permissoes-owner](R12-perfis-permissoes-owner.md) — Reconciliar R12-24 e fontes antes de executar na R12 autorizada. |
| R12-25 | access-profiles.create, access-profiles.edit | [R12-perfis-permissoes-owner](R12-perfis-permissoes-owner.md) — Reconciliar R12-25 e fontes antes de executar na R12 autorizada. |
| R12-26 | access-profiles.edit | [R12-perfis-permissoes-owner](R12-perfis-permissoes-owner.md) — Reconciliar R12-26 e fontes antes de executar na R12 autorizada. |
| R12-27 | access-profiles.create, access-profiles.edit | [R12-perfis-permissoes-owner](R12-perfis-permissoes-owner.md) — Reconciliar R12-27 e fontes antes de executar na R12 autorizada. |
| R12-28 | health-care.edit | [R12-saude-cuidado-owner](R12-saude-cuidado-owner.md) — Reconciliar R12-28, reproduzir e desenhar contrato focal após abertura R12. |
| R12-29 | health-care.create, health-care.edit, health-care.detail | [R12-saude-cuidado-owner](R12-saude-cuidado-owner.md) — Reconciliar R12-29, reproduzir e desenhar contrato focal após abertura R12. |
| R12-30 | health-care.create, health-care.edit, health-care.detail | [R12-saude-cuidado-owner](R12-saude-cuidado-owner.md) — Reconciliar R12-30, reproduzir e desenhar contrato focal após abertura R12. |
| R12-31 | medication.create, medication.edit | [R12-saude-cuidado-owner](R12-saude-cuidado-owner.md) — Reconciliar R12-31, reproduzir e desenhar contrato focal após abertura R12. |
| R12-32 | medication.list, medication.detail, medication.create, medication.edit | [R12-saude-cuidado-owner](R12-saude-cuidado-owner.md) — Reconciliar R12-32, reproduzir e desenhar contrato focal após abertura R12. |
| R12-33 | medication.create, medication.edit, medication.detail | [R12-saude-cuidado-owner](R12-saude-cuidado-owner.md) — Reconciliar R12-33, reproduzir e desenhar contrato focal após abertura R12. |
| R12-34 | meal-plans.model-create, meal-plans.model-edit | [R12-cardapios-owner](R12-cardapios-owner.md) — Reconciliar R12-34 e reproduzir após abertura explícita da R12. |
| R12-35 | meal-plans.model-create, meal-plans.model-edit | [R12-cardapios-owner](R12-cardapios-owner.md) — Reconciliar R12-35 e reproduzir após abertura explícita da R12. |
| R12-36 | meal-plans.create, meal-plans.edit, meal-plans.publish | [R12-cardapios-owner](R12-cardapios-owner.md) — Reconciliar R12-36 e reproduzir após abertura explícita da R12. |
| R12-37 | meal-plans.create, meal-plans.edit | [R12-cardapios-owner](R12-cardapios-owner.md) — Reconciliar R12-37 e reproduzir após abertura explícita da R12. |
| R12-38 | meal-plans.create, meal-plans.edit, meal-plans.publish, meal-plans.model-edit | [R12-cardapios-owner](R12-cardapios-owner.md) — Reconciliar R12-38 e reproduzir após abertura explícita da R12. |
| R12-39 | forms.edit, forms.create | [R12-formularios-agenda-owner](R12-formularios-agenda-owner.md) — Reconciliar R12-39, mapear e reproduzir na R12 autorizada. |
| R12-40 | forms.edit, forms.create | [R12-formularios-agenda-owner](R12-formularios-agenda-owner.md) — Reconciliar R12-40, mapear e reproduzir na R12 autorizada. |
| R12-41 | forms.list | [R12-formularios-agenda-owner](R12-formularios-agenda-owner.md) — Reconciliar R12-41, mapear e reproduzir na R12 autorizada. |
| R12-42 | Mapeamento pendente; não criar ID por inferência | [R12-formularios-agenda-owner](R12-formularios-agenda-owner.md) — Reconciliar R12-42, mapear e reproduzir na R12 autorizada. |
| R12-43 | chat.open | [R12-chat-contorno-owner](R12-chat-contorno-owner.md) — Reproduzir contorno no painel/lista/paginação/compositor e comparar referência aprovada. |
| R12-44 | invites.list | [R12-convites-owner](R12-convites-owner.md) — Reconciliar R12-44 e reproduzir na R12 autorizada. |
| R12-45 | invites.resend | [R12-convites-owner](R12-convites-owner.md) — Reconciliar R12-45 e reproduzir na R12 autorizada. |

Responsável funcional: C0 R12. Gate documental não certifica o produto. Perguntas abertas: arquivar originais Coelo; obrigatoriedade dos campos de cadastro sem conta; perfis profissionais no Principal versus spec 018; eventos/destinatários de notificações; precedência de cardápios e preservação de exceções históricas.
