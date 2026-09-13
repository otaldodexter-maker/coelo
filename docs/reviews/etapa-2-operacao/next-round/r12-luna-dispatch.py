"""One-shot, detached R12 -> R13 handoff. No model is used while waiting."""
import argparse
import json
import os
import queue
import re
from pathlib import Path
import shutil
import subprocess
import sys
import threading
import time
import uuid

ROOT = Path(__file__).resolve().parents[4]
DOCS = ROOT / 'docs/reviews/etapa-2-operacao/next-round'
CONTROL = ROOT.parent / 'Coelo-backups/r12-luna-dispatch'
MODEL = 'gpt-5.6-luna'


def quota(codex):
    """Documented 0.154 protocol; no reset-credit redemption or API purchase."""
    proc = subprocess.Popen([codex, 'app-server'], stdin=subprocess.PIPE,
                            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                            text=True, encoding='utf-8', creationflags=child_flags())
    responses = queue.Queue()
    def reader():
        for line in proc.stdout:
            try:
                responses.put(json.loads(line))
            except ValueError:
                pass
    threading.Thread(target=reader, daemon=True).start()
    def request(number, method, params):
        proc.stdin.write(json.dumps({'id': number, 'method': method, 'params': params}) + '\n')
        proc.stdin.flush()
        until = time.monotonic() + 30
        while time.monotonic() < until:
            result = responses.get(timeout=max(0.1, until - time.monotonic()))
            if result.get('id') == number:
                if 'error' in result:
                    raise RuntimeError('Usage read failed')
                return result['result']
        raise TimeoutError('Usage read timed out')
    try:
        request(1, 'initialize', {'clientInfo': {'name': 'coelo_luna_dispatch', 'version': '1.0'}})
        proc.stdin.write('{"method":"initialized","params":{}}\n')
        proc.stdin.flush()
        result = request(2, 'account/rateLimits/read', {'supportsLunaReserve': True})
        return {k: result.get(k) for k in ('ordinaryUsageAllowed', 'rateLimits', 'rateLimitsByLimitId')}
    finally:
        proc.terminate()
        proc.wait(timeout=5)


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def write(path, value):
    tmp = path.with_name(path.name + '.' + uuid.uuid4().hex + '.tmp')
    tmp.write_text(json.dumps(value, indent=2, ensure_ascii=False), encoding='utf-8')
    os.replace(tmp, path)


def run(args, cwd=ROOT):
    return subprocess.run(args, cwd=cwd, text=True, encoding='utf-8',
                          errors='replace', capture_output=True, check=True,
                          timeout=120).stdout.strip()


def validate_release(expected=None):
    run(['git', 'fetch', 'origin'])
    sha = run(['git', 'rev-parse', 'HEAD'])
    if run(['git', 'branch', '--show-current']) != 'dev':
        raise RuntimeError('Expected dev branch')
    if run(['git', 'status', '--porcelain']) or sha != run(['git', 'rev-parse', 'origin/dev']):
        raise RuntimeError('Checkout must be clean and published to origin/dev')
    if expected and sha != expected:
        raise RuntimeError('SHA changed after writer release')
    closure = (DOCS / 'R12-fechamento.md').read_text(encoding='utf-8')
    if not closure.startswith('---') or 'encerrada' not in closure.split('---', 2)[1]:
        raise RuntimeError('R12 must have an actual closed frontmatter')
    receipt = DOCS / 'R12-transferencia-final-R13.json'
    if not receipt.exists():
        raise RuntimeError('Missing R12 transfer receipt')
    # Check the real delivery gate, never accept an arbitrary PASS marker.
    run([sys.executable, '-X', 'utf8', 'docs/reviews/delivery_gate.py',
         'docs/reviews/entrega-atual.json'])
    return sha


def child_flags():
    return subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0


def reserve_available(usage, ceiling=95):
    for bucket in (usage.get('rateLimitsByLimitId') or {}).values():
        if bucket.get('limitName') == 'gpt-reserve' and bucket.get('normalModelSlug') == MODEL:
            windows = [bucket[k] for k in ('primary', 'secondary') if bucket.get(k)]
            return bool(windows) and all(w['usedPercent'] < ceiling for w in windows)
    return False


