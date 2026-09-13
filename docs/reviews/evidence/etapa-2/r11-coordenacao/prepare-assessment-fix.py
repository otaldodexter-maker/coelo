from pathlib import Path
import shutil
root=Path('C:/Users/adrie/Documents/Coelo')
name='20260913143441_r11_assessment_update_isolation_v1.sql'
created=Path('C:/Users/adrie/Documents/Coelo-backups/r11-local/supabase/migrations')/name
target=root/'packages/coelo_database/candidatos/r11-estrutura'/name
if created.exists(): shutil.move(str(created),str(target))
source=(root/'packages/coelo_database/migrations/20260910180350_superadmin_assessments_internal_v2.sql').read_text(encoding='utf-8-sig')
start=source.index('create or replace function app_private.assessment_v2_save_configuration(')
end=source.index('\nend $$;',start)+len('\nend $$;')
function=source[start:end]
for table in ('assessment_instruments','assessment_categories','assessment_scale_concepts','assessment_periods'):
    before=f'delete from public.{table} where configuration_id = saved.id;'
    assert function.count(before)==1
    function=function.replace(before,f'delete from public.{table} item where item.configuration_id = saved.id;')
target.write_text('-- R11: qualify child rows under #variable_conflict use_variable.\n-- Keep receipt, actor, tenant and optimistic-version checks unchanged.\n'+function+'\n',encoding='utf-8')
print(target.relative_to(root).as_posix())
