-- R14 OQ-031 / ADR 0038.
-- Ordem candidata: depois de 20260910010400_health_care_behavior_v1.sql.
-- `code` e globalmente unico para que a carga seja idempotente; o
-- `entity_type` permanece mutavel quando o Owner corrigir a classificacao.
-- A migration fica no espelho local ate autorizacao nominal para producao.

create table if not exists public.global_type_catalogs (
  id uuid primary key default gen_random_uuid(),
  code text not null,
  entity_type text not null,
  label text not null,
  description text,
  sort_order integer not null default 0,
  is_other boolean not null default false,
  requires_free_text boolean not null default false,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint global_type_catalogs_code_not_blank check (btrim(code) <> ''),
  constraint global_type_catalogs_entity_type_check check
    (entity_type in ('institution','unit','group','activity')),
  constraint global_type_catalogs_label_not_blank check (btrim(label) <> ''),
  constraint global_type_catalogs_status_check check (status in ('active','inactive')),
  constraint global_type_catalogs_other_text_check check
    (not is_other or requires_free_text),
  constraint global_type_catalogs_code_unique unique (code)
);

create index if not exists global_type_catalogs_entity_sort_uidx
  on public.global_type_catalogs(entity_type, sort_order, code);

alter table public.global_type_catalogs enable row level security;
alter table public.global_type_catalogs force row level security;
drop policy if exists global_type_catalogs_platform_read on public.global_type_catalogs;
create policy global_type_catalogs_platform_read
  on public.global_type_catalogs
  for select to authenticated
  using (app_private.has_platform_permission('platform.read'));

revoke all on table public.global_type_catalogs from public, anon, authenticated;
grant select on table public.global_type_catalogs to authenticated;
grant all on table public.global_type_catalogs to service_role;

insert into public.global_type_catalogs(
  code,entity_type,label,sort_order,is_other,requires_free_text)
values
  ('institution.basic_education_school','institution','Escola (educação básica)',10,false,false),
  ('institution.early_childhood_center','institution','Creche / educação infantil',20,false,false),
  ('institution.therapy_center','institution','Centro de terapias',30,false,false),
  ('institution.sports_club','institution','Clube / escola esportiva',40,false,false),
  ('institution.language_school','institution','Escola de idiomas / cursos',50,false,false),
  ('institution.faith_community','institution','Igreja / comunidade',60,false,false),
  ('institution.hybrid','institution','Híbrida',70,false,false),
  ('institution.other','institution','Outros',80,true,true),
  ('unit.school','unit','Escolar',10,false,false),
  ('unit.early_childhood','unit','Educação infantil',20,false,false),
  ('unit.therapy','unit','Terapias',30,false,false),
  ('unit.sports','unit','Esportes / futebol',40,false,false),
  ('unit.children_academy','unit','Academia infantil',50,false,false),
  ('unit.languages_courses','unit','Idiomas / cursos',60,false,false),
  ('unit.faith_community','unit','Igreja / comunidade',70,false,false),
  ('unit.other','unit','Outros',80,true,true),
  ('group.school_class','group','Turma escolar (ano/série)',10,false,false),
  ('group.early_childhood_class','group','Turma de educação infantil',20,false,false),
  ('group.therapy_group','group','Grupo de terapia',30,false,false),
  ('group.individual_service','group','Atendimento individual',40,false,false),
  ('group.sports_class','group','Turma esportiva',50,false,false),
  ('group.course_workshop','group','Turma de curso / oficina',60,false,false),
  ('group.community_group','group','Grupo de comunidade',70,false,false),
  ('group.other','group','Outros',80,true,true),
  ('activity.regular_class','activity','Aula regular',10,false,false),
  ('activity.extracurricular_class','activity','Aula extracurricular',20,false,false),
  ('activity.therapy_session','activity','Sessão de terapia',30,false,false),
  ('activity.training','activity','Treino',40,false,false),
  ('activity.course_workshop','activity','Oficina / curso',50,false,false),
  ('activity.event_trip','activity','Evento / passeio',60,false,false),
  ('activity.reinforcement_followup','activity','Reforço / acompanhamento',70,false,false),
  ('activity.other','activity','Outros',80,true,true)
on conflict (code) do update set
  entity_type=excluded.entity_type,
  label=excluded.label,
  description=excluded.description,
  sort_order=excluded.sort_order,
  is_other=excluded.is_other,
  requires_free_text=excluded.requires_free_text,
  status='active',
  updated_at=now();