def normal_threshold_reached(usage, threshold):
    if usage.get('ordinaryUsageAllowed') is False:
        return True
    bucket = (usage.get('rateLimitsByLimitId') or {}).get('codex') or usage.get('rateLimits') or {}
    return any(bucket.get(k, {}).get('usedPercent', 0) >= threshold
               for k in ('primary', 'secondary') if bucket.get(k))


def execute_model(state, cfg, resume_id=None, reserve=False):
    test = cfg['test']
    cwd = str(state) if test else str(ROOT)
    prompt = ('Teste de comunicacao. Nao use ferramentas nem leia ou altere arquivos. '
              'Responda somente LUNA_DISPATCH_OK.') if test else (
                  'Leia e execute integralmente ' + str(DOCS / 'R13-luna-continuacao.md') +
                  '. A R12 liberou a posse no SHA ' + cfg['releasedSha'] +
                  '. Identificador do disparo: ' + cfg['runId'] +
                  '. Diretorio de controle: ' + str(state) +
                  '. Fase de reserva: ' + str(reserve) +
                  '. Prazo global UTC epoch: ' + str(cfg['executionDeadline']) + '.')
    if not test and cfg.get('normalThreshold'):
        prompt += (' NOVA INSTRUÇÃO EXPLÍCITA DO OWNER: reabrir a mesma R13; ler primeiro '
                   + str(DOCS / 'R13-retomada-cota-owner.md') +
                   '. Este aditivo substitui os cortes históricos de95/96/98%. '
                   'Normal até99%; só então needs_reserve. Não encerrar por PITR enquanto houver trabalho independente.')
    model = 'gpt-reserve' if reserve else MODEL
    args = [cfg['codex'], '-a', 'never', 'exec', '--skip-git-repo-check',
            '-C', cwd, '-s', 'read-only' if test else 'danger-full-access',
            '-c', 'model_reasoning_effort=medium', '-c', 'model_provider="openai"',
            '--disable', 'unbounded_connection_retries']
    if resume_id:
        args += ['resume', resume_id]
    args += ['-m', model, '--json']
    if test:
        args.append('--ignore-user-config')
    args.append('-')
    # Text never goes into shell interpolation; stderr/raw model messages are not logged.
    env = os.environ.copy()
    env.pop('OPENAI_API_KEY', None)
    env.pop('CODEX_API_KEY', None)
    process = subprocess.Popen(args, cwd=cwd, env=env, stdin=subprocess.PIPE,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                               text=True, encoding='utf-8', errors='replace',
                               creationflags=child_flags())
    write(state / 'child.json', {'pid': process.pid, 'model': model, 'effort': 'medium'})
    stderr_tail = []
    def read_stderr():
        for line in process.stderr:
            stderr_tail.append(line)
            del stderr_tail[:-4]
    stderr_reader = threading.Thread(target=read_stderr, daemon=True)
    stderr_reader.start()
    process.stdin.write(prompt)
    process.stdin.close()
    confirmed = False
    completed = False
    thread_id = None
    failure = None
    lines = queue.Queue()
    def stream():
        for raw in process.stdout:
            lines.put(raw)
        lines.put(None)
    threading.Thread(target=stream, daemon=True).start()
    last_event = time.time()
    with (state / 'events.jsonl').open('a', encoding='utf-8') as log:
        while True:
            try:
                line = lines.get(timeout=30)
            except queue.Empty:
                write(state / 'heartbeat.json', {'pid': process.pid, 'time': time.time(),
                      'model': model, 'alive': process.poll() is None,
                      'quietSeconds': int(time.time() - last_event),
                      'deadlineExceeded': bool(cfg['executionDeadline']) and time.time() > cfg['executionDeadline'],
                      'note': 'Never start another writer while this process is alive'})
                continue
            if line is None:
                break
            last_event = time.time()
            try:
                event = json.loads(line)
            except ValueError:
                continue
            kind = event.get('type', '')
            safe = {'time': time.time(), 'type': kind}
            if kind == 'thread.started':
                safe['thread_id'] = event.get('thread_id')
                thread_id = event.get('thread_id')
            if kind in ('error', 'turn.failed'):
                message = json.dumps(event).lower()
                failure = 'usage_limit' if any(x in message for x in
                    ('usage limit', 'rate_limit', 'quota', 'usage_limit', 'credits depleted')) else 'other'
                safe['failure'] = failure
            if kind == 'turn.completed':
                completed = True
                safe['usage'] = event.get('usage')
            if test and event.get('item', {}).get('text', '').strip() == 'LUNA_DISPATCH_OK':
                confirmed = True
            log.write(json.dumps(safe) + '\n')
            log.flush()
    code = process.wait()
    stderr_reader.join(timeout=2)
    startup_error = None
    if code and not thread_id:
        # Keep only a small, redacted startup diagnostic; never raw stderr or model output.
        diagnostic = ''.join(stderr_tail)
        diagnostic = re.sub(r'https?://\S+|eyJ[\w.-]+|(?:sk-|sb_secret_)[\w-]+|Bearer\s+\S+', '[redacted]', diagnostic)
        startup_error = diagnostic[-1200:]
        failure = failure or 'startup'
    return {'exitCode': code, 'turnCompleted': completed, 'failure': failure, 'threadId': thread_id or resume_id,
            'startupError': startup_error,
            'testPassed': confirmed and completed and code == 0 if test else None}


