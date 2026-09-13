from pathlib import Path
import subprocess, sys
source=Path(sys.argv[1])
result=subprocess.run(['docker','exec','-i','supabase_db_coelo_r11','psql','-X','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],input=source.read_bytes(),capture_output=True)
output=(result.stdout+result.stderr).decode('utf-8',errors='replace')
if len(sys.argv)>2: Path(sys.argv[2]).write_text('\n'.join(line.rstrip() for line in output.splitlines())+'\n',encoding='utf-8')
print('\n'.join(line for line in output.splitlines() if any(x in line for x in ['ok ','ERROR:','CONTEXT:','STATE:','Failed','Looks like','1..'])))
raise SystemExit(result.returncode or (1 if 'not ok' in output else 0))
