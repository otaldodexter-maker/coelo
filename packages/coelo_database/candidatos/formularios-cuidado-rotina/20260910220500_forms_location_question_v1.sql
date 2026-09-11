-- P16 (ADR 0034, Decisoes 9, 10 e 12): pergunta de Local em Formularios.
-- Grupo formularios-cuidado-rotina, Rodada 4 (E2-R04-20260911); action_id
-- forms.location-question e forms.location-answer.
--
-- O que este pacote faz, sobre a baseline de producao + lotes 1..14:
--   * novo tipo de item `location` em form_items.kind e em form_answers.answer_kind
--     (a coluna e text com CHECK, nao enum: por isso nao existe arquivo
--     20260910220450 com ALTER TYPE ... ADD VALUE);
--   * opcao 1 da Decisao 9 (opcoes fixas, nao catalogo vivo): as opcoes de um
--     item `location` sao resolvidas pelo servidor a partir do catalogo de
--     Locais (public.activity_locations, status='active', mesma instituicao do
--     formulario) no salvamento do rascunho e de novo na publicacao, e ficam
--     congeladas em form_question_options com o snapshot (location_id, nome no
--     label, location_status). O cliente nao envia nem escolhe opcoes de Local;
--     o que ele enviar para um item `location` e ignorado;
--   * opcao 2 da Decisao 9 (local revogado depois): ao gravar, reenviar ou
--     editar uma resposta, o local escolhido precisa existir no snapshot E
--     continuar ativo no catalogo. Nao se preserva apontamento historico nem
--     ha substituicao automatica: a pessoa escolhe de novo entre os validos.
--     Erro: 23514 'form location answer requires a current location'
--     (detail FORMS_LOCATION_REVOKED);
--   * caso extra da Decisao 12: pergunta obrigatoria, visivel, sem nenhuma
--     alternativa valida (todos os locais do snapshot revogados) fica
--     bloqueada com aviso, sem forcar escolha invalida. Erro: 23514
--     'required location question has no available location'
--     (detail FORMS_LOCATION_NO_AVAILABLE_OPTION). A projecao da definicao
--     expoe por opcao `location_id`, `location_status` (snapshot) e
--     `location_available` (leitura viva) para o cliente desenhar o aviso;
--   * exportacao XLSX (superadmin_form_request_xlsx_v2) passa a aceitar
--     opcoes e respostas de `location` como as de escolha unica.
--
-- Sem AAL2, sem segredo, sem grant novo a cliente: as funcoes novas ficam em
-- app_private com revoke de public, anon, authenticated e service_role; as
-- substituidas mantem dono e ACL (CREATE OR REPLACE preserva).
--
-- Reversao (manual, forward-only): recriar as tres constraints sem
-- 'location', dropar as colunas location_id/location_status de
-- form_question_options e as funcoes *_v1 deste arquivo, e reaplicar as
-- versoes anteriores das funcoes substituidas (20260910230004 e baseline).

begin;
set local lock_timeout = '5s';
set local statement_timeout = '120s';

