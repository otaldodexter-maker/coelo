#!/usr/bin/env bash
# Roda a prova em producao do chat interno com a sessao qa-r03 sem expor segredo:
# credencial lida de Coelo-backups/qa-r03.env (fora do Git), chave anon lida do
# CLI em memoria. Nada e impresso alem do relatorio PASS/FAIL do script Deno.
set -euo pipefail
D="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${QA_ENV_FILE:-$HOME/Documents/Coelo-backups/qa-r03.env}"
[ -f "$ENV_FILE" ] || { echo "credencial ausente em $ENV_FILE"; exit 2; }
set -a; . "$ENV_FILE"; set +a
export COELO_SUPABASE_URL="${COELO_SUPABASE_URL:-https://evvbomzejfijozbtgvpt.supabase.co}"
if [ -z "${COELO_SUPABASE_ANON_KEY:-}" ]; then
  COELO_SUPABASE_ANON_KEY="$(cd "$D" && supabase projects api-keys --project-ref evvbomzejfijozbtgvpt -o json 2>/dev/null \
    | python -c 'import sys,json; print(next(k["api_key"] for k in json.load(sys.stdin) if k.get("name")=="anon"))')"
  export COELO_SUPABASE_ANON_KEY
fi
exec deno run --allow-env --allow-net "$D/scripts/chat-internal-production-proof.ts" "$@"
