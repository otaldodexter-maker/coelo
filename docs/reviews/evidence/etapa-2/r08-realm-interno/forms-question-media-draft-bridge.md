---
title: "R08 G5/G3 — ponte de question-image no rascunho produtivo"
source: "R08-plano.md G3/G5; contratos form_get_editor/form_save_draft e forms_question_media_r2_v1"
status: "RED e primeiro GREEN falho preservados; correção forward-only pronta para o espelho"
generated_at: "2026-09-12T11:55:12-03:00"
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

`20260912140546_forms_question_media_draft_bridge_v1.sql` veio estritamente
depois de `20260912140545`. Como o G0 já o aplicou no baseline, seu conteúdo
foi preservado sem mutação. A correção é o próximo candidato forward-only,
`20260912140547_forms_question_media_draft_bridge_fix_v1.sql`, que:

- aceitar no prepare tanto o form interno quanto o form people-based do caminho
  produtivo, sempre exigindo contexto interno `forms.manage`; no segundo caso,
  `current_person_id()` e
  `has_platform_permission('forms.manage', target.institution_id)` precisam
  continuar válidos;
- autorizar `form_get_editor` e `form_save_draft` contra a instituição real do
  recurso, sem desfazer o deny-by-default da raiz do realm interno;
- conservar a autoria original: `owner_person_id` para o form people-based e
  `owner_internal_identity_id` para o form interno;
- expor em `form_get_editor.media_context` somente `form_version_id`,
  `item_id`, `asset_id`, status, MIME e posição; nenhum `object_key`, URL,
  ticket ou segredo;
- reutilizar um `item_id` apenas quando o UUID recebido já pertence à mesma
  working version; IDs novos, publicados ou estrangeiros recebem UUID novo;
- trocar o FK para `ON DELETE NO ACTION DEFERRABLE`, adiá-lo somente durante o
  replace e validá-lo antes do retorno.
  Remover pergunta com imagem continua fail-closed até a exclusão nominal da
  mídia, em vez de reatar por índice ou apagar silenciosamente.

Os candidatos não alteram `forms_creator_realm_xor`, não criam
`person_auth_link`, não concedem tabela a cliente e não foram aplicados por G5.
Em produção, 140546 e 140547 devem ser tratados como uma unidade ordenada; o
primeiro não pode ser promovido sozinho.

## Casos preparados

`forms_question_media_r2_v1_test.sql` preserva os 25 casos originais do form
interno e acrescenta oito casos no caminho produtivo, totalizando plano 33:

1. prepare people-based pelo mesmo ator interno autorizado;
2. finalize no catálogo privado;
3. reload do editor com contexto mínimo;
4. save de texto depois do upload;
5. reorder preservando por `item_id`, nunca por posição;
6. remoção sem delete nominal falhando fechada;
7. rollback da remoção preservando item e binding.
8. ausência de working version devolvendo `media_context: null`.

Primeiro ciclo G0 sobre `444ac024`: RED com casos 1–18 verdes, 19/20 falhos e
aborto `forms.read required` (native/wrapper 3, rollback no fechamento). O
candidato aplicou somente no baseline com COMMIT/native/wrapper 0, mas o GREEN
repetiu a falha e as regressões não foram executadas. A hipótese inicial estava
incompleta: o ator do teste é institution-scoped, enquanto o caminho legado e
o candidato usavam o overload platform-only de `has_platform_permission`.
Também foi identificado em revisão que `RESTRICT` não serve ao adiamento do FK;
a revisão 140547 usa `NO ACTION DEFERRABLE`, contexto nulo sem working e gates
institucionais nos três consumidores produtivos. O teste agora tem plano 33.
Ela ainda não foi aplicada nem executada; nenhum resultado descrito aqui é
verde ou autoriza produção.
