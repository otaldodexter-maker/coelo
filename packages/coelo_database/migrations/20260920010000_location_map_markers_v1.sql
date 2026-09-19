-- Operação › Locais — spec 067 (mapa por imagem). Lote 96.
--   * public.location_map_markers: pontos e áreas sobre a planta da instituição ou da unidade,
--     em coordenadas relativas (0..1) à imagem, com rótulo, vínculo opcional a um local do
--     catálogo (activity_locations) e visibilidade por público (all|staff|guardians|admin|none).
--     RLS deny; leitura e escrita só por RPC no contexto interno (locations.read / locations.update),
--     com o mesmo recorte de escopo por instituição das RPCs de Locais.
--   * superadmin_location_map_get_v1(p_owner_kind, p_institution_id, p_unit_id): marcadores +
--     locais do dono (para vincular) + endereço (spec 067 §1: puxado do cadastro).
--   * superadmin_location_map_marker_save_v1(p_request_id, p_marker_id, p_expected_version,
--     p_payload) e superadmin_location_map_marker_remove_v1(p_request_id, p_marker_id,
--     p_expected_version): idempotentes por request; PT409/SAI_CONCURRENT_CHANGE em versão
--     defasada; auditoria interna.
--   A imagem da planta em si é mídia de entidade (entity_image_assets, image_kind 'floor_plan',
--   pedido à sessão de mídia); sem imagem a tela mostra os marcadores numa grade neutra.
begin;

create table if not exists public.location_map_markers (
  id uuid primary key default gen_random_uuid(),
  owner_kind text not null check (owner_kind in ('institution', 'unit')),
  institution_id uuid not null references public.institutions(id),
  unit_id uuid references public.units(id),
  location_id uuid references public.activity_locations(id),
  label text not null check (char_length(btrim(label)) between 1 and 80),
  shape text not null default 'point' check (shape in ('point', 'area')),
  x numeric(7,6) not null check (x >= 0 and x <= 1),
  y numeric(7,6) not null check (y >= 0 and y <= 1),
  points_json jsonb not null default '[]'::jsonb,
  visibility text not null default 'all' check (visibility in ('all', 'staff', 'guardians', 'admin', 'none')),
  status text not null default 'active' check (status in ('active', 'inactive')),
  management_version bigint not null default 1,
  created_by_internal_identity_id uuid references app_private.superadmin_internal_identities(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint location_map_markers_owner_ck check (
    (owner_kind = 'institution' and unit_id is null) or (owner_kind = 'unit' and unit_id is not null)),
  constraint location_map_markers_area_ck check (
    (shape = 'point' and jsonb_array_length(points_json) = 0)
    or (shape = 'area' and jsonb_array_length(points_json) >= 3))
);
alter table public.location_map_markers enable row level security;
alter table public.location_map_markers force row level security;
revoke all on public.location_map_markers from public, anon, authenticated;
create index if not exists location_map_markers_owner_idx
  on public.location_map_markers(institution_id, unit_id, status);

-- Escopo do dono: mesmo recorte das RPCs de Locais (owner de plataforma ou da instituição).
create or replace function app_private.location_map_owner_v1(
  p_context app_private.superadmin_internal_context, p_owner_kind text,
  p_institution_id uuid, p_unit_id uuid
) returns void language plpgsql stable security definer set search_path = '' as $$
begin
  if p_owner_kind not in ('institution', 'unit') or p_institution_id is null
    or (p_owner_kind = 'unit') <> (p_unit_id is not null) then
    raise invalid_parameter_value using message = 'invalid map owner', detail = 'SAI_INVALID_ARGUMENT';
  end if;
  if p_context.platform_role_code not in ('owner', 'operations')
    or not (p_context.scope_kind = 'platform'
      or (p_context.scope_kind = 'institution' and p_context.scope_institution_id = p_institution_id)) then
    raise insufficient_privilege using message = 'map access denied', detail = 'SAI_PERMISSION_DENIED';
  end if;
  if not exists (select 1 from public.institutions i where i.id = p_institution_id and i.deleted_at is null) then
    raise insufficient_privilege using message = 'map access denied', detail = 'SAI_PERMISSION_DENIED';
  end if;
  if p_unit_id is not null and not exists (select 1 from public.units u
      where u.id = p_unit_id and u.institution_id = p_institution_id) then
    raise invalid_parameter_value using message = 'unit outside institution', detail = 'SAI_INVALID_ARGUMENT';
  end if;
end
$$;
revoke all on function app_private.location_map_owner_v1(app_private.superadmin_internal_context, text, uuid, uuid)
  from public, anon, authenticated, service_role;

create or replace function app_private.location_map_marker_json(m public.location_map_markers)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', m.id, 'owner_kind', m.owner_kind, 'institution_id', m.institution_id,
    'unit_id', m.unit_id, 'location_id', m.location_id,
    'location_name', (select l.name from public.activity_locations l where l.id = m.location_id),
    'label', m.label, 'shape', m.shape, 'x', m.x, 'y', m.y, 'points', m.points_json,
    'visibility', m.visibility, 'status', m.status, 'management_version', m.management_version,
    'updated_at', m.updated_at)
