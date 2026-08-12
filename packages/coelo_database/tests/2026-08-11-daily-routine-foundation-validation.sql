-- Lightweight catalog validation for environments without pgTAP.
select table_schema, table_name
from information_schema.tables
where table_schema in ('public','app_private')
  and table_name in (
    'routine_models','routine_model_versions','routine_sections','routine_fields',
    'routine_field_options','routine_field_conditions','routine_applications',
    'routine_application_revisions','routine_application_assignees',
    'routine_launches','routine_child_entries','routine_answers',
    'routine_launch_revisions','routine_command_receipts'
  )
order by table_schema, table_name;

select routine_schema, routine_name
from information_schema.routines
where routine_schema='public' and routine_name like 'superadmin_daily_routine_%'
order by routine_name;
