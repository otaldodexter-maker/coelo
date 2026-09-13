from pathlib import Path
import shutil
root=Path('C:/Users/adrie/Documents/Coelo')
name='20260913145023_r11_assessment_all_participants_v1.sql'
created=Path('C:/Users/adrie/Documents/Coelo-backups/r11-local/supabase/migrations')/name
target=root/'packages/coelo_database/candidatos/r11-estrutura'/name
if created.exists(): shutil.move(str(created),str(target))
source=(root/'packages/coelo_database/migrations/20260910180350_superadmin_assessments_internal_v2.sql').read_text(encoding='utf-8-sig')
def definition(name):
    start=source.index('create or replace function app_private.'+name+'(')
    return source[start:source.index('$$;',start)+3]
initial=definition('assessment_v2_initial_students')
start=initial.index('  from public.activity_group_participants participant')
initial=initial[:start]+'''  from public.activity_group_links activity_link
  join public.groups group_row on group_row.id=activity_link.group_id
    and group_row.institution_id=activity_link.institution_id
    and group_row.unit_id=activity_link.unit_id and group_row.status='active'
  join public.units unit_row on unit_row.id=group_row.unit_id
    and unit_row.institution_id=group_row.institution_id and unit_row.status='active'
  join public.child_group_links child_group on child_group.group_id=group_row.id and child_group.status='active'
  join public.child_unit_links child_unit on child_unit.id=child_group.child_unit_link_id
    and child_unit.unit_id=group_row.unit_id and child_unit.status='active'
  join public.child_contexts child_context on child_context.id=child_unit.child_context_id
    and child_context.institution_id=group_row.institution_id and child_context.status='active'
  join public.people person on person.id=child_context.child_person_id and person.status='active'
  where activity_link.id=p_activity_group_link_id and activity_link.status='active'
    and (activity_link.participation_mode='all' or exists (
      select 1 from public.activity_group_participants participant
      where participant.activity_group_link_id=activity_link.id
        and participant.child_group_link_id=child_group.id
        and participant.status='active' and participant.removed_at is null))
$$;'''
validate=definition('assessment_v2_validate_students')
start=validate.index('    if not exists (\n      select 1 from public.activity_group_participants')
end=validate.index("    if (select count(*)",start)
validate=validate[:start]+'''    if not exists (
      select 1 from jsonb_array_elements(app_private.assessment_v2_initial_students(p_gradebook.activity_group_link_id)) candidate
      where candidate->>'child_context_id'=child_context_id::text
    ) then raise invalid_parameter_value using detail='ASSESSMENT_INVALID_REFERENCE'; end if;
'''+validate[end:]
snapshot=definition('assessment_v2_gradebook_snapshot')
snapshot=snapshot.replace("'students', b.students_payload,", """'students', b.students_payload || case when b.status='draft' then
      coalesce((select jsonb_agg(candidate || jsonb_build_object('id',candidate->>'child_context_id'))
        from jsonb_array_elements(app_private.assessment_v2_initial_students(b.activity_group_link_id)) candidate
        where not exists (select 1 from jsonb_array_elements(b.students_payload) saved
          where saved->>'child_context_id'=candidate->>'child_context_id')), '[]'::jsonb)
      else '[]'::jsonb end,""")
target.write_text('-- R11: all-mode eligibility and existing empty draft recovery. No participant/link creation.\n'+initial+'\n'+validate+'\n'+snapshot+'\n',encoding='utf-8')
test=root/'packages/coelo_database/candidatos/r11-estrutura/gradebook-all-participants-test.sql'
test_source=test.read_text(encoding='utf-8')
fixture=(root/'packages/coelo_database/supabase/tests/superadmin_assessments_internal_v2_test.sql').read_text(encoding='utf-8-sig')
start=fixture.index("select set_config('app_private.activity_v2_internal_marker',jsonb_build_object(")
marker=fixture[start:fixture.index('::text,true);',start)+len('::text,true);')]
test_source=test_source.replace('insert into public.activity_group_participants(activity_group_link_id',marker+'\ninsert into public.activity_group_participants(activity_group_link_id')
test.write_text(test_source,encoding='utf-8')
