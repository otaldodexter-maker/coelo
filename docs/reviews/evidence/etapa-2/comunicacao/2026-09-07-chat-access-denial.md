---
title: "Chat — invalidação do snapshot privado após negação"
source: "contrato de privacidade e revogação do Coelo; SuperadminChatPage; testes de estado e concorrência"
status: "local-behavior-green; visual-baseline-open; no-e2e-promotion"
generated_at: "2026-09-07"
---

# Correção local

Negação no envio preservava conversa, mensagens, rascunho e compositor ativo.
Negação no recibo escondia a thread atrás de erro genérico, mas mantinha o
snapshot e a geração de envio. Negação na inbox também conservava o rascunho.

Agora os quatro caminhos de negação (inbox, thread, recibo e envio) descartam
o snapshot privado desta página e invalidam as gerações de requisições. Busca,
rascunho, seleção, mensagens, paginação e intenção pendente são descartados.
Respostas antigas não podem restaurar a tela. Erros transitórios preservam o
retry idempotente e o rascunho como antes.

Somente o estado contextual de acesso negado já existente é reutilizado:
nenhuma nova composição, token, shell ou componente visual foi criado.
Isto não revoga sessão no backend nem cancela uma requisição já transmitida.

## Verificações

- RED: 18 testes anteriores passaram, 3 novos falharam por ausência do estado
  de negação ou rascunho privado ainda presente.
- GREEN inicial: 21/21. Acrescentadas duas regressões (thread negada e inbox
  tardia após negação); suíte da página: 23/23.
- Suíte completa Chat: 56 passaram e 9 goldens de página falharam.
- Controle da baseline: removida temporariamente apenas a alteração local da
  página por `apply_patch`; confirmado diff vazio desse arquivo contra HEAD;
  os mesmos 9 goldens falharam. Patch restaurado imediatamente. Exemplos de
  diferenças idênticas: light 375 = 12200 pixels; light 768 = 30767 pixels;
  light/dark 1024 e 1440 = 1849 pixels. Portanto esse delta não originou as
  diferenças observadas, mas a certificação visual permanece aberta.
- Nenhum golden foi atualizado. Artefatos `failures` não são referências.
- Análise estática dos dois arquivos: sem problemas. Formatter executado.
- Validador visual administrativo: passou com raiz do repositório e
  `apps/catalog/assets/admin-visual-contract-allowlist.json`.
- Review independente: aprovado, sem achados acionáveis no recorte.

## Handoff

- Branch `codex/e2e-comunicacao-midia-principal`; base
  `1150ca30cb5fe414bf28b4aadabb3abcc85d4dec`.
- Arquivos: `superadmin_chat_page.dart` e `superadmin_chat_page_test.dart` nas
  pastas existentes de apresentação do Chat do Superadmin.
- `chat.list`, `chat.open`, `chat.send`, `chat.receipts`: comportamento de
  negação local corrigido; não promover Front-end para verified.
- Back-end e integração não mudaram; sem execução ou escrita remota.
- Restam refresh da mesma conversa com nova permissão, baseline visual e
  negativos/persistência/reload/E2E reais aplicáveis.
- Gate de memória: `no-op`; implementação de privacidade já aprovada, sem
  nova decisão de produto ou projeção de conhecimento.
