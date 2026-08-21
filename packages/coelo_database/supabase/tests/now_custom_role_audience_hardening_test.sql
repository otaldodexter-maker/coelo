begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

select has_function(
  'app_private','now_viewer_role_class',array['uuid','uuid','uuid','uuid','uuid'],
  'Agora viewer classification exists'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'app_private.now_viewer_role_class(uuid,uuid,uuid,uuid,uuid)',
    'EXECUTE'
  ),
  'clients cannot call the private viewer classifier'
);
select ok(
  position(
    'now_viewer_role_class' in
    pg_get_functiondef('public.list_visible_now_publications(uuid,uuid,uuid,integer)'::regprocedure)
  )>0,
  'Agora feed derives audience from the authoritative viewer classifier'
);
select ok(
  position(
    'now_viewer_role_class' in
    pg_get_functiondef('public.redeem_now_media_read_ticket(uuid,uuid)'::regprocedure)
  )>0,
  'ticket redemption revalidates the authoritative viewer classifier'
);
select ok(
  position(
    'membership.role_code' in
    pg_get_functiondef('public.list_visible_now_publications(uuid,uuid,uuid,integer)'::regprocedure)
  )=0
  and position(
    'membership.role_code' in
    pg_get_functiondef('public.redeem_now_media_read_ticket(uuid,uuid)'::regprocedure)
  )=0,
  'free-form membership role codes never authorize feed or media reads'
);

insert into public.people(id,person_type,first_name,last_name,display_name,status) values
  ('95100000-0000-4000-8000-000000000001','adult','Custom','Allowed','Custom Allowed','active'),
  ('95100000-0000-4000-8000-000000000002','adult','Custom','Unassigned','Custom Unassigned','active'),
  ('95100000-0000-4000-8000-000000000003','adult','Custom','Denied','Custom Denied','active'),
  ('95100000-0000-4000-8000-000000000004','child','Agora','Student','Agora Student','active'),
  ('95100000-0000-4000-8000-000000000005','adult','Agora','Guardian','Agora Guardian','active');

insert into public.institutions(id,public_name,legal_name,slug,status) values
  ('95200000-0000-4000-8000-000000000001','Agora Custom A','Agora Custom A','agora-custom-a','active'),
  ('95200000-0000-4000-8000-000000000002','Agora Custom B','Agora Custom B','agora-custom-b','active');

insert into public.institution_memberships(id,person_id,institution_id,role_code,status,scope_kind) values
  ('95300000-0000-4000-8000-000000000001','95100000-0000-4000-8000-000000000001','95200000-0000-4000-8000-000000000001','generated-custom-role-a','active','institution'),
  ('95300000-0000-4000-8000-000000000002','95100000-0000-4000-8000-000000000002','95200000-0000-4000-8000-000000000001','arbitrary-without-assignment','active','institution'),
  ('95300000-0000-4000-8000-000000000003','95100000-0000-4000-8000-000000000003','95200000-0000-4000-8000-000000000001','generated-custom-role-denied','active','institution'),
  ('95300000-0000-4000-8000-000000000004','95100000-0000-4000-8000-000000000004','95200000-0000-4000-8000-000000000001','non-authoritative-student-label','active','institution'),
  ('95300000-0000-4000-8000-000000000005','95100000-0000-4000-8000-000000000005','95200000-0000-4000-8000-000000000001','non-authoritative-guardian-label','active','institution');

insert into public.institution_roles(id,institution_id,code,name,status,is_system,max_scope_kind) values
  ('95400000-0000-4000-8000-000000000001','95200000-0000-4000-8000-000000000001','custom-agora-reader','Leitor personalizado do Agora','active',false,'institution'),
  ('95400000-0000-4000-8000-000000000002','95200000-0000-4000-8000-000000000001','custom-agora-deny','Negação personalizada do Agora','active',false,'institution');

insert into public.institution_role_permissions(role_id,permission_id,effect,status)
select '95400000-0000-4000-8000-000000000001',permission.id,'allow','active'
from public.institution_permissions permission
where permission.code='now.publications.read';
insert into public.institution_role_permissions(role_id,permission_id,effect,status)
select '95400000-0000-4000-8000-000000000002',permission.id,'deny','active'
from public.institution_permissions permission
where permission.code='now.publications.read';

insert into public.institution_role_assignments(
  membership_id,role_id,scope_kind,status
) values
  ('95300000-0000-4000-8000-000000000001','95400000-0000-4000-8000-000000000001','institution','active'),
  ('95300000-0000-4000-8000-000000000003','95400000-0000-4000-8000-000000000001','institution','active'),
  ('95300000-0000-4000-8000-000000000003','95400000-0000-4000-8000-000000000002','institution','active');

insert into public.child_contexts(id,child_person_id,institution_id,status) values
  ('95500000-0000-4000-8000-000000000001','95100000-0000-4000-8000-000000000004','95200000-0000-4000-8000-000000000001','active');
insert into public.guardian_links(id,guardian_person_id,child_person_id,relation_type,status) values
  ('95600000-0000-4000-8000-000000000001','95100000-0000-4000-8000-000000000005','95100000-0000-4000-8000-000000000004','responsavel','active');
insert into public.guardian_context_permissions(
  guardian_link_id,child_context_id,can_view,status
) values(
  '95600000-0000-4000-8000-000000000001',
  '95500000-0000-4000-8000-000000000001',
  true,
  'active'
);

select is(
  app_private.now_viewer_role_class(
    '95100000-0000-4000-8000-000000000001',
    '95300000-0000-4000-8000-000000000001',
    '95200000-0000-4000-8000-000000000001',null,null
  ),
  'school_staff',
  'a custom institution role with an active read capability is staff'
);
select is(
  app_private.now_viewer_role_class(
    '95100000-0000-4000-8000-000000000002',
    '95300000-0000-4000-8000-000000000002',
    '95200000-0000-4000-8000-000000000001',null,null
  ),
  null,
  'an arbitrary role code without assignment remains denied'
);
select is(
  app_private.now_viewer_role_class(
    '95100000-0000-4000-8000-000000000003',
    '95300000-0000-4000-8000-000000000003',
    '95200000-0000-4000-8000-000000000001',null,null
  ),
  null,
  'an explicit deny wins over a custom role allow'
);
select is(
  app_private.now_viewer_role_class(
    '95100000-0000-4000-8000-000000000001',
    '95300000-0000-4000-8000-000000000001',
    '95200000-0000-4000-8000-000000000002',null,null
  ),
  null,
  'a custom role assignment cannot cross institutions'
);
select is(
  app_private.now_viewer_role_class(
    '95100000-0000-4000-8000-000000000004',
    '95300000-0000-4000-8000-000000000004',
    '95200000-0000-4000-8000-000000000001',null,null
  ),
  'student',
  'student audience is derived from the active child context, not role text'
);
select is(
  app_private.now_viewer_role_class(
    '95100000-0000-4000-8000-000000000005',
    '95300000-0000-4000-8000-000000000005',
    '95200000-0000-4000-8000-000000000001',null,null
  ),
  'guardian',
  'guardian audience is derived from active view permission, not role text'
);
select is(
  app_private.now_audience_matches_role('school_staff','school_staff'),
  true,
  'the derived staff class matches only the staff audience'
);
select is(
  app_private.now_audience_matches_role('school_staff','families'),
  false,
  'the derived staff class never crosses into family audience'
);

select * from finish();
rollback;
