begin;

do $$
declare current_table text;
begin
  foreach current_table in array array[
    'activity_capability_policies',
    'activity_group_capability_settings',
    'activity_group_participants'
  ] loop
    if to_regclass('public.' || current_table) is null then
      raise exception 'public.% is missing', current_table;
    end if;
    if not exists (
      select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='public' and c.relname=current_table and c.relrowsecurity
    ) then raise exception 'RLS missing on public.%', current_table; end if;
  end loop;

  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='activity_definitions'
      and column_name in ('distribution_scope','governance_kind','promoted_at')
    group by table_schema,table_name having count(*)=3
  ) then raise exception 'activity governance columns missing'; end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='activity_group_links'
      and column_name='participation_mode'
  ) then raise exception 'activity participation mode missing'; end if;

  if to_regprocedure('public.promote_activity_to_institution_standard(uuid,text,text)') is null
  then raise exception 'activity promotion RPC missing'; end if;
end
$$;

rollback;
