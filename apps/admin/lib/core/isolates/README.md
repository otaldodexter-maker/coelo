---
source: "decisions/0011-flutter-routing-performance.md"
status: "planning-context"
generated_at: "2026-06-30"
---

# Isolates

Reservado para computacao pesada fora da thread de UI do Admin.

Casos esperados: importacoes CSV/XLSX, parsing grande, validacoes em massa,
filtros custosos e exportacoes. A implementacao concreta deve nascer da spec da
feature que precisar desse trabalho.
