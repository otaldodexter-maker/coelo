---
source: R12 C0 — R12-05 attendance.create context verification
status: local-green; E2E pending
generated_at: 2026-09-13
---

# R12-05 — contexto da Nova chamada

Recorte: Etapa 2 → `apps/superadmin` → Acompanhamento → Assiduidade → Nova
chamada → Contexto → `attendance.create`.

O fluxo atual apresenta a cascata Instituição → Unidade → Turma, com Contexto
Turma/Atividade e campo de atividade dependente quando aplicável. Data,
atividade elegível, rotina diária vinculada, estado vazio/erro, foco,
responsividade e bloqueio durante submissão estão cobertos. O repositório
server-side continua responsável por derivar e revalidar escopo/capacidade;
nenhuma opção cliente foi promovida a autorização.

Prova local, Windows, checkout `dev`:

- `flutter test test/features/attendance/attendance_pages_test.dart`: 58 PASS;
- inclui opções de contexto, atividade prefill, data antiga, troca de
  repositório, negação, duplicidade, erro/retry, foco, overflow e text scale.

Nenhum código, RPC, RLS ou dado remoto foi alterado nesta verificação. O
aceite desta fatia é FE `local-green`; a prova integrada permanece pendente de
rota normal, CRUD/reload e negativa cross-tenant com massa autorizada.

Próximo gate: reproduzir pela rota normal com contexto real, confirmar que só
atividades configuradas para chamada aparecem e validar persistência/reload e
escopo por ator.
