---
title: "Circulares — reconciliar rascunho após resposta perdida"
source: "controller Circular; contrato save_draft v2; testes locais e review independente"
status: "local-green; not-e2e-complete"
generated_at: "2026-09-07"
---

# Recorte

Superadmin, Circulares criar/editar/salvar. O controller compartilhado com a
prévia do menu Principal pertence ao próprio app Superadmin; nenhum outro app
foi alterado. Nenhuma mudança em layout, RPC, migration ou produção.

Cada retry de save antes criava uma chave idempotente nova. Se a resposta se
perdesse depois da persistência, o cliente ainda teria ID vazio e tentaria
criar outro rascunho, podendo colidir com IDs dos blocos já persistidos.

O controller mantém intenção, snapshot e chave após CircularUnavailable;
reconcilia o receipt antes de salvar novas edições e compartilha uma chamada
save em voo. Falhas determinísticas tipadas liberam a intenção. Publish
continua tendo chave distinta do save.

## Verificação

- RED: três falhas comportamentais — duas colisões na recriação e duas
  chamadas concorrentes onde era esperada uma. Um erro inicial de posição
  de imports no teste foi corrigido antes dessa reprodução.
- GREEN: 9/9 no controller, incluindo publicação após save ambíguo e
  liberação da intenção após erro determinístico.
- Regressão: 68/68 não-golden de circulars e principal_circulars no Superadmin.
- Analyzer dos dois arquivos: sem problemas; formatter e diff-check.
- Review independente read-only review_chat_receipt: sem achado acionável.

Fixture stateful compara o payload do replay, IDs, versões e número de
criações. Isso é prova local, não persistência remota. Retry de resposta
perdida do próprio publish e callbacks após dispose continuam fora deste
delta; backend, autorização negativa, reload real, mídia e E2E seguem abertos.

Gate de memória: no-op; idempotência já pertence ao contrato aprovado, sem
nova decisão de produto.
