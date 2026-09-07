---
title: "E2E 3 — crosswalk local da plataforma de mídia"
source: "ADR 0032; spec compartilhada de mídia de 2026-09-03; migrations e Edge Functions citadas abaixo; revisão independente crosswalk_media e review_media_session"
status: "audited-local; proposed-evolution; no-remote-mutation"
generated_at: "2026-09-07"
---

# Resultado e limite

`public.media_assets` existe, mas é um catálogo de Acontece, não o catálogo
universal implementado. As estruturas específicas abaixo não possuem FK para
ele nas migrations deste checkout. Nenhuma migration, objeto ou configuração
remota foi alterada nesta análise. A arquitetura alvo está aprovada; a evolução
descrita aqui é proposta técnica ainda sujeita a pacote nominal e revisão.

## Estruturas existentes

Os caminhos SQL são relativos a `packages/coelo_database/migrations/` e os
caminhos Edge a `packages/coelo_database/supabase/functions/`.

| Estrutura | Ownership/vínculo atual | Provedor/caminho atual | Evidência local |
| --- | --- | --- | --- |
| `public.media_assets` | Instituição, post obrigatório, pessoa proprietária; usos em `media_links` | Edge em Supabase `coelo-happens-mvp`; aceita provider R2 no schema | `20260820182000_happens_publication_mvp.sql:40`; `happens-media/index.ts:154` |
| `now_media_assets` | Publicação, instituição e pessoa; único por publicação/kind | Supabase `coelo-now-mvp`; substituição reutiliza chave e ativo por upsert | `20260820220000_now_publication_mvp.sql:47`, `:318`; `now-media/index.ts:233` |
| `moments_media_assets` | Publicação, instituição, pessoa e links ordenados | R2 legado `coelo-moments-private`; credenciais específicas MOMENTS | `20260821112822_moments_publication_mvp.sql:64`, `:104`; `moments-media/index.ts:40`, `:116` |
| `circular_media_assets` | Circular, instituição, pessoa; uso por revisão/bloco | Supabase `coelo-circulars-private`; imagem/vídeo/PDF juntos | `20260821190000_circulars_production.sql:110`, `:137`; `circular-media/index.ts:283` |
| `form_assets` | Instituição, ocorrência e item obrigatórios; pessoa ou segredo anônimo; vínculo em `form_answer_assets` | Supabase `coelo-forms-private`; CHECK de path `<hex2>/<uuid>` | `20260813155118_forms_responses_and_private_media.sql:74`, `:94`, `:108`; `form-media/media_contract.ts:1` |
| `meal_plan_image_assets` | Tenant, instituição opcional e exatamente um pai; FKs compostas, autor e replaced_asset_id | CHECK fixa Supabase `coelo-meal-plans-private` | `20260820171000_meal_plan_private_images.sql:27`, `:54`; `meal-plan-image-cleanup/index.ts:39` |
| `chat_attachment_metadata` | Mensagem e pessoa; escopo inferido da conversa | Provider R2; chave limitada por caracteres/traversal, sem bucket/variantes/entrega declarados nessa tabela | `20260812000000_chat_production_contract.sql:14`; `20260812120244_chat_rpc_contract_hardening.sql:55` |

## Evolução mínima proposta

- Evoluir a mesma `public.media_assets`, preservando IDs e compatibilidade de
  Acontece. Permitir `post_id` nulo, isoladamente, não basta: instituição e
  proprietário em `people` obrigatórios, FK do post com cascata, MIME limitado
  a JPEG/PNG/WebP/MP4, enum `happens_media_status` e idempotência por post também
  precisam de contratos explícitos para novos escopos/finalidades.
- Estruturas de domínio passam a apontar para o ativo canônico como extensões
  ou bindings. Não criar segundo catálogo universal nem autorização alternativa
  por coluna legada. Variantes, jobs e entregas são estruturas auxiliares.
