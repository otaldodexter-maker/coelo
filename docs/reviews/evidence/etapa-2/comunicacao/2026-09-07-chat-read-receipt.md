---
title: "Chat: rejeição de recibo negado no adapter"
source: "Prompt 4; superadmin_chat_mark_read_v2; teste local do adapter"
status: "local-green-partial"
generated_at: "2026-09-07"
---

# Chat — recibos de leitura

Base: `1150ca30cb5fe414bf28b4aadabb3abcc85d4dec`.
Branch: `codex/e2e-comunicacao-midia-principal`.

`markRead` descartava o envelope de retorno da RPC e aceitava HTTP 200 com
`ok:false` como conclusão. Agora passa pelo mesmo decoder das demais ações.
Membership revogada gera `ChatUnauthorizedException`; resposta malformada ou
erro desconhecido gera `ChatFailureException`. Sem mudança de UI/schema/RPC.

Evidência: baseline 7/7; RED 7 aprovados e 2 novos falhando por falso sucesso;
GREEN 9/9 em `flutter test --no-pub
test/features/chat/data/supabase_chat_repository_test.dart`. Analyzer dos dois
arquivos sem issues. Review independente read-only aprovado sem achados;
confirmou envelope de sucesso na migration `20260901101500`, linha 354.

Delta proposto ao Coordenador para `chat.receipts`:

- Front-end anterior `audited`; continua `audited`, com correção parcial local
  comprovada no adapter. Ainda falta UI/recibos completos e regressão integrada.
- Back-end mantém estado anterior: nenhuma operação remota, SQL ou deploy.
- Integração mantém estado anterior: sem prova E2E ou promoção de contador.
- Próximo passo: provar propagação na tela e permitido/negado/revogado/reload.

Gate de conhecimento: no-op; a correção executa a autorização já aprovada,
sem criar regra de produto ou projeção nova. Referência API consultada:
https://supabase.com/docs/reference/dart/rpc.
