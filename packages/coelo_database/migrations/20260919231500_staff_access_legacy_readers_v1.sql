-- Etapa 3 F7 (ADR 0035) — varredura dos leitores legados que juntam public.institution_memberships
-- com status='active' sem passar por has_context_permission/has_active_institution_membership.
-- Decisao (Sessao ACESSO-PERFIL, 19/09): destinatarios de notificacao (sino/e-mail/push: cuidado,
-- medicacao, revisao de seguranca da crianca, avisos), "equipe visivel"/classe do leitor (Agora) e o
-- feed proprio do Principal passam a excluir o vinculo bloqueado AGORA; contagens administrativas
-- (Pessoas, Unidades, Perfis, formularios, chat) nao mudam. Cada corpo e o vigente em producao com
-- uma unica clausula a mais por membership: "and not app_private.staff_access_blocked(<alias>.id)".
begin;

-- app_private.child_care_notification_recipients_v1: 3 membership(s) filtrada(s)
CREATE OR REPLACE FUNCTION app_private.child_care_notification_recipients_v1(p_institution_id uuid, p_unit_id uuid, p_child_context_id uuid, p_actor_person_id uuid)
 RETURNS SETOF uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  with policy as (
    select coalesce(p.notify_unit, true) as notify_unit,
      coalesce(p.notify_child_hierarchy, true) as notify_child_hierarchy,
      coalesce(p.notify_other_guardians, true) as notify_other_guardians
    from (select 1) one left join public.unit_care_policies p on p.unit_id = p_unit_id
  ),
  child as (
    select cc.child_person_id from public.child_contexts cc where cc.id = p_child_context_id
  ),
  unit_people as (
    -- equipe da unidade: memberships ativas da instituicao com escopo na unidade ou na
    -- instituicao inteira; memberships de familia (guardian/student) nao sao equipe
    select m.person_id from public.institution_memberships m
    where m.institution_id = p_institution_id and m.status = 'active' and m.revoked_at is null and not app_private.staff_access_blocked(m.id)
      and (m.scope_kind = 'institution' or (m.scope_kind = 'unit' and m.scope_unit_id = p_unit_id))
      and m.role_code not in ('legal_representative', 'guardian', 'student')
      and (select notify_unit from policy)
  ),
  hierarchy_people as (
    -- profissionais atribuidos a crianca
    select m.person_id from public.professional_child_assignments a
    join public.institution_memberships m on m.id = a.membership_id
    where a.child_context_id = p_child_context_id and a.status = 'active' and a.revoked_at is null
      and m.status = 'active' and m.revoked_at is null and not app_private.staff_access_blocked(m.id)
      and m.role_code not in ('guardian', 'student')
      and (select notify_child_hierarchy from policy)
    union
    -- professores (memberships com escopo na turma) das turmas da crianca
    select m.person_id from public.child_unit_links cul
    join public.child_group_links cgl on cgl.child_unit_link_id = cul.id and cgl.status = 'active'
    join public.institution_memberships m on m.scope_kind = 'group' and m.scope_group_id = cgl.group_id
      and m.status = 'active' and m.revoked_at is null and not app_private.staff_access_blocked(m.id)
      and m.role_code not in ('guardian', 'student')
    where cul.child_context_id = p_child_context_id and cul.status = 'active' and cul.revoked_at is null
      and (select notify_child_hierarchy from policy)
  ),
  guardian_people as (
    select g.guardian_person_id from public.guardian_links g, child
    where g.child_person_id = child.child_person_id and g.status = 'active' and g.revoked_at is null
      and (select notify_other_guardians from policy)
  )
  select distinct all_people.person_id from (
    select person_id from unit_people
    union select person_id from hierarchy_people
    union select guardian_person_id from guardian_people
  ) all_people
  join public.people person on person.id = all_people.person_id
  -- pessoas de servico (espelho das identidades internas do Superadmin/Principal) nao recebem sino
  where person.person_type = 'adult' and person.deleted_at is null and person.status = 'active'
    and all_people.person_id is distinct from p_actor_person_id
$function$;

