#!/usr/bin/env python3
"""Extrai, das migrations canonicas na ordem de ordem-de-aplicacao-producao.txt, os
`insert into public.<tabela de catalogo>` de NIVEL SUPERIOR (fora de corpos $$...$$,
strings e comentarios). Serve para semear um espelho restaurado de dump schema-only.
Uso (na raiz de packages/coelo_database):
  python extract_catalogo_pos_baseline.py migrations migrations/ordem-de-aplicacao-producao.txt saida.sql
Nao contem credenciais; nao le producao.
"""
import os
import re
import sys
from collections import Counter

CATALOG = {
    'platform_permissions', 'platform_role_permissions', 'platform_roles', 'institution_permissions',
    'institution_role_permissions', 'institution_roles', 'institution_types', 'unit_types',
    'global_type_catalogs', 'activity_taxonomies', 'activity_capabilities', 'family_relationship_types',
    'guardian_permission_capabilities', 'access_profile_templates',
    'access_profile_template_platform_permissions', 'access_profile_template_institution_permissions',
    'access_profile_template_principal_capabilities', 'principal_capabilities',
    'activity_assignment_capability_actions', 'activity_admin_capability_actions',
    'activity_capability_policies', 'schema_tables', 'schema_columns',
}


def top_level_statements(src):
    out, buf, i, n = [], [], 0, len(src)
    tag = None
    inq = inlc = inbc = False
    while i < n:
        ch = src[i]
        if tag:
            if src.startswith(tag, i):
                buf.append(tag); i += len(tag); tag = None; continue
            buf.append(ch); i += 1; continue
        if inlc:
            buf.append(ch)
            if ch == '\n':
                inlc = False
            i += 1; continue
        if inbc:
            if src.startswith('*/', i):
                buf.append('*/'); i += 2; inbc = False; continue
            buf.append(ch); i += 1; continue
        if inq:
            buf.append(ch)
            if ch == "'":
                if i + 1 < n and src[i + 1] == "'":
                    buf.append("'"); i += 2; continue
                inq = False
            i += 1; continue
        m = re.match(r'\$[A-Za-z_][A-Za-z0-9_]*\$|\$\$', src[i:i + 64])
        if m:
            tag = m.group(0); buf.append(tag); i += len(tag); continue
        if src.startswith('--', i):
            inlc = True; buf.append('--'); i += 2; continue
        if src.startswith('/*', i):
            inbc = True; buf.append('/*'); i += 2; continue
        if ch == "'":
            inq = True; buf.append(ch); i += 1; continue
        if ch == ';':
            out.append(''.join(buf).strip()); buf = []; i += 1; continue
        buf.append(ch); i += 1
    if ''.join(buf).strip():
        out.append(''.join(buf).strip())
    return out


def main(migrations_dir, order_file, output):
    order = [l.strip() for l in open(order_file, encoding='utf-8') if re.match(r'^\d{14}_', l.strip())]
    pat = re.compile(r'^\s*(?:--[^\n]*\n\s*)*insert\s+into\s+"?public"?\."?([a-z_]+)"?', re.I)
    kept, missing = [], []
    for f in order:
        p = os.path.join(migrations_dir, f)
        if not os.path.exists(p):
            missing.append(f); continue
        src = open(p, encoding='utf-8', errors='replace').read()
        for st in top_level_statements(src):
            m = pat.match(st)
            if m and m.group(1).lower() in CATALOG:
                kept.append((f, m.group(1).lower(), st))
    with open(output, 'w', encoding='utf-8') as o:
        o.write('-- Trechos de catalogo (inserts de nivel superior em tabelas de catalogo) extraidos das migrations\n')
        o.write('-- canonicas na ordem de ordem-de-aplicacao-producao.txt. Uso: semear o espelho schema-only.\n')
        for f, t, st in kept:
            o.write(f'\n-- >>> {f} :: public.{t}\n{st};\n')
    print('migrations in order:', len(order), ' missing files:', missing)
    print('catalog statements kept:', len(kept))
    for t, c in Counter(t for _, t, _ in kept).most_common():
        print(f'{c:3d} {t}')


if __name__ == '__main__':
    main(*sys.argv[1:4])
