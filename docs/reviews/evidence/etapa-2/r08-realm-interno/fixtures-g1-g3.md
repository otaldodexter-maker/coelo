---
title: "R08 G5 — fixtures transacionais para G1 e G3"
source: "contratos G1 cc79cbac8 e G3; suítes SQL vigentes"
status: "preparado; execução focal pendente no espelho"
generated_at: "2026-09-12T11:10:17-03:00"
---

# Fixtures G1 e G3

## G1 — Avaliações

O contrato do G1 em `cc79cbac8` revelou que
`superadmin_assessments_internal_v2_test.sql` cobria configuração e negativa,
mas não construía a turma/aluno necessários ao diário. A fixture existente foi
estendida, ainda sob `begin`/`rollback`, com:

- turma A, vínculo atividade–unidade e atividade–turma;
- criança, contexto, vínculo de unidade/turma e participação ativa;
- exposição do vínculo em `superadmin_assessment_context_options`;
- ativação da configuração e abertura do período;
- criação do diário com exatamente uma linha de aluno.

O plano passa de 47 para 52. Os UUIDs usam apenas o prefixo sintético `8d20` e
nenhuma credencial. A suíte deve ser executada isoladamente no espelho antes
de G1 reutilizar a forma no runtime; não há mutação remota autorizada aqui.

## G3 — Local e mídia de Formulários

O menor arranjo seguro já está versionado e não deve ser duplicado:

| Aceite | Fixture/suíte canônica | Identificadores úteis no rollback |
| --- | --- | --- |
| `forms.location-answer` | `forms_location_question_v1_test.sql` | occurrence `8f16…2007`, participation `…2008`, response `…2009`, item obrigatório `…2003`, opções A `…2101/2102`, opção B `…1201` |
| snapshot pela rota produtiva v1 | `forms_location_snapshot_v1_route_test.sql` | form `8f17…0701`, Local A `…0601/0602`, Local B `…0621` |
| question-image | `forms_question_media_r2_v1_test.sql` | fluxo `superadmin_form_media_prepare_v2`, working version/item, catálogo `media_assets/media_bindings` |
| answer-image | `forms_answer_media_r2_v1_test.sql` | occurrence `8c0a…6210`, item photo `…3210`, assets `…9210/9211` |

A fixture de Local mantém `kind='location'`, snapshot server-side e resposta
por `option.id`; o Local precisa continuar ativo na mesma instituição no
submit/edit. A alternativa de outra instituição é recusada. O arranjo inclui
ocorrência aberta, participação elegível, versão publicada e rollback total.

Question-image e answer-image continuam aceites separados. O primeiro usa
versão de trabalho/item e `superadmin_form_media_prepare_v2`; o segundo usa
ocorrência publicada/item `photo|gallery` e
`form_prepare_asset_upload_r2_v1`. Nenhum `asset_id`, URL, segredo ou objeto R2
é fabricado por esta fixture documental. PUT/finalize/read reais dependem de
C0/G3 e não são provados por pgTAP.

Para runtime, C0 deve criar uma ocorrência nova pela rota autorizada para a
identidade do arquivo privado G3, registrar somente IDs não sensíveis e manter
o cleanup para o encerramento formal. Não se deve copiar os `auth.users`
sintéticos dos pgTAP para produção.
