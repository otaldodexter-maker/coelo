---
source: "decisions/0011-flutter-routing-performance.md"
status: "planning-context"
generated_at: "2026-06-30"
---

# Isolates

Reservado para computacao pesada fora da thread de UI do Principal.

Casos esperados: parsing de payloads grandes, filtros de feed, preparacao de
metadados de midia e transformacoes locais que possam causar jank. A
implementacao concreta deve nascer da spec da feature que precisar desse
trabalho.
