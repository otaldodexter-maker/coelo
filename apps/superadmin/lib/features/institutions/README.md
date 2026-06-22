---
source: "docs/product/prd-superadmin.md; docs/contexts/superadmin-context.md"
status: "planning-context"
generated_at: "2026-06-22"
---

# Institutions

Contexto de ativacao e gestao de instituicoes/tenants no Superadmin.

Primeira fatia guiada prevista:

- listar instituicoes;
- criar nova instituicao;
- definir status/plano manual inicial;
- preparar vinculo de owner inicial;
- registrar intencao de auditoria.

No primeiro ciclo, dados podem ser mock/local. Dados reais exigem auth,
server-side adequado, RLS e audit logs.
