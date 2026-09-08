---
title: "LOC-READADAPTER01 — transporte de leitura local"
source: "reserva da coordenação em 2026-09-08; LOC-ACL01 98d166d2; LOC-DTO01"
status: "approved-local-implementation"
generated_at: "2026-09-08"
---

# Contrato

Preparar somente adapter de LocationCatalogReader usando os dois readers SQL
v2 e os decoders estritos existentes. Sem HTTP real, cache, nova política,
escrita, rota, DI, mapa, mídia ou vínculos. Sessão/revisão e descarte de
respostas obsoletas continuam no controller; o backend é a autoridade.

1. Testes RED de parâmetros nominais, escopo, paginação, ID, shape e erros.
2. Adapter com transporte RPC injetável para testes e factory Supabase,
   sem fallback legado; não transmitir ator, capability ou claims do cliente.
3. Testes compostos adapter/controller para troca de contexto, revogação e
   respostas atrasadas. Sem tornar teste de transporte uma prova de RLS.
4. Testes focais/regressão Locais, analyzer, revisão independente e evidência.

Arquivos nominais: data/supabase_location_catalog_reader.dart e teste em
test/features/locations, mais este plano e evidência própria. Parada da fatia:
contrato local verificado e handoff; conclusão E2E exige replay SQL aprovado,
integração nominal e provas remotas posteriores. Estimativa 45–90 minutos.
