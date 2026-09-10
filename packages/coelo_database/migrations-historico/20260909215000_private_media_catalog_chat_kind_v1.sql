-- E2 R02 / L01: entrada de Chat no catalogo privado de midia (ADR 0032).
--
-- CONTRATO ENTREGUE
--
-- Esta migration e o menor delta que da a Chat uma linha valida em
-- public.media_assets. Ela acrescenta o discriminador 'chat-attachment' ao
-- dominio de catalog_kind, define a forma bem-formada dessa linha e ensina o
-- validador de chave app_private.private_media_catalog_key_v1 a reconhecer o
-- escopo de chat sem quebrar o formato ja validado de Forms.
--
-- O dominio de catalog_kind nao vive em enum nem em CHECK proprio: ele e
-- imposto exclusivamente por media_assets_catalog_shape_ck, cujas alternativas
-- sao disjuntas por catalog_kind. Por isso "acrescentar o valor" e, aqui,
-- recriar essa constraint com um terceiro ramo.
--
-- POR QUE NOT VALID
--
-- A constraint nova e um superconjunto estrito da anterior: os ramos
-- 'legacy-happens' e 'form-image' sao reproduzidos caractere a caractere e o
-- ramo novo so pode ser satisfeito por linhas com catalog_kind =
-- 'chat-attachment', que hoje nao existem. Nenhuma linha existente pode
-- violar a constraint nova, logo a revalidacao do acervo seria um scan
-- completo sob ACCESS EXCLUSIVE sem poder de descoberta. NOT VALID evita esse
-- custo e continua sendo aplicada integralmente a todo INSERT e UPDATE futuro,
-- que e o unico ponto que importa para o contrato de Chat.
--
-- FORMA DA LINHA DE CHAT
--
-- Nulos obrigatorios: post_id, form_id, source_form_asset_id. Preenchidos:
-- storage_provider = 'r2', bucket_id = 'coelo-media-prod', media_purpose =
-- 'attachment', original_name = '' (o nome de arquivo humano continua em
-- public.chat_attachment_metadata.file_name; o catalogo fisico nao duplica
-- PII) e exatamente um dono entre owner_person_id e owner_internal_identity_id,
-- porque Chat existe tanto no realm de pessoas quanto no realm interno do
-- Superadmin. O ciclo pending -> ready segue a mesma disciplina de Forms:
-- pending nao declara bytes/checksum/dimensoes medidos e ready exige os tres.
-- O teto de bytes (26214400) e o unico limite de Chat ja aprovado no
-- repositorio, herdado do CHECK de public.chat_attachment_metadata.byte_size.
--
-- O QUE ESTA MIGRATION NAO ENTREGA (pendencias nominais, nao esquecimentos)
--
-- 1. Nao existe coluna de vinculo com conversa ou mensagem. media_bindings e
--    hoje acoplada a Forms por FK para form_versions/form_items e NAO foi
--    forcada a aceitar Chat. Consequencia: o UUID de mensagem que aparece na
--    object_key tem o FORMATO validado, mas o catalogo NAO verifica que essa
--    mensagem existe, esta viva ou pertence a mesma instituicao. Essa
--    verificacao pertence ao futuro caminho server-side de escrita.
-- 2. Nao ha nenhum grant novo. media_assets, media_variants e media_bindings
--    continuam fail-closed para public, anon, authenticated e service_role.
--    Portanto nenhum ator consegue inserir uma linha 'chat-attachment' hoje:
--    seria necessaria uma funcao security definer dedicada, que esta rodada
--    deliberadamente nao cria. Se algum grant vier a ser considerado
--    necessario, isso e decisao do coordenador, nao efeito colateral daqui.
-- 3. Chat nao ganha rendicao derivada: private_media_catalog_child_guard_v1
--    continua exigindo catalog_kind = 'form-image' para media_variants e
--    media_bindings, entao um ativo de chat nao pode ter 'preview' nem
--    binding. Como private_media_catalog_complete_v1 tambem so atua sobre
--    'form-image', um ativo de chat e completo sozinho.
-- 4. Somente imagem. O CHECK base de public.media_assets.mime_type admite
--    apenas image/jpeg, image/png, image/webp e video/mp4; application/pdf
--    nao cabe sem alterar aquela constraint, o que seria um delta maior do que
--    esta rodada autoriza. PDF de chat (coelo-documents-prod) e video de chat
--    ficam registrados como pendencia. Chat nao usa Cloudflare Stream no MVP.
--
-- Nada aqui e autorizacao: constraint nao autoriza. Ator, tenant, conversa,
-- participacao e finalidade continuam sendo responsabilidade do caminho
-- server-side que um dia escrever essas linhas.
begin;