-- app_private.medication_notification_recipients_v1: 3 membership(s) filtrada(s)
CREATE OR REPLACE FUNCTION app_private.medication_notification_recipients_v1(p_institution_id uuid, p_unit_id uuid, p_child_context_id uuid, p_actor_person_id uuid)
 RETURNS SETOF uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$

  with policy as (

    select coalesce(p.notify_unit, true) as notify_unit,

      coalesce(p.notify_child_hierarchy, true) as notify_child_hierarchy

    from (select 1) one left join public.unit_care_policies p on p.unit_id = p_unit_id

  ),

  unit_people as (

    -- administradores/equipe da unidade: memberships ativas com escopo na

    -- unidade ou na instituicao inteira (representante legal nao opera)

    select m.person_id from public.institution_memberships m

    where m.institution_id = p_institution_id and m.status = 'active' and m.revoked_at is null and not app_private.staff_access_blocked(m.id)

      and (m.scope_kind = 'institution' or (m.scope_kind = 'unit' and m.scope_unit_id = p_unit_id))

      and m.role_code <> 'legal_representative'

      and (select notify_unit from policy)

  ),

  educator_people as (

    -- profissionais atribuidos a crianca

    select m.person_id from public.professional_child_assignments a

    join public.institution_memberships m on m.id = a.membership_id

    where a.child_context_id = p_child_context_id and a.status = 'active' and a.revoked_at is null

      and m.status = 'active' and m.revoked_at is null and not app_private.staff_access_blocked(m.id)

      and (select notify_child_hierarchy from policy)

    union

    -- educadores das turmas ativas da crianca (memberships com escopo na turma)

    select m.person_id from public.child_unit_links cul

    join public.child_group_links cgl on cgl.child_unit_link_id = cul.id and cgl.status = 'active'

    join public.institution_memberships m on m.scope_kind = 'group' and m.scope_group_id = cgl.group_id

      and m.status = 'active' and m.revoked_at is null and not app_private.staff_access_blocked(m.id)

    where cul.child_context_id = p_child_context_id and cul.status = 'active' and cul.revoked_at is null

      and (select notify_child_hierarchy from policy)

  )

  select distinct all_people.person_id from (

    select person_id from unit_people

    union select person_id from educator_people

  ) all_people

  join public.people person on person.id = all_people.person_id

  where person.person_type = 'adult' and person.deleted_at is null and person.status = 'active'

    and all_people.person_id is distinct from p_actor_person_id

$function$;

-- app_private.medication_notification_recipients_v2: 3 membership(s) filtrada(s)
CREATE OR REPLACE FUNCTION app_private.medication_notification_recipients_v2(p_institution_id uuid, p_unit_id uuid, p_child_context_id uuid, p_actor_person_id uuid)
 RETURNS SETOF uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  with policy as (
    select coalesce(p.notify_unit, true) as notify_unit,
      coalesce(p.notify_child_hierarchy, true) as notify_child_hierarchy,
      coalesce(p.notify_other_guardians, true) as notify_other_guardians
    from (select 1) one left join public.unit_care_policies p on p.unit_id = p_unit_id
  ),
  child as (
    select cc.child_person_id from public.child_contexts cc where cc.id = p_child_context_id
  ),
  unit_people as (
    -- administradores/equipe da unidade (representante legal nao opera; familia nao e equipe)
    select m.person_id from public.institution_memberships m
    where m.institution_id = p_institution_id and m.status = 'active' and m.revoked_at is null and not app_private.staff_access_blocked(m.id)
      and (m.scope_kind = 'institution' or (m.scope_kind = 'unit' and m.scope_unit_id = p_unit_id))
      and m.role_code not in ('legal_representative', 'guardian', 'student')
      and (select notify_unit from policy)
  ),
  educator_people as (
    -- profissionais atribuidos a crianca
    select m.person_id from public.professional_child_assignments a
    join public.institution_memberships m on m.id = a.membership_id
    where a.child_context_id = p_child_context_id and a.status = 'active' and a.revoked_at is null
      and m.status = 'active' and m.revoked_at is null and not app_private.staff_access_blocked(m.id)
      and m.role_code not in ('guardian', 'student')
      and (select notify_child_hierarchy from policy)
    union
    -- educadores das turmas ativas da crianca (memberships com escopo na turma)
    select m.person_id from public.child_unit_links cul
    join public.child_group_links cgl on cgl.child_unit_link_id = cul.id and cgl.status = 'active'
    join public.institution_memberships m on m.scope_kind = 'group' and m.scope_group_id = cgl.group_id
      and m.status = 'active' and m.revoked_at is null and not app_private.staff_access_blocked(m.id)
      and m.role_code not in ('guardian', 'student')
    where cul.child_context_id = p_child_context_id and cul.status = 'active' and cul.revoked_at is null
      and (select notify_child_hierarchy from policy)
  ),
  guardian_people as (
    -- E7 = b: responsaveis com vinculo ativo recebem plano atualizado e dose registrada
    select g.guardian_person_id from public.guardian_links g, child
    where g.child_person_id = child.child_person_id and g.status = 'active' and g.revoked_at is null
      and (select notify_other_guardians from policy)
  )
  select distinct all_people.person_id from (
    select person_id from unit_people
    union select person_id from educator_people
    union select guardian_person_id from guardian_people
  ) all_people
  join public.people person on person.id = all_people.person_id
  where person.person_type = 'adult' and person.deleted_at is null and person.status = 'active'
    and all_people.person_id is distinct from p_actor_person_id
