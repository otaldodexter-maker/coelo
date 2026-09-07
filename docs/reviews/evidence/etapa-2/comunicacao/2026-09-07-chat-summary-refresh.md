---
title: "Chat — atualização da permissão na conversa já selecionada"
source: "SuperadminChatPage; ChatConversationSummary; testes de concorrência e refresh"
status: "local-green; no-backend-or-e2e-promotion"
generated_at: "2026-09-07"
---

# Correção

Ao receber nova inbox com o mesmo ID da conversa aberta, a página retornava
antes de incorporar `isReadOnly`, título e contexto atualizados. O compositor
podia permanecer disponível apesar da summary mais recente ser somente leitura.

O caminho rápido agora valida a geração da busca e incorpora a summary. A
thread e a intenção idempotente em andamento são preservadas. Não refaz consulta
da thread, não interrompe envio já solicitado e não duplica envio durante
refresh. A conclusão pendente também não restaura a summary antiga/gravável.
O servidor continua reautorizando toda escrita; o estado visual não concede
permissão.

## Verificação

- RED: 23 testes passaram e 3 novos falharam porque o cabeçalho mantinha a
  summary antiga após refresh.
- GREEN: 26/26 testes da página. Novos casos: readonly após refresh; refresh
  durante envio com readonly falso; refresh durante envio com readonly true.
- Analyzer dos dois arquivos sem problemas; formatter aplicado.
- Validador administrativo passou sem alterar allowlist ou referências.
- Review independente aprovado, sem achados acionáveis.
- A baseline golden de Chat permanece aberta conforme evidência
  `2026-09-07-chat-access-denial.md`; não foi atualizada neste pacote.

## Handoff

`chat.list`, `chat.open`, `chat.send`: melhoria local de estado Flutter, sem
promoção para Front-end verified ou E2E. Nenhum BD foi executado ou alterado.
Restam os gates reais de escopo/tenant, readonly/revogação, persistência,
idempotência, auditoria e reload. Branch
`codex/e2e-comunicacao-midia-principal`, base
`1150ca30cb5fe414bf28b4aadabb3abcc85d4dec`.

Gate de memória: `no-op`; preserva comportamento de autorização já aprovado.
