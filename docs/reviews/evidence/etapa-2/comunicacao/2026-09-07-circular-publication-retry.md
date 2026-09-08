---
title: "Circulares — recuperar publicação sem reenviar outra intenção"
source: "SQL v2 de Circulares; diagnóstico e review independentes; TDD local"
status: "local-green; not-e2e"
generated_at: "2026-09-07"
---

# Causa e correção

Antes, retry de publish executava save com versão anterior ao publish já
persistido. O SQL `20260901191921_superadmin_internal_circulars_v2.sql:471`
consulta receipt antes de conferir versão, mas o cliente não preservava a
chave original. Agora retém ID/versão/chave/horário e recupera o receipt antes
de nova mutação; publicação concorrente equivalente compartilha uma operação.
Save concorrente ou durante ambiguidade é recusado sem RPC adicional.

Edição posterior ou horário diferente no retry não altera o comando original.
O receipt é reconciliado preservando conteúdo local; feedback informa que as
alterações ainda não foram publicadas e exige ação explícita nova. As duas
páginas do Superadmin não disparam onPublished nesse caso. Rejeição
determinística libera pending; CircularUnavailable conserva a intenção.

## Evidência em 2026-09-07, cerca de 21:39 BRT

- RED: seis falhas de retry/concurrency; depois um RED de busy durante edição.
- UI RED: quatro mensagens ausentes antes das duas novas variantes de texto.
- GREEN: **79/79** Circulares + principal_circulars sem arquivos golden.
- Focal controller 16/16 e widget recuperação 4/4; incluídos nos 79, não somar.
- Analyzer cinco arquivos sem apontamentos após corrigir braces da fixture.
- Formatter e validador visual bloqueante do catálogo: exit 0.
- Reviewer read-only review_chat_receipt aprovou retry/concurrency/feedback.

O primeiro teste busy abortava a asserção antes de liberar a Future sintética;
o processo próprio foi interrompido e a fixture ajustada para liberar/aguardar
antes da asserção. O RED busy=false já estava observado. Nenhum processo
Docker ou de outra frente foi alterado.

## Limites

Nenhum SQL, Supabase, R2 ou Stream executado. Hash/replay SQL apenas
inspecionado, sem alegar validação integrada. Goldens não atualizados.
O callback opcional de agendamento ainda pode concluir enquanto há publicação
em voo; host produtivo atual não o injeta. Dispose tardio também fica fora
desta fatia. Não promover tela/action_id a verified/done/verified-e2e.

UI preserva o feedback e composição existentes; sem novo widget, token,
diálogo ou mudança de baseline. Memória no-op: correção de idempotência já
prevista, sem nova política de produto aprovada.
