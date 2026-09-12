---
title: "R08 G0 — Manifesto do smoke API de answer-image"
source: "Contratos produtivos de resposta de Formulários e form-media; revisão G3/G5"
status: "discovery-read-only-sem-candidato"
generated_at: "2026-09-12T12:56:22-03:00"
---

# Smoke API de answer-image

## Estado e limites

O roteiro está preparado, mas não executou rede nem mutação remota. Sem
`--execute`, o script encerra apenas com `READY_NO_MUTATION`. Ele exige uma
`occurrence_id` real e autorizada fornecida pela coordenação; não cria formulário,
aplicação, agenda, ocorrência, participação ou pergunta, evitando duplicar as
fixtures das outras frentes. Não usa SQL direto, `service_role`, Storage legado,
Chrome/CDP nem injeta sessão.

O modo `--discover` é somente leitura: lista pelo RPC normal os formulários
publicados/ativos identificados, conserva apenas os que têm pergunta de imagem,
obtém ocorrências já referenciadas por respostas e testa cada UUID por
`form_get_occurrence_for_response` com a própria identidade QA. Ele não abre
rascunho nem chama prepare/finalize/save. O output omite títulos e pessoas.

O fluxo é o de **imagem de resposta**: payload com `occurrence_id`, `item_id`,
`byte_length` e `checksum`. Ele não envia `purpose=question-image`, `form_id` ou
`form_version_id`, que pertencem ao aceite separado de imagem da pergunta.

## Contrato e sequência

1. Autenticar com a identidade QA e a publishable key já autorizadas.
2. Ler `form_get_occurrence_for_response` e exigir ocorrência aberta, participação
   autorizada e exatamente uma pergunta `photo/gallery`, salvo `--item-id`
   explícito.
3. Abrir ou reutilizar o rascunho por `form_open_response_draft`. Para formulário
   anônimo, o `edit_secret` deve vir de uma variável de ambiente indicada por
   `--edit-secret-env`; seu valor nunca é impresso ou persistido pelo runner.
4. Chamar `form-media` action `prepare` no ramo answer-image e fazer PUT do PNG
   sintético 1×1 pelos `required_headers`, sem Authorization na URL assinada.
5. Finalizar e repetir o mesmo finalize com o mesmo request ID. Ambos devem
   retornar o envelope consumido pelo Flutter: `id`, `item_id`, `mime_type` e
   `byte_length`, correlacionados ao mesmo asset; `asset_id/state` também são
   conferidos. O replay reautoriza o ator/segredo e não cria outro asset.
6. Preservar todas as respostas existentes, substituir apenas a resposta da
   pergunta alvo por `asset_ids=[asset_id]` e salvar por
   `form_save_response_draft` com a versão real do rascunho.
7. Autorizar `download` pelo mesmo ator ou `edit_secret`, baixar a URL assinada e
   comparar bytes e SHA-256.
8. Reabrir o mesmo rascunho e exigir que o mesmo `response_id`, `item_id` e
   `asset_id` persistam após reload.
9. Encerrar somente a sessão Auth local. Não existe caminho de discard, DELETE
   ou cleanup no script; resposta e asset ficam preservados para o fechamento.

## Pré-condições para execução

- C0 deve fornecer a ocorrência já existente e autorizar nominalmente a única
  mutação do rascunho/asset.
- O deploy de `form-media` deve conter a correção final de G3 (linha de base
  `f0c7269fd`, sobre `dfe013cc5`), revisada por G5: finalize inicial e replay
  retornam os campos do `FormAsset` e `byte_length` medido; fonte nula ou
  divergente é negada. O C0 confirmou integração, 54 testes Deno PASS na base
  conjunta e deploy CLI concluído.
- A ocorrência precisa estar aberta para a identidade QA e conter pergunta
  `photo` ou `gallery`. O rascunho precisa continuar em estado `draft`.
- Para identidade anônima, o segredo correto deve existir fora do Git/log em
  variável de ambiente; o runner não inventa outro segredo, pois isso poderia
  criar resposta concorrente para a mesma participação.

## Comandos

Validação local, sem rede e sem mutação:

```powershell
rtk python docs/reviews/evidence/etapa-2/r08-ambiente-runtime/forms-answer-image-api-smoke.py
```

Descoberta remota somente leitura, autorizada pelo C0:

```powershell
rtk python docs/reviews/evidence/etapa-2/r08-ambiente-runtime/forms-answer-image-api-smoke.py --discover
```

Execução identificada, somente após liberação do C0:

```powershell
rtk python docs/reviews/evidence/etapa-2/r08-ambiente-runtime/forms-answer-image-api-smoke.py --execute --occurrence-id <UUID> --item-id <UUID-opcional>
```

Execução anônima exige segredo pré-existente em memória:

```powershell
$env:COELO_QA_FORM_EDIT_SECRET = '<valor privado>'
rtk python docs/reviews/evidence/etapa-2/r08-ambiente-runtime/forms-answer-image-api-smoke.py --execute --occurrence-id <UUID> --edit-secret-env COELO_QA_FORM_EDIT_SECRET
Remove-Item Env:COELO_QA_FORM_EDIT_SECRET
```

PASS futuro exige todos os gates acima. Prova por API não será rotulada como
E2E/UI e não substitui o gate visual de login/leitura/reload, ainda bloqueado
pela entrada de texto CUA no único Chrome compartilhado.

## Resultado da descoberta autorizada

O C0 autorizou a descoberta somente leitura pela API normal. A execução obteve
Auth HTTP 200, `form_list` HTTP 200 e logout local 204. O filtro encontrou zero
formulários identificados publicados/ativos com pergunta `photo/gallery`, zero
occurrences para conferir e, portanto, zero candidatos. Nenhum rascunho foi
aberto e `prepare/finalize/save` não foram chamados.

A fixture preservada do smoke question-image (`f88005ab-...`) não serve: continua
rascunho, possui pergunta `short_text` e não tem ocorrência. A execução mutante
segue parada até o C0 fornecer uma occurrence já existente fora desse catálogo
ou autorizar nominalmente uma única fixture mínima identificada. Nenhuma fixture
duplicada ou cleanup foi gerado. Recibo sanitizado:
[forms-answer-image-api-discovery-20260912.log](./forms-answer-image-api-discovery-20260912.log).
