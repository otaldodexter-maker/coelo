---
title: "Chat — negação do recibo pendente após refresh"
source: "review central P2; SuperadminChatPage; testes locais"
status: "local-green; not-e2e-complete"
generated_at: "2026-09-07"
---

# Recorte e resultado

O review central identificou interação entre negação e refresh: a thread já
estava renderizada, markRead pendente e a inbox atualizava a mesma conversa.
A geração da busca mudava e descartava a negação do recibo ainda relevante.

O catch agora trata autorização pela geração da thread, repository e ID da
conversa atuais. Somente erros de apresentação continuam dependendo da busca.
Nenhum refetch, alteração visual, RPC ou BD foi introduzido.

## Evidências

- RED focal: falhou porque o painel de acesso negado não apareceu após refresh.
- GREEN: 29/29 testes de página, incluindo ausência de refetch, descarte do
  conteúdo privado e negativos de troca de conversa/repository com recibo antigo.
- Analyzer de página e teste: sem problemas. Formatter aplicado.
- Validador administrativo: exit 0, sem alteração de allowlist ou golden.
- Review independente: aprovado no recorte, sem achados acionáveis.

Os nove goldens divergentes da baseline continuam abertos; esta fatia não
promove Chat a verified/E2E. Revogação real, persistência, reload e auditoria
dependem dos gates backend. Gate de memória: no-op; aplica regra de autorização
já aprovada, sem nova decisão de produto.
