import os, re

ROOT = r'C:\Users\adrie\Documents\Coelo.worktrees\e2-noturna-formularios-cuidado'
LIB = os.path.join(ROOT, 'apps', 'superadmin', 'lib')
SCOPE = ('features' + os.sep + 'forms', 'features' + os.sep + 'health_care')

def read(p):
    return open(p, encoding='utf-8', errors='replace').read()

# 1) paginas publicas do recorte e os parametros do seu construtor
pages = {}   # (arquivo, classe) -> [params]
for dp, _, fns in os.walk(LIB):
    if not any(s in dp for s in SCOPE):
        continue
    for fn in fns:
        if not fn.endswith('.dart'):
            continue
        p = os.path.join(dp, fn)
        src = read(p)
        for m in re.finditer(r'(?:final )?class (\w*Page) extends State(?:ful|less)Widget', src):
            cls = m.group(1)
            if cls.startswith('_'):
                continue
            # corpo ate a proxima declaracao de classe
            start = m.end()
            nxt = src.find('\nclass ', start)
            nxt2 = src.find('\nfinal class ', start)
            end = min(x for x in [nxt, nxt2, len(src)] if x != -1)
            body = src[start:end]
            ctor = re.search(re.escape(cls) + r'\s*\(\{(.*?)\}\)', body, re.S)
            if not ctor:
                continue
            ps = re.findall(r'(?:required\s+)?this\.(\w+)', ctor.group(1))
            pages[(p, cls)] = [x for x in ps if x != 'key']

# 2) toda a lib fora do arquivo declarante
allsrc = {}
for dp, _, fns in os.walk(LIB):
    for fn in fns:
        if fn.endswith('.dart'):
            q = os.path.join(dp, fn)
            allsrc[q] = read(q)

print('Paginas publicas do recorte:', len(pages))
print()
for (p, cls), ps in sorted(pages.items()):
    rel = p.replace(ROOT + os.sep, '').replace(os.sep, '/')
    nunca = []
    for name in ps:
        fornecido = any(
            re.search(r'(?<![\w.])' + re.escape(name) + r'\s*:', s)
            for q, s in allsrc.items() if q != p
        )
        if not fornecido:
            nunca.append(name)
    if nunca:
        print('%s  %s' % (cls, rel))
        print('   nunca fornecidos por nenhuma composicao: %s' % ', '.join(nunca))
        print()
