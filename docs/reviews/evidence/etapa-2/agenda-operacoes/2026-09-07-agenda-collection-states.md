---
title: "Agenda — estados de leitura em Solicitações e Aprovações"
source: "apps/superadmin/lib/features/agenda/domain/agenda_repository.dart"
status: "local-green; E2E aberto"
generated_at: "2026-09-07"
---

As duas telas ignoravam requestsRead e renderizavam coleção vazia em loading,
failure ou unauthorized. Oito REDs confirmaram ausência de estado/retry.
Painel compartilhado do domínio usa CoeloStatePanel para carregamento, negativa,
falha, idle e vazio confirmado. Tabela/paginação não aparecem em non-ready;
retry solicita novamente as duas leituras do canal, sem executar decisão.
Fixtures locais preservadas. Nenhum router, parser, SQL ou comando alterado.

Review encontrou loading sem anúncio; dois REDs adicionais confirmaram. Branch
recebeu Semantics label/liveRegion conforme Calendar. Harness semântico libera
handle em finally antes das invariantes do teste. Review final sem blockers.

Regressão final: 88 testes verdes (repository, Requests, Approvals e estados
remotos). Nove novos casos incluem matriz de 48 configurações: duas superfícies,
quatro larguras, dois temas e três estados; texto200% em375. Quatro goldens novos
de falha inspecionados em375dark/text200 e1440light; nenhuma baseline antiga
alterada. Analyzer e validator visual limpos.

Comando no cwd apps/superadmin: flutter test --no-pub
test/features/agenda/presentation/agenda_remote_states_test.dart
test/features/agenda/presentation/agenda_requests_page_test.dart
test/features/agenda/presentation/agenda_approvals_page_test.dart
test/features/agenda/data/supabase_agenda_repository_test.dart.

Limites: HTTP simulado não prova BD, autorização server-side, persistência ou
reload real. Troca de repository com diálogo de decisão aberto não foi alterada
neste pacote. Nenhum action_id promovido. Memória no-op: aplica estados canônicos.
