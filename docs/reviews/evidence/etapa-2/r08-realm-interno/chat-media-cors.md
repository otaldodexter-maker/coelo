---
title: "R08 G5 — preflight CORS do chat-media"
source: "R08-plano.md G5; ADR 0032; teste Deno local"
status: "integrado e implantado pelo C0; preflight remoto aprovado"
generated_at: "2026-09-12T11:06:41-03:00"
---

# Preflight CORS do chat-media

## Defeito reproduzido

Ambiente: worktree `e2-r08-realm-interno`, Deno local, sem Docker, Supabase
remoto ou segredo. Um `OPTIONS` da origem administrativa autorizada
`http://localhost:3014`, solicitando os cabeçalhos reais do cliente, não
devolvia `x-client-info` em `Access-Control-Allow-Headers`.

O teste novo `supabase/functions/chat-media/cors_test.ts` falhou antes da
correção com `AssertionError: x-client-info: false` (0 passou / 1 falhou).

## Correção e prova

A allowlist ganhou somente `x-client-info`; origem não confiável continua sem
`Access-Control-Allow-Origin`. Comando executado no diretório da função:

`deno test --allow-env --allow-read`

Resultado após a correção: **6 passaram / 0 falharam** — um teste CORS, três
testes do handler e dois testes de bytes persistidos. Houve apenas o aviso de
depreciação `punycode` vindo de dependência Node, antes da suíte.

Esta prova local não certifica R2, fluxo pela tela ou isolamento cross-tenant.

Recibo posterior do C0: o commit `ebb227212` foi integrado; a mesma suíte
passou **6/6** na base conjunta; `chat-media` v4 ficou `ACTIVE`. O preflight
remoto retornou 200 para a origem 3014/Superadmin e 403 sem
`Access-Control-Allow-Origin` para origem externa. A implantação e a medição
remota são evidência do C0, não execução desta frente. O fluxo completo
prepare/PUT/finalize/read continua com G4.

## Contrato de identificador

A spec 028 distingue `ChatAttachment.id` (vínculo) de `assetId` (ativo
canônico) e proíbe inferência. O banco aplicado de chat expõe hoje apenas o
`id` de `chat_attachment_metadata`; o plano M03 de catálogo segue como
proposta sem migration aplicada. Assim, este pacote não fabrica
`assetId = attachment_id`. No recorte R08, a leitura deve resolver o vínculo
explicitamente pela ação `read` do `chat-media`, até conciliação do catálogo.
