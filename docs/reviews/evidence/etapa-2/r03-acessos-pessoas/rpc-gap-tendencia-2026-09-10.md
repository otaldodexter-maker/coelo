---
title: "A lacuna entre cliente e producao esta aumentando"
source: "Dois dumps schema-only do projeto de producao (evvbomzejfijozbtgvpt) em 2026-09-10, com cerca de tres horas de intervalo; varredura de client.rpc em apps/superadmin/lib antes e depois do rebase em dev"
status: "measured"
generated_at: "2026-09-10"
timezone: "America/Sao_Paulo"
author: "Rodada 3, grupo acessos-pessoas"
---

# A lacuna esta aumentando, nao diminuindo

## O numero

Medi a mesma coisa duas vezes no mesmo dia, com cerca de tres horas entre uma e
outra. Entre as duas medicoes a minha branch foi rebaseada em `dev`, incorporando
o trabalho das outras frentes.

| | 1a medicao | 2a medicao | delta |
| --- | --- | --- | --- |
| RPCs distintas chamadas pelo cliente | 162 | 189 | **+27** |
| Existem em producao | 66 | 66 | **0** |
| **Ausentes em producao** | 96 | **123** | **+27** |
| Migrations necessarias | 36 | 45 | +9 |

O cliente ganhou 27 chamadas novas. Producao ganhou **zero** funcoes novas.
Cada chamada nova nasceu ausente.

## As 27

`attendance_reserve_idempotency_key`, `meal_plan_archive`,
`superadmin_account_email_change_cancel`, `superadmin_account_profile_get`,
`superadmin_account_profile_save`, `superadmin_circular_delete_v2`,
`superadmin_health_care_directory`, `superadmin_health_care_profile_detail`,
`superadmin_health_care_save_profile`, `superadmin_medication_plan_detail`,
`superadmin_medication_plan_directory`, `superadmin_medication_plan_save`,
`superadmin_routine_application_detail`, `superadmin_routine_correct_launch`,
`superadmin_routine_directory`, `superadmin_routine_launch_detail`,
`superadmin_routine_model_detail`, `superadmin_routine_publish_launch`,
`superadmin_routine_revert_application`, `superadmin_routine_save_application`,
`superadmin_routine_save_launch_draft`, `superadmin_routine_save_model`,
`superadmin_support_create`, `superadmin_support_get`, `superadmin_support_list`,
`superadmin_support_reply`, `superadmin_support_set_status`.

Sao de Rotina, Saude e Medicacao, Suporte, Conta, Assiduidade, Cardapios e
Circulares. Nenhuma e do meu recorte; isto nao e critica a frente nenhuma.

## O que producao ganhou de fato

Producao nao ficou parada: `units_rpcs_versioned_from_production_v1` foi aplicada
e o efeito esta no dump — tres `REVOKE ALL ... FROM PUBLIC` novos, em
`app_private.change_unit_handle_for_superadmin`,
`app_private.request_unit_type_for_superadmin` e
`app_private.transfer_unit_institution_for_superadmin`. E endurecimento de
privilegio, nao funcao nova, e por isso nao aparece na contagem acima.
`meal_plans_owner_permission_grants_v1` mexe em concessoes, que sao dados.

Registro isso porque a leitura preguicosa do numero seria "nada foi aplicado", e
nao e verdade.

## Por que isso importa

A meta declarada e mostrar o app funcional a um cliente. Enquanto a fila SQL fica
retida, cada hora de trabalho de Front-end **aumenta** a divida em vez de
reduzir: o cliente passa a chamar mais funcoes que nao existem. A regua do MVP
exige que a rota normal abra, e ela nao abre.

Isso nao e argumento para o Front-end parar. E argumento para a fila andar: com a
P1 respondida (dump logico no lugar do PITR), o gargalo que segurava as 45
migrations deixou de existir.

## Limites desta medicao

- Compara **nomes** de funcao. Uma funcao presente com corpo divergente conta
  como existente.
- A 2a medicao inclui o cliente inteiro apos o rebase, entao parte do crescimento
  e simplesmente trabalho que eu ainda nao enxergava, nao necessariamente escrito
  nessas tres horas.
- Nao cobre as funcoes de `app_private`, que o cliente nao chama.
