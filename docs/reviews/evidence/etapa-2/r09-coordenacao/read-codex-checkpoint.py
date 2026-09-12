"""Read only: existing R09 threads and account quota through documented App Server.

Does not resume threads, start turns, change configuration or schedule work.
The notLoaded status belongs to this reader process, not the desktop writer.
"""
import argparse
import json
from pathlib import Path
import queue
import subprocess
import sys
import threading

parser = argparse.ArgumentParser()
parser.add_argument('--front', action='append')
parser.add_argument('--quota', action='store_true')
parser.add_argument('--messages', action='store_true')
args = parser.parse_args()
sys.stdout.reconfigure(encoding='utf-8')
repo = Path(__file__).resolve().parents[5]
fronts = json.loads((repo / 'docs/reviews/etapa-2-operacao/comunicacao/coordenacao.json').read_text(encoding='utf-8'))['frentesR09']
proc = subprocess.Popen(['codex', 'app-server'], stdin=subprocess.PIPE,
                        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                        text=True, encoding='utf-8')
responses = queue.Queue()

def read():
    for line in proc.stdout:
        try:
            responses.put(json.loads(line))
        except ValueError:
            pass

threading.Thread(target=read, daemon=True).start()

def request(number, method, params):
    proc.stdin.write(json.dumps({'id': number, 'method': method, 'params': params}) + '\n')
    proc.stdin.flush()
    while True:
        result = responses.get(timeout=30)
        if result.get('id') == number:
            if 'error' in result:
                raise RuntimeError(result['error'])
            return result['result']

try:
    request(1, 'initialize', {'clientInfo': {'name': 'coelo_c0_read_checkpoint', 'version': '1.0'}})
    proc.stdin.write('{"method":"initialized","params":{}}\n')
    proc.stdin.flush()
    if args.quota:
        rate = request(2, 'account/rateLimits/read', {})
        print(json.dumps({'quota': rate.get('rateLimitsByLimitId', {}).get('codex', rate.get('rateLimits'))}))
    for number, group in enumerate(args.front or [], 3):
        thread = request(number, 'thread/read', {'threadId': fronts[group]['threadId'], 'includeTurns': True})['thread']
        turns = thread['turns']
        latest = turns[-1] if turns else {}
        result = {'front': group, 'threadId': thread['id'], 'turnId': latest.get('id'), 'status': latest.get('status')}
        if args.messages:
            result['messages'] = [item.get('text', '') for item in latest.get('items', []) if item.get('type') == 'agentMessage'][-3:]
        print(json.dumps(result, ensure_ascii=False))
finally:
    proc.stdin.close()
    proc.terminate()
    proc.wait(timeout=5)
