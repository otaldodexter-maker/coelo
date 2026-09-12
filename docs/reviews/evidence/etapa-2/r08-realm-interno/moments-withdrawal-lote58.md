---
title: "R08 G5 — retirada de Momentos e lote 58"
source: "G4 smoke API produtivo; migrations 171600/130300/130400; candidato 140550; recibos G0/C0"
status: "api-producao-aprovada-ui-e2e-pendente"
generated_at: "2026-09-12T13:15:00-03:00"
---

# Retirada de Momentos — defeito medido e correção mínima

`apps/superadmin → Coelo (Principal) → Momentos → publicação própria → moments.remove`.

O smoke API do G4 publicou e leu o PNG privado, mas `withdraw_moment` retornou
403 para o mesmo autor Owner com `p_expected_version=null`, forma aceita pelo
contrato. A publicação `bd9f2361-548f-44f8-a595-fddec3ff1396` e o ativo
`6f8f9fc8-215a-4e07-8b7f-583d210215c7` foram preservados.

## Causa

- `20260910171600` semeou o `institution_admin` com todas as permissões então existentes;
- `20260911130300` criou depois `moments.publications.remove`, sem grant ao papel;
- `20260911130400` só sincroniza permissões `%.read` no `institution_reader`;
- `withdraw_moment` exige `moments.publications.remove`;
- `list_visible_moments.can_withdraw` considerava somente autoria, não a mesma capacidade exigida pelo comando.

O preflight read-only do C0 em produção às 12:37 BRT confirmou exatamente um
template `institution_admin` ativo, uma permissão remove ativa, zero grants
remove para `institution_admin` e `institution_reader`, e ledger 140550 ausente.

## Candidato e ordem

1. `20260912140550_moments_withdraw_permission_v1.sql`, SHA-256 `9356f5e52c8d14b0c628540eceee35231c6baf0044efee04ac71c6f23d69a996`;
2. o C0 promoveu como lote 58 às 12:49 BRT, após backup e composição;
3. a pós-prova reutiliza a publicação preservada do G4, sem DELETE físico.

O delta concede remove somente ao template global `institution_admin` e torna
`can_withdraw` conservador (`autoria AND has_institution_permission(remove)`).
Não concede remove ao `institution_reader`, não muda outros papéis e não relaxa
a reautorização do RPC.

## RED/GREEN no espelho

G5 preparou os testes e não executou pgTAP nem aplicou SQL. O G0 executou:

- RED sem 140550: behavior plan 11, 4 ok e 7 not ok, `ROLLBACK`, native 0, wrapper 1;
- aplicação 140550 somente no baseline: `COMMIT`, native 0;
- GREEN: focal 4/4, behavior 11/11, regressões 23/23 e 30/30;
- total único final 68/68, `finish`/`ROLLBACK`, native/wrapper 0.

A prova comportamental usa os templates reais e nunca concede remove pela
fixture. Ela cobre administrador autor (hint, retirada, replay, feed e audit),
outro autor, autor reader sem capacidade e administrador de outro escopo.

## Produção e replay funcional

O C0 aplicou o lote 58 às 12:49 BRT, `exit 0`, com ledger 140550 na mesma
transação. A pós-prova às 12:49:45 confirmou grant único `allow/active` para o
template global `institution_admin`, nenhum grant ao `institution_reader`,
hint consultando a capability, `authenticated EXECUTE=true` e `anon=false`.
O recibo central é o commit `33dae9ab2`; backups e hashes ficam registrados
somente nessa evidência central, sem duplicar caminhos privados neste arquivo.

No replay produtivo do G4, a retirada da mesma publicação passou e o reload do
feed não a listou. A leitura pelo próprio autor continuou 200, coerente com o
ramo autoral de `authorize_moments_media_read`; portanto a antiga expectativa
403 do harness não demonstra novo defeito. A consulta read-only posterior com
`qa-r06-realm` negou o mesmo asset com 403 e encerrou a sessão local com 204.
A prova foi publicada por G4 em `3f664595a` e integrada pelo C0. Ela comprova o
contrato API em produção, mas não é cross-tenant (ambas as contas são
Owner/platform) nem UI/E2E.