alter table public.media_assets drop constraint media_assets_catalog_shape_ck;

alter table public.media_assets
  add constraint media_assets_catalog_shape_ck check ((
    (catalog_kind = 'legacy-happens'
      and post_id is not null and owner_person_id is not null and byte_size is not null
      and form_id is null and source_form_asset_id is null
      and owner_internal_identity_id is null and media_purpose is null
      and pixel_width is null and pixel_height is null)
    or
    (catalog_kind = 'form-image'
      and post_id is null and form_id is not null
      and storage_provider = 'r2' and bucket_id = 'coelo-media-prod'
      and original_name = '' and media_purpose is not null
      and mime_type in ('image/jpeg','image/png','image/webp')
      and (byte_size is null or byte_size between 1 and 4194304)
      and (
        (media_purpose = 'question-image' and source_form_asset_id is null
          and num_nonnulls(owner_person_id,owner_internal_identity_id) = 1)
        or (media_purpose = 'answer-image' and source_form_asset_id is not null
          and owner_internal_identity_id is null)
      )
      and (checksum_sha256 is null or checksum_sha256 ~ '^[0-9a-f]{64}$')
      and num_nonnulls(pixel_width,pixel_height) in (0,2)
      and ((pixel_width is null and pixel_height is null)
        or (pixel_width between 1 and 2560 and pixel_height between 1 and 2560))
      and (status <> 'ready' or (checksum_sha256 is not null
        and pixel_width is not null and pixel_height is not null
        and byte_size is not null))
      and (status <> 'pending' or (byte_size is null and checksum_sha256 is null
        and pixel_width is null and pixel_height is null))
    )
    or
    (catalog_kind = 'chat-attachment'
      and post_id is null and form_id is null and source_form_asset_id is null
      and storage_provider = 'r2' and bucket_id = 'coelo-media-prod'
      and original_name = '' and media_purpose = 'attachment'
      and num_nonnulls(owner_person_id,owner_internal_identity_id) = 1
      and mime_type in ('image/jpeg','image/png','image/webp')
      and (byte_size is null or byte_size between 1 and 26214400)
      and (checksum_sha256 is null or checksum_sha256 ~ '^[0-9a-f]{64}$')
      and num_nonnulls(pixel_width,pixel_height) in (0,2)
      and ((pixel_width is null and pixel_height is null)
        or (pixel_width between 1 and 2560 and pixel_height between 1 and 2560))
      and (status <> 'ready' or (checksum_sha256 is not null
        and pixel_width is not null and pixel_height is not null
        and byte_size is not null))
      and (status <> 'pending' or (byte_size is null and checksum_sha256 is null
        and pixel_width is null and pixel_height is null))
    )
  ) is true) not valid;

-- Mesmo formato opaco da ADR 0032:
--   <escopo>/<uuid do escopo>/<dominio>/<tipo de entidade>/<uuid da entidade>/
--   <finalidade>/<uuid do ativo>/<rendicao>/<uuid do objeto>.<ext>
-- O ramo de Forms e reproduzido sem alteracao. O ramo de Chat valida apenas o
-- FORMATO do UUID da mensagem: o catalogo nao conhece public.messages e nao
-- deriva autorizacao de chave. Qualquer outro catalog_kind cai em '$a', que
-- nao casa com nenhuma chave.
create or replace function app_private.private_media_catalog_key_v1(
  p_asset public.media_assets,p_rendition text,p_key text,p_mime text
) returns boolean language sql immutable security invoker set search_path = '' as $$
  select p_key ~ (
    '^tenants/' || p_asset.institution_id::text || '/'
    || case p_asset.catalog_kind
      when 'form-image' then 'forms/form/' || p_asset.form_id::text
      when 'chat-attachment' then
        'chat/message/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
      else '$a' end
    || '/' || p_asset.media_purpose || '/' || p_asset.id::text || '/' || p_rendition
    || '/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
    || case p_mime when 'image/jpeg' then '[.]jpg$' when 'image/png' then '[.]png$'
      when 'image/webp' then '[.]webp$' else '$a' end
  );
