begin;

alter table public.meal_plans force row level security;
grant select, insert, update, delete on table public.meal_plans to authenticated;
revoke all on table public.meal_plans from anon;

alter function public.meal_plan_list(jsonb) security invoker;
alter function public.meal_plan_get(uuid) security invoker;
alter function public.meal_plan_create_or_update_draft(text, jsonb, uuid, integer) security invoker;
alter function public.meal_plan_submit_for_review(text, uuid, integer) security invoker;
alter function public.meal_plan_publish(text, uuid, integer) security invoker;
alter function public.meal_plan_conflicts_check(text, text, date, date, jsonb, jsonb) security invoker;
alter function public.meal_plan_effective_snapshot(jsonb) security invoker;

commit;
