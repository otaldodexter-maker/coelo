-- Somente metadados da capability e dos templates envolvidos.
select current_timestamp as measured_at,
 (select count(*) from public.institution_roles where institution_id is null
   and code='institution_admin' and is_system and status='active') as active_admin_templates,
 (select jsonb_agg(jsonb_build_object('role',r.code,'effect',rp.effect,'status',rp.status,
   'revoked',rp.revoked_at is not null))
  from public.institution_role_permissions rp
  join public.institution_roles r on r.id=rp.role_id
  join public.institution_permissions p on p.id=rp.permission_id
  where r.institution_id is null and r.is_system
    and r.code in ('institution_admin','institution_reader')
    and p.code='moments.publications.remove') as existing_grants,
 (select count(*) from public.institution_permissions where code='moments.publications.remove'
   and status='active') as active_permissions,
 (select count(*) from supabase_migrations.schema_migrations where version='20260912140550') as ledger;
