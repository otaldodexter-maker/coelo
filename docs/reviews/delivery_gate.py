"""Read-only delivery audit. PASS documents a claim; it never certifies runtime."""
from pathlib import Path
import argparse
import json
import subprocess

SKILLS = ['coelo-ui', 'coelo-knowledge', 'coelo-supabase',
          'coelo-flutter-review', 'coelo-flutter-supabase-review']
TRACKERS = ['coelo-flutter-pendencias.md', 'coelo-supabase-pendencias.md',
            'coelo-flutter-integrado-supabase-pendencias.md']


def validate(report, facts):
    errors = []
    require = lambda condition, message: errors.append(message) if not condition else None
    require(report.get('completion') in ('complete', 'partial'), 'Declare complete or partial explicitly')
    require(facts.get('root', report.get('target')) == report.get('target'), 'Audit root differs from declared destination')
    require(facts.get('baseValid', True), 'Opening base must be an ancestor before delivered HEAD')
    require(not facts['dirty'], 'Destination has uncommitted files')
    require(facts['divergence'] == [0, 0], 'Destination differs from origin/dev; commit/push/fetch required')
    require(not facts['missingSkillFiles'], 'Skills are missing, outdated or differ from delivered HEAD')
    require(set(facts['stash']) == set(report.get('preservedStash', {})), 'Stash is not reconciled')
    for entry in report.get('preservedStash', {}).values():
        require(bool(entry.get('reason')) and bool(entry.get('evidence')), 'Stash lacks preservation evidence')
    protected = report.get('protectedWorktrees', {})
    require(report.get('target') in facts['worktrees'], 'Declared destination is not a registered worktree')
    for path in facts['worktrees']:
        require(path == report.get('target') or bool(protected.get(path)), 'Extra worktree has no explicit disposition: '+path)
    residuals = report.get('residualBranches', {})
    require(set(residuals) == set(facts['branches']), 'Residual branch inventory is incomplete or stale')
    evidence = set(report.get('evidenceFiles', []))
    for branch, current in facts['branches'].items():
        declared = residuals.get(branch, {})
        require(declared.get('sha') == current['sha'], 'Residual HEAD changed: '+branch)
        require(set(declared.get('exclusive', [])) == set(current['exclusive']), 'Unclassified exclusive commits: '+branch)
        require(declared.get('disposition') in ('patch-equivalent', 'superseded', 'retained-review'), 'Invalid disposition: '+branch)
        require(bool(declared.get('reason')) and declared.get('evidence') in evidence, 'Missing content-review evidence: '+branch)
        if declared.get('disposition') in ('patch-equivalent', 'superseded'):
            require(declared.get('successor') in facts.get('validSuccessors', []), 'Missing integrated successor: '+branch)
        if declared.get('disposition') == 'retained-review':
            require(bool(declared.get('owner')) and bool(declared.get('nextGate')), 'Retained review lacks owner/next gate: '+branch)
            require(report.get('completion') == 'partial', 'Unreviewed history forbids complete consolidation')
    items = report.get('ownerItems', [])
    require(bool(items), 'Owner commitments must be enumerated from the conversation')
    ids = [item.get('id') for item in items]
    require(all(ids) and len(ids) == len(set(ids)), 'Missing or duplicate Owner item IDs')
    mapped = set()
    for item in items:
        require(item.get('status') in ('done', 'open', 'deferred'), 'Invalid Owner item status')
        require(item.get('evidence') in evidence, 'Owner item has no published evidence: '+str(item.get('id')))
        require(all(item.get(layer) for layer in ('fe', 'be', 'e2e')), 'Owner item omits FE/BE/E2E')
        if item.get('status') == 'done' and item.get('actionIds'):
            require(item.get('fe') == 'verified' and item.get('be') in ('done','not-applicable')
                    and item.get('e2e') in ('verified-e2e','flutter-only'),
                    'Done product item still has an open layer: '+str(item.get('id')))
        mapped.update(item.get('actionIds', []))
        if item.get('status') != 'done':
            require(bool(item.get('owner')) and bool(item.get('nextGate')), 'Open item lacks owner/next gate')
            require(report.get('completion') == 'partial', 'Open commitment forbids complete claim')
    require(set(facts['changedActions']).issubset(mapped), 'Changed action omitted from commitment ledger')
    require(mapped.issubset(set(report.get('trackerActionIds', []))), 'Action missing from one or more trackers')
    memory = report.get('memory', {})
    require(memory.get('status') in ('captured', 'no-op'), 'Memory gate omitted')
    require(bool(memory.get('reason')), 'Memory decision lacks explanation')
    if memory.get('status') == 'captured':
        require(memory.get('evidence') in evidence, 'Memory capture is not published')
    deployment = report.get('deployment', {})
    require(deployment.get('status') in ('deployed', 'not-requested', 'pending'), 'Deployment status omitted')
    require(deployment.get('evidence') in evidence, 'Deployment distinction has no evidence')
    if deployment.get('status') == 'pending':
        require(report.get('completion') == 'partial', 'Pending deployment forbids complete claim')
    return errors


