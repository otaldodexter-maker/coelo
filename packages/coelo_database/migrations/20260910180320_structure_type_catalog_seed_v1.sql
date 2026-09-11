-- Candidato de estrutura (R04, 11/09/2026): catalogo minimo de tipos de Estrutura.
-- Producao (medida em 10/09 pelo seed do catalogo) tem ZERO institution_types,
-- UM unit_type e ZERO plans. Sem tipo de instituicao ativo, nenhum caminho de
-- criacao de instituicao funciona: o legado (create_institution_for_superadmin)
-- exige o tipo por nome e o formulario do Superadmin oferece o filtro
-- "Sem tipos cadastrados". Os nomes abaixo sao os do protótipo aprovado
-- (fake_institution_directory_repository) e podem ser renomeados pelo Owner
-- sem migration nova: sao dados de catalogo, nao regra.
-- Idempotente: insere so o que nao existe, por code. Nao altera tipos existentes.
begin;

do $preflight$
begin
  if current_user<>'postgres' then
    raise insufficient_privilege using
      message='structure type catalog seed must run as postgres';
  end if;
  if to_regclass('public.institution_types') is null
    or to_regclass('public.unit_types') is null then
    raise object_not_in_prerequisite_state using
      message='institution_types and unit_types are required';
  end if;
end
$preflight$;

insert into public.institution_types(id,code,name,description,status)
select seed.id,seed.code,seed.name,seed.description,'active'
from (values
  ('a0000000-0000-4000-8000-000000000101'::uuid,'escola','Escola',
    'Escola de educacao basica.'),
  ('a0000000-0000-4000-8000-000000000102'::uuid,'colegio','Colégio',
    'Colegio com mais de uma etapa de ensino.'),
  ('a0000000-0000-4000-8000-000000000103'::uuid,'creche','Creche',
    'Creche e educacao infantil.')
) seed(id,code,name,description)
where not exists(
  select 1 from public.institution_types existing
  where lower(existing.code)=seed.code or lower(existing.name)=lower(seed.name)
);

insert into public.unit_types(id,code,name,description,status)
select seed.id,seed.code,seed.name,seed.description,'active'
from (values
  ('a0000000-0000-4000-8000-000000000201'::uuid,'sede','Sede',
    'Unidade principal da instituicao.'),
  ('a0000000-0000-4000-8000-000000000202'::uuid,'filial','Filial',
    'Unidade secundaria ou anexa.')
) seed(id,code,name,description)
where not exists(
  select 1 from public.unit_types existing
  where lower(existing.code)=seed.code or lower(existing.name)=lower(seed.name)
);

do $postcondition$
begin
  if (select count(*) from public.institution_types where status='active')<1
    or (select count(*) from public.unit_types where status='active')<1 then
    raise object_not_in_prerequisite_state using
      message='structure type catalog seed left no active type';
  end if;
end
$postcondition$;

commit;
