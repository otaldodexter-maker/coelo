---
title: "E2E5 — feedback de conclusão parcial de Agenda"
source: "agenda_event_form_page.dart; testes de formulário; review agenda_ui_contract"
status: "correção local verificada; protocolo backend continua aberto"
generated_at: "2026-09-07"
---

Recorte: reconhecer falha de operação complementar após save confirmado.
Não redesenha transação, receipt, retry idempotente ou comando server-side.
Ordem: RED de retorno/exception → correção → regressão/review. Parada local:
sem sucesso falso e sem nova gravação cega na mesma instância. Cerca de 6 min.

Quatro RED: ocorrência e solicitação de publicação, cada uma com retorno
unavailable e Exception. Retorno era ignorado e onSaved executava; Exception
perdia a distinção de save já confirmado e deixava repetição disponível.

A conclusão agora verifica cada resultado e interrompe a sequência em falha.
Feedback informa que o evento foi salvo, mas a etapa complementar não pôde ser
confirmada, orientando reabrir e verificar estado. Botões de gravação e callbacks
antigos são bloqueados nessa instância; Cancelar permanece disponível. Não há
retry automático, reprodução da próxima operação ou exposição da Exception.

- Form + management: **31/31 PASS**; depois, quatro casos reforçados com callback
  antigo e Cancelar acionável: **4/4 PASS**.
- Analyzer2 sem issues; visual validator/diff check PASS.
- Review independente sem blocker; sugestões de callback/Cancelar incorporadas.

Essa proteção UI não torna atômico o protocolo backend composto. A exigência da
spec050 de não alterar o agregado em falha permanece gate para sua implementação
server-side; não foi rebaixada para aceitar sucesso parcial como E2E.
Gate de memória no-op: honestidade de estado já exigida, sem decisão nova.
Rastreadores centrais sob writer Coordenador.
