-- R14 OQ-031 / ADR 0038: quatro catalogos globais, por code, com Outros.
begin;

create extension if not exists pgtap with schema extensions;

select plan(11);

select has_table('public','global_type_catalogs','catalogo global de tipos');
select ok(
  (select relrowsecurity and relforcerowsecurity
   from pg_class where oid='public.global_type_catalogs'::regclass),
  'catalogo global forca RLS'
);
select col_is_unique('public','global_type_catalogs',array['code'],
  'code e a chave idempotente do catalogo');
select is(
  (select count(*)::integer from public.global_type_catalogs where entity_type='institution'),
  8, 'catalogo de instituicao tem oito entradas aprovadas'
);
select is(
  (select count(*)::integer from public.global_type_catalogs where entity_type='unit'),
  8, 'catalogo de unidade tem oito entradas aprovadas'
);
select is(
  (select count(*)::integer from public.global_type_catalogs where entity_type='group'),
  8, 'catalogo de turma tem oito entradas aprovadas'
);
select is(
  (select count(*)::integer from public.global_type_catalogs where entity_type='activity'),
  8, 'catalogo de atividade tem oito entradas aprovadas'
);
select is(
  (select count(*)::integer from public.global_type_catalogs where is_other),
  4, 'cada catalogo inclui Outros'
);
select ok(
  (select bool_and(requires_free_text) from public.global_type_catalogs where is_other),
  'Outros exige texto livre'
);
select is(
  (select count(*)::integer from public.global_type_catalogs),
  32, 'reaplicar a carga por code nao duplica entradas'
);
select is(
  has_table_privilege('authenticated','public.global_type_catalogs','insert'),
  false, 'cliente autenticado nao escreve catalogo global diretamente'
);

select * from finish();
rollback;
