---
title: "Contrato de mídia privada para Chat (L01 → L02)"
source: "decisions/0032-mvp-private-media-r2.md; packages/coelo_database/migrations/20260908160000_private_media_catalog_r2_v1.sql; packages/coelo_database/migrations/20260908215522_forms_superadmin_media_read_r2_v1.sql; packages/coelo_database/migrations/20260909135000_private_media_catalog_chat_kind_v1.sql; packages/coelo_database/migrations/20260812000000_chat_production_contract.sql; packages/coelo_database/migrations/20260812120244_chat_rpc_contract_hardening.sql; packages/coelo_database/migrations/20260901101500_superadmin_internal_chat_v2.sql; packages/coelo_api/lib/src/media/"
status: "contrato-proposto-para-consumo-de-l02"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Contrato de mídia privada para Chat (L01 → L02)

Este documento responde ao pedido de L02: um `catalog_kind` de chat no catálogo
privado e o contrato de emissão de ticket de upload e de leitura. É contrato,
não implementação. Tudo que está descrito como "existe" foi lido no repositório
e está citado com caminho; tudo que está descrito como pendência **não foi
implementado nesta rodada**.

Chat **não usa Cloudflare Stream no MVP**. Nenhuma peça abaixo depende de
Stream, e nenhuma deve ser desenhada assumindo que ele exista.

## 1. O que a migration entrega

`packages/coelo_database/migrations/20260909135000_private_media_catalog_chat_kind_v1.sql`

1. **Discriminador novo.** `catalog_kind = 'chat-attachment'` passa a fazer
   parte do domínio de `public.media_assets`. Esse domínio não é enum nem CHECK
   próprio: ele é imposto só por `media_assets_catalog_shape_ck`, cujos ramos
   são disjuntos por `catalog_kind`. A constraint foi recriada com um terceiro
   ramo, como `NOT VALID` — ela é superconjunto estrito da anterior, então
   nenhuma linha existente pode violá-la e revalidar o acervo seria um scan
   completo sob `ACCESS EXCLUSIVE` sem poder de descoberta. `NOT VALID` continua
   valendo integralmente para todo `INSERT` e `UPDATE` futuro.
2. **Forma bem-formada da linha de chat.** Nulos obrigatórios: `post_id`,
   `form_id`, `source_form_asset_id`. Preenchidos: `storage_provider = 'r2'`,
   `bucket_id = 'coelo-media-prod'`, `media_purpose = 'attachment'`,
   `original_name = ''` e exatamente um dono entre `owner_person_id` e
   `owner_internal_identity_id` (Chat existe nos dois realms). O ciclo
   `pending -> ready` segue a disciplina de Forms: `pending` não declara
   bytes/checksum/dimensões, `ready` exige os três. Teto de bytes 26 214 400,
   herdado do CHECK já aprovado em `public.chat_attachment_metadata.byte_size`.
   O nome humano do arquivo continua em `chat_attachment_metadata.file_name`; o
   catálogo físico não duplica esse dado.
3. **Validador de chave generalizado.** `app_private.private_media_catalog_key_v1`
   ganhou um ramo de chat, mantendo o formato opaco da ADR 0032:

   ```
   tenants/<institution_id>/chat/message/<message_uuid>/attachment/<asset_id>/<rendition>/<object_uuid>.<ext>
   ```

   O ramo de Forms foi reproduzido caractere a caractere e continua válido.
   Qualquer outro `catalog_kind` cai num padrão que não casa com nenhuma chave.
4. **Guarda de ativo.** `app_private.private_media_catalog_asset_guard_v1`
   reconhece Chat antes do ramo de Forms: valida instituição viva e formato de
   chave, e mantém as invariantes já existentes (`catalog_kind` imutável,
   identidade/escopo/chave imutáveis, sem regressão de status).

## 2. O que a migration NÃO entrega

Estas são pendências nominais, não esquecimentos:

