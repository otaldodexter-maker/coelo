---
title: "R07 — censo final independente do C0"
source: "flutter test da base conjunta2f0a1cfb7 + correcoesC0; reporterJSON gerado na execução"
status: "executado; suite global vermelha com residuos atribuidos"
generated_at: "2026-09-12"
---

# Censo final do Superadmin

Comando (apps/superadmin): `rtk flutter test --no-pub --reporter expanded --file-reporter json:build/r07-c0-final.json`.
Concluído em426.010ms de execução do reporter: **6727PASS,33FAIL,11SKIP**.
6760executados conclusivos,6771incluindo ignorados; aprovação dos conclusivos
99,51%; cobertura executada deste plano descoberto99,84%. Estes percentuais
são de testes, nunca progresso do produto. Não contam outros pacotes.
Sem casos did-not-complete; exit1 esperado pelas33falhas.

Plano integral descoberto da suíte padrão Superadmin, incluindo
test/app,test/core/config,test/shared e todas as famílias. Censoanterior
C0:6726/34/11; contratoRPCresolvido entreexecuções. Não somar reruns.
R05relatou6692/53/11; G8mediu6713/42/11antesdos6ajustesdeRouter.
São bases diferentes e quantidade de testes mudou; não declarar35açõesnovas.

## Falhas por arquivo e dono

| Arquivo | Casos falhos | Dono / primeiro gate |
| --- | --- | --- |
| apps/superadmin/test/app/router/person_detail_golden_test.dart | 2 | G2: Regravação nominalA já autorizada; compararPNGantesdealterar. |
| apps/superadmin/test/app/router/structure_detail_golden_test.dart | 4 | G1: Regravação nominalA já autorizada; compararPNGantesdealterar. |
| apps/superadmin/test/features/activities/presentation/activity_golden_test.dart | 9 | G1: Regravação nominalA já autorizada; compararPNGantesdealterar. |
| apps/superadmin/test/features/help_center/presentation/screens/superadmin_help_center_page_golden_test.dart | 1 | G7: Regravação nominalA já autorizada; compararPNGantesdealterar. |
| apps/superadmin/test/features/health_care/presentation/medication_plan_ui_contract_test.dart | 1 | G3: Defeito real: overflow375/200%; corrigir frame com posse e testar consumidores. |
| apps/superadmin/test/features/institutions/presentation/screens/institution_directory_page_golden_test.dart | 1 | G1: Regravação nominalA já autorizada; compararPNGantesdealterar. |
| apps/superadmin/test/features/invites/invite_golden_test.dart | 1 | G2: Regravação nominalA já autorizada; compararPNGantesdealterar. |
| apps/superadmin/test/features/people/presentation/person_form_page_test.dart | 1 | G2: Expectativa24desatualizada frentea space10=40; conferirP15eajustar. |
| apps/superadmin/test/features/people/presentation/person_golden_test.dart | 1 | G2: Regravação nominalA já autorizada; compararPNGantesdealterar. |
| apps/superadmin/test/features/platform_users/presentation/platform_user_pages_golden_test.dart | 1 | G2: Regravação nominalA já autorizada; compararPNGantesdealterar. |
| apps/superadmin/test/features/principal_circulars/presentation/principal_circular_golden_test.dart | 10 | G6: Aplicar lista nominal1A/3A+/6R; conciliar compositor de teste versus host real. |
| apps/superadmin/test/shared/presentation/widgets/superadmin_form_action_footer_adoption_test.dart | 1 | G1: Defeito real: rodapé canônico do Criar modelo, já autorizado. |

Aprovar um golden não o regrava. As33falhas continuam reproduzidas no censo;
30estão em testes golden,3emcontratos/layout. Não foram escondidas por
skip/allowlist. A correção do contratoRPCdaG8 foi aplicada peloC0 e teve4/4PASS.

## Outras verificações do C0

- flutter analyze --no-pub: sem issues, após remover2imports não usados;
  mudança posterior deRPCsomente removeu lista obsoleta; análise focal final
  do arquivo será registrada no fechamento.
- coelo_api/test/forms:134PASS, pacote separado do censoSuperadmin.
- internal-user-create/cors_test.ts:3PASS.
- circular-media/index_test.ts:25PASS.
- Rodapéadoption: C0removeu exceção indevida de formulário real; falha passa
  a pertencerG1, não indica regressão criada no app.
- Testes anteriores por família estão em verificacao-fechamento.md, sem somar.

RelatóriosJSONbrutos foram preservados fora doGit em
C:/Users/adrie/Documents/Coelo-backups/r07-worktrees-20260912/e2-r07-coordenacao/
(r07-c0-full.json e r07-c0-final.json). Este resumo commitado é a referência
de certificação documental; logs não são expostos como prova pública.
