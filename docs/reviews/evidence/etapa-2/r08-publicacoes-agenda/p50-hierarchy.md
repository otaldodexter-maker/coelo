---
source: ADR 0034 P50; production router; circular v2 repository and RPC; R06 route evidence
status: reconciliado-local-green
generated_at: 2026-09-12
---

# P50 — resposta no Superadmin com hierarquia

A rota administrativa de detalhe compoe SuperadminCircularDetailPage com dois caminhos separados:

1. Responder aparece somente para Circular publicada, aberta e quando os repositorios produtivos de leitura/resposta estao compostos. A navegacao hospeda PrincipalCircularReader dentro do shell do Superadmin e conserva a autorizacao server-side do repositorio real.
2. O resumo administrativo chama superadmin_circular_response_summary_v2. A RPC exige circulars.read por superadmin_circular_context, restringe a instituicao resolvida e devolve apenas contagens agregadas; circular inexistente ou fora da hierarquia segue o mesmo caminho indisponivel.

As capturas R06 ui-12 a ui-15 continuam validas para abrir a resposta, enviar e observar o resumo apos reload. A R08 nao promove novo E2E com esta leitura documental; a regressao local do leitor passou no pacote focal de 67 testes.

Fontes de codigo:

- apps/superadmin/lib/app/router/superadmin_router.dart
- apps/superadmin/lib/features/circulars/presentation/superadmin_circular_detail_page.dart
- apps/superadmin/lib/features/circulars/data/supabase_superadmin_circular_repository.dart
- packages/coelo_database/migrations/20260910200100_superadmin_internal_circulars_v2_baseline.sql
- packages/coelo_database/supabase/tests/superadmin_internal_circulars_v2_test.sql
