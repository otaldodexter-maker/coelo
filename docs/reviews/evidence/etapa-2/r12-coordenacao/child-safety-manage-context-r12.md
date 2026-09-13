---
source: R12 C0 — R12-15 child-safety authorization management
status: local-green; E2E pending
generated_at: 2026-09-13
---

# R12-15 — contexto no gerenciamento de autorização

Recorte: Etapa 2 → `apps/superadmin` → Segurança da criança → Criança →
Gerenciar autorização → `child-safety.child`, `child-safety.edit`,
`child-safety.suspend`.

O diálogo agora apresenta a identidade da criança, instituição/unidade,
relação localizada, capacidades e motivo, além de decisão, ciclo de vida e
validade. Aprovar/Rejeitar continuam exclusivos de solicitações pendentes;
Suspender aparece somente para autorização aprovada e ativa; Editar permanece
condicionado à solicitação pendente e à capacidade de mutação.

Prova local, Windows, checkout `dev`:

- regressão `read-only composition disables edit transition and suspension`:
  1 PASS, incluindo contexto e capacidades no diálogo;
- relação com códigos de domínio tem regressão própria em R12-14;
- contrato, SQL, RPC e RLS não foram alterados.

O aceite FE é local-green. Rota normal, auditoria/retry, reload e negativa
cross-tenant permanecem pendentes de prova integrada.

Próximo gate: executar gerenciamento pela rota normal com estados pendente,
aprovado ativo e suspenso, confirmando ações e escopo do ator.