do $preflight$
declare xlsx_def text; pat text; occurrences integer;
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'forms location candidate requires postgres';
  end if;
  if to_regclass('public.form_items') is null or to_regclass('public.form_answers') is null
    or to_regclass('public.form_question_options') is null or to_regclass('public.form_answer_options') is null
    or to_regclass('public.activity_locations') is null
    or to_regprocedure('app_private.superadmin_form_replace_draft_definition_v2(uuid,jsonb)') is null
    or to_regprocedure('app_private.superadmin_form_validate_draft_definition_v2(uuid)') is null
    or to_regprocedure('app_private.validate_form_definition(uuid)') is null
    or to_regprocedure('app_private.form_replace_response_answers(public.form_responses,jsonb,text)') is null
    or to_regprocedure('app_private.form_assert_required_response_answers(public.form_responses)') is null
    or to_regprocedure('app_private.form_definition_projection(uuid,uuid)') is null
    or to_regprocedure('app_private.form_publish(uuid,bigint,jsonb)') is null
    or to_regprocedure('app_private.superadmin_form_request_xlsx_v2(uuid,bigint,jsonb)') is null
    or to_regprocedure('app_private.form_assert_payload_keys(jsonb,text[],text)') is null
    or to_regprocedure('app_private.superadmin_form_validate_draft_payload_v2(jsonb)') is null then
    raise object_not_in_prerequisite_state using message = 'forms location dependencies missing';
  end if;
  if not exists (select 1 from pg_attribute where attrelid = 'public.activity_locations'::regclass
      and attname = 'scope_kind' and not attisdropped) then
    raise object_not_in_prerequisite_state using message = 'location catalog v2 (20260910230013) required';
  end if;
  if exists (select 1 from pg_attribute where attrelid = 'public.form_question_options'::regclass
      and attname in ('location_id', 'location_status') and not attisdropped) then
    raise object_not_in_prerequisite_state using message = 'forms location package already applied';
  end if;
  if not exists (select 1 from pg_constraint where conrelid = 'public.form_items'::regclass and conname = 'form_items_kind_ck'
      and pg_get_constraintdef(oid) like '%''gallery''::text, ''information''::text%' and pg_get_constraintdef(oid) not like '%location%')
    or not exists (select 1 from pg_constraint where conrelid = 'public.form_answers'::regclass and conname = 'form_answers_kind_ck'
      and pg_get_constraintdef(oid) not like '%location%')
    or not exists (select 1 from pg_constraint where conrelid = 'public.form_answers'::regclass and conname = 'form_answers_typed_value_ck'
      and pg_get_constraintdef(oid) like '%''single_choice''::text, ''multiple_choice''::text, ''photo''::text, ''gallery''::text%') then
    raise object_not_in_prerequisite_state using message = 'forms kind constraints drift';
  end if;
  xlsx_def := pg_get_functiondef('app_private.superadmin_form_request_xlsx_v2(uuid,bigint,jsonb)'::regprocedure);
  foreach pat in array array[
    $p$and (o.form_version_id<>i.form_version_id or i.kind not in ('single_choice','multiple_choice')))$p$,
    $p$where o.id is null or a.answer_kind not in ('single_choice','multiple_choice'))$p$,
    $p$when a.answer_kind in ('single_choice','multiple_choice') then coalesce(($p$
  ] loop
    occurrences := (length(xlsx_def) - length(replace(xlsx_def, pat, ''))) / length(pat);
    if occurrences <> 1 then
      raise object_not_in_prerequisite_state using message = 'xlsx exporter body drift: ' || pat;
    end if;
  end loop;
end
$preflight$;

-- 1. Tipo de item e de resposta.
alter table public.form_items drop constraint form_items_kind_ck;
alter table public.form_items add constraint form_items_kind_ck check (kind = any (array[
  'short_text', 'integer', 'decimal', 'money', 'date', 'yes_no', 'single_choice', 'multiple_choice',
  'scale', 'photo', 'gallery', 'information', 'location']));
alter table public.form_answers drop constraint form_answers_kind_ck;
alter table public.form_answers add constraint form_answers_kind_ck check (answer_kind = any (array[
  'short_text', 'integer', 'decimal', 'money', 'date', 'yes_no', 'single_choice', 'multiple_choice',
  'scale', 'photo', 'gallery', 'location']));
alter table public.form_answers drop constraint form_answers_typed_value_ck;
alter table public.form_answers add constraint form_answers_typed_value_ck check (
  num_nonnulls(text_value, integer_value, decimal_value, money_minor_units, date_value, yes_no_value, scale_value)
  = case when answer_kind = any (array['single_choice', 'multiple_choice', 'photo', 'gallery', 'location']) then 0 else 1 end);

-- 2. Snapshot do Local na opcao congelada.
alter table public.form_question_options
  add column location_id uuid,
  add column location_status text,
  add constraint form_options_location_snapshot_ck check (
    num_nonnulls(location_id, location_status) in (0, 2)
    and (location_status is null or location_status = 'active'));
create index form_options_location_id_idx on public.form_question_options(location_id) where location_id is not null;
comment on column public.form_question_options.location_id is
  'P16: id do Local do catalogo congelado nesta opcao (item kind=location). Nao e FK: revogar ou apagar o Local nao altera o snapshot; a validade e reconferida ao gravar a resposta.';
comment on column public.form_question_options.location_status is
  'P16: status do Local no momento do snapshot (v1 congela apenas locais ativos).';

-- 3. Resolucao do snapshot a partir do catalogo (server-side, sem cliente).
create function app_private.form_location_options_snapshot_v1(p_institution_id uuid)
returns table(location_id uuid, name text, status text)
language sql stable security definer set search_path = '' as $$
  select l.id, l.name, l.status::text
    from public.activity_locations l
   where l.institution_id = p_institution_id and l.status = 'active'
   order by lower(l.name), l.name, l.id
   limit 201;
$$;

create function app_private.form_apply_location_options_v1(p_version_id uuid)
returns void language plpgsql volatile security definer set search_path = '' as $$
declare
  target_institution uuid;
  item_row public.form_items;
  option_count integer;
begin
  select f.institution_id into target_institution
    from public.form_versions v join public.forms f on f.id = v.form_id
   where v.id = p_version_id;
  if target_institution is null then
    raise invalid_parameter_value using message = 'form version unavailable';
  end if;
  for item_row in select * from public.form_items where form_version_id = p_version_id and kind = 'location' loop
    if exists (select 1 from public.form_answer_options ao join public.form_question_options o on o.id = ao.option_id
               where o.item_id = item_row.id) then
      raise check_violation using message = 'location options with answers cannot be replaced';
    end if;
    delete from public.form_question_options where item_id = item_row.id;
    insert into public.form_question_options(form_version_id, item_id, label, position, location_id, location_status)
    select p_version_id, item_row.id, btrim(s.name), row_number() over (order by lower(s.name), s.name, s.location_id) - 1,
           s.location_id, s.status
      from app_private.form_location_options_snapshot_v1(target_institution) s;
    select count(*) into option_count from public.form_question_options where item_id = item_row.id;
    if option_count > 200 then
      raise check_violation using message = 'location item cannot snapshot more than 200 locations';
    end if;
  end loop;
end;
$$;

create function app_private.form_location_option_available_v1(p_option_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.form_question_options o
    join public.activity_locations l on l.id = o.location_id
    where o.id = p_option_id and l.institution_id = (
      select f.institution_id from public.form_versions v join public.forms f on f.id = v.form_id
      where v.id = o.form_version_id)
      and l.status = 'active');
$$;

-- 3b. Validador do payload (realm interno v2): as chaves de snapshot que a
--     projecao devolve nas opcoes de `location` sao toleradas no eco do
--     cliente; para os demais tipos o contrato de opcao nao muda. Corpo de
--     20260910230004 com uma condicao a mais.
create or replace function app_private.superadmin_form_validate_draft_payload_v2(p_payload jsonb)
returns void language plpgsql immutable security definer set search_path='' as $function$
declare
  s jsonb; i jsonb; o jsonb; c jsonb;
  field_name text;
  section_position integer:=0;
  item_position integer;
  option_position integer;
  item_count integer:=0;
begin
  -- Technical request ceiling; relational limits below remain authoritative.
  if p_payload is null or pg_catalog.jsonb_typeof(p_payload) is distinct from 'object'
    or pg_catalog.octet_length(p_payload::text)>33554432
    or p_payload-array['id','institution_id','kind','identity_mode','response_unit','title','description','sections']<>'{}'::jsonb
    or not (p_payload ?& array['institution_id','kind','identity_mode','response_unit','title','sections']) then
    raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
  end if;
  foreach field_name in array array['institution_id','kind','identity_mode','response_unit','title'] loop
    if pg_catalog.jsonb_typeof(p_payload->field_name) is distinct from 'string' then
      raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
    end if;
  end loop;
  foreach field_name in array array['id','description'] loop
    if p_payload ? field_name and p_payload->field_name<>'null'::jsonb
      and pg_catalog.jsonb_typeof(p_payload->field_name)<>'string' then
      raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
    end if;
  end loop;
  if p_payload->>'institution_id' !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    or (p_payload->>'id' is not null and p_payload->>'id' !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
    or p_payload->>'kind' not in ('form','quick_poll')
    or p_payload->>'identity_mode' not in ('identified','anonymous')
    or p_payload->>'response_unit' not in ('person','child_family_context')
    or pg_catalog.char_length(btrim(p_payload->>'title')) not between 1 and 200
    or pg_catalog.char_length(p_payload->>'description')>4000
    or pg_catalog.jsonb_typeof(p_payload->'sections') is distinct from 'array' then
    raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
  end if;
  if pg_catalog.jsonb_array_length(p_payload->'sections')>20 then raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT'; end if;
  for s in select value from pg_catalog.jsonb_array_elements(p_payload->'sections') loop
    if pg_catalog.jsonb_typeof(s) is distinct from 'object'
      or s-array['id','title','description','position','items']<>'{}'::jsonb
      or not (s ?& array['id','title','position','items']) then raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT'; end if;
    if pg_catalog.jsonb_typeof(s->'id') is distinct from 'string' or pg_catalog.char_length(s->>'id') not between 1 and 128
      or pg_catalog.jsonb_typeof(s->'title') is distinct from 'string'
      or pg_catalog.jsonb_typeof(s->'position') is distinct from 'number' or s->>'position' !~ '^[0-9]+$'
      or (s->>'position')::integer<>section_position
      or pg_catalog.jsonb_typeof(s->'items') is distinct from 'array'
      or (s ? 'description' and s->'description'<>'null'::jsonb and pg_catalog.jsonb_typeof(s->'description')<>'string') then
      raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
    end if;
    section_position:=section_position+1; item_position:=0;
    for i in select value from pg_catalog.jsonb_array_elements(s->'items') loop
      item_count:=item_count+1;
      if item_count>200 or pg_catalog.jsonb_typeof(i) is distinct from 'object'
        or i-array['id','kind','label','help_text','position','is_required','config','options','conditions']<>'{}'::jsonb
        or not (i ?& array['id','kind','label','position']) then raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT'; end if;
      foreach field_name in array array['id','kind','label'] loop
        if pg_catalog.jsonb_typeof(i->field_name) is distinct from 'string' then raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT'; end if;
      end loop;
      if pg_catalog.char_length(i->>'id') not between 1 and 128
        or pg_catalog.jsonb_typeof(i->'position') is distinct from 'number' or i->>'position' !~ '^[0-9]+$'
        or (i->>'position')::integer<>item_position
        or (i ? 'help_text' and i->'help_text'<>'null'::jsonb and pg_catalog.jsonb_typeof(i->'help_text')<>'string')
        or (i ? 'is_required' and pg_catalog.jsonb_typeof(i->'is_required') is distinct from 'boolean')
        or (i ? 'config' and pg_catalog.jsonb_typeof(i->'config') is distinct from 'object') then
        raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
      end if;
      item_position:=item_position+1; option_position:=0;
      foreach field_name in array array['options','conditions'] loop
        if i ? field_name and pg_catalog.jsonb_typeof(i->field_name) is distinct from 'array' then raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT'; end if;
      end loop;
      if pg_catalog.jsonb_array_length(coalesce(i->'options','[]'))>50
        or pg_catalog.jsonb_array_length(coalesce(i->'conditions','[]'))>200 then raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT'; end if;
      for o in select value from pg_catalog.jsonb_array_elements(coalesce(i->'options','[]')) loop
        -- P16: a projecao devolve location_id/location_status/location_available nas
        -- opcoes de item `location`; o cliente pode devolve-las e o servidor as ignora.
        if pg_catalog.jsonb_typeof(o) is distinct from 'object'
          or o-array['id','label','position','location_id','location_status','location_available']<>'{}'::jsonb
          or (i->>'kind'<>'location' and o-array['id','label','position']<>'{}'::jsonb)
          or not (o ?& array['id','label','position'])
          or pg_catalog.jsonb_typeof(o->'id') is distinct from 'string' or pg_catalog.char_length(o->>'id') not between 1 and 128
          or pg_catalog.jsonb_typeof(o->'label') is distinct from 'string'
          or pg_catalog.jsonb_typeof(o->'position') is distinct from 'number' or o->>'position' !~ '^[0-9]+$'
          or (o->>'position')::integer<>option_position then raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT'; end if;
        option_position:=option_position+1;
      end loop;
      for c in select value from pg_catalog.jsonb_array_elements(coalesce(i->'conditions','[]')) loop
        if pg_catalog.jsonb_typeof(c) is distinct from 'object'
          or c-array['source_item_id','kind','expected_yes_no','option_ids']<>'{}'::jsonb
          or pg_catalog.jsonb_typeof(c->'source_item_id') is distinct from 'string'
          or pg_catalog.char_length(c->>'source_item_id') not between 1 and 128
          or pg_catalog.jsonb_typeof(c->'kind') is distinct from 'string'
          or c->>'kind' not in ('yes_no','choice') then raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT'; end if;
        if c->>'kind'='yes_no' then
          if pg_catalog.jsonb_typeof(c->'expected_yes_no') is distinct from 'boolean'
            or (c ? 'option_ids' and c->'option_ids' not in ('[]'::jsonb,'null'::jsonb)) then raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT'; end if;
        else
          if (c ? 'expected_yes_no' and c->'expected_yes_no'<>'null'::jsonb)
            or pg_catalog.jsonb_typeof(c->'option_ids') is distinct from 'array' then raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT'; end if;
          if pg_catalog.jsonb_array_length(c->'option_ids') not between 1 and 50
            or exists(select 1 from pg_catalog.jsonb_array_elements(c->'option_ids') v where pg_catalog.jsonb_typeof(v)<>'string' or pg_catalog.char_length(v#>>'{}') not between 1 and 128) then
            raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
          end if;
        end if;
      end loop;
    end loop;
  end loop;
end
$function$;

-- 4. Substituicao da definicao do rascunho (realm interno v2): opcoes de
--    `location` enviadas pelo cliente sao ignoradas; o snapshot e do servidor.
create or replace function app_private.superadmin_form_replace_draft_definition_v2(
  p_version_id uuid,
  p_sections jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  section_json jsonb;
  item_json jsonb;
  option_json jsonb;
  condition_json jsonb;
  source_section_id text;
  source_item_id text;
  source_option_id text;
  section_ids jsonb := '{}'::jsonb;
  item_ids jsonb := '{}'::jsonb;
  option_ids jsonb := '{}'::jsonb;
begin
  if jsonb_typeof(p_sections) <> 'array' then
    raise invalid_parameter_value using message = 'sections must be an array';
  end if;
  if jsonb_array_length(p_sections) > 20 then
    raise check_violation using message = 'maximum 20 form sections';
  end if;

  delete from public.form_sections where form_version_id = p_version_id;

  for section_json in select value from jsonb_array_elements(p_sections) loop
    perform app_private.form_assert_payload_keys(
      section_json,
      array['id','title','description','position','items'],
      'form section'
    );
    source_section_id := nullif(section_json ->> 'id', '');
    if source_section_id is null or section_ids ? source_section_id then
      raise invalid_parameter_value using message = 'unique section id required';
    end if;
    section_ids := section_ids || jsonb_build_object(source_section_id, gen_random_uuid()::text);
    if jsonb_typeof(section_json -> 'items') <> 'array' then
      raise invalid_parameter_value using message = 'section items must be an array';
    end if;
    for item_json in select value from jsonb_array_elements(section_json -> 'items') loop
      perform app_private.form_assert_payload_keys(
        item_json,
        array['id','kind','label','help_text','position','is_required','config','options','conditions'],
        'form item'
      );
      source_item_id := nullif(item_json ->> 'id', '');
      if source_item_id is null or item_ids ? source_item_id then
        raise invalid_parameter_value using message = 'unique item id required';
      end if;
      item_ids := item_ids || jsonb_build_object(source_item_id, gen_random_uuid()::text);
      if jsonb_typeof(coalesce(item_json -> 'options', '[]'::jsonb)) <> 'array'
         or jsonb_typeof(coalesce(item_json -> 'conditions', '[]'::jsonb)) <> 'array' then
        raise invalid_parameter_value using message = 'item options and conditions must be arrays';
      end if;
      if jsonb_array_length(coalesce(item_json -> 'options', '[]'::jsonb)) > 50 then
        raise check_violation using message = 'maximum 50 form options per item';
      end if;
      -- P16: opcoes de Local sao do servidor (snapshot do catalogo), nunca do cliente.
      if item_json ->> 'kind' = 'location' then continue; end if;
      for option_json in select value from jsonb_array_elements(coalesce(item_json -> 'options', '[]'::jsonb)) loop
        perform app_private.form_assert_payload_keys(
          option_json, array['id','label','position'], 'form option'
        );
        source_option_id := nullif(option_json ->> 'id', '');
        if source_option_id is null or option_ids ? source_option_id then
          raise invalid_parameter_value using message = 'unique option id required';
        end if;
        option_ids := option_ids || jsonb_build_object(source_option_id, gen_random_uuid()::text);
      end loop;
    end loop;
  end loop;

  if (select count(*) from jsonb_object_keys(item_ids)) > 200 then
    raise check_violation using message = 'maximum 200 form items';
  end if;

  for section_json in select value from jsonb_array_elements(p_sections) loop
    source_section_id := section_json ->> 'id';
    insert into public.form_sections(id, form_version_id, title, description, position)
    values (
      (section_ids ->> source_section_id)::uuid,
      p_version_id,
      btrim(section_json ->> 'title'),
      nullif(btrim(section_json ->> 'description'), ''),
      (section_json ->> 'position')::integer
    );
    for item_json in select value from jsonb_array_elements(section_json -> 'items') loop
      source_item_id := item_json ->> 'id';
      insert into public.form_items(
        id, form_version_id, section_id, kind, label, help_text, is_required, position, config_jsonb
      ) values (
        (item_ids ->> source_item_id)::uuid,
        p_version_id,
        (section_ids ->> source_section_id)::uuid,
        item_json ->> 'kind',
        btrim(item_json ->> 'label'),
        nullif(btrim(item_json ->> 'help_text'), ''),
        coalesce((item_json ->> 'is_required')::boolean, false),
        (item_json ->> 'position')::integer,
        coalesce(item_json -> 'config', '{}'::jsonb)
      );
      if item_json ->> 'kind' = 'location' then continue; end if;
      for option_json in select value from jsonb_array_elements(coalesce(item_json -> 'options', '[]'::jsonb)) loop
        source_option_id := option_json ->> 'id';
        insert into public.form_question_options(id, form_version_id, item_id, label, position)
        values (
          (option_ids ->> source_option_id)::uuid,
          p_version_id,
          (item_ids ->> source_item_id)::uuid,
          btrim(option_json ->> 'label'),
          (option_json ->> 'position')::integer
        );
      end loop;
    end loop;
  end loop;

  for section_json in select value from jsonb_array_elements(p_sections) loop
    for item_json in select value from jsonb_array_elements(section_json -> 'items') loop
      source_item_id := item_json ->> 'id';
      for condition_json in select value from jsonb_array_elements(coalesce(item_json -> 'conditions', '[]'::jsonb)) loop
        perform app_private.form_assert_payload_keys(
          condition_json,
          array['source_item_id','kind','expected_yes_no','option_ids'],
          'form condition'
        );
        if not item_ids ? (condition_json ->> 'source_item_id') then
          raise invalid_parameter_value using message = 'condition source item not found';
        end if;
        for source_option_id in
          select value
            from jsonb_array_elements_text(
              case when condition_json ->> 'kind' = 'choice'
                then condition_json -> 'option_ids' else '[null]'::jsonb end
            )
        loop
          if condition_json ->> 'kind' = 'choice' and not option_ids ? source_option_id then
            raise invalid_parameter_value using message = 'condition source option not found';
          end if;
          insert into public.form_question_conditions(
            form_version_id, target_item_id, source_item_id, condition_kind,
            expected_yes_no, source_option_id
          ) values (
            p_version_id,
            (item_ids ->> source_item_id)::uuid,
            (item_ids ->> (condition_json ->> 'source_item_id'))::uuid,
            condition_json ->> 'kind',
            (condition_json ->> 'expected_yes_no')::boolean,
            case when source_option_id is null then null
                 else (option_ids ->> source_option_id)::uuid end
          );
        end loop;
      end loop;
    end loop;
  end loop;
  perform app_private.form_apply_location_options_v1(p_version_id);
  perform app_private.superadmin_form_validate_draft_definition_v2(p_version_id);
end;
$$;

-- 5. Validadores: opcoes de `location` sao aceitas somente com snapshot; o
--    rascunho pode ter zero locais ativos, a publicacao exige ao menos um.
create or replace function app_private.superadmin_form_validate_draft_definition_v2(p_version_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_has_cycle boolean;
  v_max_depth integer;
begin
  if (select count(*) from public.form_sections where form_version_id = p_version_id) > 20 then
    raise check_violation using message = 'maximum 20 form sections';
  end if;
  if (select count(*) from public.form_items where form_version_id = p_version_id) > 200 then
    raise check_violation using message = 'maximum 200 form items';
  end if;
  if exists (
    select 1
      from public.form_items item
     where item.form_version_id = p_version_id
       and item.kind in ('single_choice', 'multiple_choice')
       and (select count(*) from public.form_question_options option_row where option_row.item_id = item.id) not between 2 and 50
  ) then
    raise check_violation using message = 'choice item requires between 2 and 50 options';
  end if;
  if exists (
    select 1
      from public.form_question_options option_row
      join public.form_items item on item.id = option_row.item_id
     where option_row.form_version_id = p_version_id
       and (item.form_version_id <> p_version_id or item.kind not in ('single_choice', 'multiple_choice', 'location'))
  ) then
    raise check_violation using message = 'form options require a choice item in the same version';
  end if;
  if exists (
    select 1
      from public.form_question_options option_row
      join public.form_items item on item.id = option_row.item_id
     where option_row.form_version_id = p_version_id
       and ((item.kind = 'location') <> (option_row.location_id is not null))
  ) then
    raise check_violation using message = 'location options must come from the catalog snapshot';
  end if;
  if exists (
    select 1
      from public.form_question_conditions condition_row
      join public.form_items source_item on source_item.id = condition_row.source_item_id
     where condition_row.form_version_id = p_version_id
       and (
         (condition_row.condition_kind = 'yes_no' and source_item.kind <> 'yes_no')
         or (condition_row.condition_kind = 'choice' and source_item.kind not in ('single_choice', 'multiple_choice'))
       )
  ) then
    raise check_violation using message = 'condition source kind is not allowed';
  end if;
  if exists (
    select 1
      from public.form_items item
      join public.form_sections section_row on section_row.id = item.section_id
     where item.form_version_id = p_version_id
       and section_row.form_version_id <> p_version_id
  ) or exists (
    select 1
      from public.form_question_conditions condition_row
      join public.form_items source_item on source_item.id = condition_row.source_item_id
      join public.form_items target_item on target_item.id = condition_row.target_item_id
     where condition_row.form_version_id = p_version_id
       and (source_item.form_version_id <> p_version_id or target_item.form_version_id <> p_version_id)
  ) then
    raise check_violation using message = 'form definition version mismatch';
  end if;

  if exists (
    select 1 from public.form_question_conditions c
    join public.form_question_options o on o.id=c.source_option_id
    where c.form_version_id=p_version_id and (o.item_id<>c.source_item_id or o.form_version_id<>p_version_id)
  ) then raise check_violation using message='condition option does not belong to its source'; end if;

  -- One logical edge can have 50 option rows. Never enumerate option paths.
  -- UNION deduplicates (origin,target,depth), bounded by 200*200*5 states.
  with recursive edges(source_id,target_id) as (
    select distinct source_item_id,target_item_id from public.form_question_conditions
    where form_version_id=p_version_id
  ), walk(origin_id,current_item_id,depth) as (
    select source_id,target_id,1 from edges
    union
    select walk.origin_id,edges.target_id,walk.depth+1
    from walk join edges on edges.source_id=walk.current_item_id
    where walk.depth<5
  )
  select coalesce(bool_or(origin_id=current_item_id), false), coalesce(max(depth), 0)
    into v_has_cycle, v_max_depth
    from walk;

  if v_has_cycle then
    raise check_violation using message = 'form condition cycle';
  end if;
  if v_max_depth > 4 then
    raise check_violation using message = 'maximum form condition depth is 4';
  end if;
end;
$$;

create or replace function app_private.validate_form_definition(p_version_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_has_cycle boolean;
  v_max_depth integer;
  v_form_kind text;
  v_quick_poll_intent text;
  v_quick_poll_item_count integer;
begin
  if (select count(*) from public.form_sections where form_version_id = p_version_id) > 20 then
    raise check_violation using message = 'maximum 20 form sections';
  end if;
  if (select count(*) from public.form_items where form_version_id = p_version_id) > 200 then
    raise check_violation using message = 'maximum 200 form items';
  end if;
  select form_row.kind, form_row.description
    into v_form_kind, v_quick_poll_intent
    from public.form_versions version_row
    join public.forms form_row on form_row.id = version_row.form_id
   where version_row.id = p_version_id;
  if v_form_kind = 'quick_poll' then
    if char_length(btrim(coalesce(v_quick_poll_intent, ''))) not between 1 and 280 then
      raise check_violation using message = 'quick poll intent requires between 1 and 280 characters';
    end if;
    select count(*) into v_quick_poll_item_count
      from public.form_items item where item.form_version_id = p_version_id;
    if v_quick_poll_item_count <> 1
       or exists(
         select 1 from public.form_items item
          where item.form_version_id = p_version_id and item.kind = 'information'
       ) then
      raise check_violation using message = 'quick poll requires exactly one question';
    end if;
  end if;
  if exists (
    select 1
      from public.form_items item
     where item.form_version_id = p_version_id
       and item.kind in ('single_choice', 'multiple_choice')
       and (select count(*) from public.form_question_options option_row where option_row.item_id = item.id) not between 2 and 50
  ) then
    raise check_violation using message = 'choice item requires between 2 and 50 options';
  end if;
  if exists (
    select 1
      from public.form_question_options option_row
      join public.form_items item on item.id = option_row.item_id
     where option_row.form_version_id = p_version_id
       and (item.form_version_id <> p_version_id or item.kind not in ('single_choice', 'multiple_choice', 'location'))
  ) then
    raise check_violation using message = 'form options require a choice item in the same version';
  end if;
  if exists (
    select 1
      from public.form_question_options option_row
      join public.form_items item on item.id = option_row.item_id
     where option_row.form_version_id = p_version_id
       and ((item.kind = 'location') <> (option_row.location_id is not null))
  ) then
    raise check_violation using message = 'location options must come from the catalog snapshot';
  end if;
  if exists (
    select 1
      from public.form_items item
     where item.form_version_id = p_version_id
       and item.kind = 'location'
       and not exists (select 1 from public.form_question_options option_row where option_row.item_id = item.id)
  ) then
    raise check_violation using message = 'location item requires at least one active location';
  end if;
  if exists (
    select 1
      from public.form_question_conditions condition_row
      join public.form_items source_item on source_item.id = condition_row.source_item_id
     where condition_row.form_version_id = p_version_id
       and (
         (condition_row.condition_kind = 'yes_no' and source_item.kind <> 'yes_no')
         or (condition_row.condition_kind = 'choice' and source_item.kind not in ('single_choice', 'multiple_choice'))
       )
  ) then
    raise check_violation using message = 'condition source kind is not allowed';
  end if;
  if exists (
    select 1
      from public.form_items item
      join public.form_sections section_row on section_row.id = item.section_id
     where item.form_version_id = p_version_id
       and section_row.form_version_id <> p_version_id
  ) or exists (
    select 1
      from public.form_question_conditions condition_row
      join public.form_items source_item on source_item.id = condition_row.source_item_id
      join public.form_items target_item on target_item.id = condition_row.target_item_id
     where condition_row.form_version_id = p_version_id
       and (source_item.form_version_id <> p_version_id or target_item.form_version_id <> p_version_id)
  ) then
    raise check_violation using message = 'form definition version mismatch';
  end if;

  with recursive walk(current_item_id, path, depth, cycle) as (
    select condition_row.target_item_id,
           array[condition_row.source_item_id, condition_row.target_item_id],
           1,
           condition_row.target_item_id = condition_row.source_item_id
      from public.form_question_conditions condition_row
     where condition_row.form_version_id = p_version_id
    union all
    select condition_row.target_item_id,
           walk.path || condition_row.target_item_id,
           walk.depth + 1,
           condition_row.target_item_id = any(walk.path)
      from walk
      join public.form_question_conditions condition_row
        on condition_row.source_item_id = walk.current_item_id
     where condition_row.form_version_id = p_version_id
       and not walk.cycle
       and walk.depth <= 4
  )
  select coalesce(bool_or(cycle), false), coalesce(max(depth), 0)
    into v_has_cycle, v_max_depth
    from walk;

  if v_has_cycle then
    raise check_violation using message = 'form condition cycle';
  end if;
  if v_max_depth > 4 then
    raise check_violation using message = 'maximum form condition depth is 4';
  end if;
end;
$$;

-- 6. Publicacao: a lista congela no momento da publicacao (spec), refazendo o
--    snapshot da versao de trabalho antes de validar. Corpo de 20260910230004
--    mais uma linha.
create or replace function app_private.form_publish(
  p_request_id uuid,
  p_expected_version bigint,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := app_private.require_forms_actor('forms.publish');
  target_form_id uuid;
  form_row public.forms;
  replay jsonb;
  result jsonb;
begin
  perform app_private.form_assert_payload_keys(p_payload, array['form_id'], 'form publish');
  target_form_id := (p_payload ->> 'form_id')::uuid;
  perform app_private.superadmin_form_lock_legacy_resource_v2(target_form_id);
  replay := app_private.form_begin_command(
    p_request_id, actor, 'form_publish', p_expected_version, p_payload
  );
  if replay is not null then return replay; end if;
  perform pg_advisory_xact_lock(hashtextextended(target_form_id::text, 0));
  select * into form_row from public.forms where id = target_form_id for update;
  perform app_private.superadmin_form_assert_legacy_resource_v2(form_row.id);
  if form_row.id is null then raise no_data_found using message = 'form unavailable'; end if;
  if form_row.management_version <> p_expected_version then
    raise serialization_failure using message = 'expected_version mismatch';
  end if;
  if form_row.working_version_id is null then
    raise check_violation using message = 'working version required';
  end if;
  perform app_private.form_apply_location_options_v1(form_row.working_version_id);
  perform app_private.validate_form_definition(form_row.working_version_id);
  update public.form_versions
     set state = 'superseded'
   where id = form_row.published_version_id and state = 'published';
  update public.form_versions
     set state = 'published', published_at = now()
   where id = form_row.working_version_id and state = 'working';
  update public.forms
     set status = 'published',
         published_version_id = working_version_id,
         working_version_id = null,
         first_published_at = coalesce(first_published_at, now()),
         management_version = management_version + 1,
         updated_by_person_id = actor,
         updated_at = now()
   where id = target_form_id;
  update public.form_occurrences
     set form_version_id = form_row.working_version_id,
         management_version = management_version + 1
   where form_occurrences.form_id = target_form_id
     and status = 'scheduled'
     and opens_at > now();
  result := app_private.form_definition_projection(target_form_id);
  insert into audit.audit_logs(
    actor_person_id, mfa_aal, action_code, object_type, object_id, institution_id, outcome,
    after_json
  ) values (
    actor, auth.jwt() ->> 'aal', 'forms.publish', 'form', target_form_id,
    form_row.institution_id, 'success', jsonb_build_object('published_version_id', form_row.working_version_id)
  );
  return app_private.form_complete_command(p_request_id, result);
end;
$$;

-- 7. Projecao da definicao: opcoes de `location` levam o snapshot e a
--    disponibilidade viva, para o cliente desabilitar o revogado e mostrar o
--    aviso do caso extra. Itens de outros tipos nao mudam de forma.
create or replace function app_private.form_definition_projection(p_form_id uuid, p_version_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', form_row.id,
    'institution_id', form_row.institution_id,
    'kind', form_row.kind,
    'identity_mode', form_row.identity_mode,
    'response_unit', form_row.response_unit,
    'title', form_row.title,
    'description', form_row.description,
    'status', form_row.status,
    'management_version', form_row.management_version,
    'sections', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', section_row.id,
        'title', section_row.title,
        'description', section_row.description,
        'position', section_row.position,
        'items', coalesce((
          select jsonb_agg(jsonb_build_object(
            'id', item_row.id,
            'kind', item_row.kind,
            'label', item_row.label,
            'help_text', item_row.help_text,
            'position', item_row.position,
            'is_required', item_row.is_required,
            'config', item_row.config_jsonb,
            'options', coalesce((
              select jsonb_agg((jsonb_build_object(
                'id', option_row.id, 'label', option_row.label, 'position', option_row.position
              ) || case when item_row.kind = 'location' then jsonb_build_object(
                'location_id', option_row.location_id,
                'location_status', option_row.location_status,
                'location_available', app_private.form_location_option_available_v1(option_row.id)
              ) else '{}'::jsonb end) order by option_row.position, option_row.id)
              from public.form_question_options option_row
              where option_row.item_id = item_row.id
            ), '[]'::jsonb),
            'conditions', coalesce((
              select jsonb_agg(jsonb_build_object(
                'source_item_id', grouped.source_item_id,
                'kind', grouped.condition_kind,
                'expected_yes_no', grouped.expected_yes_no,
                'option_ids', grouped.option_ids
              ) order by grouped.source_item_id, grouped.condition_kind)
              from (
                select condition_row.source_item_id,
                       condition_row.condition_kind,
                       condition_row.expected_yes_no,
                       coalesce(jsonb_agg(condition_row.source_option_id)
                         filter (where condition_row.source_option_id is not null), '[]'::jsonb) as option_ids
                  from public.form_question_conditions condition_row
                 where condition_row.target_item_id = item_row.id
                 group by condition_row.source_item_id, condition_row.condition_kind,
                          condition_row.expected_yes_no
              ) grouped
            ), '[]'::jsonb)
          ) order by item_row.position, item_row.id)
          from public.form_items item_row
          where item_row.section_id = section_row.id
        ), '[]'::jsonb)
      ) order by section_row.position, section_row.id)
      from public.form_sections section_row
      where section_row.form_version_id = coalesce(
        p_version_id, form_row.working_version_id, form_row.published_version_id
      )
    ), '[]'::jsonb)
  )
  from public.forms form_row
  where form_row.id = p_form_id;
$$;

-- 8. Resposta: `location` grava uma opcao do snapshot (option_ids com um id),
--    e a opcao precisa apontar para um Local que continua ativo (opcao 2).
--    Defeito latente da baseline corrigido de passagem: a variavel PL/pgSQL
--    `answer_id` colidia com a coluna form_answer_options.answer_id /
--    form_answer_assets.answer_id ("column reference answer_id is ambiguous",
--    42702) em toda resposta de escolha ou midia; renomeada para
--    inserted_answer_id. O pgTAP deste pacote cobre a gravacao de opcao.
create or replace function app_private.form_replace_response_answers(p_response public.form_responses, p_answers jsonb, p_edit_secret text default null::text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare answer_json jsonb;
declare option_id_text text;
declare asset_id_text text;
declare inserted_answer_id uuid;
declare item_row public.form_items;
declare answer_kind text;
declare answer_count integer;
declare configured_min numeric;
declare configured_max numeric;
declare configured_date_min date;
declare configured_date_max date;
begin
  if jsonb_typeof(p_answers) <> 'array' or jsonb_array_length(p_answers) > 200 then
    raise invalid_parameter_value using message = 'answers must be an array with at most 200 items';
  end if;
  delete from public.form_answers where response_id = p_response.id;
  for answer_json in select value from jsonb_array_elements(p_answers) loop
    perform app_private.form_assert_payload_keys(
      answer_json,
      array[
        'item_id','kind','text_value','integer_value','decimal_value','money_minor_units',
        'date_value','yes_no_value','scale_value','option_ids','asset_ids'
      ],
      'form answer'
    );
    select * into item_row
      from public.form_items
     where id = (answer_json ->> 'item_id')::uuid
       and form_version_id = p_response.form_version_id;
    if item_row.id is null or item_row.kind = 'information' then
      raise invalid_parameter_value using message = 'answer item unavailable';
    end if;
    answer_kind := answer_json ->> 'kind';
    if answer_kind <> item_row.kind then
      raise invalid_parameter_value using message = 'answer kind mismatch';
    end if;
    if answer_kind = 'short_text'
       and char_length(coalesce(answer_json ->> 'text_value', ''))
           > coalesce((item_row.config_jsonb ->> 'max_length')::integer, 1000) then
      raise check_violation using message = 'short text answer exceeds maximum length';
    elsif answer_kind in ('integer', 'decimal', 'money') then
      configured_min := (item_row.config_jsonb ->> 'min_value')::numeric;
      configured_max := (item_row.config_jsonb ->> 'max_value')::numeric;
      if (answer_kind = 'integer' and (
            (answer_json ->> 'integer_value')::numeric < coalesce(configured_min, '-Infinity'::numeric)
            or (answer_json ->> 'integer_value')::numeric > coalesce(configured_max, 'Infinity'::numeric)
          )) or (answer_kind = 'decimal' and (
            (answer_json ->> 'decimal_value')::numeric < coalesce(configured_min, '-Infinity'::numeric)
            or (answer_json ->> 'decimal_value')::numeric > coalesce(configured_max, 'Infinity'::numeric)
          )) or (answer_kind = 'money' and (
            (answer_json ->> 'money_minor_units')::numeric < coalesce(configured_min, '-Infinity'::numeric)
            or (answer_json ->> 'money_minor_units')::numeric > coalesce(configured_max, 'Infinity'::numeric)
          )) then
        raise check_violation using message = 'numeric form answer is out of range';
      end if;
    elsif answer_kind = 'date' then
      configured_date_min := (item_row.config_jsonb ->> 'min_value')::date;
      configured_date_max := (item_row.config_jsonb ->> 'max_value')::date;
      if (answer_json ->> 'date_value')::date < coalesce(configured_date_min, '-infinity'::date)
         or (answer_json ->> 'date_value')::date > coalesce(configured_date_max, 'infinity'::date) then
        raise check_violation using message = 'date form answer is out of range';
      end if;
    elsif answer_kind = 'scale' and (
      (answer_json ->> 'scale_value')::integer < coalesce((item_row.config_jsonb ->> 'scale_min')::integer, 1)
      or (answer_json ->> 'scale_value')::integer > coalesce((item_row.config_jsonb ->> 'scale_max')::integer, 10)
    ) then
      raise check_violation using message = 'scale form answer is out of range';
    end if;
    insert into public.form_answers(
      response_id, form_version_id, item_id, answer_kind, text_value, integer_value,
      decimal_value, money_minor_units, date_value, yes_no_value, scale_value
    ) values (
      p_response.id, p_response.form_version_id, item_row.id, answer_kind,
      answer_json ->> 'text_value', (answer_json ->> 'integer_value')::bigint,
      (answer_json ->> 'decimal_value')::numeric, (answer_json ->> 'money_minor_units')::bigint,
      (answer_json ->> 'date_value')::date, (answer_json ->> 'yes_no_value')::boolean,
      (answer_json ->> 'scale_value')::integer
    ) returning id into inserted_answer_id;

    if answer_kind in ('single_choice', 'multiple_choice', 'location') then
      if jsonb_typeof(coalesce(answer_json -> 'option_ids', '[]'::jsonb)) <> 'array'
         or exists(
           select 1 from jsonb_array_elements(answer_json -> 'option_ids') option_id
            where jsonb_typeof(option_id) <> 'string'
         ) then
        raise invalid_parameter_value using message = 'invalid answer options';
      end if;
      answer_count := jsonb_array_length(coalesce(answer_json -> 'option_ids', '[]'::jsonb));
      if answer_count <> (select count(distinct option_id)
                            from jsonb_array_elements_text(answer_json -> 'option_ids') option_id) then
        raise invalid_parameter_value using message = 'form answer option ids must be unique';
      end if;
      if (answer_kind in ('single_choice', 'location') and answer_count <> 1)
         or (answer_kind = 'multiple_choice' and answer_count not between
           coalesce((item_row.config_jsonb ->> 'min_selections')::integer, 1)
           and coalesce((item_row.config_jsonb ->> 'max_selections')::integer, 50)) then
        raise check_violation using message = 'multiple choice selection count is out of range';
      end if;
      for option_id_text in select value #>> '{}' from jsonb_array_elements(answer_json -> 'option_ids') loop
        if not exists(
          select 1 from public.form_question_options
          where id = option_id_text::uuid and item_id = item_row.id
        ) then
          raise invalid_parameter_value using message = 'answer option unavailable';
        end if;
        -- P16, opcao 2: o Local do snapshot precisa continuar ativo no catalogo
        -- da instituicao. Sem alternativa valida numa pergunta obrigatoria, o
        -- bloqueio e explicito em vez de forcar uma escolha invalida.
        if answer_kind = 'location'
           and not app_private.form_location_option_available_v1(option_id_text::uuid) then
          if item_row.is_required and not exists (
            select 1 from public.form_question_options candidate
             where candidate.item_id = item_row.id
               and app_private.form_location_option_available_v1(candidate.id)
          ) then
            raise check_violation using message = 'required location question has no available location',
              detail = 'FORMS_LOCATION_NO_AVAILABLE_OPTION';
          end if;
          raise check_violation using message = 'form location answer requires a current location',
            detail = 'FORMS_LOCATION_REVOKED';
        end if;
        insert into public.form_answer_options(answer_id, option_id, position)
        values (
          inserted_answer_id,
          option_id_text::uuid,
          (select count(*) from public.form_answer_options where form_answer_options.answer_id = inserted_answer_id)
        );
      end loop;
    elsif answer_kind in ('photo', 'gallery') then
      if jsonb_typeof(coalesce(answer_json -> 'asset_ids', '[]'::jsonb)) <> 'array'
         or exists(
           select 1 from jsonb_array_elements(answer_json -> 'asset_ids') asset_id
            where jsonb_typeof(asset_id) <> 'string'
         ) then
        raise invalid_parameter_value using message = 'invalid answer assets';
      end if;
      answer_count := jsonb_array_length(coalesce(answer_json -> 'asset_ids', '[]'::jsonb));
      if (answer_kind = 'photo' and answer_count <> 1)
         or (answer_kind = 'gallery' and answer_count not between
           coalesce((item_row.config_jsonb ->> 'min_images')::integer, 1)
           and coalesce((item_row.config_jsonb ->> 'max_images')::integer, 5)) then
        raise check_violation using message = 'form answer asset count is out of range';
      end if;
      for asset_id_text in select value #>> '{}' from jsonb_array_elements(answer_json -> 'asset_ids') loop
        if not exists(
          select 1 from public.form_assets asset
          where asset.id = asset_id_text::uuid and asset.item_id = item_row.id
            and asset.occurrence_id = p_response.occurrence_id and asset.state = 'finalized'
            and (
              (p_response.identity_mode = 'identified'
                and asset.prepared_by_person_id = p_response.respondent_person_id)
              or (p_response.identity_mode = 'anonymous'
                and asset.prepared_by_person_id is null
                and app_private.form_verify_anonymous_edit_secret(
                  p_edit_secret, asset.anonymous_upload_secret_hash
                ))
            )
        ) then
          raise invalid_parameter_value using message = 'answer asset unavailable';
        end if;
        insert into public.form_answer_assets(answer_id, asset_id, position)
        values (
          inserted_answer_id,
          asset_id_text::uuid,
          (select count(*) from public.form_answer_assets where form_answer_assets.answer_id = inserted_answer_id)
        );
      end loop;
    end if;
  end loop;

  if exists (
    select 1
      from public.form_answers target_answer
     where target_answer.response_id = p_response.id
       and exists (
         select 1 from public.form_question_conditions condition_row
         where condition_row.target_item_id = target_answer.item_id
       )
       and not exists (
         select 1
           from public.form_question_conditions condition_row
           join public.form_answers source_answer
             on source_answer.response_id = p_response.id
            and source_answer.item_id = condition_row.source_item_id
          where condition_row.target_item_id = target_answer.item_id
            and (
              (condition_row.condition_kind = 'yes_no'
               and source_answer.yes_no_value = condition_row.expected_yes_no)
              or (condition_row.condition_kind = 'choice' and exists(
                select 1 from public.form_answer_options selected_option
                where selected_option.answer_id = source_answer.id
                  and selected_option.option_id = condition_row.source_option_id
              ))
            )
       )
  ) then
    raise check_violation using message = 'hidden form answers are not accepted';
  end if;
end;
$$;

-- 9. Obrigatoriedade: `location` conta como respondida quando ha uma opcao
--    ainda disponivel; pergunta obrigatoria visivel sem alternativa valida
--    bloqueia com o codigo proprio (caso extra da Decisao 12).
create or replace function app_private.form_assert_required_response_answers(p_response public.form_responses)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  missing_item_id uuid;
  missing_kind text;
begin
  select item.id, item.kind
    into missing_item_id, missing_kind
    from public.form_items item
   where item.form_version_id = p_response.form_version_id
     and item.is_required
     and (
       not exists (
         select 1 from public.form_question_conditions condition_row
          where condition_row.target_item_id = item.id
       )
       or exists (
         select 1
           from public.form_question_conditions condition_row
           join public.form_answers source_answer
             on source_answer.response_id = p_response.id
            and source_answer.item_id = condition_row.source_item_id
          where condition_row.target_item_id = item.id
            and (
              (condition_row.condition_kind = 'yes_no'
               and source_answer.yes_no_value = condition_row.expected_yes_no)
              or (condition_row.condition_kind = 'choice' and exists (
                select 1 from public.form_answer_options selected
                 where selected.answer_id = source_answer.id
                   and selected.option_id = condition_row.source_option_id
              ))
            )
       )
     )
     and not exists (
       select 1
         from public.form_answers answer
        where answer.response_id = p_response.id
          and answer.item_id = item.id
          and case
            when item.kind = 'short_text' then nullif(btrim(answer.text_value), '') is not null
            when item.kind in ('single_choice', 'multiple_choice') then exists (
              select 1 from public.form_answer_options selected where selected.answer_id = answer.id
            )
            when item.kind = 'location' then exists (
              select 1 from public.form_answer_options selected
               where selected.answer_id = answer.id
                 and app_private.form_location_option_available_v1(selected.option_id)
            )
            when item.kind in ('photo', 'gallery') then exists (
              select 1 from public.form_answer_assets attached where attached.answer_id = answer.id
            )
            else true
          end
     )
   order by (item.kind = 'location' and not exists (
       select 1 from public.form_question_options candidate
        where candidate.item_id = item.id
          and app_private.form_location_option_available_v1(candidate.id))) desc,
     item.position, item.id
   limit 1;
  if missing_item_id is null then
    return;
  end if;
  if missing_kind = 'location' and not exists (
    select 1 from public.form_question_options candidate
     where candidate.item_id = missing_item_id
       and app_private.form_location_option_available_v1(candidate.id)
  ) then
    raise check_violation using message = 'required location question has no available location',
      detail = 'FORMS_LOCATION_NO_AVAILABLE_OPTION';
  end if;
  raise check_violation using message = 'required visible form answers are missing';
end;
$$;

-- 10. Exportacao XLSX: as tres ramificacoes por tipo aceitam `location`
--     como escolha unica (preflight conferiu uma ocorrencia de cada trecho).
do $xlsx$
declare def text;
begin
  def := pg_get_functiondef('app_private.superadmin_form_request_xlsx_v2(uuid,bigint,jsonb)'::regprocedure);
  def := replace(def,
    $p$and (o.form_version_id<>i.form_version_id or i.kind not in ('single_choice','multiple_choice')))$p$,
    $p$and (o.form_version_id<>i.form_version_id or i.kind not in ('single_choice','multiple_choice','location')))$p$);
  def := replace(def,
    $p$where o.id is null or a.answer_kind not in ('single_choice','multiple_choice'))$p$,
    $p$where o.id is null or a.answer_kind not in ('single_choice','multiple_choice','location'))$p$);
  def := replace(def,
    $p$when a.answer_kind in ('single_choice','multiple_choice') then coalesce(($p$,
    $p$when a.answer_kind in ('single_choice','multiple_choice','location') then coalesce(($p$);
  execute def;
end
$xlsx$;

-- 11. ACL minima das funcoes novas; as substituidas preservam dono e grants.
do $acl$
declare signature text;
begin
  foreach signature in array array[
    'app_private.form_location_options_snapshot_v1(uuid)',
    'app_private.form_apply_location_options_v1(uuid)',
    'app_private.form_location_option_available_v1(uuid)'
  ] loop
    execute 'alter function ' || signature || ' owner to postgres';
    execute 'revoke all on function ' || signature || ' from public, anon, authenticated, service_role';
  end loop;
end
$acl$;
comment on function app_private.form_apply_location_options_v1(uuid) is
  'P16: congela em form_question_options os Locais ativos da instituicao do formulario para cada item kind=location da versao (snapshot: location_id, nome, status). Chamada no salvamento do rascunho v2 e na publicacao.';
comment on function app_private.form_location_option_available_v1(uuid) is
  'P16: leitura viva; verdadeiro quando o Local congelado na opcao continua ativo no catalogo da mesma instituicao.';

-- 12. Pos-condicoes.
do $post$
declare signature text;
begin
  foreach signature in array array[
    'app_private.form_location_options_snapshot_v1(uuid)',
    'app_private.form_apply_location_options_v1(uuid)',
    'app_private.form_location_option_available_v1(uuid)'
  ] loop
    if has_function_privilege('anon', signature, 'execute')
      or has_function_privilege('authenticated', signature, 'execute')
      or has_function_privilege('service_role', signature, 'execute') then
      raise object_not_in_prerequisite_state using message = 'forms location helper leaked to a client role: ' || signature;
    end if;
  end loop;
  if pg_get_functiondef('app_private.superadmin_form_request_xlsx_v2(uuid,bigint,jsonb)'::regprocedure)
       !~ $p$'single_choice','multiple_choice','location'$p$ then
    raise object_not_in_prerequisite_state using message = 'xlsx exporter was not patched';
  end if;
  if (select count(*) from pg_constraint where conrelid in ('public.form_items'::regclass, 'public.form_answers'::regclass)
        and conname in ('form_items_kind_ck', 'form_answers_kind_ck', 'form_answers_typed_value_ck')
        and pg_get_constraintdef(oid) like '%location%') <> 3 then
    raise object_not_in_prerequisite_state using message = 'forms kind constraints were not extended';
  end if;
end
$post$;

commit;