$$;
revoke all on function app_private.location_map_marker_json(public.location_map_markers)
  from public, anon, authenticated, service_role;

create or replace function public.superadmin_location_map_get_v1(
  p_owner_kind text, p_institution_id uuid, p_unit_id uuid default null
) returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid := gen_random_uuid();
  error_code text; error_detail text; result jsonb;
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('locations.read');
    perform app_private.location_map_owner_v1(ctx, p_owner_kind, p_institution_id, p_unit_id);
    result := jsonb_build_object(
      'owner', jsonb_build_object('kind', p_owner_kind, 'institution_id', p_institution_id, 'unit_id', p_unit_id,
        'name', case when p_unit_id is null
          then (select i.public_name from public.institutions i where i.id = p_institution_id)
          else (select u.name from public.units u where u.id = p_unit_id) end,
        'address', case when p_unit_id is null
          then (select to_jsonb(a) - 'id' - 'institution_id' from public.institution_addresses a
                where a.institution_id = p_institution_id limit 1)
          else coalesce(
            (select to_jsonb(a) - 'id' - 'unit_id' from public.unit_addresses a where a.unit_id = p_unit_id limit 1),
            -- Unidade que herda o endereço da instituição (spec 067 §1: uma fonte só).
            (select to_jsonb(a) - 'id' - 'institution_id' from public.institution_addresses a
              where a.institution_id = p_institution_id limit 1)) end),
      'markers', coalesce((select jsonb_agg(app_private.location_map_marker_json(m) order by m.created_at)
        from public.location_map_markers m
        where m.institution_id = p_institution_id and m.unit_id is not distinct from p_unit_id
          and m.status = 'active'), '[]'::jsonb),
      'locations', coalesce((select jsonb_agg(jsonb_build_object('id', l.id, 'name', l.name,
          'kind', l.kind, 'floor', l.floor, 'scope_kind', l.scope_kind, 'unit_id', l.unit_id)
          order by l.name)
        from public.activity_locations l
        where l.institution_id = p_institution_id and l.status <> 'archived'
          and (p_unit_id is null or l.unit_id = p_unit_id or l.unit_id is null)), '[]'::jsonb));
    return jsonb_build_object('ok', true, 'data', result, 'error', null);
  exception
    when insufficient_privilege then
      get stacked diagnostics error_detail = pg_exception_detail;
      error_code := case when error_detail like 'SAI_%' then error_detail else 'SAI_INTERNAL_ERROR' end;
    when invalid_parameter_value then error_code := 'SAI_INVALID_ARGUMENT';
    when others then error_code := 'SAI_INTERNAL_ERROR';
  end;
  return app_private.superadmin_internal_error_envelope(error_code, correlation);
end
$$;

