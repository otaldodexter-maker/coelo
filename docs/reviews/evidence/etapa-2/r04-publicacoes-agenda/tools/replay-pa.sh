#!/usr/bin/env bash
# Prova limpa dos candidatos de publicacoes-agenda: db reset (baseline+seed) + migrations/ + candidatos + pgTAP
SP="C:/Users/adrie/AppData/Local/Temp/claude/c--Users-adrie-Documents-Coelo/bee22887-ff75-486f-a4d7-9f49031af2a8/scratchpad"
W=/c/Users/adrie/Documents/Coelo.worktrees/e2-r04-publicacoes-agenda
C=supabase_db_coelo_baseline_pa
cd "$SP/pa-project" || exit 1
echo "== $(date '+%H:%M:%S') db reset"
supabase db reset --local > "$SP/replay-reset.log" 2>&1 || { echo "RESET FALHOU"; tail -5 "$SP/replay-reset.log"; exit 1; }
echo "== $(date '+%H:%M:%S') migrations/"
for f in "$SP"/pa-migrations/*.sql; do
  docker exec -i $C psql -v ON_ERROR_STOP=1 -q -U postgres < "$f" > "$SP/replay-mig.log" 2>&1 || { echo "FALHOU $(basename $f)"; grep -m3 -i error "$SP/replay-mig.log"; exit 1; }
done
echo "   migrations OK"
echo "== $(date '+%H:%M:%S') candidatos"
for f in "$W"/packages/coelo_database/candidatos/publicacoes-agenda/*.sql; do
  docker exec -i $C psql -v ON_ERROR_STOP=1 -q -U postgres < "$f" > "$SP/replay-mig.log" 2>&1 && echo "   ok $(basename $f)" || { echo "FALHOU $(basename $f)"; grep -m3 -i error "$SP/replay-mig.log"; exit 1; }
done
echo "== $(date '+%H:%M:%S') pgTAP"
for t in superadmin_internal_notices_v2_baseline_test superadmin_internal_circulars_v2_baseline_test superadmin_internal_circular_delete_v1_test superadmin_internal_circular_delete_v2_behavior_test "$@"; do
  docker exec -i $C psql -v ON_ERROR_STOP=0 -q -U postgres < "$W/packages/coelo_database/supabase/tests/$t.sql" > "$SP/replay-$t.log" 2>&1
  echo "   $t: ok=$(grep -cE '^ *ok [0-9]' $SP/replay-$t.log) not_ok=$(grep -cE '^ *not ok' $SP/replay-$t.log) erros=$(grep -ciE '^ERROR|psql:.*ERROR' $SP/replay-$t.log) plano=$(grep -ci 'Looks like' $SP/replay-$t.log)"
done
echo "== $(date '+%H:%M:%S') fim"
