---
source: "R08 G3; posse nominal C0 para handleAnswerR2; SupabaseFormsApi.finalizeAssetUpload; form-media/index.ts"
status: "local-green; deploy e prova produtiva pendentes C0"
generated_at: "2026-09-12"
---

# Confirmação de imagem de resposta no R2

Recorte: `apps/superadmin -> Formulários -> Responder -> Galeria -> forms.upload`. Imagem de pergunta é outro ramo e outro aceite. Base `2441725d5`, worktree G3 após `0b05e95f2`.

O consumidor Flutter exige `id`, `item_id`, `mime_type` e `byte_length` ao confirmar o ativo. O ramo R2 devolvia apenas `asset_id/state/media_asset_id`; no replay nem `media_asset_id` era retornado. Isso impedia o consumidor de aceitar a confirmação mesmo com upload concluído.

O ramo agora reautoriza pelo RPC existente, verifica o descritor do mesmo ativo e, somente depois da confirmação, projeta os quatro campos mínimos de `form_assets`. Exige estado `finalized` e igualdade de MIME/tamanho com o descritor. Retorna também os campos anteriores para compatibilidade. O replay fornece o mesmo envelope sem ler novamente o objeto R2. Não usa campo do cliente como autorização nem modifica SQL, grants, finalidade, buckets ou tokens.

Verificação local:

- RED: `06-answer-finalize-red.log`, 0 aprovados / 3 falhos esperados.
- GREEN com typecheck Deno: `06-answer-finalize-tests.log`, **53 aprovados / 0 falhos**, arquivos `index_test.ts`, `media_contract_test.ts`, `question_image_test.ts`.
- Cobertura focal: confirmação inicial, replay, projeção ausente/inconsistente/não confirmada e autorização negada. Os demais casos são regressão dos ramos existentes, sem somar reruns ao denominador.
- `git diff --check` sem erro de conteúdo; aviso de normalização LF/CRLF do checkout Windows.
- Nenhuma operação remota ou dado sintético criado por G3. Deploy e smoke pertencem a C0. Não certifica `forms.upload` E2E.

Gate de memória: compatibilidade de implementação corrigida; nenhuma regra nova de produto ou autorização. A evidência é o delta para o escritor central.
