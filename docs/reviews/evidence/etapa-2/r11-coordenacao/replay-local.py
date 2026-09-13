"""Apply integrated post-baseline files serially to the isolated R11 container."""
from pathlib import Path
import subprocess, json, hashlib
root = Path('C:/Users/adrie/Documents/Coelo')
report = []
directory = root/'packages/coelo_database/migrations'
order = (directory/'ordem-de-aplicacao-producao.txt').read_text(encoding='utf-8-sig')
for name in [line.strip() for line in order.splitlines() if line.strip() and not line.lstrip().startswith('#')]:
    path = directory/name
    content = path.read_bytes()
    result = subprocess.run(['docker','exec','-i','supabase_db_coelo_r11','psql','-X','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'], input=content, capture_output=True)
    report.append({'file':path.name,'sha256':hashlib.sha256(content).hexdigest(),'exit_code':result.returncode})
    if result.returncode:
        print(path.name, result.stderr.decode('utf-8', errors='replace')[-2000:])
        break
out = root/'docs/reviews/evidence/etapa-2/r11-coordenacao/local-replay.json'
out.write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
print(json.dumps({'files':len(report),'passed':sum(r['exit_code']==0 for r in report),'last':report[-1]}))
raise SystemExit(report[-1]['exit_code'])
