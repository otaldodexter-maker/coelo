#!/usr/bin/env bash
# Roda suites pgTAP num espelho Docker e resume PLAN/ok/notok + falhas.
# Uso: run_pgtap.sh <container_db> <suite.sql> [<suite.sql> ...]
# Ex.: run_pgtap.sh supabase_db_coelo_mirror_r15_b_apoio supabase/tests/child_safety_lifecycle_timeout_fix_v1_test.sql
c="$1"; shift
for t in "$@"; do
  echo "=== $t ==="
  docker exec -i "$c" psql -U postgres -d postgres -At -q -v ON_ERROR_STOP=0 < "$t" 2>&1 \
    | awk '/^ok /{o++} /^not ok/{n++; print} /^[0-9]+\.\.[0-9]+$/{plan=$0} /^# Looks like|^# Failed|ERROR/{print} END{print "PLAN " plan " ok=" o+0 " notok=" n+0}'
done
