import json, io, re, subprocess

P = r'C:\Users\adrie\Documents\Coelo\docs\reviews\etapa-2-operacao\comunicacao\formularios-cuidado.json'
WT = r'C:\Users\adrie\Documents\Coelo.worktrees\e2-noturna-formularios-cuidado'

def git(*a):
    return subprocess.run(['git'] + list(a), cwd=WT, capture_output=True, text=True).stdout.strip()

def anc(sha, ref):
    return subprocess.run(['git', 'merge-base', '--is-ancestor', sha, ref],
                          cwd=WT, capture_output=True).returncode == 0

subprocess.run(['git', 'fetch', '-q', 'origin'], cwd=WT, capture_output=True)
d = json.load(io.open(P, encoding='utf-8'))

print('=== 1. HEAD declarado contra HEAD real ===')
real = git('rev-parse', 'HEAD')
print('  declarado:', d.get('head'))
print('  real     :', real)
print('  ESTADO   :', 'OK' if d.get('head') == real else 'PODRE')

print()
print('=== 2. divergencia com o remoto ===')
ahead = git('rev-list', '--count', 'origin/work/etapa2-noturna-formularios-cuidado..HEAD')
behind = git('rev-list', '--count', 'HEAD..origin/work/etapa2-noturna-formularios-cuidado')
up = d.get('upstream', {})
print('  declarado: ahead', up.get('ahead'), 'behind', up.get('behind'))
print('  real     : ahead', ahead, 'behind', behind)
print('  ESTADO   :', 'OK' if (str(up.get('ahead')) == ahead and str(up.get('behind')) == behind) else 'PODRE')

print()
print('=== 3. integracao de cada SHA, remedida agora ===')
podres = []
for c in d.get('delivered_commits', []):
    agora = anc(c['sha'], 'origin/dev')
    if bool(c.get('integrado_em_dev')) != agora:
        podres.append((c['sha'], c.get('integrado_em_dev'), agora))
print('  commits declarados:', len(d.get('delivered_commits', [])))
print('  campos podres    :', podres or 'nenhum')

print()
print('=== 4. residual declarado contra remedido ===')
res = d.get('residual_por_sha', {})
integ_agora = [c['sha'] for c in d['delivered_commits'] if anc(c['sha'], 'origin/dev')]
ret_agora = [c['sha'] for c in d['delivered_commits'] if not anc(c['sha'], 'origin/dev')]
print('  retidos declarados:', res.get('retidos'))
print('  retidos agora     :', ret_agora)
print('  ESTADO            :', 'OK' if res.get('retidos') == ret_agora else 'PODRE')

print()
print('=== 5. numeros superados sobrevivendo sem marca ===')
raw = io.open(P, encoding='utf-8').read()
for velho in ['808', '5225', '5332', '5350']:
    hits = len(re.findall(r'(?<!\d)' + velho + r'(?!\d)', raw))
    if hits:
        print('  "%s" aparece %d vez(es) — conferir se esta marcado como superado' % (velho, hits))

print()
print('=== 6. arvore e stash, agora ===')
print('  porcelain:', git('status', '--porcelain').splitlines() or 'limpa')
print('  stash    :', git('stash', 'list') or 'vazio')
