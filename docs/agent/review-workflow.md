---
title: "Roteamento de revisões e aceites Coelo"
source: "AGENTS.md; .agents/skills/coelo-flutter-review/SKILL.md; .agents/skills/coelo-supabase/SKILL.md; .agents/skills/coelo-flutter-supabase-review/SKILL.md"
status: "active"
generated_at: "2026-09-14"
updated_at: "2026-09-14"
audience: "team"
---

# Revisões

Escolha o recorte antes de agir:

- `coelo-frontend`: Flutter/Dart ou Astro, sempre com app e superfície;
- `coelo-backend`: Supabase/Postgres/R2/Stream/Workers;
- `coelo-frontend-backend`: quando o aceite atravessa cliente e backend.

O contrato do recorte contém objetivo, incluído, fora de escopo, ordem,
critério de parada, evidências esperadas e tempo estimado. Uma auditoria
documental não certifica runtime, persistência, RLS, reload ou E2E.

Para R13, comece pelo estado atual e pelas pendências R13. Os grandes
rastreadores em `docs/reviews` são detalhe de auditoria; os arquivos em
`docs/reviews/archive` nunca são fila executável.

Ao alterar estado, sincronize inventário e matrizes no mesmo ciclo. Separe
avanço local, FE, BE, E2E, testes executados e testes aprovados. O delivery gate
é obrigatório somente quando o escopo inclui integração/publicação ou entrega
formal; rode `python docs/reviews/delivery_gate.py` após commit/push.
