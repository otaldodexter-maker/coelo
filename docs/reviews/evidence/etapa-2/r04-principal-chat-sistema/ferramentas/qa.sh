S="<pasta onde estao estes scripts>"
APP=<checkout>/apps/superadmin
EV=<checkout>/docs/reviews/evidence/etapa-2/r04-principal-chat-sistema/rota-real-r04b
PORT=9409; BASE=http://127.0.0.1:3009
ws() { curl -s "http://127.0.0.1:$PORT/json" | python -c "import json,sys; t=[x for x in json.load(sys.stdin) if x['type']=='page' and not x['url'].startswith('chrome')]; print(t[0]['webSocketDebuggerUrl'])"; }
clean() { sed 's/Running build hooks\.\.\.//g' | grep -v 'asynchronous suspension' | grep -v '^#[0-9]'; }
drv() { (cd "$APP" && dart run test_driver/qa_drive.dart "$(ws)" "$@" 2>&1 | clean); }
sem() { dart run "$S/cdp_sem.dart" "$(ws)" "$@" 2>&1 | clean; }
go() { drv goto "$BASE$1" | tail -1; }
shot() { drv shot "$EV/$1.png" | tail -1; }
login_qa() { set -a; . /c/Users/adrie/Documents/Coelo-backups/qa-r03.env; set +a; drv login | tail -1; unset QA_EMAIL QA_PASSWORD; }
texts() { drv texts | tr '\n' ' ' | head -c "${1:-700}"; echo; }
