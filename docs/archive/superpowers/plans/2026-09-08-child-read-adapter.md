---
title: "CHILD-READADAPTER01 — transporte isolado"
source: "direção da coordenação em 2026-09-08; CHILD-READ01 a9a5974"
status: "approved-local-preparation-no-http-no-wiring"
generated_at: "2026-09-08"
---

# Contrato da fatia

Adaptador stateless para a assinatura candidata de diretório infantil,
reutilizando request/DTO e padrão nominal de Locais. Sem controller, UI, Auth,
framework, SQL, grants, HTTP real, DI ou router. Nenhum fallback legado.

1. RED de transporte ausente: parâmetros/defaults/cursor, negações, limite e
   envelope estrito, isolamento entre chamadas independentes.
2. Implementar uma chamada RPC injetável; mapear falhas a tipos seguros,
   sem armazenar mensagem/payload ou cursor em cache.
3. Regressão nominal, analyzer, review readonly, memória e commit testado.

8192 é orçamento candidato UTF-8 de transporte; nunca truncar nomes ou
promover essa restrição a limite cadastral. Parada local: adapter revisado e
testado; SQL/wiring dependem dos gates centrais. Checkpoint03:20 permanece.
Estimativa30–45min, sem promessa de conclusão do diretório ou E2E.
