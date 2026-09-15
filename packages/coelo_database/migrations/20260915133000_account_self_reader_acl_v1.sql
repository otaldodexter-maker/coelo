-- R14: Account reader is self-scoped and callable only by the internal realm.
-- Candidate order: after 20260910230020_superadmin_account_profile_v1.sql.
-- Apply locally first; production requires nominal authorization.
begin;

revoke all on function public.superadmin_account_profile_get() from public, anon;
grant execute on function public.superadmin_account_profile_get() to authenticated;

commit;
