---
source: "apps/admin/README.md"
status: "planning-context"
generated_at: "2026-06-22"
---

# Core

Infraestrutura local do app Admin: configuracao, guards, bootstrap e
adaptadores que nao pertencem a uma feature unica.

`isolates` deve guardar helpers para computacao pesada fora da thread de UI,
especialmente importacoes, parsing grande, validacoes em massa e exportacoes.
