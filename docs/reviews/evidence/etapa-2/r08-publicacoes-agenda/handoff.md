---
source: R08-prompts.md common contract and G6; spec 037; ADR 0034 decision 20
status: local-green-browser-blocked
generated_at: 2026-09-12
---

# R08 G6 — Publicacoes e Agenda

## Contrato inicial

- Objetivo: fechar os gates autorizados de Circulares e Agenda, preservando as provas R06 validas e recertificando somente o codigo afetado.
- Incluido: `circulars`, `agenda`, `principal_circulars`, `circular-media` e notificacoes do shell sob posse confirmada.
- Fora de escopo: inventario/rastreadores, deploy (C0), `publication_surface.dart` reservado a G3 e qualquer decisao visual ausente.
- Ordem: host produtivo versus legado; blocos ordenados; P50; attach no runtime 3014; comparacao dos seis R web/A+; sino e 4.000 versus 10.000.
- Criterio de parada: T0+4h ou ordem do C0; handoff final ate T0+4h10; ajustes ate T0+4h30.
- Evidencias: testes focais vermelho/verde, analise estatica, comparacoes visuais sem sobrescrever R, rota real quando o slot for concedido, commits e push a cada checkpoint.
- Estimativa inicial: o delta de implementacao concentra-se no compositor produtivo e sua previa; o leitor do Principal ja percorre `detail.blocks` em ordem. A prova remota de attach depende do slot Chrome/runtime 3014.

## Abertura

- Base incorporada: `origin/dev` em `0e7042bab`.
- Compositor produtivo: `SuperadminCircularComposerPage`, composto por `ProductionCircularComposerHost` na rota real.
- Compositor legado: `PrincipalCircularComposerPage`, mantido apenas por testes/compatibilidade e fora do host produtivo.
- Limite canonico: `CircularLimits.bodyCharacters = 10000`, coerente com spec 037; a indicacao visual de 4.000 nao altera o contrato.
- Leitor: `PrincipalCircularReader` ja renderiza cada item de `detail.blocks` sequencialmente.
- Primeiro gate: a autoria e a previa produtivas ainda agrupam o primeiro texto, um bloco de midia e as perguntas por tipo.

## Decisoes reconciliadas

- H14: C0 aceitou shell.load como acao-pai da carga/contagem do ContextNotificationFeed; abrir o centro e persistir read_at e evidencia complementar nomeada. Nao existe ID novo, nao muda o denominador e nao promove BE/E2E de uma acao flutter-only.
- H21: spec 037 e CircularLimits.bodyCharacters fixam 10.000 caracteres somados entre blocos de texto. O contador 4.000 da referencia visual e conflito documental/visual, nao autorizacao para reduzir o contrato.
- Os seis R nominais sao circular_composer_{light,dark}_{768,1024,1440}. A comparacao do caso 1440 mostra rodape interno no render atual contra rodape no conteiner/shell da referencia. Nenhum PNG R sera sobrescrito; a geometria continua focal para o Owner/C0.

## Implementacao em curso

- O controlador agora prepara operacoes por identidade para adicionar, editar e mover blocos de texto e mover qualquer bloco, mantendo o teto agregado de 10.000.
- O compositor produtivo renderiza os blocos na ordem do dominio e expoe texto, midia e pergunta simples com movimento; a previa percorre a mesma lista.
- Os presets de resposta atualizam a pergunta existente e preservam sua posicao relativa; o teste focal confere os quatro IDs antes/depois do preset.
- O leitor do Principal ja percorria a lista em ordem; foi acrescentada uma chave semantica por bloco para a prova focal, sem alterar a composicao.
- Testes focais: 67 verdes, zero falhas abertas. A primeira execucao encontrou uma expectativa invertida no teste novo; apos a correcao, os dois arquivos afetados passaram 43/43 e os outros tres ja estavam verdes.
- Analise focal dos seis arquivos Dart tocados: No issues found (11:27 BRT).
- P50 foi reconciliado em `p50-hierarchy.md`; as provas R06 permanecem vigentes e a regressao local do leitor passou.
- Prova detalhada em `flutter-verification.md`. O slot global foi liberado imediatamente ao C0.
- Gate de memoria: 64 artigos validados; nenhuma regra duravel nova, pois ordem intercalada e limite de 10.000 ja constam nas fontes canonicas/projecoes. No-op documental.
- A fixture visual dos tres A+ usa `texto -> midia -> pergunta -> texto` e cobre claro 375 normal/200% e claro 1440/200%. Somente esses tres PNGs autorizados foram regravados e inspecionados; os seis R permanecem intocados.
- `circular-media-preflight-3014.md` registra OPTIONS 200 em producao para a origem 3014, inclusive `x-client-info`; o aceite de `circulars.attach` continua aguardando a rota real.
- Revisao de G7 encontrou o segundo gate funcional: novos arquivos ainda eram agregados ao primeiro bloco. Corrigido em `3def837bf`: cada upload vira bloco proprio depois do bloco escolhido; selecao multipla encadeia os novos IDs, preserva a ordem e o teto agregado de quatro. Regressao final 58/58 PASS e tres A+ commitados em `4c4aaae68`; analyze focal verde.
- O runtime produtivo `circular-media` v13 passou no preflight direto com origem `http://127.0.0.1:3014`, inclusive `x-client-info`. O aceite E2E de `circulars.attach` nao foi promovido: o unico Chrome pertence a G0 e o C0 vedou novo browser/CDP nesta janela.
- Inspecao do C0 no A+ 375/200% encontrou `Texto` quebrado em duas linhas dentro do cabeçalho. O `_BlockActions` agora mede rotulo + acoes com o `TextScaler` real e desloca as acoes para uma linha propria apenas quando nao cabem; teste focal preparado. Analyze verde; golden afetado aguarda slot Flutter e, ate la, esta correcao permanece WIP.
