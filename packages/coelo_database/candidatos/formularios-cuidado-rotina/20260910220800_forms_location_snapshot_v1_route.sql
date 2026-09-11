-- 20260910220800_forms_location_snapshot_v1_route
--
-- P16 (ADR 0034, Decisao 9 opcao 1) na rota de producao: snapshot de Locais no
-- caminho v1 de salvamento do rascunho (achado F-R04-FCR-005 do grupo
-- formularios-cuidado-rotina, Rodada 4, 11/09/2026).
--
-- O pacote 20260910220500 so aplica app_private.form_apply_location_options_v1
-- no superadmin_forms_save_draft_v2 (replace_draft_definition_v2) e no
-- form_publish. O editor de producao chama public.form_save_draft (v1), que
-- delega a app_private.form_replace_working_definition e valida com
-- app_private.validate_form_definition; sem snapshot, um item `location`
-- chega ao validador com zero opcoes e a rota devolve 23514
-- "location item requires at least one active location" mesmo com Local ativo.
--
-- O que este pacote faz: recria app_private.form_replace_working_definition com
-- o mesmo corpo de producao e uma unica linha a mais, chamando o mesmo helper
-- de snapshot antes do validador (o cliente v1 tambem nao escolhe opcoes de
-- Local; o que enviar para um item `location` e substituido pelo catalogo).
-- Nenhuma assinatura, dono ou ACL muda (CREATE OR REPLACE preserva); sem
-- AAL2, sem grant a cliente.
--
-- Reversao (manual, forward-only): reaplicar a versao anterior da funcao
-- (baseline 20260910000000), removendo a linha do snapshot.

begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'forms location v1 route requires postgres';
  end if;
  if to_regprocedure('app_private.form_replace_working_definition(uuid,jsonb)') is null
    or to_regprocedure('app_private.form_apply_location_options_v1(uuid)') is null
    or to_regprocedure('app_private.validate_form_definition(uuid)') is null
    or to_regprocedure('app_private.form_save_draft(uuid,bigint,jsonb)') is null then
    raise object_not_in_prerequisite_state using message = 'forms location v1 route requires 20260910220500 applied';
  end if;
  if (select prosrc from pg_proc where oid = 'app_private.form_replace_working_definition(uuid,jsonb)'::regprocedure)
     like '%form_apply_location_options_v1%' then
    raise object_not_in_prerequisite_state using message = 'forms location v1 route already applied';
  end if;
end
$preflight$;

CREATE OR REPLACE FUNCTION app_private.form_replace_working_definition(p_version_id uuid, p_sections jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  perform app_private.validate_form_definition(p_version_id);
end;
$function$

;

alter function app_private.form_replace_working_definition(uuid,jsonb) owner to postgres;
revoke all on function app_private.form_replace_working_definition(uuid,jsonb) from public, anon, authenticated, service_role;
commit;
