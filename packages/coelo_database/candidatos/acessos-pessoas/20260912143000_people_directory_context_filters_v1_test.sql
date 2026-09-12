-- pgTAP do candidato 20260912143000. Executar somente após o candidato, em banco local descartável.
begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

-- Contrato único PostgREST: a assinatura antiga é removida, defaults preservam
-- chamadas anteriores e os quatro filtros novos são explicitamente tipados.
select has_function('public','superadmin_people_list',array[
  'text','person_type[]','record_status[]','uuid[]','uuid[]','uuid[]','text[]','text[]',
  'text','boolean','integer','integer','text','uuid[]','text[]','text[]','text[]'
], 'listagem de Pessoas expõe atividade e localidade sem sobrecarga');
select is((select count(*)::int from pg_proc where pronamespace='public'::regnamespace and proname='superadmin_people_list'),1,
  'PostgREST vê uma única assinatura de listagem');
select function_privs_are('public','superadmin_people_list',array[
  'text','person_type[]','record_status[]','uuid[]','uuid[]','uuid[]','text[]','text[]',
  'text','boolean','integer','integer','text','uuid[]','text[]','text[]','text[]'
], 'authenticated',array['EXECUTE'],'authenticated conserva execução');
select ok(not has_function_privilege('anon',
  'public.superadmin_people_list(text,public.person_type[],public.record_status[],uuid[],uuid[],uuid[],text[],text[],text,boolean,integer,integer,text,uuid[],text[],text[],text[])','EXECUTE'),
  'anon não recebe diretório de Pessoas');

create function pg_temp.people_list_def() returns text language sql as $$
  select pg_get_functiondef('public.superadmin_people_list(text,public.person_type[],public.record_status[],uuid[],uuid[],uuid[],text[],text[],text,boolean,integer,integer,text,uuid[],text[],text[],text[])'::regprocedure)
$$;
select ok(pg_temp.people_list_def() like all(array[
  '%activity_group_assignments%', '%activity_group_links%', '%activity_group_participants%',
  '%aga.status=''active''%', '%aga.revoked_at is null%', '%agp.removed_at is null%'
]), 'atividade aceita somente profissional/participante vigentes');
select ok(pg_temp.people_list_def() like '%from context_rows c where c.person_id=p.id%'
  and pg_temp.people_list_def() like '%c.institution_id=any(p_institution_ids)%'
  and pg_temp.people_list_def() like '%c.unit_id=any(p_unit_ids)%'
  and pg_temp.people_list_def() like '%c.group_id=any(p_group_ids)%',
  'instituição, unidade e grupo são resolvidos no mesmo contexto');
select ok(pg_temp.people_list_def() like '%r.name contextual_role_name%'
  and pg_temp.people_list_def() like '%b.contextual_role_name role_name%'
  and pg_temp.people_list_def() not like '%left join public.institution_roles r on r.code=b.contextual_role%',
  'nome do perfil vem da linha original, inclusive perfil global com institution_id nulo');
select ok(pg_temp.people_list_def() like '%coalesce(ua.state,ia.state)%'
  and pg_temp.people_list_def() like '%coalesce(ua.city,ia.city)%'
  and pg_temp.people_list_def() like '%coalesce(ua.district,ia.district)%',
  'localidade percorre unidade/instituição canônicas, não ID de endereço do cliente');
select ok(pg_temp.people_list_def() like '%''activity_id'',c.activity_id%'
  and pg_temp.people_list_def() like '%''activity_name'',c.activity_name%',
  'membership emite a atividade que o domínio Dart já declara');
select ok(pg_temp.people_list_def() like '%''total_count'',(select count(*) from filtered)%'
  and pg_temp.people_list_def() like '%page_rows as (select * from ranked%',
  'contagem é de pessoas distintas antes da paginação');
select ok(pg_temp.people_list_def() like '%p_segment=''children''%'
  and pg_temp.people_list_def() like '%p_segment=''dual_profile''%',
  'segmentos legados continuam compostos antes dos filtros novos');

-- Regressões executáveis com a fixture A/B que acompanha a serialização:
-- 1) pessoa exclusivamente B não aparece para p_institution_ids=A;
-- 2) unit=B com institution=A e group=B com unit/institution=A lançam 23514;
-- 3) pessoa A+B não passa pela combinação A + unit/grupo/papel B;
-- 4) atividade A retorna profissional e criança elegíveis, nunca B;
-- 5) assignment/link/participant revoked, inactive ou removed não entram;
-- 6) atividade+localidade+segmento compõem e total_count não duplica antes da página.
select lives_ok($$select public.superadmin_people_list(p_search=>'__h28_no_fixture__',p_limit=>8)$$,
  'defaults antigos continuam chamáveis antes da fixture A/B');
select * from finish();
rollback;
