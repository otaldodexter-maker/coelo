---
source: "apps/principal/README.md"
status: "planning-context"
generated_at: "2026-06-22"
---

# Core

Infraestrutura local do Principal: configuracao, guards, bootstrap e
adaptadores que nao pertencem a uma feature unica.

Mantenha este diretorio enxuto para evitar um "core" que vira deposito geral.

`isolates` deve guardar helpers para computacao pesada fora da thread de UI,
como parsing de payloads grandes, preparacao de metadados de midia e filtros
custosos de feed.
