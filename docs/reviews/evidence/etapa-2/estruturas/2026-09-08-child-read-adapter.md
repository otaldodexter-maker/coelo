---
title: "CHILD-READADAPTER01 — adaptador de leitura isolado"
source: "direção da coordenação; docs/superpowers/plans/2026-09-08-child-read-adapter.md; DTO a9a5974"
status: "local-verified-no-http-no-wiring-not-e2e"
generated_at: "2026-09-08"
---

# Resultado

Uma chamada nominal a superadmin_child_context_directory_v2, com request/DTO
existentes. Adaptador stateless, transporte injetável e construtor Supabase
não conectado. Não armazena sessão, cursor, cache ou mensagens de transporte.
Sem retry automático, fallback legado, nova política, grants, SQL ou UI.

RED inicial por ausência do adapter/tipos, seguido de 19 testes PASS.
Com 27 testes do adapter Locais, regressão nominal total46 PASS.
Cobertura: quatro parâmetros exatos/default20, limite1/50, cursor opaco com
Unicode/espaços,8192 bytes exatos/excedente, falha honesta antes do transporte,
shape e instituição divergentes, cursor de saída excessivo, sete negações SAI,
três códigos Postgrest negados, erro inesperado sanitizado, nenhuma leitura
extra, duas chamadas concorrentes com instituições diferentes e retry explícito.

Analyzer dos dois arquivos: zero issues. Revisão independente readonly sem
P1/P2; conferência independente adicional enumerou matriz de request/erros.
Dois gates de memória PASS; no-op de projeção, pois não há comportamento de
produto aprovado novo. Sem mudança visual ou necessidade de novo golden.

8192 permanece limite candidato de transporte, não limite cadastral; o adapter
não trunca nenhum valor. O teste sem HTTP não comprova sessão, RLS, auditoria
ou paginação PostgreSQL. Descarte de resultado tardio/invalidação pertence ao
consumidor futuro. SQL e wiring continuam sujeitos aos gates centrais.
