---
title: "Diretório de Convites do Superadmin"
knowledge_id: "superadmin-invites-directory"
source: "docs/superpowers/checkpoints/2026-08-04-superadmin-invites-ui-handoff.md"
status: "validated"
generated_at: "2026-08-28"
audience: "team"
surfaces: [superadmin, convites, diretorio]
visibility: "internal"
review_owner: "Coelo Product e Design"
---

# Diretório de Convites do Superadmin

O diretório de Convites segue a baseline de Instituições: cards são a visão
inicial e a tabela redimensionável é uma alternativa acessível pelo toggle
compartilhado. Em largura compacta, os cards formam uma coluna e evitam exigir
rolagem horizontal para a leitura primária. Busca, filtros e flyout de ações
continuam disponíveis nas duas visões.

Cards usam 11 itens por página, colunas próximas de 340 px e indicador de status
expansível; a tabela usa 8 itens por página e chip de status. Com callback real,
o card de criação permanece junto aos estados vazio, sem resultado e erro
recuperável. Sem callback ou em acesso não autorizado, criar fica ausente.

Revogar mantém confirmação negativa; reenviar pode apresentar um link de uso
único. Dialogs, links, feedback e comandos pertencem ao repository/contexto que
os iniciou. Ao trocar o repository, a tela cancela o debounce, invalida loads e
comandos, fecha overlays próprios e limpa busca, filtros, paginação, busy,
ledger e dados anteriores antes de carregar o novo contexto.

Essas garantias são locais ao Flutter. Capability autoritativa, RLS,
persistência produtiva, entrega por provedor, auditoria remota e validação
cross-tenant permanecem contratos server-side e não são comprovados pelo
preview ou pelos testes non-golden.
