from pathlib import Path
import shutil
root=Path('C:/Users/adrie/Documents/Coelo')
directory=root/'packages/coelo_database/candidatos/r11-conta'
directory.mkdir(parents=True,exist_ok=True)
name='20260913144142_r11_account_avatar_access_v2.sql'
created=Path('C:/Users/adrie/Documents/Coelo-backups/r11-local/supabase/migrations')/name
target=directory/name
if created.exists(): shutil.move(str(created),str(target))
projection=(root/'packages/coelo_database/migrations/20260911200300_account_profile_service_person_email_v1.sql').read_text(encoding='utf-8-sig')
projection=projection[projection.index('create or replace function'):]
projection=projection.replace("'first_name', person.first_name", "'avatar_contract_version', 2, 'first_name', person.first_name")
projection=projection.replace("left(upper(coalesce", "coalesce(person.account_avatar_initials, left(upper(coalesce",1)
projection=projection.replace("''), '')), 2),", "''), '')), 2)),",1)
projection=projection.replace("'background_color', '#FFF1EB'", "'background_color', coalesce(person.account_avatar_background_color, '#FFF1EB')")
start=projection.index("      'capabilities', coalesce(")
end=projection.index("    ), 'email_change'",start)
projection=projection[:start]+'''      'capabilities', coalesce((select jsonb_agg(distinct permission.description)
        from public.platform_permissions permission
        where permission.status='active' and exists (
          select 1 from public.platform_memberships membership
          where membership.person_id=p_person_id and membership.status='active'
            and membership.revoked_at is null
            and app_private.has_platform_permission(permission.code,membership.scope_institution_id))), '[]'::jsonb),
      'capability_details', coalesce((select jsonb_agg(item order by item->>'module_label',item->>'scope_label',item->>'label')
        from (select distinct jsonb_build_object(
          'code',permission.code,'label',permission.description,
          'module_code',permission.module_code,'module_label',permission.module_label,
          'scope_kind',membership.scope_kind,'scope_id',membership.scope_institution_id,
          'scope_label',case when membership.scope_kind='platform' then 'Plataforma' else institution.public_name end
        ) item
        from public.platform_memberships membership
        join public.platform_roles role on role.id=membership.role_id and role.status='active'
        cross join public.platform_permissions permission
        left join public.institutions institution on institution.id=membership.scope_institution_id
        where membership.person_id=p_person_id and membership.status='active'
          and membership.revoked_at is null and permission.status='active'
          and app_private.has_platform_permission(permission.code,membership.scope_institution_id)) items), '[]'::jsonb)
'''+projection[end:]
source=(root/'packages/coelo_database/migrations/20260910230020_superadmin_account_profile_v1.sql').read_text(encoding='utf-8-sig')
start=source.index('create or replace function public.superadmin_account_profile_save(')
end=source.index('\n$$;',start)+len('\n$$;')
save=source[start:end].replace('public.superadmin_account_profile_save(', 'public.superadmin_account_profile_save_v2(',1)
save=save.replace('p_requested_email text default null, p_avatar_initials text default null','p_requested_email text default null, p_avatar_initials text default null,\n  p_avatar_background_color text default null')
save=save.replace("or (p_avatar_initials is not null", "or (p_avatar_background_color is not null and p_avatar_background_color !~ '^#[0-9A-Fa-f]{6}$')\n    or (p_avatar_initials is not null",1)
save=save.replace('  select response_json into result from public.account_profile_command_receipts where request_id = p_request_id;', '''  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text,0));
  if exists (select 1 from public.account_profile_command_receipts where request_id=p_request_id and (person_id<>actor_id or action_code<>'save')) then
    raise exception using errcode='42501',message='account_request_not_owned';
  end if;
  select response_json into result from public.account_profile_command_receipts where request_id=p_request_id and person_id=actor_id and action_code='save';''')
save=save.replace('  update public.people set first_name', '''  if current_email is null then select email into current_email from auth.users where id=auth.uid(); end if;
  update public.people set account_avatar_initials=coalesce(upper(p_avatar_initials),account_avatar_initials),
    account_avatar_background_color=coalesce(upper(p_avatar_background_color),account_avatar_background_color), first_name''')
sql='''-- R11: self-owned initials/color and real capability metadata. No photo transport added.
begin;
alter table public.people add column account_avatar_initials text check(account_avatar_initials ~ '^[[:alpha:]]{1,2}$');
alter table public.people add column account_avatar_background_color text check(account_avatar_background_color ~ '^#[0-9A-F]{6}$');
'''+projection+'\n'+save+'''
revoke all on function public.superadmin_account_profile_save_v2(uuid,text,text,text,text,text,text) from public,anon;
grant execute on function public.superadmin_account_profile_save_v2(uuid,text,text,text,text,text,text) to authenticated;
create or replace function public.superadmin_account_profile_save(
  p_request_id uuid,p_first_name text,p_last_name text,p_mobile_phone text,
  p_requested_email text default null,p_avatar_initials text default null
) returns jsonb language sql security definer set search_path='' as $$
  select public.superadmin_account_profile_save_v2(p_request_id,p_first_name,p_last_name,p_mobile_phone,p_requested_email,p_avatar_initials,null)
$$;
commit;
'''
target.write_text(sql,encoding='utf-8')
print(target.relative_to(root).as_posix())
