-- R05 realm-interno (7): @ das pessoas da instituicao no detalhe (Decisao 16)
--
-- Depois de 20260911170100_person_handles_v1 (lote 31) toda pessoa adulta
-- nasce com um @ em public.person_handles. O detalhe da instituicao
-- (superadmin_institution_detail_v2) passa a devolver `handle` em
-- representatives[] e administrators[] em vez de null; o cliente mostra o @
-- e usa superadmin_person_handle_get/set/availability (170100) para editar.
--
-- Reversao: recriar app_private.superadmin_institution_detail_payload_v2
-- como em 20260911210000.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'institution handles migration must run as postgres';
  end if;
  if to_regclass('public.person_handles') is null
    or to_regprocedure('app_private.ensure_person_handle(uuid)') is null
    or to_regprocedure('app_private.superadmin_institution_detail_payload_v2(uuid)') is null
    or to_regprocedure('public.superadmin_institution_contacts_edit_v1(uuid,uuid,bigint,jsonb)') is null then
    raise object_not_in_prerequisite_state using
      message = 'person_handles_v1 (170100) and institution_contacts_v1 (210000) are required';
  end if;
end
$preflight$;

create or replace function app_private.superadmin_institution_detail_payload_v2(
  p_institution_id uuid
) returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select app_private.institution_management_payload(p_institution_id)
    || pg_catalog.jsonb_build_object(
      'representatives', coalesce((
        select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'id', r.id,
          'person_id', p.id,
          'membership_id', r.membership_id,
          'is_primary', r.is_primary,
          'status', r.status::text,
          'starts_on', r.starts_on,
          'first_name', p.first_name,
          'last_name', p.last_name,
          'display_name', p.display_name,
          'handle', (select h.normalized_handle from public.person_handles h
            where h.person_id = p.id and h.status = 'active' and h.revoked_at is null
            order by h.created_at desc limit 1),
          'date_of_birth', p.date_of_birth,
          'email_masked', (select c.masked_value from public.person_contacts c
            where c.person_id = p.id and c.contact_type = 'email' and c.status = 'active'
            order by c.created_at desc limit 1),
          'mobile_phone_masked', (select c.masked_value from public.person_contacts c
            where c.person_id = p.id and c.contact_type = 'mobile_phone' and c.status = 'active'
            order by c.created_at desc limit 1),
          'cpf_masked', (select i.masked_value from app_private.person_identity_identifiers i
            where i.person_id = p.id and i.identifier_kind = 'cpf' and i.status = 'active'
            order by i.created_at desc limit 1)
        ) order by r.is_primary desc, r.starts_on, r.id)
        from public.institution_legal_representatives r
        join public.people p on p.id = r.person_id and p.deleted_at is null
        where r.institution_id = p_institution_id and r.status in ('active','draft')
      ), '[]'::jsonb),
      'administrators', coalesce((
        select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'membership_id', m.id,
          'person_id', p.id,
          'role_code', m.role_code,
          'level', case m.role_code
            when 'owner' then 'admin_master'
            when 'institution_admin' then 'authorized_administrator'
            else 'coordinator' end,
          'status', m.status::text,
          'first_name', p.first_name,
          'last_name', p.last_name,
          'display_name', p.display_name,
          'handle', (select h.normalized_handle from public.person_handles h
            where h.person_id = p.id and h.status = 'active' and h.revoked_at is null
            order by h.created_at desc limit 1),
          'has_active_login', exists (select 1 from public.person_auth_links l
            where l.person_id = p.id and l.status = 'active' and l.revoked_at is null),
          'invitation_status', case when exists (select 1 from public.person_auth_links l
            where l.person_id = p.id and l.status = 'active' and l.revoked_at is null)
            then 'accepted' else 'not_sent' end,
          'email_masked', (select c.masked_value from public.person_contacts c
            where c.person_id = p.id and c.contact_type = 'email' and c.status = 'active'
            order by c.created_at desc limit 1),
          'mobile_phone_masked', (select c.masked_value from public.person_contacts c
            where c.person_id = p.id and c.contact_type = 'mobile_phone' and c.status = 'active'
            order by c.created_at desc limit 1),
          'cpf_masked', (select i.masked_value from app_private.person_identity_identifiers i
            where i.person_id = p.id and i.identifier_kind = 'cpf' and i.status = 'active'
            order by i.created_at desc limit 1),
          'source_representative_id', (select r.id from public.institution_legal_representatives r
            where r.membership_id = m.id and r.status in ('active','draft')
            order by r.starts_on limit 1)
        ) order by m.created_at, m.id)
        from public.institution_memberships m
        join public.people p on p.id = m.person_id and p.deleted_at is null
        where m.institution_id = p_institution_id and m.status = 'active' and m.revoked_at is null
          and m.role_code in ('owner','institution_admin','coordinator')
          and p.person_type = 'adult'
      ), '[]'::jsonb)
    )
  from public.institutions i
  where i.id = p_institution_id and i.deleted_at is null
$$;

alter function app_private.superadmin_institution_detail_payload_v2(uuid) owner to postgres;
revoke all on function app_private.superadmin_institution_detail_payload_v2(uuid)
  from public, anon, authenticated, service_role;

commit;