1. **Nenhum vínculo com conversa ou mensagem no banco.** `public.media_bindings`
   é acoplada a Forms por FK para `form_versions`/`form_items` e **não** foi
   forçada a aceitar Chat. O UUID de mensagem na `object_key` tem o **formato**
   validado, mas o catálogo **não verifica** que a mensagem existe, está viva ou
   pertence à mesma instituição. Essa verificação pertence ao caminho
   server-side de escrita (item 5 abaixo).
2. **Nenhum grant novo.** `media_assets`, `media_variants` e `media_bindings`
   continuam fail-closed para `public`, `anon`, `authenticated` e
   `service_role`. Consequência direta: **hoje ninguém consegue inserir uma
   linha `chat-attachment`**. Seria necessária uma função `security definer`
   dedicada, que esta rodada deliberadamente não cria. Se algum grant vier a ser
   considerado necessário, é decisão do coordenador — não deve ser adicionado
   como efeito colateral de uma feature.
3. **Sem rendição derivada.** `private_media_catalog_child_guard_v1` continua
   exigindo `catalog_kind = 'form-image'` para `media_variants`/`media_bindings`,
   então um ativo de chat não pode ter `preview` nem binding. Como
   `private_media_catalog_complete_v1` também só atua sobre `form-image`, um
   ativo de chat é completo sozinho.
4. **Somente imagem.** O CHECK base de `public.media_assets.mime_type` admite
   `image/jpeg`, `image/png`, `image/webp` e `video/mp4`. `application/pdf` não
   cabe sem alterar aquela constraint, o que seria um delta maior do que esta
   rodada autoriza. PDF de chat (`coelo-documents-prod`) e vídeo de chat ficam
   registrados como pendência.

## 3. Contrato de leitura — o padrão a copiar

O par de RPCs de Forms em
`packages/coelo_database/migrations/20260908215522_forms_superadmin_media_read_r2_v1.sql`
é o padrão vigente no repositório. Chat deve consumir a **mesma forma**, com a
sua própria capacidade e a sua própria permissão.

### 3.1 `public.superadmin_form_authorize_media_read_v2(p_query jsonb) returns jsonb`

- **Quem autoriza:** `grant execute ... to authenticated`; `public`, `anon` e
  `service_role` estão revogados. Internamente chama
  `app_private.require_superadmin_internal_context('forms.responses.read')`.
- **Escopo de autorização:** identidade interna, link, membership, sessão viva
  em `auth.sessions`, `aal` em (`aal1`,`aal2`) e `scope_kind` em
  (`platform`,`institution`). Em escopo institucional, a instituição do recurso
  precisa bater com a do ator. O contexto é revalidado **depois** de resolver o
  descritor, e o par precisa ser idêntico ao inicial.
- **Entrada:** objeto com exatamente `asset_id` (UUID) e `rendition`
  (`original`|`preview`); qualquer chave extra, tipo errado ou payload acima de
  32 KiB é `SAI_INVALID_ARGUMENT`. Exige isolamento `read committed`.
- **Saída:** `{ok, error, data:{asset_id, rendition, read_token, expires_at}}`.
- **Ciclo de vida / TTL:** grava em `app_private.form_media_read_tokens` apenas
  o **hash SHA-256** do token; o token cru só existe na resposta. TTL máximo de
  **2 minutos**, imposto por CHECK (`expires_at <= created_at + interval '2
  minutes'`). Uso único. A linha é imutável exceto por `consumed_at`, via
  trigger `forms_media_read_token_immutable_v1`.
- **Fail-closed:** qualquer negação retorna envelope de erro correlacionado e
  audita a denegação; a auditoria de sucesso roda **fora** do bloco recuperável,
  de modo que falha de auditoria desfaz a emissão do ticket.

### 3.2 `public.form_redeem_media_read_r2_v1(p_read_token text) returns jsonb`

- **Quem autoriza:** `grant execute ... to service_role`; `authenticated`,
  `anon` e `public` revogados. É o gateway server-side que resgata, nunca o
  cliente.
