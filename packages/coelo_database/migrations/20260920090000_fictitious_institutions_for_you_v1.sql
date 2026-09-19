-- Fechamento da Etapa 3 (ADR 0045 §4 item 5, F12): três instituições fictícias com hierarquia
-- para validar o "Para você". Lote 106 (Sessão ETAPA-3, 20/09/2026; Owner autorizou massa sintética).
--   * Colégio Horizonte Azul (colegio), Creche Jardim das Cores (creche), Escola Raízes do Saber
--     (escola): cada uma com 2 unidades (sede + filial), 2 turmas por unidade, 1 coordenação,
--     2 professores (um por unidade), 4 responsáveis (vínculo por turma) e 6 crianças com
--     contexto, vínculo de unidade aceito, turma e responsáveis (mãe/pai) — ids fixos
--     f1c7<n>000-0000-4000-8000-… ; idempotente (on conflict / not exists).
--   * Um responsável por instituição recebe login (contas na Auth Admin, nunca insert em
--     auth.users): fic-horizonte@coelo.me, fic-jardim@coelo.me, fic-raizes@coelo.me. O vínculo
--     person_auth_links só é gravado se a conta existir; rodar de novo depois de criar a conta.
--   * Quatro publicações "Para você" para validar a audiência: plataforma (todas), instituição
--     (só Horizonte Azul), unidade (só a sede do Horizonte Azul) e turma (só Maternal I da sede).
-- Reversão: delete das linhas com prefixo f1c7 (institutions em cascata) e das 4 notices f1c79.

begin;
set local lock_timeout = '5s';
set local statement_timeout = '120s';

do $preflight$
begin
  if current_user <> 'postgres' then raise exception 'executar como postgres'; end if;
  if not exists (select 1 from public.institution_types where code in ('colegio','creche','escola'))
    or not exists (select 1 from public.unit_types where code = 'sede')
    or not exists (select 1 from public.family_relationship_types where code in ('mother','father')) then
    raise exception 'catálogos ausentes (institution_types/unit_types/family_relationship_types)';
  end if;
end $preflight$;

create temporary table fic(n int, code text, name text, slug text, itype text, stem text) on commit drop;
insert into fic values
  (1,'horizonte','Colégio Horizonte Azul','colegio-horizonte-azul','colegio','horizonteazul'),
  (2,'jardim','Creche Jardim das Cores','creche-jardim-das-cores','creche','jardimdascores'),
  (3,'raizes','Escola Raízes do Saber','escola-raizes-do-saber','escola','raizesdosaber');

create temporary table fic_people(n int, k int, ptype text, first_name text, last_name text) on commit drop;
insert into fic_people values
  -- k: 1 coordenação, 2/3 professores (unidade 1/2), 4..7 responsáveis, 8..13 crianças
  (1,1,'adult','Marina','Albuquerque'),(1,2,'adult','Rafael','Mendes'),(1,3,'adult','Juliana','Prado'),
  (1,4,'adult','Camila','Ferreira'),(1,5,'adult','Diego','Ferreira'),(1,6,'adult','Patrícia','Nogueira'),(1,7,'adult','Leandro','Nogueira'),
  (1,8,'child','Alice','Ferreira'),(1,9,'child','Bento','Ferreira'),(1,10,'child','Clara','Nogueira'),
  (1,11,'child','Davi','Nogueira'),(1,12,'child','Elisa','Castro'),(1,13,'child','Felipe','Castro'),
  (2,1,'adult','Helena','Barros'),(2,2,'adult','Tiago','Lima'),(2,3,'adult','Fernanda','Moraes'),
  (2,4,'adult','Aline','Souza'),(2,5,'adult','Marcos','Souza'),(2,6,'adult','Renata','Teixeira'),(2,7,'adult','Bruno','Teixeira'),
  (2,8,'child','Gael','Souza'),(2,9,'child','Heloísa','Souza'),(2,10,'child','Isabela','Teixeira'),
  (2,11,'child','João','Teixeira'),(2,12,'child','Laura','Ramos'),(2,13,'child','Miguel','Ramos'),
  (3,1,'adult','Sérgio','Andrade'),(3,2,'adult','Luciana','Pires'),(3,3,'adult','André','Carvalho'),
  (3,4,'adult','Tatiane','Rocha'),(3,5,'adult','Paulo','Rocha'),(3,6,'adult','Vanessa','Dias'),(3,7,'adult','Cláudio','Dias'),
  (3,8,'child','Nina','Rocha'),(3,9,'child','Otávio','Rocha'),(3,10,'child','Pedro','Dias'),
  (3,11,'child','Rita','Dias'),(3,12,'child','Sofia','Guedes'),(3,13,'child','Theo','Guedes');

