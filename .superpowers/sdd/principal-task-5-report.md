---
source: "specs/050-principal-ui-ux-closure.md"
status: "in-progress"
generated_at: "2026-09-01"
---

# Task 5 — Composição real Principal

## Resultado parcial

- `/principal-happens`, `/principal-happens/publish`, `/principal-now`,
  `/principal-now/publication` e `/principal-moments/publish` foram separados
  das rotas fake `/dev`.
- A composição recebe repositories Supabase pelo `SuperadminAuthScope`,
  `SuperadminApp`, `main.dart` e router.
- O contexto é derivado pelo ator autenticado; IDs de tenant/instituição não
  são aceitos pela URL nem escolhidos pelo cliente.
- A rota real de Acontece usa dados-base vazios e o feed remoto, sem herdar
  `PrincipalHappensPreviewData.demo`.
- O launcher de mensagens reutiliza `/communication/conversations`.
- O publicador real de Momentos possui host próprio que cria e descarta o
  controller de produção, sem usar o controller demo.

## Backend local

A migration `20260901161700_principal_runtime_contexts.sql` cria
`list_my_principal_contexts()` sem parâmetros, com `SECURITY DEFINER`,
`search_path` vazio, identidade derivada de `auth.uid()`, vínculos ativos e
grants apenas para `authenticated`. O pgTAP contém 13 asserts de autenticação,
revogação e isolamento entre instituições.

## Evidências

- 5 testes Flutter/Dart focados passaram.
- Analyzer dos arquivos afetados: `No issues found!` antes da ampliação de Agora.
- `git diff --check`: limpo.
- O replay SQL segue bloqueado por outro replay Supabase local em execução; não
  houve tentativa de mutação remota por orientação da coordenação.

## Pendências

- Reexecutar pgTAP assim que o lock local for liberado.
- Completar Momentos, Para Você, Perfil, Circulares e Chat tipado nas rotas reais.
- Implantar migrations/Edges faltantes no ambiente remoto somente após release
  da coordenação.
- Provar permitido, negado, revogado, cross-tenant, persistência e reload E2E.

## Classificação

Flutter real: parcial. Supabase: local-green parcial, com replay pendente.
Integração E2E: aberta. Nenhuma parte deste relatório equivale a implantação
remota concluída.
