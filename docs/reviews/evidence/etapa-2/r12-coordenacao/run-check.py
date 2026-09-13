"""Run one serial check with UTF-8 output outside Git and preserve its exit code."""
from pathlib import Path
import subprocess
import sys
sys.stdout.reconfigure(encoding='utf-8')

name, cwd, *command = sys.argv[1:]
log = Path('C:/Users/adrie/Documents/Coelo-backups') / ('r12-' + name + '.log')
with log.open('w', encoding='utf-8') as output:
    result = subprocess.run(['rtk', 'proxy', *command], cwd=cwd,
                            stdout=output, stderr=subprocess.STDOUT)
print(f'{name}: exit={result.returncode}; log={log}')
print(log.read_text(encoding='utf-8', errors='replace')[-1400:])
raise SystemExit(result.returncode)