- **Escopo de autorização:** consome o token **antes** de reautorizar (um replay
  concorrente espera e depois não encontra linha não consumida), reconstrói o
  contexto do ator a partir da sessão registrada, refaz o descritor e compara
  campo a campo com o que foi gravado na emissão. Divergência é negação.
- **Saída:** descritor sem `response_id`/`form_version_id`/`item_id`, mais
  `expires_at`. Negação retorna `null` — sem vazar motivo ao transporte.
- **Fail-closed:** expirado, consumido, sessão morta, permissão revogada ou
  descritor divergente resultam em `null` com auditoria `denied`.

### 3.3 O que Chat precisa ter de equivalente

Um par próprio, por exemplo `chat_authorize_media_read_*` (grant a
`authenticated`) e `chat_redeem_media_read_*` (grant a `service_role`), com
tabela própria de capacidades hash-only e TTL curto, ancorado na permissão de
leitura de conversa de Chat — **não** em `forms.responses.read`. Isso é
pendência de L01 (ver seção 6).

## 4. Contrato de upload e de leitura no cliente — o que já é estável em Dart

`packages/coelo_api/lib/src/media/` já define o contrato de cliente e **não
precisa de refatoração**:

| Peça | Papel | Fail-closed relevante |
| --- | --- | --- |
| `MediaUploadGateway` | interface do adaptador de domínio: `prepare`, `finalize`, `reconcile`, `discard`, ligada a um `MediaUploadTarget` imutável | **não tem nenhuma implementação de produção hoje**; só o teste em `packages/coelo_api/test/media/media_uploader_test.dart` |
| `SessionMediaUploader` | orquestração: um único PUT, sem redirect, cookie, interceptor de auth ou retry implícito; PUT/finalize ambíguo gera **uma** reconciliação explícita, nunca DELETE automático | limpa buffers e cancela o transfer na invalidação de sessão |
| `MediaUploadTarget` | correlação (`institution_id`, `resource_id`, `domain`, `purpose`) | é correlação, **não** autorização; o servidor deriva ator, ownership e finalidade por conta própria |
| `MediaUploadMetadata` / `MediaUploadSource` | metadados declarados e cópia própria dos bytes | declaração nunca substitui medição server-side; `clear()` zera o buffer |
| `MediaUploadTicket` / `MediaUploadPreparation` | capacidade PUT temporária; só o estado `uploadRequired` carrega ticket | rejeita URL não-HTTPS, fragmento, `userInfo`, header duplicado e headers proibidos (`authorization`, `cookie`, `x-api-key`, `host`, …) |
| `MediaUploadReceipt` / `MediaUploadResult` | recibo produzido **só** após validação real no servidor | o cliente não pode inventar recibo |
| `MediaReader` / `SessionMediaReader` | leitura via gateway, sem cache nem polling implícito | valida correlação de `asset_id` e recusa ticket já expirado |
| `MediaReadRequest` / `MediaReadResult` / `MediaReadTicket` | rendição pedida e capacidade temporária de leitura | ticket só existe no estado `available`; não logar nem persistir URL/headers |
| `MediaSession` | fronteira de tempo de vida por sessão/contexto autorizado | `invalidate()` marca inválido de forma síncrona e dispara todos os purges; falha de purge nunca reativa a sessão |

**L02 pode escrever o adapter direto contra `MediaUploadGateway` sem esperar
refatoração.** O contrato está fechado; o que falta é o servidor do outro lado.

## 5. Quem grava a linha em `public.chat_attachment_metadata`

Situação atual, verificada: `public.superadmin_chat_send_message_v2(uuid, text,
uuid)` é text-only e tem grant para `authenticated`; a sobrecarga que aceitava
`p_attachment_ids` foi dropada em `20260812120244_chat_rpc_contract_hardening.sql`;
nada no repositório insere em `public.chat_attachment_metadata`; os grants em
`20260812000000_chat_production_contract.sql` dão `select` a `authenticated` e
`all` somente a `service_role`.

