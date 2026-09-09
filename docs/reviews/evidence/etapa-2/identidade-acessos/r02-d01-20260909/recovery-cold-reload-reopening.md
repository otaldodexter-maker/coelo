---
title: "R02 D00 — reabertura FE do cold reload em recovery"
source: "D01 handoff R9, 2026-09-09T14:06:51-03:00; recovery-cold-reload-red-storage.txt na worktree D01; autorização de retomada D00 pelo Owner"
status: "open-regression"
generated_at: "2026-09-09"
---

apps/superadmin → Auth → Redefinir senha → reinício do cliente durante recovery → auth.reset.

D01 reproduziu com SDK e ConditionalSupabaseLocalStorage/SharedPreferences reais, transporte HTTP sintético e sessão sintética: persist=true permite bootstrap/contexto normal após cold reload; persist=false passou. O log original termina em 1 aprovado e 1 falho. Isso demonstra perda de confinamento no cliente; não demonstra autorização indevida no backend real.

Origem preservada: C:/Users/adrie/Documents/Coelo.worktrees/e2-r02-d01-autenticacao/docs/reviews/evidence/etapa-2/identidade-acessos/r02-d01-20260909/recovery-cold-reload-red-storage.txt. Handoff D01 R9 liga teste, resultado e proposta. D00 não repetiu o teste nesta reconciliação.

O aceite FE auth.reset volta a pending-verification até correção e prova integrada. A composição no mesmo processo anteriormente aprovada permanece como evidência parcial, sem cobrir reinício frio. Auth FE passa temporariamente de 2/4 a 1/4; BE e E2E permanecem pendentes.

Reserva concedida na assignment D01 retomada r8: somente supabase_coelo_auth_gateway.dart e conditional_supabase_local_storage.dart, com testes exclusivos D01. Corrigir persistência/remoção serializada sem criar claim durável de autorização; manter recovery em memória e exigir novo link após reinício. Release por SHA e verificação pertinente na base conjunta. Sem aplicação remota autorizada por este registro.
