---
title: "Atividades — negação imediata no diretório"
source: "apps/superadmin/lib/features/activities/presentation/activity_directory_view_model.dart"
status: "local-partial; sem promoção E2E"
generated_at: "2026-09-07"
---

# activities.list — Passo 3–6/6 da fatia local

Problema reproduzido em quatro REDs: negação de página ou opções deixava
loading/snapshot anterior enquanto o outro RPC permanecia pendente.
Future.wait agora encerra antecipadamente somente para autorização negada;
exceções genéricas seguem capturadas, sem vencer negação posterior.
Página e todas as opções são limpas pelo catch existente com generation guard.

Seis casos novos cobrem negação em ambas as posições, sibling tardio com sucesso
ou falha, negação obsoleta após filtro autorizado e dispose. Os testes não
aguardam o sibling para afirmar limpeza e término do retry.

19/19 testes de domínio/ViewModel/ordenação e 20/20 testes da página passaram;
analyzer focado limpo.
Review independente estático sem achados acionáveis. Sem mudança visual,
contrato remoto ou nova regra de produto; memória no-op.
Nenhum BD executado, nenhum action_id promovido. SQL A01 está na fila serial
para RED pelo Eng1; persistência e prova E2E continuam abertas.
