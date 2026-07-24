begin;

do $$
declare current_table text;
begin
  foreach current_table in array array[
    'attendance_reason_catalog','attendance_sessions',
    'attendance_expected_participants','attendance_notices',
    'attendance_notice_attachments','attendance_records',
    'attendance_record_revisions'
  ] loop
    if to_regclass('public.' || current_table) is null then
      raise exception 'public.% is missing',current_table;
    end if;
    if not exists (
      select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='public' and c.relname=current_table and c.relrowsecurity
    ) then raise exception 'RLS missing on public.%',current_table; end if;
  end loop;
  if to_regclass('public.attendance_summary') is null
  then raise exception 'attendance summary view missing'; end if;
  if not exists (
    select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relname='attendance_summary'
      and c.reloptions @> array['security_invoker=true']
  ) then raise exception 'attendance summary must be security_invoker'; end if;
  if to_regprocedure(
    'public.submit_attendance_notice(uuid,text,timestamptz,timestamptz,uuid,text,text,uuid)'
  ) is null then raise exception 'attendance notice RPC missing'; end if;
  if to_regprocedure(
    'public.confirm_attendance_record(uuid,uuid,text,uuid,text)'
  ) is null then raise exception 'attendance confirmation RPC missing'; end if;
end
$$;

rollback;
