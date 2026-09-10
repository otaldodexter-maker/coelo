import io, os, re, subprocess, glob

ROOT = r'C:\Users\adrie\Documents\Coelo.worktrees\e2-noturna-formularios-cuidado'
DOCS = os.path.join(ROOT, 'docs', 'reviews', 'evidence', 'etapa-2', 'formularios-cuidado')

sha_re = re.compile(r'\b[0-9a-f]{7,40}\b')
path_re = re.compile(r'(?:packages|apps|docs|specs|decisions)/[A-Za-z0-9_./-]+')


def is_commit(sha):
    # NAO usar shell=True aqui: no cmd do Windows o ^ de ^{commit} e escape e
    # some, e todo objeto passa a "nao existir". Foi assim que a primeira
    # versao desta checagem reprovou ate o SHA da base.
    r = subprocess.run(['git', 'cat-file', '-t', sha],
                       cwd=ROOT, capture_output=True, text=True)
    return r.returncode == 0 and r.stdout.strip() == 'commit'


bad_sha, bad_path, ok_sha, ok_path = [], [], 0, 0

for doc in sorted(glob.glob(os.path.join(DOCS, '*.md'))):
    text = io.open(doc, encoding='utf-8').read()
    name = os.path.basename(doc)

    for sha in sorted(set(sha_re.findall(text))):
        if not re.search(r'[a-f]', sha):
            continue
        if is_commit(sha):
            ok_sha += 1
        else:
            bad_sha.append((name, sha))

    for rel in sorted(set(path_re.findall(text))):
        rel = rel.rstrip('.,;:)')
        if os.path.exists(os.path.join(ROOT, rel.replace('/', os.sep))):
            ok_path += 1
        elif glob.glob(os.path.join(ROOT, rel.replace('/', os.sep)) + '*'):
            ok_path += 1
        else:
            bad_path.append((name, rel))

print('SHAs que resolvem para commit:', ok_sha)
print('Caminhos alcancaveis a partir da raiz:', ok_path)
print()
if bad_sha:
    print('SHAs QUE NAO RESOLVEM:')
    for n, s in bad_sha:
        print('  %-48s %s' % (n, s))
else:
    print('Nenhum SHA inexistente.')
print()
if bad_path:
    print('CAMINHOS QUE O LEITOR NAO ALCANCA:')
    for n, p in bad_path:
        print('  %-48s %s' % (n, p))
else:
    print('Nenhum caminho quebrado.')
