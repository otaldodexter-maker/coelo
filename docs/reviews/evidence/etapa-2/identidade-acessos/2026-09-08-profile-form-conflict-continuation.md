---
title: "Perfis — continuação do diálogo após descarte do formulário"
source: "RED local; reserva nominal do Coordenador em 2026-09-08; review account_review"
status: "local-green; not-verified-e2e"
generated_at: "2026-09-08"
---

## Recorte e evidência

Somente o retorno do diálogo de conflito no formulário de Perfis/Modelos.
O RED real teve 1 PASS e 1 FAIL: o formulário montado recarregava normalmente;
após seu descarte, confirmar o diálogo ainda disparava outra leitura (2 em vez
de 1). O teste usa repository sintético e não prova autorização remota.

A correção adiciona apenas `if (!mounted) return;` após o diálogo e antes de
`_reloadReferencePreservingDraft`. Não muda payload, commands, request IDs,
callbacks, navegação, regras de conflito ou preservação do rascunho.

Verificações executadas:

- Teste novo `access_profile_form_continuation_test.dart`: 2/2 PASS.
- Teste novo + `access_profile_pages_test.dart` +
  `access_profile_detail_context_test.dart`: 22/22 PASS.
- Analyzer do formulário e teste novo: sem problemas.
- Review independente account_review: aprovado, sem bloqueios estáticos.

Não cobre troca de recurso dentro do mesmo State, cancelamento de RPC já
enviada, backend, produção nem E2E. Os três goldens de Perfis previamente
vermelhos continuam pendentes; não houve rebaseline nem alegação de correção
visual. Gate de memória: no-op, pois restaura comportamento existente e não
introduz decisão de produto. Coordenador recebe o handoff para os rastreadores.