$function$;

-- app_private.child_safety_add_unit_review_recipients: 1 membership(s) filtrada(s)
CREATE OR REPLACE FUNCTION app_private.child_safety_add_unit_review_recipients(p_event_id uuid, p_institution_id uuid, p_unit_id uuid)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$

  with memberships as (

    select m.id,m.person_id from public.institution_memberships m

    where m.institution_id=p_institution_id and m.status='active' and m.revoked_at is null and not app_private.staff_access_blocked(m.id)

  ), effects as (

    select m.person_id,rp.effect from memberships m

    join public.institution_role_assignments a on a.membership_id=m.id

      and a.status='active' and a.scope_kind='unit' and a.scope_unit_id=p_unit_id

      and (a.starts_at is null or a.starts_at<=now())

      and (a.expires_at is null or a.expires_at>now())

    join public.institution_roles r on r.id=a.role_id and r.status='active'

      and (r.institution_id is null or r.institution_id=p_institution_id)

    join public.institution_role_permissions rp on rp.role_id=r.id

      and rp.status='active' and rp.revoked_at is null

    join public.institution_permissions p on p.id=rp.permission_id

      and p.code='authorized_people.manage' and p.status='active'

    union all

    select m.person_id,o.effect from memberships m

    join public.institution_member_permission_overrides o on o.membership_id=m.id

      and o.institution_id=p_institution_id and o.permission_code='authorized_people.manage'

      and o.scope_kind='unit' and o.scope_unit_id=p_unit_id

      and o.status='active' and o.revoked_at is null

      and (o.starts_at is null or o.starts_at<=now())

      and (o.expires_at is null or o.expires_at>now())

  ), allowed as (

    select person_id from effects group by person_id

    having bool_or(effect='allow') and not bool_or(effect='deny')

  )

  insert into public.context_notification_recipients(event_id,person_id)

    select p_event_id,person_id from allowed on conflict do nothing

$function$;

-- app_private.materialize_notice_publication_job: 1 membership(s) filtrada(s)
CREATE OR REPLACE FUNCTION app_private.materialize_notice_publication_job(p_job_id uuid, p_limit integer DEFAULT 1000)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$

declare

  job app_private.notice_publication_jobs;

  rule jsonb; dimension text; role_codes jsonb; plan_ids jsonb; excluded jsonb;

  search_term text; search_pattern text;

  page_count integer; last_key text;