create or replace function public.superadmin_location_map_marker_save_v1(
  p_request_id uuid, p_marker_id uuid, p_expected_version bigint, p_payload jsonb
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare ctx app_private.superadmin_internal_context; correlation uuid := gen_random_uuid();
  error_code text; error_detail text; marker public.location_map_markers%rowtype;
  receipt app_private.superadmin_internal_lifecycle_receipts%rowtype; request_hash bytea;
  v_owner_kind text := p_payload ->> 'owner_kind'; v_institution_id uuid; v_unit_id uuid; v_location_id uuid;
  v_shape text := coalesce(p_payload ->> 'shape', 'point'); v_points jsonb := coalesce(p_payload -> 'points', '[]'::jsonb);
  result jsonb;
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('locations.update');
    if p_request_id is null or jsonb_typeof(p_payload) <> 'object' then
      raise invalid_parameter_value using message = 'marker request incomplete', detail = 'SAI_INVALID_ARGUMENT';
    end if;
    request_hash := extensions.digest(coalesce(p_marker_id::text, '') || '|' || coalesce(p_expected_version::text, '')
      || '|' || p_payload::text, 'sha256');
    perform pg_advisory_xact_lock(hashtextextended(ctx.internal_identity_id::text || ':' || p_request_id::text, 0));
    select * into receipt from app_private.superadmin_internal_lifecycle_receipts where request_id = p_request_id;
    if receipt.request_id is not null then
      if receipt.actor_internal_identity_id is distinct from ctx.internal_identity_id
        or receipt.request_hash is distinct from request_hash then
        raise invalid_parameter_value using message = 'request id already used', detail = 'SAI_INVALID_ARGUMENT';
      end if;
      return jsonb_build_object('ok', true, 'data', receipt.result_json || jsonb_build_object('replayed', true), 'error', null);
    end if;
    if p_marker_id is null then
      v_institution_id := (p_payload ->> 'institution_id')::uuid;
      v_unit_id := (p_payload ->> 'unit_id')::uuid;
      if p_expected_version is not null then
        raise invalid_parameter_value using message = 'new marker has no version', detail = 'SAI_INVALID_ARGUMENT';
      end if;
    else
      select * into marker from public.location_map_markers where id = p_marker_id for update;
      if marker.id is null then
        raise insufficient_privilege using message = 'map access denied', detail = 'SAI_PERMISSION_DENIED';
      end if;
      v_owner_kind := marker.owner_kind; v_institution_id := marker.institution_id; v_unit_id := marker.unit_id;
    end if;
    perform app_private.location_map_owner_v1(ctx, v_owner_kind, v_institution_id, v_unit_id);
    if p_marker_id is not null and marker.management_version is distinct from p_expected_version then
      raise exception using errcode = 'PT409', message = 'marker version stale', detail = 'SAI_CONCURRENT_CHANGE';
    end if;
    -- Local vinculado tem de ser do mesmo dono.
    v_location_id := nullif(p_payload ->> 'location_id', '')::uuid;
    if v_location_id is not null and not exists (select 1 from public.activity_locations l
        where l.id = v_location_id and l.institution_id = v_institution_id
          and (v_unit_id is null or l.unit_id is null or l.unit_id = v_unit_id)) then
      raise invalid_parameter_value using message = 'location outside owner', detail = 'SAI_INVALID_ARGUMENT';
    end if;
    if v_shape = 'point' then v_points := '[]'::jsonb; end if;
    if v_shape = 'area' and (jsonb_typeof(v_points) <> 'array' or jsonb_array_length(v_points) < 3
        or exists (select 1 from jsonb_array_elements(v_points) pt
          where jsonb_typeof(pt) <> 'array' or jsonb_array_length(pt) <> 2
            or (pt ->> 0)::numeric not between 0 and 1 or (pt ->> 1)::numeric not between 0 and 1)) then
      raise invalid_parameter_value using message = 'area needs three points in 0..1', detail = 'SAI_INVALID_ARGUMENT';
    end if;
    if p_marker_id is null then
      insert into public.location_map_markers(owner_kind, institution_id, unit_id, location_id, label, shape, x, y,
        points_json, visibility, created_by_internal_identity_id)
      values (v_owner_kind, v_institution_id, v_unit_id, v_location_id, btrim(p_payload ->> 'label'), v_shape,
        (p_payload ->> 'x')::numeric, (p_payload ->> 'y')::numeric, v_points,
        coalesce(p_payload ->> 'visibility', 'all'), ctx.internal_identity_id)
      returning * into marker;
    else
      update public.location_map_markers set
        location_id = v_location_id, label = coalesce(btrim(p_payload ->> 'label'), label),
        shape = v_shape, x = coalesce((p_payload ->> 'x')::numeric, x), y = coalesce((p_payload ->> 'y')::numeric, y),
        points_json = v_points, visibility = coalesce(p_payload ->> 'visibility', visibility),
        status = coalesce(p_payload ->> 'status', status),
        management_version = management_version + 1, updated_at = now()
      where id = p_marker_id returning * into marker;
    end if;
    result := app_private.location_map_marker_json(marker);
    insert into app_private.superadmin_internal_lifecycle_receipts(request_id, actor_internal_identity_id, entity,
      entity_id, action_code, expected_version, request_hash, result_json)
    values (p_request_id, ctx.internal_identity_id, 'location_map_marker', marker.id, 'location_map.marker.save',
      coalesce(p_expected_version, 0), request_hash, result);
    perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id, ctx.internal_auth_link_id,
      ctx.internal_membership_id, ctx.session_id, 'locations.update', ctx.aal, 'location_map.marker.save',
      'success'::public.audit_outcome, null, correlation, v_institution_id, 'location_map_marker', marker.id);
    return jsonb_build_object('ok', true, 'data', result || jsonb_build_object('replayed', false), 'error', null);
  exception
    when insufficient_privilege then
      get stacked diagnostics error_detail = pg_exception_detail;
      error_code := case when error_detail like 'SAI_%' then error_detail else 'SAI_INTERNAL_ERROR' end;
    when invalid_parameter_value or check_violation or foreign_key_violation or invalid_text_representation then
      error_code := 'SAI_INVALID_ARGUMENT';
    when sqlstate 'PT409' then error_code := 'SAI_CONCURRENT_CHANGE';
    when others then error_code := 'SAI_INTERNAL_ERROR';
  end;
  return app_private.superadmin_internal_error_envelope(error_code, correlation);
end
$$;

create or replace function public.superadmin_location_map_marker_remove_v1(
  p_request_id uuid, p_marker_id uuid, p_expected_version bigint
) returns jsonb language sql security definer set search_path = '' as $$
  select public.superadmin_location_map_marker_save_v1(p_request_id, p_marker_id, p_expected_version,
    jsonb_build_object('status', 'inactive'))
$$;

do $acl$
declare f regprocedure;
begin
  for f in select p.oid::regprocedure from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname like 'superadmin_location_map_%_v1' loop
    execute format('alter function %s owner to postgres', f);
    execute format('revoke all on function %s from public, anon, service_role', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end
$acl$;

commit;
