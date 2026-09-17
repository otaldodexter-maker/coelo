#!/usr/bin/env bash
# Recria o banco de um espelho local a partir de um dump schema-only de producao, com ACL fiel:
# revoga os default privileges locais de funcoes em public ANTES da restauracao (senao anon/
# authenticated/service_role ganham execute em toda funcao criada). Depois semeia o catalogo
# (seed de referencia + trechos pos-baseline + papeis de sistema) e instala o pgTAP.
# Uso:
#   restaurar-espelho.sh <pasta do espelho (com supabase/config.toml)> <container_db> <dump.sql> \
#     <pasta packages/coelo_database> <catalogo-pos-baseline.sql>
# Nao le producao; nao contem credenciais. Rodar com o espelho ja iniciado (`supabase start`).
set -euo pipefail
M="$1"; C="$2"; DUMP="$3"; PKG="$4"; CAT="$5"
cd "$M"
echo "== db reset $(date +%T) =="
supabase db reset --workdir . 2>&1 | tail -2
echo "== revoke default privileges =="
docker exec -i "$C" psql -U postgres -d postgres -At -v ON_ERROR_STOP=1 \
  -c "alter default privileges for role postgres in schema public revoke all on functions from anon, authenticated, service_role;" \
  -c "select defaclacl from pg_default_acl where defaclrole='postgres'::regrole and defaclnamespace='public'::regnamespace and defaclobjtype='f';"
echo "== restore $(date +%T) =="
docker exec -i "$C" psql -U postgres -d postgres -q -v ON_ERROR_STOP=0 < "$DUMP" > restore.log 2>&1 || true
echo "restore errors: $(grep -c ERROR restore.log || true)"
echo "== catalogo =="
docker exec -i "$C" psql -U postgres -d postgres -q -v ON_ERROR_STOP=0 < "$PKG/supabase/seed.sql" 2>&1 | grep -E "ERROR" || true
docker exec -i "$C" psql -U postgres -d postgres -q -v ON_ERROR_STOP=0 < "$CAT" 2>&1 | grep -E "ERROR" || true
docker exec -i "$C" psql -U postgres -d postgres -At -c "select app_private.seed_institution_role_system_templates();" > /dev/null
awk '/^-- >>> .* :: public\.institution_role_permissions$/{p=1} p{print} p&&/;$/{p=0}' "$CAT" \
  | docker exec -i "$C" psql -U postgres -d postgres -q -v ON_ERROR_STOP=0 2>&1 | grep -E "ERROR" || true
docker exec -i "$C" psql -U postgres -d postgres -At -c "create extension if not exists pgtap with schema extensions" > /dev/null
echo "== verify $(date +%T) =="
docker exec -i "$C" psql -U postgres -d postgres -At \
  -c "select 'anon_exec_public_fns', count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and has_function_privilege('anon', p.oid, 'execute')" \
  -c "select 'authenticated_exec_public_fns', count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and has_function_privilege('authenticated', p.oid, 'execute')" \
  -c "select 'fn_with_40001', count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','app_private') and p.prosrc like '%serialization_failure%'" \
  -c "select 'platform_permissions', count(*) from public.platform_permissions" \
  -c "select 'institution_roles_system', count(*) from public.institution_roles where institution_id is null and is_system" \
  -c "select 'people', count(*) from public.people"
