---
fonte: revisao G6 de9863512b9; autorizacao C0; baseline get_profile_about
status: local-green
data_geracao: 2026-09-12
---

# Perfil — sujeito da resposta e mudança de papel

apps/superadmin → Coelo → Perfil → Editar → principal.profile-edit.
C0 autorizou dois achados da revisão G6: resposta plana não podia ser relabelada
com sujeito pedido quando subject_type/id divergiam; didUpdateWidget precisava
invalidar draft também na mudança isolada de roleCode ou scopeKind.

Correção mínima: parser compara tipo e ID exatos antes de criar a página;
FormatException segue o mapeamento existente para Unavailable, sem fallback de
autorização. Contexto inclui papel e tipo de escopo nas comparações de recarga.
Nenhum actor inventado no DTO, contrato oficial/H02 ou backend alterado.

Base68a0464fb. RED focal: 6 falhas esperadas/native1 (4 parser +2 widget),
sem erro de compilação. GREEN dos dois arquivos completos: 43PASS/0FAIL/0SKIP,
native0 (6novos+37existentes; não somar reruns). Analyze dos4arquivos: zero/native0.
Logs: profile-subject-red.jsonl, profile-subject-green.jsonl,
profile-subject-analyze.log. Testes de versão sem sujeito foram ajustados para
continuar isolando versão inválida, sem mascarar a asserção pelo novo guard.

Slot C0 cedido após G3, devolvido13h37. Não há runner G4 ativo. FE local-green;
nenhuma promoção BE/UI/E2E/cross-tenant e nenhuma nova fixture remota.
Memória: nenhuma regra nova, apenas cumprimento do contrato existente.
