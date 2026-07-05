---
source: "decisions/0011-flutter-routing-performance.md"
status: "implementation-context"
generated_at: "2026-06-30"
---

# Isolates

Helpers para executar computacao pesada fora da thread de UI do Superadmin.

Use para parsing grande, validacoes em massa, filtros custosos, exportacoes e
preparacao de metadados. Nao use dentro de `build` para mascarar widget pesado:
primeiro componentize a tela, reduza rebuilds e use builders/slivers.

Regras:

- Funcoes passadas para `compute` devem ser top-level ou static e receber dados
  transferiveis entre isolates.
- Sempre informe `debugLabel` claro.
- Nao envie secrets, `service_role`, tokens de sessao ou dados sensiveis
  desnecessarios.
- Retorne modelos simples ou DTOs; regra de negocio continua em domain/data.
