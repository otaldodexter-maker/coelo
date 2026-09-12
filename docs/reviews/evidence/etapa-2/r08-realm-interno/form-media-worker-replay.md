---
title: "R08 G5 — compatibilidade do worker form-media com replay do lote 57"
source: "novo gate C0 de 2026-09-12; form-media/index.ts; contratos SQL 140548"
status: "teste Deno local verde; sem deploy"
generated_at: "2026-09-12T12:29:27-03:00"
---

# Worker finalize e replay

O worker existente já é compatível com o contrato aplicado no lote 57. Quando
`superadmin_form_media_authorize_finalize_v2` informa que o asset está `ready`
e o pedido é replay, o worker não confia apenas nesse marcador: relê HEAD e
bytes do objeto R2, recalcula SHA-256 e dimensões e chama o finalizador com as
medidas observadas. O finalizador só reconcilia se asset, medidas e variante
original coincidem; divergência permanece fail-closed no banco.

O harness Deno passou a representar `status` e `replayed` nos dois RPCs e ganhou
um caso explícito de resposta perdida após o primeiro finalize. Resultado local:

- filtro `question-image finalize`: 4/4, 25 filtrados;
- suíte completa `form-media/index_test.ts`: 29/29;
- zero chamadas de rede real; transport R2 e RPCs são doubles do harness.

A primeira invocação feita da raiz falhou antes dos testes por não carregar os
aliases do `deno.json`; a repetição correta ocorreu no diretório `form-media`,
sem instalar dependência. Não houve alteração no worker produtivo, deploy,
SQL, segredo ou dado sintético.