**Recomendação de contrato (L01): opção (a) — o caminho server-side de
resgate/finalize grava a linha, e o cliente fica inteiramente fora da escrita
de metadados de mídia.**

Justificativa, toda ela apoiada no que já é padrão no repositório:

1. O cliente nunca escreve metadados de mídia. Em Forms, `authenticated` só
   consegue **pedir** capacidade; a escrita física do catálogo não tem grant
   nenhum, e `media_variants`/`media_bindings` são fail-closed para todos os
   papéis.
2. Quem consome o ticket é `service_role`: `form_redeem_media_read_r2_v1` tem
   grant exclusivo para `service_role`, e é ele quem materializa o efeito.
3. A autorização é revalidada no servidor **no momento do resgate**, não no
   momento em que o cliente afirma ter subido o arquivo. O resgate consome a
   capacidade antes de reautorizar e compara o descritor recomputado com o que
   foi gravado na emissão.
4. `MediaUploadGateway.finalize` já é o ponto natural desse commit no contrato
   Dart, e `reconcile` já cobre o caso ambíguo sem DELETE automático.

A opção (b) — o envio de mensagem passar a aceitar ids de anexo já finalizados —
reabriria uma superfície que foi deliberadamente fechada em `20260812120244` e
faria o cliente carregar ids que o servidor teria de reautorizar de qualquer
forma. Não é recomendada.

**Isto é uma recomendação de contrato. A RPC de staging/commit correspondente
NÃO está sendo implementada nesta rodada.** É pendência nominal.

## 6. O que ainda falta para `chat.attach` funcionar de fato

De **L01** (back-end / gateway):

1. RPC de staging/commit de anexo de chat (`security definer`), que valide
   conversa, participação, tenant e finalidade, insira a linha
   `chat-attachment` em `media_assets` e, no commit, grave
   `public.chat_attachment_metadata` — conforme a recomendação (a) da seção 5.
2. Par de RPCs de capacidade de leitura de mídia de chat, no molde da seção 3,
   com tabela própria hash-only, TTL curto e uso único.
3. Edge Function de `chat-media` (assinatura R2 e transporte), que hoje **não
   existe**; nenhuma credencial R2 pode viver no banco ou no cliente.
4. Decisão do coordenador sobre PDF e vídeo em chat (exigem alterar o CHECK base
   de `media_assets.mime_type` e admitir `coelo-documents-prod`).
5. Decisão do coordenador sobre vincular ativo de chat à mensagem no banco — hoje
   o vínculo só existe no formato da `object_key`.

De **L02** (cliente):

1. Adapter Dart implementando `MediaUploadGateway` contra as RPCs acima, e o
   `MediaUploadPut` de transporte.
2. Consumo de `SessionMediaUploader`/`SessionMediaReader` na UI de Chat, com
   `MediaSession` invalidada no logout e em troca de contexto sensível.
3. UI de anexo, estados de envio/reconciliação e o comportamento do envio de
   mensagem enquanto `superadmin_chat_send_message_v2` continuar text-only.

Enquanto 1 e 3 de L01 não existirem, `chat.attach` permanece bloqueado ponta a
ponta, e nada aqui deve ser declarado concluído.

## 7. Prova local desta entrega

`packages/coelo_database/supabase/tests/private_media_catalog_chat_kind_v1_test.sql`
foi executado em container Postgres descartável
(`public.ecr.aws/supabase/postgres:17.6.1.165`), com replay parcial e nominal
das migrations necessárias: **50 asserções, 50 `ok`, 0 `not ok`, plano `1..50`**.
Cobre o discriminador novo aceito, os antigos ainda aceitos, linhas de chat
malformadas recusadas, chave de chat bem formada aceita e malformada recusada,
formato de Forms preservado e ausência de grants em
`media_variants`/`media_bindings` para `anon`, `authenticated` e `service_role`.
Nada foi aplicado em Supabase ou Cloudflare remoto. Isto é prova local, não
certificação ponta a ponta.
