"""Start the single QA server detached from the coordinator command."""
from pathlib import Path
import socket
import subprocess
import sys

root = Path(__file__).resolve().parents[5]
private = root.parent / 'Coelo-backups'
name = sys.argv[1] if len(sys.argv) > 1 else 'r12-focal'
if name not in ('r11-account-v3', 'r12-focal'):
    raise SystemExit('Unexpected build target')
build = root / 'apps/superadmin/build' / name
server = private / 'consolidacao-20260913/runtime-r10/serve.py'
if not (build / 'main.dart.js').is_file() or not server.is_file():
    raise SystemExit('Build or retained QA server missing')
with socket.socket() as probe:
    if probe.connect_ex(('127.0.0.1', 3000)) == 0:
        raise SystemExit('Port 3000 already owned')
with (private / 'r12-runtime.stdout.log').open('ab') as out, (private / 'r12-runtime.stderr.log').open('ab') as err:
    process = subprocess.Popen(
        [sys.executable, str(server), str(build), '3000', '127.0.0.1'],
        cwd=root, stdin=subprocess.DEVNULL, stdout=out, stderr=err,
        creationflags=subprocess.DETACHED_PROCESS | subprocess.CREATE_NEW_PROCESS_GROUP,
        close_fds=True,
    )
print(f'R12 runtime PID={process.pid} port=3000 build={name}; detached, no pending coordinator command')