def watch(state):
    # Exclusive claim prevents a second watcher from starting a second writer.
    with (state / 'watch.claim').open('x') as claim:
        claim.write(str(os.getpid()))
    cfg = read(state / 'config.json')
    write(state / 'status.json', {'status': 'waiting', 'pid': os.getpid(), 'runId': cfg['runId']})
    try:
        while time.time() < cfg['expiresAt']:
            if (state / 'cancel').exists():
                write(state / 'status.json', {'status': 'cancelled'})
                return
            ready = state / 'ready.json'
            if ready.exists():
                signal = read(ready)
                if signal['runId'] != cfg['runId'] or signal['test'] != cfg['test']:
                    raise RuntimeError('Signal does not belong to this run/mode')
                if not cfg['test']:
                    validate_release(signal['sha'])
                # Atomic one-shot claim; never retry a model run after an interruption.
                with (state / 'dispatch.claim').open('x') as claim:
                    claim.write(str(time.time()))
                cfg['releasedSha'] = signal['sha']
                cfg['executionDeadline'] = 0 if cfg.get('normalThreshold') == 99 else time.time() + 12600
                write(state / 'status.json', {'status': 'running', 'pid': os.getpid()})
                result = execute_model(state, cfg, resume_id=cfg.get('resumeThread'))
                request_path = state / 'continuation.json'
                wants_reserve = (request_path.exists() and
                    read(request_path).get('status') == 'needs_reserve')
                if not cfg['test'] and (result['failure'] == 'usage_limit' or wants_reserve):
                    usage = quota(cfg['codex'])
                    write(state / 'quota-after-limit.json', usage)
                    threshold = cfg.get('normalThreshold')
                    if threshold and result['failure'] != 'usage_limit' and not normal_threshold_reached(usage, threshold):
                        # An old prompt must not spend reserve early. Continue the SAME writer once in normal.
                        if request_path.exists():
                            os.replace(request_path, state / 'continuation-before-normal-resume.json')
                        if result['threadId']:
                            result = execute_model(state, cfg, resume_id=result['threadId'])
                            wants_reserve = request_path.exists() and read(request_path).get('status') == 'needs_reserve'
                            usage = quota(cfg['codex'])
                            write(state / 'quota-after-normal-resume.json', usage)
                    eligible = (result['failure'] == 'usage_limit' or
                                (wants_reserve and (not threshold or normal_threshold_reached(usage, threshold))))
                    within_time = not cfg['executionDeadline'] or time.time() < cfg['executionDeadline']
                    if eligible and result['threadId'] and reserve_available(usage, 99 if threshold else 95) and within_time:
                        reason = 'usage_limit' if result['failure'] == 'usage_limit' else 'normal_threshold' if threshold else 'checkpoint_request'
                        write(state / 'retry.json', {'reason': reason, 'attempt': 1,
                              'reserveRequested': True, 'reserveConfirmed': True,
                              'model': 'gpt-reserve', 'normalModel': MODEL})
                        if request_path.exists():
                            request_path.rename(state / 'continuation-before-reserve.json')
                        result = execute_model(state, cfg, result['threadId'], reserve=True)
                    elif eligible:
                        result['reserveBlocked'] = True
                    elif wants_reserve:
                        result['normalStoppedEarly'] = True
                write(state / 'status.json', {'status': 'finished', **result})
                return
            time.sleep(5)
        write(state / 'status.json', {'status': 'expired'})
    except Exception as exc:
        # Only exception type is retained: upstream failures may contain sensitive text.
        write(state / 'status.json', {'status': 'blocked', 'errorType': type(exc).__name__})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['arm', 'status', 'release', 'cancel', 'quota', '_watch'])
    parser.add_argument('--test', action='store_true')
    parser.add_argument('--run-id')
    parser.add_argument('--release-writer', action='store_true')
    parser.add_argument('--resume-thread')
    parser.add_argument('--normal-threshold', type=int, choices=[99])
    args = parser.parse_args()
    if args.resume_thread or args.normal_threshold:
        if args.command != 'arm' or args.test or not args.resume_thread or args.normal_threshold != 99:
            parser.error('Authorized reopening requires arm --resume-thread ID --normal-threshold 99')
    if args.command == 'quota':
        print(json.dumps(quota(shutil.which('codex'))))
        return
    CONTROL.mkdir(parents=True, exist_ok=True)
    pointer = CONTROL / ('test-current.json' if args.test else 'current.json')
    if args.command == 'arm':
        if args.resume_thread:
            previous_state = CONTROL / read(pointer)['runId']
            previous_status = read(previous_state / 'status.json')
            previous_thread = previous_status.get('threadId') or read(previous_state / 'config.json').get('resumeThread')
            if previous_status.get('status') not in ('finished', 'cancelled') or previous_thread != args.resume_thread:
                raise RuntimeError('Resume only the finished supervisor thread; active writers cannot be replaced')
        if pointer.exists():
            previous = read(pointer)['runId']
            old = CONTROL / previous / 'status.json'
            status = read(old)['status'] if old.exists() else 'starting'
            if status in ('starting', 'waiting', 'running'):
                print(json.dumps({'runId': previous, 'status': status, 'reused': True}))
                return
        codex = shutil.which('codex')
        if not codex or 'ChatGPT' not in run([codex, 'login', 'status']):
            # login status can be written on stderr by some versions.
            auth = subprocess.run([codex or 'codex', 'login', 'status'], capture_output=True, text=True)
            if auth.returncode or 'ChatGPT' not in auth.stdout + auth.stderr:
                raise RuntimeError('ChatGPT authentication required; no API billing fallback')
        identifier = uuid.uuid4().hex
        state = CONTROL / identifier
        state.mkdir()
        write(state / 'config.json', {'runId': identifier, 'test': args.test,
                                     'codex': codex, 'expiresAt': time.time() + 43200,
                                     'resumeThread': args.resume_thread, 'normalThreshold': args.normal_threshold})
        write(state / 'status.json', {'status': 'starting'})
        write(pointer, {'runId': identifier})
        flags = child_flags()
        if os.name == 'nt':
            flags |= subprocess.DETACHED_PROCESS | subprocess.CREATE_NEW_PROCESS_GROUP
        proc = subprocess.Popen([sys.executable, str(Path(__file__).resolve()), '_watch',
                                 '--run-id', identifier], cwd=ROOT,
                                stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                                stderr=subprocess.DEVNULL, creationflags=flags,
                                start_new_session=os.name != 'nt')
        print(json.dumps({'runId': identifier, 'pid': proc.pid, 'state': str(state)}))
        return
    identifier = args.run_id or read(pointer)['runId']
    if len(identifier) != 32 or any(c not in '0123456789abcdef' for c in identifier):
        raise RuntimeError('Invalid run ID')
    state = CONTROL / identifier
    if args.command == '_watch':
        watch(state)
    elif args.command == 'status':
        print(json.dumps({'runId': identifier, 'state': str(state), **read(state / 'status.json')}))
    elif args.command == 'cancel':
        if read(state / 'status.json')['status'] not in ('waiting', 'starting'):
            raise RuntimeError('Cancel only cancels a pending dispatch, not an active writer')
        (state / 'cancel').touch()
        print('Cancellation requested')
    elif args.command == 'release':
        cfg = read(state / 'config.json')
        if cfg['test'] != args.test or not args.release_writer:
            raise RuntimeError('Explicit writer release and matching test mode required')
        if read(state / 'status.json')['status'] != 'waiting':
            raise RuntimeError('Watcher is not waiting')
        sha = 'test-only' if cfg['test'] else validate_release()
        write(state / 'ready.json', {'runId': identifier, 'test': cfg['test'], 'sha': sha})
        print('Writer released; do not perform further repository writes in R12')


if __name__ == '__main__':
    main()
