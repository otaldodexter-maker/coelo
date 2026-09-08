---
title: "LOC-READADAPTER01 — reader RPC preparado localmente"
source: "docs/superpowers/plans/2026-09-08-location-read-adapter.md; SQL 98d166d2; DTO LOC-DTO01"
status: "local-verified-not-connected-not-e2e"
generated_at: "2026-09-08"
---

# Resultado nominal

SupabaseLocationCatalogReader implementa o reader existente com transporte RPC
injetável e construtor Supabase, usando somente superadmin_location_directory_v2
e superadmin_location_detail_v2. Sem cache, cliente legado, fallback, escrita,
rota, DI, mídia ou conexão remota executada.

Directory envia exatamente scope_kind/institution_id/unit_id/search/limit/offset.
Detail envia somente location_id. UUIDs, limites e busca são verificados antes
do transporte; busca usa trim somente de espaço ASCII, preservando Unicode e
o limite por codepoint. A autorização continua exclusivamente no backend.
Os DTOs existentes verificam envelopes, shape, ID e proprietário. Sete erros
SAI de autorização e Postgrest 42501/PGRST301/PGRST302 viram negação segura;
demais erros viram indisponibilidade sem conservar payload ou mensagem raw.

## Evidência local

- RED inicial observado: compilação falhou pela ausência do adapter/tipo.
  Não se apresenta esse resultado como falha runtime SQL.
- Após implementação, 22 testes PASS; cinco contraprovas adicionais resultaram
  em 27 testes PASS. Busca Unicode máxima, offset 10000, tamanho acima do
  solicitado, falha Postgrest genérica, negação tardia/revisão e revogação
  corrente cobertos. Nenhum endpoint real usado; somente transporte injetado.
- Integração local com controller descarta sucesso antigo após troca de
  proprietário ou perda de sessão; erro antigo após nova revisão não substitui
  sucesso atual; negação atual remove dados carregados.
- Regressão completa test/features/locations: 88 PASS, sem atualizar goldens.
- Analyzer dos dois arquivos nominais: zero issues após três anotações de
  tipo explícitas nos testes. Testes focais repetidos após essas anotações.
- Revisão independente somente leitura: nenhum P1/P2. Dois gates de memória
  PASS. Nenhuma nova regra de produto, portanto sem nova projeção de atividade.

## Próximo gate

Replay SQL autorizado/serializado pelo Engenheiro 1 e apresentação de hunk
nominal de rota/DI à coordenação. Esta fatia não habilita navegação produtiva,
não comprova RLS, persistência, auditoria ou permissão remota e não fecha
nenhum dos sete IDs de Locais como E2E. O restante de Estruturas/Pessoas/Alunos,
transferências e revogações continua no escopo original.
