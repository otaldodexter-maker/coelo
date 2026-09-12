---
source: "R08 G6 handoff; six-r-final-map.md; spec 037; ADR 0034 decisions 15 and 20"
status: "proposal-for-c0; not-authoritative; owner-input-required"
generated_at: "2026-09-12"
---

# Proposta de backlog R09 — Publicações e Agenda

Esta proposta não altera o backlog, os prompts ou os rastreadores autoritativos
do C0. Ela separa decisão ainda inexistente de execução já autorizável e não
reabre aceites fechados na R08.

## 1. Decisão do Owner para os seis R

Estado: bloqueado por decisão visual nominal.

Antes de editar código ou imagem, o Owner precisa responder, para cada série
claro/escuro e largura 768/1024/1440:

1. O alvo é `PrincipalCircularComposerPage` legado/somente de teste,
   `SuperadminCircularComposerPage` produtivo, ou ambos?
2. O golden deve capturar somente a superfície ou o shell completo?
3. Qual é a geometria aprovada do rodapé: ancorado ao limite inferior do
   contêiner, interno ao card, ou outra referência explicitamente anexada?
4. O host legado deve convergir visualmente ou deve apenas permanecer congelado
   até uma decisão separada sobre sua retirada?

Motivo: 768/1024 resolvem apenas para o legado; os basenames 1440 existem nos
dois hosts. A referência 1440 inclui shell e rodapé, embora a observação nominal
diga que esse rodapé não existe. O design system e ADR 0034/P15 continuam
exigindo rodapé ancorado. Nenhuma dessas fontes autoriza escolher uma geometria
por inferência.

Aceite da decisão: tabela Owner registra path/componente, tema, viewport,
recorte e rodapé para os seis arquivos, sem texto contraditório.

## 2. Aplicar a decisão visual, somente depois do item 1

Estado: dependente do Owner.

- Alterar somente o componente nominalmente indicado.
- Preservar a ordem `texto -> mídia -> pergunta -> texto`, o limite agregado de
  10.000 caracteres e os A+ já aprovados.
- Não regravar em massa: atualizar apenas os R cujo alvo e geometria foram
  aprovados, comparar master/test/diff e inspecionar claro, escuro, 200% e as
  larguras afetadas.
- Recertificar testes focais e análise estática do código efetivamente tocado;
  aprovação visual não promove FE/BE/E2E.

## 3. `circulars.attach` pela rota normal

Estado: executável quando C0 conceder Chrome/runtime e coordenar fixture.

Pré-condições já satisfeitas: `circular-media` v13 implantada; preflight da
origem 3014 inclui `x-client-info`; smoke API 16/16 provou upload, ordem,
publicação, leitura e bytes. A fixture circular da R08 ficou indisponível após
exclusão lógica e não deve ser restaurada ou recriada silenciosamente.

Aceite R09: em nova fixture sintética autorizada e retida, a rota produtiva
anexa mídia, preserva a ordem, publica, recarrega e lê o mesmo ativo; negativa
de outro tenant é registrada. API isolada não substitui essa prova UI/E2E.

## 4. Evidência complementar do sino

Estado: baixa prioridade; não cria action_id.

Quando houver evento sintético para o ator autorizado, abrir o centro pela rota
normal e provar `read_at` após reload, inclusive retry depois de falha
transitória. O resultado continua subaceite de `shell.load`; não altera o
denominador nem promove backend/E2E por si só.

## Fora do backlog de correção

- Não reabrir P50 sem delta no caminho já recertificado.
- Não reduzir o limite de texto para 4.000: spec 037 e o contrato implementado
  fixam 10.000 somados; 4.000 era apenas referência visual conflitante.
- Não repetir suites ou goldens sem delta material.
- Não limpar os recursos do manifesto R08 antes do encerramento da Etapa 2 e do
  ACK do C0; cleanup, deploy, inventário e rastreadores permanecem centralizados.

## Evidências de entrada

- `six-r-final-map.md`
- `visual-comparison.md`
- `a-plus-recertification.md`
- `circular-media-preflight-3014.md`
- `smoke-circular-media-r08.md`
- `shell-notification-mapping.md`
- `retained-r08-resources-proposal.json`

