---
title: "Chat — consumidor explícito de imagem temporária"
source: "Prompt 4; plano aprovado 2026-09-07-chat-image-consumer; MediaReader/MediaSession; revisão independente"
status: "local-preparation; visual-and-remote-gates-open"
generated_at: "2026-09-07"
---

## Contrato do recorte

Objetivo: ligar a tile existente a um leitor de preview canônico opcional e
conter a capacidade temporária à visualização/contexto. Incluído: Chat único
no Superadmin, diálogo, tile, página, encaminhamento aditivo App/router,
negativos e memória. Fora: upload, transporte HTTP de produção, Scope/main,
Auth compartilhado, DDL/R2/Stream, apps Admin/Principal/Site e rastreadores.
Ordem: RED → consumidor → composição → regressões/inspeção → review.
Critério de parada desta fatia: preparação local preservada, sem declarar
front-end completo ou verified-e2e. Estimativa inicial 45–75 minutos; gates
visuais adicionais e transporte permanecem em andamento.

## Resultado local

- `Abrir imagem` só lê após ação explícita, por `assetId` e rendition preview.
  Sem asset/reader/session ativo, ação visível desabilitada com explicação.
  ID de metadata e `downloadUrl` legado nunca viram autoridade/fallback.
- Diálogo canônico: loading/processing/expired/unavailable, retry explícito,
  prazo do ticket, estado seguro em erro HTTP/decode, sem polling.
- Respostas tardias conferem geração e ownership local; sessão invalidada
  remove provider e impede nova leitura. Dispose/contexto cancela timers e
  remove somente a rota própria; foco retorna à ação correspondente.
- RED reproduziu abertura imediatamente seguida por troca de contexto:
  builder guard isolado era insuficiente pela ordem de build. I/O inicia
  pós-frame e confere ownership antes/depois do await; desmontagem imediata
  também tem teste. Sessão compartilhada não é invalidada para fechar tile.
- Cache Flutter tem teste com imagem sintética decodificada: RawImage real
  aparece, invalidação remove pixels do widget e entradas pending/live/keepAlive
  do provider exato. Não é prova de HTTP, cache browser, zeroização ou R2.
- `NetworkImage` não é um objeto de diagnóstico sanitizado: não há log no
  consumidor, mas seu toString do SDK pode conter capability. Não registrar
  providers/DTOs; não afirmar sanitização global do framework.

## Verificação executada

- 82/82 testes não-golden de Chat.
- 3/3 composição: rota normal com/sem dependências; reconstrução real de
  `SuperadminApp` por key substitui router e instala nova sessão/leitor.
- Analyzer focal de dez arquivos: sem problemas; format/diff-check e
  validador visual verdes.
- Oito PNGs **novos candidatos**, sem atualização de histórico: quatro
  estados distribuídos por 375/768/1024/1440, claro/escuro, texto 200% e
  reduced motion. Todos inspecionados; rodada comparativa 8/8 após correção
  canônica do footer em `4a5ff8e0` (evidência separada).
- Revisão independente aprovou lifecycle, encaminhamento e purge no recorte;
  sugestão final de teste de desmontagem imediata foi acrescentada e passou.
- Gate de conhecimento: spec028 primeiro, projeção team depois; ambos os
  scripts de validação passaram. Capturados limites estáveis de identidade,
  autorização temporária e eviction, sem conteúdo de conversas.

## Limites que continuam abertos

App captura router/dependências no initState. O teste prova reconstrução por
key, **não** que Scope/main já fazem essa composição de mídia nem troca
in-place; integração Auth será serializada pelo Coordenador. `/dev` não recebe
o leitor real desta passagem. Nenhum fake foi adicionado à rota normal.

Ainda faltam matriz completa de estados por largura/tema, candidato visual
available, hover/foco/teclado do novo fluxo completo e runtime/browser real.
Goldens históricos de Chat tinham divergências documentadas anteriormente e
não foram sobrescritos nem reclassificados por esta fatia. Faltam transporte,
catálogo, decoder, autorização server-side/read, arquivo sintético R2 real,
reload, revogação, expiração e cleanup em produção sob lease nominal.

Escopo E2E3 original permanece integral: Comunicação, plataforma de Mídia,
Coelo (Principal) no Superadmin e cabeçalho global. Este consumidor não
substitui as demais telas/ações e não encerra a tarefa.

## Delta de revisão central — tema herdado

O Coordenador identificou que DialogRoute manual não capturava o tema local
abaixo do Navigator. RED com raiz clara/subárvore escura reproduziu superfície
branca; correção usa `InheritedTheme.capture` para o mesmo Navigator dono,
barreira do DialogTheme/Theme e traversal fechado, preservando ownership.
22/22 testes tile/diálogo passaram após a correção. Nenhum golden histórico
atualizado; este delta restaura tema do contexto, sem nova regra de produto.
