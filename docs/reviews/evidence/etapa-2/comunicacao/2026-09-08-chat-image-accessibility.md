---
title: "Chat — movimento reduzido, teclado e matriz de estados de imagem"
source: "Contrato visual Coelo vigente; consumidor 8d34a63a/df7f9544; testes Flutter locais"
status: "local-green; não frontend-verified ou E2E"
generated_at: "2026-09-08"
---

# Recorte

Consumidor de imagem do Chat canônico em Superadmin. Objetivo: respeitar
movimento reduzido na rota efetiva e verificar os estados existentes nas quatro
larguras, nos dois temas e com texto 200%. Não muda design, transportador,
composição, sessão, contratos de backend ou recursos remotos. Ordem: RED da
rota, correção mínima, matriz de conteúdo e regressão. Esta fatia termina com
verificações locais; a frente E2E 3 continua no escopo integral.

# Evidência

- RED reproduzido: Enter abria a rota com duração 150 ms apesar de
  `disableAnimations: true`.
- Correção produtiva de uma linha: `AnimationStyle.noAnimation` condicionado à
  preferência vigente no contexto de abertura; padrão preservado.
- GREEN: Enter abre, transições de ida/volta têm duração zero, uma única leitura
  é emitida; Escape fecha e foco retorna ao botão de origem.
- 40 combinações de conteúdo: loading/processing/expired/unavailable/available ×
  375/768/1024/1440 × claro/escuro, todas com texto 200% e movimento reduzido.
  Verifica estado, ausência de exceções, botão Fechar >=48 px e `RawImage`
  decodificada no estado disponível.
- `available` usa entrada de cache Flutter sintética 4×4 previamente decodificada,
  não requisição HTTP ou objeto R2. O teardown desmonta e resolve loading pendente.
- 124 testes não-golden de Chat: GREEN. Oito goldens candidatos existentes:
  GREEN, sem atualizar qualquer PNG/baseline. Analyzer três arquivos: sem issues.
  Format e diff check; validador visual GREEN. Review read-only sem bloqueantes.

# Limites e memória

A matriz cobre conteúdo/layout, não navegação real nas 40 combinações nem
adequação visual de imagens com proporções variadas. Teste da rota efetiva é
separado; golden disponível, revisão de proporções e prova em navegador real
continuam abertos. Não demonstra transporte, autorização/persistência remota,
cache HTTP/browser, R2 ou Stream. Nenhum segredo, SQL, recurso remoto ou arquivo
compartilhado alterado. Restaura acessibilidade já aprovada: gate de memória sem
nova decisão/artigo. Coordenador atualiza rastreadores sem promover status E2E.
