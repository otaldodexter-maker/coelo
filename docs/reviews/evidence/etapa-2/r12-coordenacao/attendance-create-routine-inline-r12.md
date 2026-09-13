---
source: R12 C0 — R12-06 attendance.create / daily-routine.apply
status: local-green; E2E pending
generated_at: 2026-09-13
---

# R12-06 — rotina vinculada na Nova chamada

Recorte: Etapa 2 → `apps/superadmin` → Acompanhamento → Assiduidade → Nova
chamada → Contexto → Chamada → `attendance.create`, `daily-routine.apply`.

O wizard foi reduzido ao fluxo `Contexto → Chamada`. A etapa separada
`Rotina diária` foi removida. Após a seleção de data, turma e atividade, o
contexto informa que a rotina diária vinculada será resolvida pelo contexto
autorizado; não existe controle para trocar a rotina durante o lançamento.
O contrato de criação permanece server-side, incluindo resolução da rotina
efetiva, versão e snapshot.

Evidências locais no checkout `dev`, Windows:

- `flutter test test/features/attendance/attendance_pages_test.dart`: 57 PASS;
- `flutter analyze --no-fatal-infos`: No issues found;
- o teste cobre o estado inicial sem a etapa Rotina diária, lançamento direto,
  duplicidade, bloqueio durante submissão, troca de repositório, erro/retry,
  resposta incompatível e responsividade.

Nenhuma RPC, RLS ou persistência remota foi alterada. O aceite desta fatia é
FE `local-green`; a prova integrada permanece pendente da rota normal, criação
com contexto real, persistência/reload e negativa cross-tenant.

Próximo gate: reproduzir `Nova chamada` pela rota normal com massa autorizada,
confirmar a rotina efetiva e sua versão no servidor, validar snapshot/reload e
provar que um ator fora do escopo não consegue lançar a chamada.
