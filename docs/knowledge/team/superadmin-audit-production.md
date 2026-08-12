---
title: Auditoria produtiva do Superadmin
knowledge_id: superadmin-audit-production
source: specs/027-superadmin-audit-production.md
status: validated
generated_at: 2026-08-11
audience: team
surfaces: [superadmin, audit]
visibility: internal
review_owner: Coelo Product
---

# Auditoria produtiva do Superadmin

Auditoria é um diretório somente leitura sobre evidências minimizadas em
`audit.audit_logs`. O Flutter nunca consulta o schema diretamente: lista,
detalhe e exportação passam por contratos server-side que revalidam pessoa,
vínculo, capability e escopo em cada requisição.

Cada evento preserva ator e papel/contexto, instituição quando aplicável, ação,
recurso, before/after minimizado, motivo, correlation id, origem, instante e
resultado. Eventos não podem ser editados ou excluídos por papéis de aplicação.
A retenção permanece indefinida até decisão jurídica formal; não existe expurgo
automático.

`audit.read` autoriza consulta. Exportar é uma capability separada,
`audit.export`, exige AAL2 e gera job auditado com CSV/XLSX privado e temporário.
Busca, filtros, ordenação, contagem e cursor são executados no servidor. A lista
não carrega o diff; o detalhe o busca sob demanda para evitar N+1 e exposição
desnecessária.

Na UI, Instituições é a baseline bloqueante. A toolbar mantém busca e filtros à
esquerda e Cards/Tabela + Exportar à direita; tabela, paginação, flyout e estados
reutilizam os componentes administrativos canônicos. Fixtures, métricas
demonstrativas, filtros client-side, hover cinza e widgets Material crus são
proibidos.
