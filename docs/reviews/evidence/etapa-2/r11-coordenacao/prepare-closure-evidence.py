"""Build an auditable R11 census; never copy private backup contents."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import subprocess

root = Path(__file__).resolve().parents[5]
out = Path(__file__).resolve().parent
base = '1d2f95b5942f5aab23439151b57853dd3180b041'
def git(*args):
    return subprocess.check_output(['git', *args], cwd=root).decode('utf-8').strip()
def write(name, value):
    (out/name).write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n',encoding='utf-8')
now = datetime.now(timezone.utc).isoformat()
before = json.loads(git('show',base+':docs/reviews/inventario-etapa-2.json'))
after = json.loads((root/'docs/reviews/inventario-etapa-2.json').read_text(encoding='utf-8'))
historical = json.loads((root/'docs/reviews/evidence/etapa-2/r10-coordenacao/closure-metrics.json').read_text(encoding='utf-8'))
history = {m['name']:m['afterIds'] for m in historical['metrics']}
def census(data):
    actions=data['actions']; be=[a for a in actions if a['backendStatus']!='not-applicable']; active=[a for a in actions if a['scope']=='mvp' and a['integratedStatus']!='flutter-only']
    fe_done=[a['id'] for a in actions if a['frontendStatus']=='verified']; be_done=[a['id'] for a in be if a['backendStatus']=='done']
    return [
        ('FE verified',fe_done,len(actions)),
        ('FE local-green entre pendentes',[a['id'] for a in actions if a['frontendStatus']=='local-green'],len(actions)-len(fe_done)),
        ('Aprovacao visual',history['Aprovacao visual'],len(actions)),
        ('BE local-green entre pendentes',[a['id'] for a in be if a['backendStatus']=='local-green'],len(be)-len(be_done)),
        ('Cobertura SQL',history['Cobertura SQL'],len(be)),
        ('BE done',be_done,len(be)),
        ('E2E',[a['id'] for a in active if a['integratedStatus']=='verified-e2e'],len(active)),
    ]
metrics=[]
for (name,old,oldn),(_,new,newn) in zip(census(before),census(after)):
    metrics.append(dict(name=name,before=dict(count=len(old),denominator=oldn,percent=round(100*len(old)/oldn,2)),after=dict(count=len(new),denominator=newn,percent=round(100*len(new)/newn,2)),beforeIds=old,afterIds=new,deltaPercentagePoints=round(100*len(new)/newn-100*len(old)/oldn,2),evidenceBasis='historical IDs preserved; no new R11 certification' if name in history and name in ['Aprovacao visual','Cobertura SQL'] else 'inventory classification; see action evidence dates'))
scope=['account.profile','auth.recover','auth.reset','activities.assessment','activities.publish','assessments.entry','assessments.gradebook','assessments.detail','assessments.close','assessments.reopen','groups.list']
write('closure-metrics.json',dict(round='R11',at=now,base=base,head=git('rev-parse','HEAD'),mappingChanged=False,metrics=metrics,scope=[{k:a.get(k) for k in ['id','screen','frontendStatus','backendStatus','integratedStatus']} for a in after['actions'] if a['id'] in scope]))
backups=[]
for name in ['r11-candidates-schema.sql','r11-candidates-data.sql']:
    path=Path('C:/Users/adrie/Documents/Coelo-backups')/name
    backups.append(dict(path=str(path),bytes=path.stat().st_size,sha256=hashlib.file_digest(path.open('rb'),'sha256').hexdigest()))
write('backup-manifest.json',dict(at=now,files=backups,commandsExit=0,pitrReplacement=False,restoreTested=False,limitations='Schema and data are separate logical snapshots. Circular foreign keys require an appropriate restore procedure. Not a PITR backup, not proof of restore, and must be refreshed/revalidated before a later remote batch.'))
write('git-checkpoint.json',dict(at=now,head=git('rev-parse','HEAD'),originDev=git('rev-parse','origin/dev'),divergence=git('rev-list','--left-right','--count','HEAD...origin/dev'),stash=git('stash','list'),worktrees=git('worktree','list','--porcelain'),commits=git('log','--format=%H %s',base+'..HEAD').splitlines(),retainedIgnored=['apps/superadmin/.env.local','apps/superadmin/build/principal-pos-r10','apps/superadmin/build/r11-account','apps/superadmin/build/r11-account-v2','apps/superadmin/build/r11-account-v3','C:/Users/adrie/Documents/Coelo-backups/r11-local','C:/Users/adrie/Documents/Coelo-backups/r11-chrome','C:/Users/adrie/Documents/Coelo-backups/qa-r03.env']))
cases=[
 ('profile.name-save-reload','P','account-name-reload.png'),('profile.cancel','P','account-v3-cancel-after.png'),
 ('profile.footer-desktop','P','account-v3-profile.png'),('profile.footer-mobile','P','account-v3-mobile.png'),
 ('profile.access-search','P','account-access-search.png'),('profile.access-scroll','P','account-v3-mobile-access.png'),
 ('profile.crop-preview','P','account-photo-crop-adjusted.png'),('profile.unconfirmed-save-message','P','account-photo-unconfirmed.png'),
 ('profile.principal-current-fallback','P','account-v3-principal.png'),('profile.photo-persist','F','account-photo-reload.png'),
 ('profile.color-persist','F','account-color-reload.png'),('profile.initials-persist','B','pending SQL'),
 ('profile.remove-persisted-photo','B','no persisted avatar transport'),('profile.access-metadata-groups','B','pending SQL'),
 ('profile.switch-session-current-round','U','R10 evidence is historical, not rerun'),
 ('auth.normal-request','P','checkpoint-1136.md'),('auth.nonexistent-generic','P','auth-nonexistent.png'),
 ('auth.real-mailbox-delivery','B','no message in accessible inbox'),('auth.real-reset-link','B','mail and redirect configuration'),
 ('auth.new-session','B','no authorized real reset completed'),('auth.expired-link','B','no real link'),('auth.single-use','B','no real link'),
 ('activities.assessment-update','F','assessment-update-red.json'),('activities.publish-configuration','B','pending SQL; activity already active'),
 ('assessments.eligible-student','F','gradebook-empty-retained.png'),('assessments.grade-save','B','pending SQL'),
 ('assessments.detail-reload','B','pending grade'),('assessments.close','B','pending grade'),('assessments.reopen','B','pending close'),
 ('assessments.real-cross-tenant','B','local denial tested; remote proof pending'),('groups.counters-reload','F','checkpoint-1136.md'),
]
counts={status:sum(c[1]==status for c in cases) for status in 'PFBSU'}
write('ui-acceptance-plan.json',dict(at=now,environment='normal UI, local QA build, Supabase production, synthetic data',counts=counts,planned=len(cases),executed=counts['P']+counts['F'],cases=[dict(id=a,status=b,evidence=c) for a,b,c in cases],note='Subchecks of the explicit R11 plan; P is not a whole-action E2E certificate. Flutter cases and pgTAP assertions are reported separately.'))
print(json.dumps(dict(metrics=[dict(name=m['name'],after=m['after']) for m in metrics],ui=counts,uiPlanned=len(cases),backups=[dict(bytes=b['bytes'],sha256=b['sha256']) for b in backups]),ensure_ascii=False))
