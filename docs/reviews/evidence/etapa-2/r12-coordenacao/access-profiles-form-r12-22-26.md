---
source: R12-22/R12-26; R12-perfis-permissoes-owner.md
status: local-green
generated_at: 2026-09-13
---

# R12-22/R12-26 — formulário de perfil

Recorte: `apps/superadmin > Acessos > Perfis e permissões > criar/editar >
Perfil e escopo/rodapé`.

O campo técnico `Código` foi removido da superfície operacional. O contrato
continua preservado: em criação, o código é derivado deterministicamente do
nome; em edição, o identificador carregado continua no payload sem edição
manual. O botão `Continuar` habilitado usa `FilledButton` tanto em criação
quanto em edição, mantendo estados desabilitados distintos.

Evidência: `access_profile_pages_test.dart`, 18 testes PASS, incluindo ausência
do campo na criação e continuidade preenchida na edição. Nenhuma alteração de
grant, RLS ou contrato remoto foi feita; a prova integrada continua pendente.
