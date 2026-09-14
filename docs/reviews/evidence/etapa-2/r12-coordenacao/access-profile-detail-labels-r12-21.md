---
source: R12-perfis-permissoes-owner.md; access_profile_detail_page.dart
status: local-green; rota normal e golden pendentes
generated_at: 2026-09-14
---

# R12-21 — detalhe com hierarquia e rótulos de produto

Em `apps/superadmin > Acessos > Perfis e permissões > Detalhe`, o resumo e as
permissões configuradas mantêm a hierarquia em cartões, traduzem módulos,
telas e ações para os rótulos de produto e preservam o código técnico apenas
fora do texto principal. As ações específicas `próprias` e `todas` continuam
distintas. Não houve alteração de autorização, grants ou contrato backend.

A suíte de páginas de Perfis passou 17/17 e `flutter analyze` do detalhe PASS.
FE local-green; rota normal, reload, golden aprovado e negativa cross-tenant
continuam pendentes.
