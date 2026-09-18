---
title: "Respostas — confirmação perdida e retry idempotente"
source: "Spec Forms aprovada; revisão read-only de FormResponsePage; contrato request_id/expected_version existente"
status: "executing-local-bugfix"
generated_at: "2026-09-08"
---

Objetivo: corrigir retry que cria novo request após o backend confirmar uma
mutação e a resposta de rede se perder. Inclui salvar, enviar e reabrir edição
na superfície atual; não altera backend, realm, mídia, anonimato, rotas ou
replay SQL. Estimativa local 25–45 minutos, sem ETA E2E.

1. Fake persiste receipt/versão e lança unavailable; RED exige mesma operação,
   comando, versão esperada e payload no retry.
2. Reter intenção até confirmação ou negativa definitiva de validação/conflito;
   não trocar operação em comando pendente. Preservar revisão local posterior
   em save, mantendo resumo de envio fiel ao receipt como no contrato anterior.
3. Invalidar pendência na troca do contexto, sem deixar callback antigo atuar.
   Mensagem de erro também aparece no estado submitted ao reabrir edição.
4. Review, regressões, analyzer, evidência da frente e handoff central.

Gate: testes locais não comprovam entrega E2E; composição nominal de respostas,
persistência real e segurança integrada permanecem abertas.
