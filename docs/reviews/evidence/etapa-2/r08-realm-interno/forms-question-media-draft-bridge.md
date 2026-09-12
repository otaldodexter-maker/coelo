---
title: "R08 G5/G3 — ponte de question-image no rascunho produtivo"
source: "R08-plano.md G3/G5; contratos form_get_editor/form_save_draft e forms_question_media_r2_v1"
status: "candidato preparado; RED/GREEN dinâmicos pendentes do espelho"
generated_at: "2026-09-12T11:45:59-03:00"
---

# Ponte de mídia do rascunho produtivo

## Defeito medido

O host produtivo de autoria usa `public.form_get_editor` e
`public.form_save_draft`. Esse caminho mantém autoria people-based, inclusive
quando a pessoa foi resolvida para uma identidade interna pela ponte dos lotes
49–55. Já `public.superadmin_form_media_prepare_v2` aceitava somente forms com
`created_by_internal_identity_id`, enquanto o editor não devolvia a versão de
trabalho nem os bindings. Além disso, `form_save_draft` apaga e recria todos os
itens; o FK `media_bindings.item_id` é `ON DELETE RESTRICT`.

Consequência reproduzível pelo contrato SQL: o mesmo ator autorizado consegue
salvar a pergunta, mas não preparar sua imagem; se um binding for criado por
arranjo manual, o save seguinte é bloqueado ou perde a identidade do item. Uma
troca para o RPC v2 isolado não corrige o host que efetivamente roda.

## Candidato forward-only

`20260912140546_forms_question_media_draft_bridge_v1.sql` vem estritamente
depois de `20260912140545` e propõe:

- aceitar no prepare tanto o form interno quanto o form people-based do caminho
  produtivo, sempre exigindo contexto interno `forms.manage`; no segundo caso,
  `current_person_id()` e `has_platform_permission('forms.manage')` precisam
  continuar válidos;
- conservar a autoria original: `owner_person_id` para o form people-based e
  `owner_internal_identity_id` para o form interno;
- expor em `form_get_editor.media_context` somente `form_version_id`,
  `item_id`, `asset_id`, status, MIME e posição; nenhum `object_key`, URL,
  ticket ou segredo;
- reutilizar um `item_id` apenas quando o UUID recebido já pertence à mesma
  working version; IDs novos, publicados ou estrangeiros recebem UUID novo;
- tornar o FK deferível somente durante o replace e validá-lo antes do retorno.
  Remover pergunta com imagem continua fail-closed até a exclusão nominal da
  mídia, em vez de reatar por índice ou apagar silenciosamente.

O candidato não altera `forms_creator_realm_xor`, não cria `person_auth_link`,
não concede tabela a cliente e não foi aplicado por G5.

## Casos preparados

`forms_question_media_r2_v1_test.sql` preserva os 25 casos originais do form
interno e acrescenta sete casos no caminho produtivo, totalizando plano 32:

1. prepare people-based pelo mesmo ator interno autorizado;
2. finalize no catálogo privado;
3. reload do editor com contexto mínimo;
4. save de texto depois do upload;
5. reorder preservando por `item_id`, nunca por posição;
6. remoção sem delete nominal falhando fechada;
7. rollback da remoção preservando item e binding.

Não há alegação de pgTAP executado neste documento. RED sem candidato,
aplicação apenas no baseline e GREEN/regressões dependem de posse nominal do
espelho pelo G0/C0.
