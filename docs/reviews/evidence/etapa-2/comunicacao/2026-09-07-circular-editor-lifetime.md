---
title: "Circulares — lifetime do editor e identidade de perguntas"
source: "Prompt 4; pendências P2 do editor; revisão independente; REDs locais"
status: "local-verified; e2e-open"
generated_at: "2026-09-07"
---

## Recorte inicial

Pendências conhecidas: publicação A chamava callback B após troca; picker de
agendamento A podia agendar B; campos title/body retinham A. Objetivo: impedir
essas transposições mantendo o controller antigo vivo no teste. Incluído
somente `SuperadminCircularComposerPage` e teste de páginas existente; fora
backend, host, Auth, publicação remota, import/export, UI nova e outras apps.
Ordem: RED por ação, correção do lifecycle, investigação de campos análogos,
regressões e review. Estimativa 20–35 min; parada desta fatia no gate local,
sem declarar Circulares completa ponta a ponta.

## Correção e provas

Quatro REDs confirmados antes da alteração: callback depois de trocar editor,
callback depois de desmontar página, data antiga no controller novo e campos
desatualizados. `didUpdateWidget` reseta título/texto/data/preview somente se
controller muda; geração identifica contexto. Publicação captura controller
e callback e verifica lifetime após await. Picker também identifica a última
solicitação, sem aplicar data do contexto anterior.

Durante o recorte, campo de pergunta mostrou a mesma classe de defeito:
remoção de A reutilizava seu TextEditingController para B. RED confirmado;
key por controller/ID resolveu identidade. Um segundo RED no mesmo teste
confirmou texto externo desatualizado; `didUpdateWidget` sincroniza somente
quando o texto efetivamente difere, sem resetar seleção na digitação normal.

- 18/18 testes focais da página, cinco novos.
- 96/96 testes não-golden de Circulars + Principal Circulars.
- Analyzer focal de dois arquivos, format, diff-check e validador visual verdes.
- Revisão independente aprovou os quatro casos de lifecycle e depois o delta
  de perguntas. A fixture imediata de publish usa o ID efetivamente solicitado.

A confirmação de A no servidor não é desfeita por trocar editor: esta correção
impede somente callback/data/campo antigo de atingir B. Nenhuma alegação de
cancelamento remoto, zeroização de memória ou prova de RLS. Nenhum PNG,
migration ou recurso remoto modificado. Baselines históricas não foram
atualizadas. Questões distintas fora do recorte permanecem abertas.

Memória no-op: restaura isolamento/consistência já exigidos, sem nova política
durável. Handoff ao Coordenador para os rastreadores oficiais, que não são
editados por E2E3.
