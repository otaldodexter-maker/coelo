---
source: R08-prompts.md common contract and G6; spec 037; ADR 0034 decision 20
status: delivered-local-and-api-green-ui-and-owner-decisions-blocked
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
- Inspecao do C0 no A+ 375/200% encontrou `Texto` quebrado em duas linhas dentro do cabecalho. O `_BlockActions` agora mede rotulo + acoes com o `TextScaler` real e desloca as acoes para uma linha propria apenas quando nao cabem; Agendamento usa duas linhas locais em 200%. Teste focal 1/1, golden update+verify 2/2 e inspecao visual verdes em `dd332b98c`; somente o A+ afetado mudou.
- Gate adicional H14 fechado em `702e75873`: corrida de carga com centro aberto e retry apos falha de `markRead` corrigidos; feed + controlador 13/13 PASS. Continua subaceite de `shell.load`, sem novo ID ou promocao BE/E2E.
- Smoke produtivo de API `circular-media` v13: 16/16 PASS para prepare/PUT/finalize, ordem `text-media-question-text`, publish/read/bytes, negativa anonima e P50 save/submit/summary. Prova API, nao UI/E2E. Houve desvio de retencao: a fixture foi fechada e excluida antes do ACK especifico, embora o contrato mandasse preserva-la. C0 foi avisado; auditoria somente leitura confirmou detail `CIRCULAR_NOT_FOUND`, asset read 403 e catalogos 403. Nenhuma restauracao/recriacao foi feita; detalhes em `smoke-circular-media-r08.md`.

## Handoff final da frente

- Os seis R foram preservados. O mapeamento final confirma que 768/1024
  pertencem apenas ao compositor legado, enquanto os basenames 1440 existem
  também no host produtivo; a fonte do Owner não registra path e conflita sobre
  a presença/geometria do rodapé. Não há decisão visual suficiente para nova
  gravação.
- O manifesto agregado de recursos retidos foi proposto ao C0 com nove grupos,
  somente IDs e retenção, sem e-mail, URL assinada, token, credencial ou sessão.
- Revisões estáticas adicionais fecharam sem defeito concreto a sessão de mídia
  de Principal e o cache/retry de unidade/local de Grupos. A revisão de
  `anonymousEditSecrets` encontrou composição produtiva ausente; o C0 a
  implementou e a prova focal passou 17/17, sem E2E.
- A revisão do save/reload de perfil encontrou validação insuficiente do sujeito
  canônico e identidade incompleta na troca de papel; o corretivo G4 passou
  43/43 e análise estática.
- H25 foi comparado visualmente nos seis pares: o delta era apenas elipse precoce
  causada pela faixa de resize. A correção G3 preservou o master e passou 16
  goldens sem rebaseline; alvos sort estreitos continuam pendência separada.
- A matriz G8 foi aceita com 121/238/422 eventos, 293 eventos anônimos, 281
  chaves de exibição e 12 colisões. O parser geral também foi aceito sobre o
  ciclo 180: hash do input conferido, `done=false/time=97850`, exit nativo 1,
  411 passed, 4 failed, 1 skipped e nenhum done órfão. Nenhum Flutter foi
  repetido por G6.
- O runtime API de imagem de resposta do G0 passou, inclusive download, bytes e
  releitura; essa evidência permanece API e não promove UI.

Pendências legítimas: `circulars.attach` pela UI no runtime 3014 quando o slot
for autorizado; decisão nominal do Owner para os seis R/rodapé; integração e
registro central pelo C0. A branch foi publicada até
`1eccbc591d47f962092dba2f083320b28fff768e` e a worktree deve ser preservada.

## Selo final — 14h32 BRT

- A ordem nominal do Owner substituiu os marcos antigos: entrega das frentes até
  14h40, revisão até 14h50 e fechamento C0 até 15h00. O T0 histórico não muda.
- C0 emitiu ACK220 para a revisão 89 por SHA fixo. A proposta G6 de backlog R09
  foi integrada, e os drafts G7 corrigidos foram aprovados em
  `4e5fd717709602ba30d62b5af094a529eb21d82a`. R09 está preparada, não iniciada.
- A fixture circular criada na prova API usou circular
  `aa9e26a6-2874-4e19-ac79-a41f56c44468` e asset
  `429f1bc4-f579-4179-9193-0e6304aa3e0f`. A circular está logicamente excluída
  e indisponível; o asset READY foi preservado conforme a medição somente
  leitura. Não houve restauração, recriação ou cleanup.
- O manifesto proposto agrega nove grupos de recursos retidos e não contém
  dados pessoais, links assinados, tokens, credenciais, headers ou sessões.
- O lote 59/H28, seus 44/44 no espelho e os testes integrados de Pessoas e
  acessibilidade são posse/prova do C0; G6 não reaplicou SQL nem repetiu testes.
- Último checkpoint publicado antes deste selo:
  `35cc5c912f5181315ef475f9e5e75ae0185cbab8`. Não há WIP local além deste
  fechamento documental; a worktree deve permanecer instalada.

Feito: implementação e provas focais de blocos intercalados, P50 preservado,
runtime/API de mídia, A+, sino, reconciliação 10.000/4.000, revisões delegadas,
proposta e revisão R09. Pendente: somente os gates explicitamente bloqueados de
UI `circulars.attach` e decisão Owner dos seis R, além da integração/fechamento
central do C0.