- Alterar writers por vertical nominal, transacionalmente com autorização,
  ownership, metadados e vínculo. Não presumir objetos legados a migrar nem
  atualizar todos os providers silenciosamente.
- Novas substituições criam novo ativo/objeto. Agora não deve continuar o
  upsert da mesma chave. PDF resolve documentos; XLSX resolve transitório.

## Dependências concretas de Formulários (E2E 4)

1. `form-media/index.ts:79` exige `person_auth_links`; o RPC service-only
   `form_media_authorize_for_worker` permanece people-based
   (`20260813155126_forms_security_performance_closure.sql:261`). Introduzir
   autorização nominal por realm/contexto/capability sem fabricar pessoa para
   o ator interno. Reautorizar prepare, finalize, read e discard.
2. `form_assets` exige ocorrência/item de resposta: imagem de pergunta não
   cabe sem distinguir autoria e resposta. Não inventar ocorrência fictícia
   nem vínculo correlacionável para resposta anônima.
3. `form-media/index.ts:115`, `:150`, `:192` usa upload/download/assinatura
   Supabase; `media_contract.ts:126` e CHECKs fixam path legado. Schema e
   writer precisam evoluir juntos para o catálogo/R2.
4. Finalização (`index.ts:156`, `media_contract.ts:139`) valida assinatura MIME,
   bytes e SHA256, mas não prova decoder real, pixels/dimensões, normalização,
   remoção EXIF/GPS, variantes ou cleanup exigidos pela ADR 0032. Objeto deve
   permanecer invisível até processamento e binding transacional.
5. Reutilizar `form_file_jobs`, que já pertence ao formulário com ocorrência
   opcional, idempotência e expiração de 24 horas
   (`20260813155124_forms_jobs_notifications_and_exports.sql:31`). O contrato
   legado admite formatos excedentes, exige pessoa e path incompatível.
   `form-operations/index.ts:249` já gera XLSX; `:29` fixa bucket legado e
   `:189` aceita formatos fora do MVP. `form_multipart_uploads` também contém
   bucket/path legados.
6. A ADR 0032:120 aprova explicitamente o caminho transitório
   `tenants/<tenant_uuid>/exports/forms/<export_job_uuid>/responses.xlsx`.
   Isto é contrato alvo, não evidência de writer pronto. Download precisa
   reautorizar `forms.responses.export`, formulário e job antes do ticket.
7. O rastreador backend registra `form-export-download` v4 remoto sem fonte
   local. Recuperar proveniência nominal antes de substituir/deploy; não
   inferir implementação pelo nome da função.

## Divergências documentais a reconciliar pelo Coordenador/Owner

- Chat: ADR 0032:99 usa `communication/chat-message`; spec compartilhada:142
  usa `chat/chat-message` e sua tabela de domínios também define `chat`.
- Capa contextual: ADR 0032:82 usa `profiles/principal-context`; spec:137 usa
  `identity/principal-context`.

Não foi escolhida silenciosamente uma allowlist. Esses conflitos não impedem
preparar o contrato Forms já definido; impedem afirmar consenso da allowlist
geral. Foram enviados ao Coordenador para registro na fonte canônica, sem
editar os rastreadores compartilhados nesta worktree.

## Handoff e memória

- Branch: `codex/e2e-comunicacao-midia-principal`; base `1150ca30cb5fe414bf28b4aadabb3abcc85d4dec`.
- Prova: inspeção local e revisão independente; nenhum teste de objetos,
  introspecção Supabase remota ou cadeia E2E nesta análise.
- Estados dos action_ids: sem promoção Front-end, Back-end ou E2E.
- Próximo gate: contrato nominal + migration revisada e replay local antes de
  qualquer lease remoto. ETA de conclusão da plataforma ainda não calculável
  sem resolver schema/atores/processamento/runtime e credenciais por função.
- Gate de memória: `no-op`; não houve nova decisão aprovada. Este arquivo é
  evidência técnica, não projeção de produto nem registro de conversa bruta.
