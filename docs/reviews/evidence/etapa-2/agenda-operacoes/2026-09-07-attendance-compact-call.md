---
title: "Chamada — navegação e rodapé acessíveis no compacto"
source: "apps/superadmin/lib/features/attendance/attendance_pages.dart"
status: "local-partial; sem promoção E2E"
generated_at: "2026-09-07"
---

# attendance.mark / attendance.finish / attendance.correct — UI

RED existente reproduzido: 375x900/texto200, RenderFlex vertical em
AttendanceCallPage Column linha786, área343x407, overflow11px. Navegação e footer
fixos excediam a altura disponível. Em compacto, ambos agora participam do scroll
da chamada; wide preserva rail/footer. Componentes compartilhados, callbacks,
permissões e bloqueio de comandos não foram alterados.

Baseline: comportamento compacto vigente do SuperadminFormFrame, sem editar
o componente compartilhado. Lista contínua, tokens, alvos e texto preservados.

- 38/38 testes da página, incluindo matriz375/768/1024/1440texto200.
- Dois casos novos comprovam footer/retorno integralmente visível, hit-test,
  callback e possibilidade de rolar de volta, claro/escuro.
- Quatro novas imagens compactas (início/rodapé, claro/escuro) inspecionadas.
- Goldens: três casos passaram (dois novos e desktop antigo); contexto antigo
  de nova chamada375 segue divergente15,84%/53458pixels. Nenhum baseline antigo
  sobrescrito. Esse fluxo não foi editado.
- Analyzer focado limpo; validador de contratos visuais passou sem allowlist.
- Review independente estático sem blockers; erro/inflight permanecem visíveis.

BD nenhum: testes usam fixture. Sem persistência/reload produtivo, tenantA/B
ou promoção de action_id. Exportações reais permanecem pós-MVP e intocadas.
Memória no-op: concretiza responsividade aprovada sem nova regra de produto.