def collect(root, report):
    def git(*args):
        return subprocess.check_output(['git', *args], cwd=root).decode('utf-8').strip()
    subprocess.run(['git','fetch','origin','--prune'],cwd=root,check=True)
    base=git('rev-parse',report['baseReference']);head=git('rev-parse','HEAD')
    facts = dict(root=str(root), baseValid=base!=head and subprocess.run(
                     ['git','merge-base','--is-ancestor',base,head],cwd=root).returncode==0,
                 validSuccessors=[], dirty=git('status', '--porcelain').splitlines(),
                 divergence=[int(n) for n in git('rev-list','--left-right','--count','HEAD...origin/dev').split()],
                 stash=git('stash','list','--format=%gd').splitlines(), worktrees=[], branches={}, missingSkillFiles=[])
    for block in git('worktree','list','--porcelain').split('\n\n'):
        meta=dict(line.split(' ',1) if ' ' in line else (line,'') for line in block.splitlines())
        facts['worktrees'].append(str(Path(meta['worktree']).resolve()))
        dirty=git('-C',meta['worktree'],'status','--porcelain')
        if dirty:
            facts['dirty'].append('worktree:'+meta['worktree'])
        if 'branch' not in meta:
            exclusive=git('rev-list',meta['HEAD'],'--not','origin/dev').splitlines()
            if exclusive:
                facts['branches']['detached:'+meta['worktree']]={'sha':meta['HEAD'],'exclusive':exclusive}
    for row in git('for-each-ref','--format=%(refname:short)|%(objectname)',
                   'refs/heads','refs/remotes/origin').splitlines():
        branch, sha=row.split('|')
        if branch=='origin/HEAD':
            continue
        exclusive=git('rev-list',branch,'--not','origin/dev').splitlines()
        if exclusive:
            facts['branches'][branch]={'sha':sha,'exclusive':exclusive}
    for residual in report.get('residualBranches', {}).values():
        successor=residual.get('successor')
        if successor and subprocess.run(['git','merge-base','--is-ancestor',successor,'HEAD'],
                                        cwd=root,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode==0:
            facts['validSuccessors'].append(successor)
    for skill in SKILLS:
        relative=f'.agents/skills/{skill}/SKILL.md'
        path=root/relative
        try:
            delivered=git('show','HEAD:'+relative)
            if path.read_text(encoding='utf-8').strip()!=delivered or 'delivery-gate.md' not in delivered:
                facts['missingSkillFiles'].append(relative)
        except (OSError, subprocess.CalledProcessError):
            facts['missingSkillFiles'].append(relative)
    reference='.agents/skills/coelo-flutter-supabase-review/references/delivery-gate.md'
    try:
        if (root/reference).read_text(encoding='utf-8').strip()!=git('show','HEAD:'+reference):
            facts['missingSkillFiles'].append(reference)
        git('ls-files','--error-unmatch',reference)
    except (OSError,subprocess.CalledProcessError):
        facts['missingSkillFiles'].append(reference)
    current=json.loads((root/'docs/reviews/inventario-etapa-2.json').read_text(encoding='utf-8'))
    before=json.loads(git('show',report['baseReference']+':docs/reviews/inventario-etapa-2.json'))
    old={a['id']:a for a in before['actions']}
    new={a['id']:a for a in current['actions']}
    facts['changedActions']=[key for key in old.keys()|new.keys() if old.get(key)!=new.get(key)]
    matrices=[(root/'docs/reviews'/name).read_text(encoding='utf-8') for name in TRACKERS]
    report['trackerActionIds']=[a['id'] for a in current['actions'] if all(a['id'] in m for m in matrices)]
    for name in report.get('evidenceFiles', []):
        path=(root/name).resolve()
        if not path.is_relative_to(root) or not path.is_file():
            raise ValueError('Evidence missing or outside repo: '+name)
        git('ls-files','--error-unmatch',name)
    return facts


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('report', type=Path)
    parser.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[2])
    args=parser.parse_args();root=args.root.resolve()
    report=json.loads(args.report.read_text(encoding='utf-8'))
    facts=collect(root,report)
    errors=validate(report,facts)
    for error in errors:
        print('FAIL: '+error)
    if errors:
        return 1
    subprocess.run(['node','docs/reviews/validate-trackers.cjs'],cwd=root,check=True)
    subprocess.run(['python','-X','utf8','.agents/skills/coelo-knowledge/scripts/coelo_knowledge.py',
                    'validate','--root',str(root),'--quiet'],cwd=root,check=True)
    print('PASS '+('COMPLETE' if report['completion']=='complete' else 'DOCUMENTED_PARTIAL')+
          ': repository/records reconciled; no new runtime certification')
    return 0


if __name__=='__main__':
    raise SystemExit(main())
