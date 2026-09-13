---
source: R12 C0 — R12-16/R12-17/R12-18 child-safety wizard gates
status: diagnostic; contract decisions pending
generated_at: 2026-09-13
---

# R12-16 a R12-18 — gates do wizard de Segurança da criança

Recorte: Etapa 2 → `apps/superadmin` → Segurança da criança → Criar/Editar →
`child-safety.create`, `child-safety.edit`.

R12-16: `SuperadminFormStepNavigation` expõe somente etapas concluídas ou a
etapa atual (`enabled: index <= step`); a regressão existente cobre busca,
seleção, avanço e retorno sem salto inválido.

R12-17: o campo atual é `Identificador da pessoa global` com hint de UUID.
Não foi encontrado reader/contrato de busca por nome, sobrenome, CPF, e-mail,
celular ou `@`; não é seguro trocar para uma busca fake. UUID permanece apenas
como dado técnico até existir consulta autorizada e vínculo real.

R12-18: não há contrato de pessoa global sem conta com campos de nome,
documento, celular/e-mail e deduplicação. A obrigatoriedade/optionalidade e a
verificação precisam de decisão antes de criar tabela, RPC ou formulário.

Prova local: `safety_pages_test.dart` cobre o wizard e estados de permissão;
nenhum SQL, RPC, RLS ou persistência foi alterado neste diagnóstico.

Próximo gate: aprovar contrato de busca/cadastro de pessoa e regras de
opcionalidade; então implementar com minimização, escopo, deduplicação e
auditoria.