-- ids determinísticos: f1c7 n 000-0000-4000-8000-0000 kind 00 seq
create function pg_temp.fid(n int, kind int, seq int) returns uuid language sql immutable as $$
  select (format('f1c7%s000-0000-4000-8000-%s%s', n, lpad(kind::text, 4, '0'), lpad(seq::text, 8, '0')))::uuid
$$;

-- 1. instituições
insert into public.institutions(id, public_name, slug, status, institution_type_id, management_version)
select pg_temp.fid(n,1,0), name, slug, 'active', (select id from public.institution_types t where t.code = fic.itype), 1
from fic
on conflict (id) do nothing;

-- 2. unidades (sede + filial)
insert into public.units(id, institution_id, name, slug, status, unit_type_id, handle)
select pg_temp.fid(n,2,u), pg_temp.fid(n,1,0),
  case u when 1 then 'Sede' else 'Unidade Norte' end,
  case u when 1 then 'sede' else 'unidade-norte' end,
  'active',
  (select id from public.unit_types t where t.code = case u when 1 then 'sede' else 'filial' end),
  case u when 1 then 'sede.' || stem else 'norte.' || stem end
from fic cross join generate_series(1,2) u
on conflict (id) do nothing;

-- 3. turmas (2 por unidade)
insert into public.groups(id, institution_id, unit_id, name, group_type, status, handle)
select pg_temp.fid(n,3,(u-1)*2+g), pg_temp.fid(n,1,0), pg_temp.fid(n,2,u),
  case (u-1)*2+g when 1 then 'Maternal I' when 2 then 'Maternal II' when 3 then 'Jardim I' else 'Jardim II' end,
  'class', 'active',
  case (u-1)*2+g when 1 then 'maternal1' when 2 then 'maternal2' when 3 then 'jardim1' else 'jardim2' end
    || '.' || case u when 1 then 'sede.' else 'norte.' end || stem
from fic cross join generate_series(1,2) u cross join generate_series(1,2) g
on conflict (id) do nothing;

-- 4. pessoas
insert into public.people(id, person_type, first_name, last_name, display_name, status, date_of_birth)
select pg_temp.fid(n,4,k), ptype::public.person_type, first_name, last_name, first_name || ' ' || last_name, 'active',
  case when ptype = 'child' then date '2022-03-01' + ((k - 8) * 120) else null end
from fic_people
on conflict (id) do nothing;

-- 5. vínculos de equipe e de família (memberships)
insert into public.institution_memberships(id, person_id, institution_id, role_code, status, scope_kind, scope_unit_id, scope_group_id)
select pg_temp.fid(n,5,k), pg_temp.fid(n,4,k), pg_temp.fid(n,1,0),
  case when k = 1 then 'coordinator' when k in (2,3) then 'teacher' else 'guardian' end,
  'active',
  case when k = 1 then 'institution' when k in (2,3) then 'unit' else 'group' end,
  case when k in (2,3) then pg_temp.fid(n,2,k-1) else null end,
  -- responsáveis 4/5 na turma 1 (Maternal I, sede), 6/7 na turma 3 (Jardim I, norte)
  case when k in (4,5) then pg_temp.fid(n,3,1) when k in (6,7) then pg_temp.fid(n,3,3) else null end
from fic_people where ptype = 'adult'
on conflict (id) do nothing;

-- 6. crianças: contexto, vínculo de unidade aceito, turma
--    8/9 → Maternal I (sede), 10/11 → Jardim I (norte), 12/13 → Maternal II (sede, sem responsável com vínculo)
insert into public.child_contexts(id, child_person_id, institution_id, status)
select pg_temp.fid(n,6,k), pg_temp.fid(n,4,k), pg_temp.fid(n,1,0), 'active'
from fic_people where ptype = 'child'
on conflict (id) do nothing;

insert into public.child_unit_links(id, child_context_id, unit_id, status, accepted_by, accepted_at)
select pg_temp.fid(n,7,k), pg_temp.fid(n,6,k),
  case when k in (10,11) then pg_temp.fid(n,2,2) else pg_temp.fid(n,2,1) end,
  'active', pg_temp.fid(n,4,1), now()
from fic_people where ptype = 'child'
on conflict (id) do nothing;

