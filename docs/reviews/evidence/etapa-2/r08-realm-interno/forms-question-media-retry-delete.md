---
title: "R08 G5/G3 — retry de finalize, delete nominal e não-enumeração"
source: "R08-plano.md G3/G5; forms_question_media_r2_v1 e revisão C0/G3 de 2026-09-12"
status: "candidatos 140548/140549 e casos preparados; RED/GREEN pendentes do espelho"
generated_at: "2026-09-12T12:04:58-03:00"
---

# Resíduos do fluxo question-image

## Defeitos medidos por inspeção

O corpo vigente de `superadmin_form_media_authorize_finalize_v2` recusa todo
ticket com `used_at`, e `form_media_finalize_question_r2_v1` também recusa a
segunda confirmação. Se o primeiro finalize foi confirmado no banco e a
resposta se perdeu, o mesmo pedido não consegue reconciliar o estado `ready`.

O delete nominal marca o asset como `deleted` e agenda a chave no R2, mas não
remove `media_bindings`. Assim, mesmo depois da exclusão autorizada, o FK do
item continua impedindo remover a pergunta. A revisão C0 também confirmou que
`form_get_editor` distinguia recurso existente fora do tenant (`forms.read
required`) de recurso inexistente (`form unavailable`).

## Candidato 140548

`20260912140548_forms_question_media_retry_delete_v1.sql` propõe somente:

- `authorize_finalize` aceita reconciliação pelo mesmo ator quando ticket usado
  e asset `ready`, marcando `replayed=true`;
- o finalizador aceita replay apenas se bytes, SHA-256, dimensões e variante
  original coincidem exatamente; qualquer diferença continua
  `FORM_MEDIA_TICKET_INVALID`;
- delete nominal remove o binding `question-image`, inclusive curando binding
  residual em replay, sem apagar fisicamente o asset ou a trilha;
- editor inexistente, internal-only e cross-tenant respondem igualmente `form
  unavailable` antes de projetar dados.

O pacote mantém owners e grants explícitos, não muda RLS, não toca segredo nem
faz operação R2. Ele vem depois de 140546 e 140547 e não foi aplicado por G5.

## Casos preparados

`forms_question_media_retry_delete_v1_test.sql` tem plano 9: prepare, primeiro
finalize, authorize de reconciliação, replay idêntico do finalize, rejeição de
medidas alteradas, remoção do binding no delete, remoção posterior da pergunta
e equivalência entre erros cross-tenant e inexistente. Não há alegação de pgTAP
executado; RED/aplicação local/GREEN pertencem ao espelho coordenado.

## Fechamento terminal 140549

A revisão G3 confirmou um resíduo depois de 140548: mismatch e expiração
automática também mudam o asset para `deleted`, mas não passam pelo delete
nominal. Como o editor oculta deleted, o usuário não teria como soltar esse
binding e a pergunta permaneceria presa.

Sem mutar 140548, o candidato seguinte
`20260912140549_forms_question_media_terminal_unbind_v1.sql` centraliza a
invariante em trigger restrito a `catalog_kind=form-image`,
`media_purpose=question-image` e transição real para `deleted`. O backfill
remove apenas bindings de assets já logicamente encerrados; catálogo, variante,
ticket, limpeza e auditoria são preservados. A suíte focal de plano 7 cobre
mismatch, expiração, remoção dos dois bindings e save posterior sem as
perguntas. Também não foi aplicada nem executada por G5.