begin

  if auth.role() is distinct from 'service_role' or p_limit not between 1 and 5000 then

    raise exception using errcode = '42501', message = 'not_authorized';

  end if;

  select * into job from app_private.notice_publication_jobs

  where id = p_job_id and state = 'processing' for update;

  if not found then

    raise exception using errcode = 'P0002', message = 'publication_job_not_found';

  end if;



  rule := coalesce(job.audience_snapshot -> 'rules' -> 0, '{}'::jsonb);

  dimension := coalesce(rule ->> 'dimension', 'platform');

  role_codes := coalesce(job.audience_snapshot -> 'role_codes', '[]'::jsonb);

  plan_ids := coalesce(job.audience_snapshot -> 'plan_ids', '[]'::jsonb);

  excluded := coalesce(rule -> 'excluded_ids', '[]'::jsonb);

  search_term := nullif(trim(coalesce(rule -> 'filters' -> 'search' ->> 0, '')), '');

  search_pattern := case when search_term is null then null

    else '%' || replace(replace(replace(search_term, '\', '\\'), '%', '\%'), '_', '\_') || '%' end;



  with institutional_candidates as (

    select distinct membership.person_id, membership.institution_id,

      membership.person_id::text || ':' || membership.institution_id::text as recipient_key

    from public.institution_memberships membership

    where membership.status = 'active'::public.record_status

      and membership.revoked_at is null and not app_private.staff_access_blocked(membership.id)

      and (jsonb_array_length(coalesce(rule -> 'filters' -> 'institution_ids', '[]'::jsonb)) = 0

        or rule -> 'filters' -> 'institution_ids' ? membership.institution_id::text)

      and (jsonb_array_length(coalesce(rule -> 'filters' -> 'unit_ids', '[]'::jsonb)) = 0

        or rule -> 'filters' -> 'unit_ids' ? membership.scope_unit_id::text

        or exists (select 1 from public.groups filter_group

          where filter_group.id = membership.scope_group_id

            and rule -> 'filters' -> 'unit_ids' ? filter_group.unit_id::text))

      and (jsonb_array_length(role_codes) = 0 or role_codes ? membership.role_code)

      and (jsonb_array_length(plan_ids) = 0 or exists (

        select 1 from public.institution_subscriptions subscription

        where subscription.institution_id = membership.institution_id

          and subscription.status::text in ('active', 'trial')

          and plan_ids ? subscription.plan_id::text))

      and (search_pattern is null or case dimension

        when 'institution' then exists (select 1 from public.institutions institution

          where institution.id = membership.institution_id

            and institution.public_name ilike search_pattern escape '\')

        when 'unit' then exists (select 1 from public.units unit

          where (unit.id = membership.scope_unit_id or unit.id = (select scoped_group.unit_id

              from public.groups scoped_group where scoped_group.id = membership.scope_group_id))

            and unit.name ilike search_pattern escape '\')

        when 'group' then exists (select 1 from public.groups scoped_group

          where scoped_group.id = membership.scope_group_id

            and scoped_group.name ilike search_pattern escape '\')

        else true end)

      and case dimension

        when 'platform' then true

        when 'institution' then (

          (coalesce((rule ->> 'select_all')::boolean, false)

            or rule -> 'target_ids' ? membership.institution_id::text)

          and not (excluded ? membership.institution_id::text))

        when 'unit' then (

          (coalesce((rule ->> 'select_all')::boolean, false)

            or rule -> 'target_ids' ? membership.scope_unit_id::text

            or exists (select 1 from public.groups scoped_group

              where scoped_group.id = membership.scope_group_id

                and rule -> 'target_ids' ? scoped_group.unit_id::text))

          and not (excluded ? membership.scope_unit_id::text

            or exists (select 1 from public.groups scoped_group

              where scoped_group.id = membership.scope_group_id

                and excluded ? scoped_group.unit_id::text)))

        when 'group' then (

          (coalesce((rule ->> 'select_all')::boolean, false)

            or rule -> 'target_ids' ? membership.scope_group_id::text)

          and not (excluded ? membership.scope_group_id::text))

        else false end

  ), platform_candidates as (

    select distinct membership.person_id, null::uuid as institution_id,

      membership.person_id::text || ':platform' as recipient_key

    from public.platform_memberships membership

    where dimension = 'platform'

      and membership.status::text = 'active'

      and membership.revoked_at is null

      and jsonb_array_length(role_codes) = 0

  ), person_candidates as (

    select person.id as person_id, null::uuid as institution_id,

      person.id::text || ':person' as recipient_key

    from public.people person

    where dimension = 'person'

      and person.deleted_at is null

      and (coalesce((rule ->> 'select_all')::boolean, false) or rule -> 'target_ids' ? person.id::text)

      and not (excluded ? person.id::text)

      and (search_pattern is null or person.display_name ilike search_pattern escape '\')

  ), candidates as (

    select * from institutional_candidates

    union select * from platform_candidates

    union select * from person_candidates

  ), selected as (

    select * from candidates

    where job.cursor_key is null or recipient_key > job.cursor_key

    order by recipient_key limit p_limit

  ), inserted as (

    insert into public.notice_receipts(notice_id, person_id, institution_id)

    select job.notice_id, person_id, institution_id from selected

    on conflict do nothing returning 1

  )

  select count(*), max(recipient_key) into page_count, last_key from selected;



  update app_private.notice_publication_jobs

  set cursor_key = coalesce(last_key, cursor_key),

      resolved_count = resolved_count + page_count,

      state = case when page_count < p_limit then 'completed' else 'processing' end,

      completed_at = case when page_count < p_limit then now() else null end

  where id = job.id returning * into job;



  if page_count < p_limit then

    if job.resolved_count = 0 then

      update app_private.notice_publication_jobs

      set state = 'failed', last_error_code = 'empty_audience', completed_at = null,

          attempts = 20, locked_at = null, locked_by = null

      where id = job.id;

      insert into analytics.notice_events(notice_id, event_name, properties_json)

      values (job.notice_id, 'audience_empty', jsonb_build_object(

        'publication_job_id', job.id, 'notice_version', job.notice_version));

      return jsonb_build_object('state', 'failed', 'error_code', 'empty_audience');

    end if;

    update app_private.notice_publication_jobs

    set locked_at = null, locked_by = null where id = job.id;

    insert into analytics.notice_events(notice_id, event_name, properties_json)

    values (job.notice_id, 'audience_materialized', jsonb_build_object(

      'publication_job_id', job.id, 'notice_version', job.notice_version,

      'recipient_count', job.resolved_count));

  end if;

  return jsonb_build_object('state', job.state, 'resolved_count', job.resolved_count,

    'cursor_key', job.cursor_key);

end

$function$;

-- app_private.now_viewer_role_class: 1 membership(s) filtrada(s)
CREATE OR REPLACE FUNCTION app_private.now_viewer_role_class(p_person_id uuid, p_membership_id uuid, p_institution_id uuid, p_unit_id uuid, p_group_id uuid)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$

  with student_context as (

    select 1

    from public.child_contexts child_context

    left join public.child_unit_links unit_link

      on unit_link.child_context_id=child_context.id

     and unit_link.status='active'

     and unit_link.revoked_at is null

    left join public.child_group_links group_link

      on group_link.child_unit_link_id=unit_link.id

     and group_link.status='active'

     and (group_link.starts_at is null or group_link.starts_at<=now())

     and (group_link.ends_at is null or group_link.ends_at>now())

    where child_context.child_person_id=p_person_id

      and child_context.institution_id=p_institution_id

      and child_context.status='active'

      and child_context.archived_at is null

      and (p_unit_id is null or unit_link.unit_id=p_unit_id)

      and (p_group_id is null or group_link.group_id=p_group_id)

    limit 1

  ),

  guardian_context as (

    select 1

    from public.guardian_links guardian

    join public.child_contexts child_context

      on child_context.child_person_id=guardian.child_person_id

     and child_context.institution_id=p_institution_id

     and child_context.status='active'

     and child_context.archived_at is null

    join public.guardian_context_permissions guardian_permission

      on guardian_permission.guardian_link_id=guardian.id

     and guardian_permission.child_context_id=child_context.id

     and guardian_permission.can_view

     and guardian_permission.status='active'

     and (guardian_permission.starts_at is null or guardian_permission.starts_at<=now())

     and (guardian_permission.expires_at is null or guardian_permission.expires_at>now())

    left join public.child_unit_links unit_link

      on unit_link.child_context_id=child_context.id

     and unit_link.status='active'

     and unit_link.revoked_at is null

    left join public.child_group_links group_link

      on group_link.child_unit_link_id=unit_link.id

     and group_link.status='active'

     and (group_link.starts_at is null or group_link.starts_at<=now())

     and (group_link.ends_at is null or group_link.ends_at>now())

    where guardian.guardian_person_id=p_person_id

      and guardian.status='active'

      and guardian.revoked_at is null

      and (p_unit_id is null or unit_link.unit_id=p_unit_id)

      and (p_group_id is null or group_link.group_id=p_group_id)

    limit 1

  ),

  active_membership as (

    select membership.id

    from public.institution_memberships membership

    where membership.id=p_membership_id

      and membership.person_id=p_person_id

      and membership.institution_id=p_institution_id

      and membership.status='active'

      and membership.revoked_at is null and not app_private.staff_access_blocked(membership.id)

  ),

  staff_effects as (

    select role_permission.effect

    from active_membership membership

    join public.institution_role_assignments assignment

      on assignment.membership_id=membership.id

     and assignment.status='active'

     and (assignment.starts_at is null or assignment.starts_at<=now())

     and (assignment.expires_at is null or assignment.expires_at>now())

    join public.institution_roles role_record

      on role_record.id=assignment.role_id

     and role_record.status='active'

     and (role_record.institution_id is null or role_record.institution_id=p_institution_id)

    join public.institution_role_permissions role_permission

      on role_permission.role_id=role_record.id

     and role_permission.status='active'

     and role_permission.revoked_at is null

    join public.institution_permissions permission_record

      on permission_record.id=role_permission.permission_id

     and permission_record.code='now.publications.read'

     and permission_record.status='active'

    where assignment.scope_kind='institution'

       or (assignment.scope_kind='unit' and assignment.scope_unit_id=p_unit_id)

       or (

         assignment.scope_kind='group'

         and assignment.scope_group_id=p_group_id

         and (p_unit_id is null or assignment.scope_unit_id=p_unit_id)

       )

  )

  select case

    when exists(select 1 from student_context) then 'student'

    when exists(select 1 from guardian_context) then 'guardian'

    when exists(select 1 from active_membership)

      and exists(select 1 from staff_effects where effect='allow')

      and not exists(select 1 from staff_effects where effect='deny')

      then 'school_staff'

    else null

  end

$function$;

-- public.list_my_principal_for_you: 1 membership(s) filtrada(s)
CREATE OR REPLACE FUNCTION public.list_my_principal_for_you(p_target_device text, p_membership_id uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 50)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$

declare

  actor_person uuid;

  items jsonb;

begin

  if (select auth.uid()) is null then

    raise insufficient_privilege using message = 'authentication_required';

  end if;

  if p_limit is null or p_limit not between 1 and 100 then

    raise invalid_parameter_value using message = 'invalid_for_you_query';

  end if;

  if p_target_device is null or p_target_device not in ('all', 'web', 'mobile', 'tablet') then

    raise invalid_parameter_value using message = 'invalid_for_you_target_device';

  end if;

  actor_person := app_private.person_id_for_auth_user((select auth.uid()));

  if actor_person is null then

    raise insufficient_privilege using message = 'principal_context_denied';

  end if;



  with actor as (

    select

      membership.id             as membership_id,

      membership.person_id      as person_id,

      membership.institution_id as institution_id,

      membership.role_code      as role_code,

      scoped_unit.id            as unit_id,

      scoped_group.id           as group_id

    from public.people person

    join public.institution_memberships membership

      on membership.person_id = person.id

     and membership.status = 'active'

     and membership.revoked_at is null and not app_private.staff_access_blocked(membership.id)

    join public.institutions institution

      on institution.id = membership.institution_id

     and institution.status = 'active'

    left join public.groups scoped_group

      on scoped_group.id = membership.scope_group_id

     and scoped_group.institution_id = membership.institution_id

     and scoped_group.status = 'active'

    left join public.units scoped_unit

      on scoped_unit.id = coalesce(membership.scope_unit_id, scoped_group.unit_id)

     and scoped_unit.institution_id = membership.institution_id

     and scoped_unit.status = 'active'

    where person.id = actor_person

      and person.status = 'active'

      and (p_membership_id is null or membership.id = p_membership_id)

  ),

  eligible as (

    select notice.*,

      notice.audience_json -> 'rules' -> 0 as rule_json,

      coalesce(notice.audience_json -> 'role_codes', '[]'::jsonb) as role_codes

    from public.platform_notices notice

    where notice.notice_type::text in ('highlight', 'content_card', 'for_you')

      and notice.status::text = 'active'

      and (notice.target_device = 'all' or notice.target_device = p_target_device)

      and notice.starts_at is not null

      and notice.starts_at <= now()

      and (notice.ends_at is null or notice.ends_at > now())

  ),

  visible as (

    select distinct on (eligible.id) eligible.*

    from eligible

    cross join actor

    where

      (jsonb_array_length(eligible.role_codes) = 0

        or exists (select 1 from jsonb_array_elements_text(eligible.role_codes) code(value)

                   where code.value = actor.role_code))

      and (

        case eligible.rule_json ->> 'dimension'

          when 'platform' then true

          when 'institution' then

            coalesce((eligible.rule_json ->> 'select_all')::boolean, false)

            or (eligible.rule_json -> 'target_ids') ? actor.institution_id::text

          when 'unit' then

            actor.unit_id is not null and (

              coalesce((eligible.rule_json ->> 'select_all')::boolean, false)

              or (eligible.rule_json -> 'target_ids') ? actor.unit_id::text)

          when 'group' then

            actor.group_id is not null and (

              coalesce((eligible.rule_json ->> 'select_all')::boolean, false)

              or (eligible.rule_json -> 'target_ids') ? actor.group_id::text)

          when 'person' then

            coalesce((eligible.rule_json ->> 'select_all')::boolean, false)

            or (eligible.rule_json -> 'target_ids') ? actor.person_id::text

          else false

        end)

      and not exists (

        select 1 from jsonb_array_elements_text(coalesce(eligible.rule_json -> 'excluded_ids', '[]'::jsonb)) excluded(value)

        where excluded.value in (actor.institution_id::text, coalesce(actor.unit_id::text, ''),

          coalesce(actor.group_id::text, ''), actor.person_id::text, actor.membership_id::text))

      and not exists (

        select 1 from public.notice_rules rule

        where rule.notice_id = eligible.id and rule.effect = 'exclude'

          and ((rule.target_type = 'platform')

            or (rule.target_type = 'institution' and rule.target_id = actor.institution_id)

            or (rule.target_type = 'unit' and rule.target_id = actor.unit_id)

            or (rule.target_type = 'group' and rule.target_id = actor.group_id)

            or (rule.role_filter is not null and rule.role_filter = actor.role_code)))

    order by eligible.id

  )

  select coalesce(jsonb_agg(app_private.superadmin_notice_json(notice)

      order by page.rank, page.occurred_at desc, page.id desc), '[]'::jsonb)

    into items

  from (select visible.id,

          case visible.priority_code when 'urgent' then 0 when 'important' then 10 else 20 end as rank,

          coalesce(visible.starts_at, visible.published_at, visible.created_at) as occurred_at

        from visible

        order by 2, 3 desc, 1 desc

        limit p_limit) page

  join public.platform_notices notice on notice.id = page.id;



  return jsonb_build_object('ok', true, 'data', jsonb_build_object('items', items), 'error', null);

end $function$;

-- public.redeem_now_media_read_ticket: 1 membership(s) filtrada(s)
CREATE OR REPLACE FUNCTION public.redeem_now_media_read_ticket(p_ticket uuid, p_viewer_auth_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  redeemed record;
  redeeming_person_id uuid;
begin
  redeeming_person_id:=app_private.person_id_for_auth_user(p_viewer_auth_user_id);
  if redeeming_person_id is null then
    raise insufficient_privilege using message='media_read_ticket_invalid';
  end if;
  delete from app_private.now_media_read_tickets ticket
  using public.now_media_assets asset,
        public.now_publications publication
  where ticket.token=p_ticket
    and ticket.expires_at>now()
    and ticket.viewer_person_id=redeeming_person_id
    and asset.id=ticket.media_asset_id
    and asset.status='ready'
    and publication.id=asset.publication_id
    and publication.institution_id=asset.institution_id
    and publication.status in('scheduled','published')
    and publication.publish_at<=now()
    and publication.expires_at>now()
    and publication.status<>'expired'
    and exists(
      select 1
      from public.now_publication_audiences audience
      where audience.publication_id=publication.id
        and audience.institution_id=publication.institution_id
        and audience.unit_id is not distinct from publication.unit_id
        and audience.group_id is not distinct from publication.group_id
        and app_private.now_audience_matches_role(
          app_private.now_viewer_role_class(
            ticket.viewer_person_id,
            (
              -- membership ativa do visitante na instituicao da publicacao (nula para o responsavel por vinculo)
              select membership.id
              from public.institution_memberships membership
              where membership.person_id=ticket.viewer_person_id
                and membership.institution_id=publication.institution_id
                and membership.status='active'
                and membership.revoked_at is null and not app_private.staff_access_blocked(membership.id)
              order by membership.created_at
              limit 1
            ),
            publication.institution_id,
            publication.unit_id,
            publication.group_id
          ),
          audience.audience_kind
        )
    )
  returning asset.storage_provider,asset.bucket_id,asset.object_key,asset.mime_type into redeemed;
  if redeemed.object_key is null then
    raise insufficient_privilege using message='media_read_ticket_invalid';
  end if;
  return jsonb_build_object(
    'storage_provider',redeemed.storage_provider,
    'bucket_id',redeemed.bucket_id,
    'object_key',redeemed.object_key,
    'mime_type',redeemed.mime_type
  );
end $function$;

commit;