insert into public.child_group_links(id, child_unit_link_id, group_id, status)
select pg_temp.fid(n,8,k), pg_temp.fid(n,7,k),
  case when k in (8,9) then pg_temp.fid(n,3,1) when k in (10,11) then pg_temp.fid(n,3,3) else pg_temp.fid(n,3,2) end,
  'active'
from fic_people where ptype = 'child'
on conflict (id) do nothing;

-- 7. responsáveis ↔ crianças (mãe = k par 4/6, pai = 5/7)
insert into public.guardian_links(id, guardian_person_id, child_person_id, relation_type, relationship_type_id, relationship_detail, status)
select pg_temp.fid(n,9,g*100+c), pg_temp.fid(n,4,g), pg_temp.fid(n,4,c),
  case when g in (4,6) then 'mae' else 'pai' end,
  (select id from public.family_relationship_types t where t.code = case when g in (4,6) then 'mother' else 'father' end order by created_at limit 1),
  'Fictício (Etapa 3)', 'active'
from fic cross join (values (4,8),(5,8),(4,9),(5,9),(6,10),(7,10),(6,11),(7,11)) l(g,c)
on conflict (id) do nothing;

insert into public.guardian_context_permissions(guardian_link_id, child_context_id, can_view, can_message, can_react, status)
select gl.id, cc.id, true, true, true, 'active'
from public.guardian_links gl
join public.child_contexts cc on cc.child_person_id = gl.child_person_id
where gl.id::text like 'f1c7%' and cc.id::text like 'f1c7%'
  and not exists (select 1 from public.guardian_context_permissions p where p.guardian_link_id = gl.id and p.child_context_id = cc.id);

-- 8. login do responsável k=4 de cada instituição (conta criada na Auth Admin)
insert into public.person_auth_links(person_id, auth_user_id, status)
select pg_temp.fid(f.n,4,4), u.id, 'active'
from fic f
join auth.users u on lower(u.email) = 'fic-' || f.code || '@coelo.me'
where not exists (select 1 from public.person_auth_links l where l.person_id = pg_temp.fid(f.n,4,4) and l.status = 'active' and l.revoked_at is null)
  and not exists (select 1 from public.person_auth_links l where l.auth_user_id = u.id and l.status = 'active')
  and not exists (select 1 from app_private.superadmin_internal_auth_links l where l.auth_user_id = u.id);

-- 9. publicações "Para você" por audiência (assinadas pelo coelo.educa quando faz sentido)
insert into public.platform_notices(id, notice_type, status, title, body_text, starts_at, priority_code, audience_json, audience_label, target_device, published_at, official_profile_id)
values
  ('f1c79000-0000-4000-8000-000000000001', 'for_you', 'active', 'Semana de adaptação: como acolher em casa',
    'Dicas curtas para os primeiros dias na escola, do sono à despedida na porta.', now() - interval '1 hour', 'routine',
    '{"rules":[{"dimension":"platform","select_all":true}]}', 'Toda a plataforma', 'all', now(),
    (select id from public.official_profiles where handle = 'coelo.educa')),
  ('f1c79000-0000-4000-8000-000000000002', 'highlight', 'active', 'Horizonte Azul: reunião de famílias na quinta',
    'A coordenação apresenta o calendário do semestre às 18h, no auditório da sede.', now() - interval '1 hour', 'important',
    format('{"rules":[{"dimension":"institution","select_all":false,"target_ids":["%s"]}]}', pg_temp.fid(1,1,0))::jsonb,
    'Colégio Horizonte Azul', 'all', now(), null),
  ('f1c79000-0000-4000-8000-000000000003', 'content_card', 'active', 'Sede: cardápio da semana já está no app',
    'Lanches e almoço da sede atualizados; confira alergias no perfil de cuidado.', now() - interval '1 hour', 'routine',
    format('{"rules":[{"dimension":"unit","select_all":false,"target_ids":["%s"]}]}', pg_temp.fid(1,2,1))::jsonb,
    'Horizonte Azul · Sede', 'all', now(), null),
  ('f1c79000-0000-4000-8000-000000000004', 'for_you', 'active', 'Maternal I: traga a garrafinha com nome',
    'A partir de segunda, cada criança usa a própria garrafinha identificada.', now() - interval '1 hour', 'routine',
    format('{"rules":[{"dimension":"group","select_all":false,"target_ids":["%s"]}]}', pg_temp.fid(1,3,1))::jsonb,
    'Horizonte Azul · Sede · Maternal I', 'all', now(), null)
on conflict (id) do nothing;

-- follow automático dos perfis oficiais para quem tem login
select app_private.official_profiles_backfill_follows_v1();

commit;
