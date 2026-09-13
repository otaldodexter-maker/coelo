from pathlib import Path
import shutil
root=Path('C:/Users/adrie/Documents/Coelo')
name='20260913143659_r11_group_directory_counts_v1.sql'
created=Path('C:/Users/adrie/Documents/Coelo-backups/r11-local/supabase/migrations')/name
target=root/'packages/coelo_database/candidatos/r11-estrutura'/name
if created.exists(): shutil.move(str(created),str(target))
source=(root/'packages/coelo_database/migrations-historico/20260811151254_group_management_security.sql').read_text(encoding='utf-8-sig')
start=source.index('create or replace function app_private.superadmin_group_directory(')
end=source.index('\nend $$;',start)+len('\nend $$;')
function=source[start:end]
function=function.replace("where (nullif(btrim(p_search), '') is null", "where app_private.has_platform_permission('groups.read', group_record.institution_id)\n      and (nullif(btrim(p_search), '') is null",1)
before="'status', status, 'created_at', created_at, 'updated_at', updated_at"
after="""'status', status, 'created_at', created_at, 'updated_at', updated_at,
      'student_count', jsonb_array_length(app_private.superadmin_group_students_payload(filtered.id)),
      'activity_ids', case when filtered.inherit_activities then
        coalesce((select jsonb_agg(distinct link.activity_id order by link.activity_id)
          from public.activity_unit_links link
          join public.activity_definitions activity on activity.id=link.activity_id
            and activity.institution_id=filtered.institution_id
          where link.unit_id=filtered.unit_id and link.institution_id=filtered.institution_id
            and link.status='active'), '[]'::jsonb)
        else coalesce((select jsonb_agg(distinct link.activity_id order by link.activity_id)
          from public.activity_group_links link
          join public.activity_definitions activity on activity.id=link.activity_id
            and activity.institution_id=filtered.institution_id
          where link.group_id=filtered.id and link.unit_id=filtered.unit_id
            and link.institution_id=filtered.institution_id and link.status='active'), '[]'::jsonb)
        end"""
assert function.count(before)==1
target.write_text('-- R11: count active links using existing inheritance and authorized hierarchy.\n'+function.replace(before,after)+'\n',encoding='utf-8')
test=root/'packages/coelo_database/candidatos/r11-estrutura/group-directory-counts-test.sql'
test.write_text(test.read_text().replace("status='ended'", "status='inactive'").replace('ended unit','inactive unit').replace('ended group','inactive group'),encoding='utf-8')
