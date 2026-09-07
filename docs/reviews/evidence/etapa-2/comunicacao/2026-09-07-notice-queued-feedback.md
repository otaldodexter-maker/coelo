---
title: "Avisos — feedback de publicação enfileirada"
source: "contrato N01; NoticeFormPage; status retornado pelo repository; testes Flutter"
status: "focal-local-green; baseline-mobile-failures-open; not-e2e-complete"
generated_at: "2026-09-07"
---

# Recorte

O formulário anunciava Aviso publicado mesmo quando o servidor retornava
scheduled. Agora apresenta Publicação agendada nesse caso e mantém a mensagem
anterior para active. Usa o status autorizado, sem inferência pelo relógio.
Controller e adapter já aceitam scheduled; nenhuma RPC, modelo ou BD foi alterado.

## Evidência

- RED comportamental: scheduled falhou pela ausência da mensagem agendada;
  active passou. Antes desse RED foi corrigido somente o locator do teste,
  que inicialmente procurava um rótulo de botão inexistente.
- GREEN focal: 2/2, conferindo callback, versão +1 e feedback renderizado.
- Regressão controller/adapter/domínio: 31/31 antes desta correção.
- Regressão ampliada com página: 38 passaram e 2 falharam.
- As duas falhas mobile foram reproduzidas com o arquivo de produção
  temporariamente idêntico ao HEAD, confirmado por diff vazio; a correção foi
  restaurada imediatamente. Continuar estava em y=1117 fora do viewport
  375x812, causando falha de avanço/audiência e de abertura de data. Não foi
  alterada a baseline nem a interação desses testes neste pacote.
- Analyzer de página e teste sem problemas; formatter e validador
  administrativo passaram. Review independente aprovado no recorte.

Continuam abertos: os dois testes mobile, visual/goldens, replay SQL N01,
publicação real, processamento/erro de fila, persistência, auditoria e reload.
Não promover a tela para verified ou E2E por esta fatia.

Gate de memória: no-op; feedback aplica a distinção já aprovada entre solicitação
de publicação e publicação efetivada, sem nova regra de produto.
