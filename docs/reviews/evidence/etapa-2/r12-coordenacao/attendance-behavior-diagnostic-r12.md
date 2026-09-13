---
source: R12 C0 — R12-08 attendance behavior diagnostic
status: local-green; E2E pending
generated_at: 2026-09-13
---

# R12-08 — comportamento da chamada

Recorte: Etapa 2 → `apps/superadmin` → Assiduidade → Chamada →
`attendance.mark`, `attendance.correct`, `attendance.finish`,
`daily-routine.apply`.

O relato do Owner pede reproduzir salvar, editar, adicionar sentimento depois
do primeiro lançamento, exibir campos da rotina, concluir e recarregar. A
suíte local existente cobre esses caminhos com repositório sintético: cada
participante é salvo explicitamente, alterações preservam o draft em erro,
retry funciona, sentimento permanece local até o save, rotina pendente é
renderizada/expandida e conclusão fica bloqueada enquanto há pendência.

Prova local, Windows, checkout `dev`:

- `flutter test test/features/attendance/attendance_pages_test.dart`: 57 PASS;
- `flutter analyze --no-fatal-infos`: No issues found;
- inclui save por participante, correção, erro/retry, troca de repositório,
  resposta incompatível, sentimento e rotina pendente.

Não foi possível certificar aqui a reprodução pela rota normal com massa
remota real, nem afirmar causa de backend/RLS a partir do relato. Nenhum SQL,
RPC ou contrato remoto foi alterado. O apontamento continua aberto para
prova integrada com múltiplos alunos/turmas, rotina vinculada, reload e
negativa cross-tenant.

Próximo gate: executar a massa sintética autorizada pela rota normal, registrar
payload/versão/resultado de cada operação e confirmar persistência após reload.
