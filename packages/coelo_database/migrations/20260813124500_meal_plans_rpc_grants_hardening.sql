-- SECURITY DEFINER meal-plan RPCs must never be callable anonymously.

revoke all on function public.meal_plan_json(public.meal_plans) from public, anon, authenticated;
revoke all on function public.meal_plan_list(jsonb) from public, anon;
revoke all on function public.meal_plan_get(uuid) from public, anon;
revoke all on function public.meal_plan_conflicts_check(text, text, date, date, jsonb, jsonb) from public, anon;
revoke all on function public.meal_plan_create_or_update_draft(text, jsonb, uuid, integer) from public, anon;
revoke all on function public.meal_plan_submit_for_review(text, uuid, integer) from public, anon;
revoke all on function public.meal_plan_publish(text, uuid, integer) from public, anon;
revoke all on function public.meal_plan_effective_snapshot(jsonb) from public, anon;

grant execute on function public.meal_plan_list(jsonb) to authenticated;
grant execute on function public.meal_plan_get(uuid) to authenticated;
grant execute on function public.meal_plan_conflicts_check(text, text, date, date, jsonb, jsonb) to authenticated;
grant execute on function public.meal_plan_create_or_update_draft(text, jsonb, uuid, integer) to authenticated;
grant execute on function public.meal_plan_submit_for_review(text, uuid, integer) to authenticated;
grant execute on function public.meal_plan_publish(text, uuid, integer) to authenticated;
grant execute on function public.meal_plan_effective_snapshot(jsonb) to authenticated;
