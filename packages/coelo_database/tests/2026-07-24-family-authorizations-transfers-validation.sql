-- Family authorizations and transfers validation. All fixtures roll back.
begin;

do $$
declare
  current_table text;
begin
  foreach current_table in array array[
    'family_relationship_types',
    'guardian_permission_capabilities',
    'guardian_context_permission_grants',
    'guardian_invitation_children',
    'authorized_people',
    'authorized_person_authorizations',
    'authorized_person_authorization_capabilities',
    'context_notification_events',
    'context_notification_recipients',
    'child_unit_transfer_requests',
    'child_unit_transfer_items'
  ] loop
    if to_regclass('public.' || current_table) is null then
      raise exception 'public.% is missing', current_table;
    end if;
    if not exists (
      select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public' and c.relname = current_table and c.relrowsecurity
    ) then
      raise exception 'RLS missing on public.%', current_table;
    end if;
  end loop;

  if (select count(*) from public.family_relationship_types
      where code in ('father','mother','grandfather','grandmother','brother',
                     'sister','stepfather','stepmother','cousin_male',
                     'cousin_female','uncle','aunt','other')
        and status = 'active') <> 13 then
    raise exception 'family relationship catalog is incomplete';
  end if;

  if (select count(*) from public.guardian_permission_capabilities
      where code in ('view_context','message','react',
                     'manage_authorized_people','manage_attendance_notices')
        and status = 'active') <> 5 then
    raise exception 'guardian capability catalog is incomplete';
  end if;

  if to_regprocedure(
    'public.create_authorized_person_authorization(uuid,uuid,text,text,text,bytea,text,text,text,text[],date,date)'
  ) is null then
    raise exception 'authorized-person creation RPC missing';
  end if;

  if to_regprocedure(
    'public.suspend_authorized_person_authorization(uuid,text)'
  ) is null then
    raise exception 'authorized-person suspension RPC missing';
  end if;

  if to_regprocedure(
    'public.decide_child_unit_transfer(uuid,text,text)'
  ) is null then
    raise exception 'transfer decision RPC missing';
  end if;
end
$$;

rollback;
