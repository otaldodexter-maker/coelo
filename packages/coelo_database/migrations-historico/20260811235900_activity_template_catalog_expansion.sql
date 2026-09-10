-- Expand the curated, filterable Activity template catalog from 21 to 40.
begin;

insert into public.activity_taxonomies(
  code, taxonomy_kind, name, sort_order
) values
  ('ciencias-exatas', 'category', 'Ciências exatas', 35),
  ('ciencias-naturais', 'category', 'Ciências naturais', 37)
on conflict(code) do update set
  parent_id = null,
  taxonomy_kind = 'category',
  name = excluded.name,
  sort_order = excluded.sort_order,
  status = 'active',
  updated_at = now();

with subtype_seed(category_code, code, name, sort_order) as (
  values
    ('artes-cultura', 'coral', 'Coral', 50),
    ('artes-cultura', 'fotografia', 'Fotografia', 60),
    ('artes-cultura', 'ceramica', 'Cerâmica', 70),
    ('esportes-movimento', 'futebol', 'Futebol', 50),
    ('esportes-movimento', 'basquete', 'Basquete', 60),
    ('esportes-movimento', 'volei', 'Vôlei', 70),
    ('esportes-movimento', 'handebol', 'Handebol', 80),
    ('esportes-movimento', 'atletismo', 'Atletismo', 90),
    ('esportes-movimento', 'ginastica', 'Ginástica', 100),
    ('idiomas-comunicacao', 'frances', 'Francês', 30),
    ('idiomas-comunicacao', 'libras', 'Libras', 40),
    ('ciencias-exatas', 'matematica', 'Matemática', 10),
    ('ciencias-exatas', 'fisica', 'Física', 20),
    ('ciencias-exatas', 'quimica', 'Química', 30),
    ('ciencias-naturais', 'biologia', 'Biologia', 10),
    ('ciencias-naturais', 'astronomia', 'Astronomia', 20),
    ('ciencias-tecnologia', 'cultura-maker', 'Cultura maker', 90),
    ('apoio-pedagogico', 'alfabetizacao', 'Alfabetização', 30),
    ('culinaria-vida-pratica', 'educacao-financeira', 'Educação financeira', 20)
)
insert into public.activity_taxonomies(
  parent_id, code, taxonomy_kind, name, sort_order
)
select category.id, seed.code, 'subtype', seed.name, seed.sort_order
from subtype_seed seed
join public.activity_taxonomies category
  on category.code = seed.category_code
 and category.taxonomy_kind = 'category'
on conflict(code) do update set
  parent_id = excluded.parent_id,
  taxonomy_kind = 'subtype',
  name = excluded.name,
  sort_order = excluded.sort_order,
  status = 'active',
  updated_at = now();

with template_seed(code) as (
  values
    ('coral'), ('fotografia'), ('ceramica'),
    ('futebol'), ('basquete'), ('volei'), ('handebol'), ('atletismo'),
    ('ginastica'), ('frances'), ('libras'), ('matematica'), ('fisica'),
    ('quimica'), ('biologia'), ('astronomia'), ('cultura-maker'),
    ('alfabetizacao'), ('educacao-financeira')
)
insert into public.activity_templates(
  scope_kind, code, name, description, taxonomy_id,
  governance_kind, template_payload
)
select
  'platform',
  taxonomy.code,
  taxonomy.name,
  'Modelo inicial editável de ' || lower(taxonomy.name) || '.',
  taxonomy.id,
  'optional',
  jsonb_build_object(
    'taxonomy_code', taxonomy.code,
    'governance_kind', 'optional'
  )
from template_seed seed
join public.activity_taxonomies taxonomy
  on taxonomy.code = seed.code
 and taxonomy.taxonomy_kind = 'subtype'
on conflict do nothing;

with template_seed(code) as (
  values
    ('coral'), ('fotografia'), ('ceramica'),
    ('futebol'), ('basquete'), ('volei'), ('handebol'), ('atletismo'),
    ('ginastica'), ('frances'), ('libras'), ('matematica'), ('fisica'),
    ('quimica'), ('biologia'), ('astronomia'), ('cultura-maker'),
    ('alfabetizacao'), ('educacao-financeira')
)
update public.activity_templates template
set
  name = taxonomy.name,
  description = 'Modelo inicial editável de ' || lower(taxonomy.name) || '.',
  taxonomy_id = taxonomy.id,
  governance_kind = 'optional',
  template_payload = jsonb_build_object(
    'taxonomy_code', taxonomy.code,
    'governance_kind', 'optional'
  ),
  status = 'active',
  updated_at = now()
from template_seed seed
join public.activity_taxonomies taxonomy
  on taxonomy.code = seed.code
 and taxonomy.taxonomy_kind = 'subtype'
where template.scope_kind = 'platform'
  and template.institution_id is null
  and template.code = seed.code;

create unique index if not exists activity_templates_platform_active_name_uidx
  on public.activity_templates(lower(btrim(name)))
  where scope_kind = 'platform'
    and institution_id is null
    and status = 'active';

-- Keep the public contract discoverable after local migrations/schema-cache
-- reloads. The private implementation owns authorization and response shape.
create or replace function public.superadmin_activity_template_options(
  p_institution_id uuid default null
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select app_private.superadmin_activity_template_options($1)
$$;

revoke all on function public.superadmin_activity_template_options(uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.superadmin_activity_template_options(uuid)
  to authenticated;

revoke all on function public.superadmin_upsert_activity(jsonb, uuid)
  from public, anon;
grant execute on function public.superadmin_upsert_activity(jsonb, uuid)
  to authenticated;

comment on function public.superadmin_activity_template_options(uuid) is
  'Returns institutions, filterable taxonomy and active platform/institution Activity templates using the canonical JSON shape.';

notify pgrst, 'reload schema';

commit;
