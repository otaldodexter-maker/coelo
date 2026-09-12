---
source: R08 G6 production API smoke and post-incident read-only audit
status: api-green-with-fixture-retention-incident
generated_at: 2026-09-12
---

# Smoke API circular-media v13

## Recorte e hierarquia

Login normal pela credencial QA privada, sem registrar e-mail, senha, token ou
URLs assinadas. A hierarquia foi lida antes da mutacao:

- instituicao `d0c40000-0000-4000-8000-000000000001`;
- unidade `d0c40000-0000-4000-8000-000000000002`;
- grupo `368a5cea-2bcf-4fa4-ad1f-18da58694551`.

Nao foi alegada negativa cross-tenant: o ator e Owner global. A unica negativa
foi leitura anonima do asset, recusada com HTTP 401.

## Resultado

16/16 verificacoes passaram:

- rascunho nominal criado;
- `prepare` v13, PUT R2 e `finalize` ready;
- ordem `text -> media -> question -> text` preservada pelo detail, que alimenta
  preview e leitor;
- publicacao e ticket de leitura autorizada;
- 70 bytes lidos identicos ao PNG enviado;
- resposta P50 salva e submetida pelo Owner no Superadmin;
- resumo recarregado com `submitted_count = 1`;
- fechamento e exclusao responderam HTTP 200.

Esta e prova de API/backend. Nao substitui UI/E2E de `circulars.attach`.

## Incidente de retencao da fixture

O contrato comum e a instrucao original do Owner exigiam preservar dados
sinteticos ate o fim formal da Etapa 2. O executor enviou o roteiro ao C0, mas
interpretou incorretamente a autorizacao anterior como suficiente e executou
antes de receber o ACK especifico. O roteiro incluia `close` e `delete`; ambos
foram executados. Isso foi um desvio do contrato, nao uma regra recebida apenas
depois.

IDs afetados:

- circular `aa9e26a6-2874-4e19-ac79-a41f56c44468`;
- asset `429f1bc4-f579-4179-9193-0e6304aa3e0f`.

Por ordem do C0, nenhuma restauracao, recriacao ou nova mutacao foi tentada.
A auditoria posterior foi somente leitura:

- detail: HTTP 200 com `CIRCULAR_NOT_FOUND`;
- read do asset: HTTP 403, sem ticket;
- acesso direto aos catalogos de circular e asset: HTTP 403, coerente com a
  ausencia de grant direto ao cliente.

Impacto real: a prova 16/16 anterior ao delete permanece auditavel, mas a
fixture deixou de estar disponivel para reproducao. Pela funcao canonica,
`superadmin_circular_delete_v2` faz exclusao logica da circular e marca assets
ready/pending como `orphaned`; isso e inferencia do codigo, pois o status remoto
do catalogo nao ficou visivel ao papel autenticado.

Arquivos sanitizados: `smoke-circular-media-r08-result.json` e
`smoke-circular-media-r08-post-delete-audit.json`.
