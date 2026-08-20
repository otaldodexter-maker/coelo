-- Lightweight catalog validation for environments without pgTAP.
select table_schema, table_name
from information_schema.tables
where table_schema = 'public' and table_name = 'meal_plans';

select routine_schema, routine_name, security_type
from information_schema.routines
where routine_schema = 'public'
  and routine_name in (
    'meal_plan_list',
    'meal_plan_get',
    'meal_plan_create_or_update_draft',
    'meal_plan_submit_for_review',
    'meal_plan_publish',
    'meal_plan_conflicts_check',
    'meal_plan_effective_snapshot'
  )
order by routine_name;

select c.relrowsecurity, c.relforcerowsecurity
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relname = 'meal_plans';

select pol.polname, pg_get_expr(pol.polqual, pol.polrelid) as using_expression
from pg_policy pol
join pg_class c on c.oid = pol.polrelid
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relname = 'meal_plans'
order by pol.polname;
