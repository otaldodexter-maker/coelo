"""R01 ownership/documentation check; does not certify product behavior."""
from pathlib import Path
import json
import re
import subprocess
import yaml

root = Path(__file__).resolve().parents[3]
operation = root / 'docs/reviews/etapa-2-operacao'
inventory = json.loads((root / 'docs/reviews/inventario-etapa-2.json').read_text(encoding='utf8'))
ownership = json.loads((operation / 'assignments/ownership.json').read_text(encoding='utf8'))
state = json.loads((operation / 'reports/estado-operacional.json').read_text(encoding='utf8'))
ids = [a['id'] for a in inventory['actions']]
assigned = ownership['actions']
assert len(ids) == len(set(ids)) == len(assigned) == 219
assert sorted(ids) == sorted(a['action_id'] for a in assigned)
assert all(a['executor'] in state['executors'] for a in assigned)
assert all(a['classification'] in {'ativa', 'adiada', 'gate formal', 'não aplicável'} for a in assigned)
for code, executor in state['executors'].items():
    assignment = (operation / f'assignments/{code}.md').read_text(encoding='utf8')
    listed = re.findall(r'^\| `([^`]+)` \| (?:ativa|adiada|gate formal|não aplicável) \|', assignment, re.M)
    assert sorted(listed) == sorted(a['action_id'] for a in assigned if a['executor'] == code), code
    prompt = (operation / f'next-round/R01-{code}-prompt.md').read_text(encoding='utf8')
    assert executor['path'] in prompt and executor['branch'] in prompt
    path = Path(executor['path'])
    if path.exists():
        branch = subprocess.check_output(['git', '-C', str(path), 'branch', '--show-current'], text=True).strip()
        assert branch == executor['branch'], (code, branch)
for code, coordinator in state.get('operational_coordinators', {}).items():
    assert code not in {a['executor'] for a in assigned}, 'operational coordinator cannot own product actions'
    assert coordinator['action_ids'] == []
    assignment = (operation / f'assignments/{code}.md').read_text(encoding='utf8')
    prompt = (operation / f'next-round/R01-{code}-prompt.md').read_text(encoding='utf8')
    assert coordinator['path'] in assignment and coordinator['branch'] in prompt
    path = Path(coordinator['path'])
    assert path.is_dir(), (code, 'missing worktree')
    branch = subprocess.check_output(['git', '-C', str(path), 'branch', '--show-current'], text=True).strip()
    assert branch == coordinator['branch'], (code, branch)
    handoff = Path(coordinator['handoff_path'])
    assert handoff == path / f'docs/reviews/etapa-2-operacao/handoffs/{code}.md'
    metadata = yaml.safe_load(handoff.read_text(encoding='utf8').split('---', 2)[1])
    assert all(metadata.get(k) for k in ('source', 'status', 'generated_at'))
    if coordinator['operational_ack'] is None:
        assert coordinator['status'].startswith('prepared-')
for code, front in state.get('validation_fronts', {}).items():
    assert code not in state['executors']
    assert code not in {a['executor'] for a in assigned}
    assert front['action_ids_transferred'] is False
    assert code in state['operational_coordinators'][front['supervisor']]['scope']
    assignment = (operation / f'assignments/{code}.md').read_text(encoding='utf8')
    prompt = (operation / f'next-round/R01-{code}-prompt.md').read_text(encoding='utf8')
    assert front['path'] in prompt and front['branch'] in prompt
    assert front['baseline'] in assignment
    reserved = front['reserved_test_paths']
    assert len(reserved) == len(set(reserved)) and all(p in assignment for p in reserved)
    path = Path(front['path'])
    assert path.is_dir()
    branch = subprocess.check_output(['git', '-C', str(path), 'branch', '--show-current'], text=True).strip()
    assert branch == front['branch'], (code, branch)
    subprocess.run(['git', '-C', str(path), 'merge-base', '--is-ancestor', front['baseline'], 'HEAD'], check=True)
    handoff = Path(front['handoff_path'])
    assert handoff == path / f'docs/reviews/etapa-2-operacao/handoffs/{code}.md'
    metadata = yaml.safe_load(handoff.read_text(encoding='utf8').split('---', 2)[1])
    assert all(metadata.get(k) for k in ('source', 'status', 'generated_at'))
for path in operation.rglob('*.md'):
    content = path.read_text(encoding='utf8')
    assert content.startswith('---\n'), path
    metadata = yaml.safe_load(content.split('---', 2)[1])
    assert all(metadata.get(k) for k in ('source', 'status', 'generated_at')), path
assert not list((operation / 'handoffs').glob('C[0-9][0-9].md')), 'C00 must not fabricate executor handoffs'
assert state['delivery_branch'] == 'dev'
assert state['window_end'] == '2026-09-16T12:20:00-03:00'
print('PASS: 219 IDs with five implementation owners; operational coordinators isolated; assignments/prompts/frontmatter/branches valid; bootstrap handoffs distinct from acknowledgements.')