$$;

-- O guarda de ativo passa a reconhecer Chat antes do ramo de Forms. As duas
-- verificacoes anteriores continuam intactas: catalog_kind e imutavel e uma
-- linha ja gravada nao pode trocar identidade, escopo, chave nem regredir de
-- status. Um ativo de chat so valida escopo e chave; nao ha entidade de chat
-- no catalogo para conferir, e essa e exatamente a pendencia registrada acima.
create or replace function app_private.private_media_catalog_asset_guard_v1()
returns trigger language plpgsql security definer set search_path = '' as $$
declare target public.forms; source public.form_assets;
begin
  if tg_op = 'UPDATE' and new.catalog_kind is distinct from old.catalog_kind then
    raise check_violation using message = 'media_catalog_origin_immutable';
  end if;
  if new.catalog_kind = 'legacy-happens' then return new; end if;
  if tg_op = 'UPDATE' and (
    row(new.id,new.institution_id,new.form_id,new.source_form_asset_id,
      new.owner_person_id,new.owner_internal_identity_id,new.media_purpose,new.object_key,new.bucket_id)
    is distinct from
    row(old.id,old.institution_id,old.form_id,old.source_form_asset_id,
      old.owner_person_id,old.owner_internal_identity_id,old.media_purpose,old.object_key,old.bucket_id)
    or (old.status <> 'pending' and row(new.mime_type,new.byte_size,new.checksum_sha256,new.pixel_width,new.pixel_height)
      is distinct from row(old.mime_type,old.byte_size,old.checksum_sha256,old.pixel_width,old.pixel_height))
    or (old.status = 'deleted' and new.status <> 'deleted')
    or (old.status <> 'pending' and new.status = 'pending')
  ) then raise check_violation using message = 'media_catalog_identity_immutable'; end if;
  if new.catalog_kind = 'chat-attachment' then
    if not exists (select 1 from public.institutions institution
        where institution.id = new.institution_id and institution.deleted_at is null)
      or app_private.private_media_catalog_key_v1(new,'original',new.object_key,new.mime_type) is not true
    then raise check_violation using message = 'media_catalog_scope_invalid'; end if;
    return new;
  end if;
  select * into target from public.forms where id = new.form_id for share;
  if target.id is null or target.institution_id is distinct from new.institution_id
    or app_private.private_media_catalog_key_v1(new,'original',new.object_key,new.mime_type) is not true
  then raise check_violation using message = 'media_catalog_scope_invalid'; end if;
  if new.media_purpose = 'answer-image' then
    select * into source from public.form_assets where id = new.source_form_asset_id for share;
    if source.id is null or source.institution_id is distinct from new.institution_id
      or source.prepared_by_person_id is distinct from new.owner_person_id
      or ((source.prepared_by_person_id is null) <> (target.identity_mode = 'anonymous'))
      or (new.status = 'ready' and source.state <> 'finalized')
      or not exists (select 1 from public.form_occurrences occurrence
        where occurrence.id = source.occurrence_id and occurrence.form_id = target.id
          and occurrence.institution_id = new.institution_id)
    then raise check_violation using message = 'media_catalog_response_owner_invalid'; end if;
  elsif new.media_purpose = 'question-image' and
    ((target.created_by_internal_identity_id is null) <> (new.owner_internal_identity_id is null)) then
    raise check_violation using message = 'media_catalog_author_realm_invalid';
  end if;
  return new;
end;
$$;

revoke all on function app_private.private_media_catalog_key_v1(public.media_assets,text,text,text),
  app_private.private_media_catalog_asset_guard_v1() from public,anon,authenticated,service_role;

comment on constraint media_assets_catalog_shape_ck on public.media_assets is
  'ADR0032: forma bem-formada por catalog_kind. NOT VALID por ser superconjunto estrito da versao anterior; aplica-se integralmente a toda escrita futura.';
commit;
