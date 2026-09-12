---
title: "R08 G5 — revisão focal do finalize de imagem-resposta"
source: "commits G3 dfe013cc5 e f0c7269fd; contrato form-media"
status: "integrado-e-deployado-v17"
generated_at: "2026-09-12T13:12:28-03:00"
---

# Finalize de imagem-resposta — revisão de segurança e contrato

Recorte: Edge Function `form-media`, ação `answer-r2/finalize`, incluindo
replay após resposta perdida. G5 revisou o diff; não executou Deno, pgTAP,
SQL ou chamada produtiva. O G3 informou 53 testes Deno verdes e typecheck.

## Resultado

- Fresh e replay reautorizam primeiro com `form_finalize_asset_upload` usando
  o JWT do usuário. Uma negação para antes de descriptor, leitura privilegiada
  ou R2.
- O descriptor precisa devolver o mesmo `asset_id` autorizado. A leitura com
  `service_role` usa igualdade pelo ID exato e exige estado `finalized`, item,
  MIME e tamanho coerentes.
- Replay não toca o R2 e devolve o mesmo envelope mínimo do cliente.
- A resposta não expõe bucket, object key, ticket, URL ou segredo; devolve
  apenas IDs, `item_id`, MIME, estado e bytes.

O primeiro commit `dfe013cc5` usava `expected_byte_length` no DTO. G5 bloqueou
o deploy porque esse campo representa o anúncio, não a medida confirmada. O
follow-up `f0c7269fd` passou a selecionar e devolver `actual_byte_length`, exige
valor numérico igual ao tamanho confirmado pelo descriptor e acrescenta casos
fail-closed para valor nulo ou divergente. Com esse follow-up, a revisão G5 foi
aprovada para integração; implantação continua exclusiva do C0.

## Integração e deploy

O C0 integrou os dois commits no ciclo 120, executou a suíte conjunta Deno em
54/54 com typecheck e implantou `form-media` v17 (`verify_jwt=true`), bundle
SHA-256 `ea77bf6721130bb0717dae4bcd4dff7ee8350727c0842d26d3d1fc16e243a762`.
OPTIONS retornou 204 com origem exata para 3014 e produção; origem externa foi
negada com 403. O answer-image ainda requer seu smoke produtivo próprio; o
smoke question-image já aprovado não certifica esse ramo.
