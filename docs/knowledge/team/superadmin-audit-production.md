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
e detalhe passam por contratos server-side que revalidam pessoa, vínculo,
capability e escopo em cada requisição. Exportação real está fora do MVP pela
ADR 0031; o botão permanece visível com mensagem de disponibilidade futura.

Cada evento preserva ator e papel/contexto, instituição quando aplicável, ação,
recurso, before/after minimizado, motivo, correlation id, origem, instante e
resultado. Eventos não podem ser editados ou excluídos por papéis de aplicação.
A retenção permanece indefinida até decisão jurídica formal; não existe expurgo
automático.

`audit.read` autoriza consulta. `audit.export` permanece como capability de
contrato futuro, mas não gera job, CSV ou XLSX durante o MVP.
Busca, filtros, ordenação, contagem e cursor são executados no servidor. A lista
não carrega o diff; o detalhe o busca sob demanda para evitar N+1 e exposição
desnecessária.

Na UI, Instituições é a baseline bloqueante. A toolbar mantém busca e filtros à
esquerda e Cards/Tabela + Exportar à direita; tabela, paginação, flyout e estados
reutilizam os componentes administrativos canônicos. Fixtures, métricas
demonstrativas, filtros client-side, hover cinza e widgets Material crus são
proibidos.
