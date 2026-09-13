"""Back up ignored files of integrated, clean worktrees; never remove them here."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import os
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[5]
PARENT = Path('C:/Users/adrie/Documents/Coelo.worktrees').resolve()
BACKUP = Path('C:/Users/adrie/Documents/Coelo-backups/consolidacao-20260913')

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT).decode('utf-8').strip()

def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024*1024), b''):
            h.update(chunk)
    return h.hexdigest()

bundle = BACKUP / 'coelo-all-refs.bundle'
subprocess.run(['git','bundle','verify',str(bundle)],cwd=ROOT,check=True,
               stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
report={'at':datetime.now(timezone.utc).isoformat(), 'destination':str(ROOT),
        'bundle':{'path':str(bundle),'bytes':bundle.stat().st_size,'sha256':digest(bundle),'verified':True},
        'worktrees':[]}
for block in git('worktree','list','--porcelain').split('\n\n'):
    meta=dict(line.split(' ',1) if ' ' in line else (line,'') for line in block.splitlines())
    path=Path(meta['worktree']).resolve()
    if path==ROOT or path==Path('C:/Users/adrie/Documents/Coelo').resolve():
        continue
    assert path.parent==PARENT, 'Path outside approved worktree root'
    assert not git('-C',str(path),'status','--short'), 'Dirty worktree retained'
    subprocess.run(['git','merge-base','--is-ancestor',meta['HEAD'],'origin/dev'],cwd=ROOT,check=True)
    names=git('-C',str(path),'ls-files','--others','--ignored','--exclude-standard','-z').split('\0')
    names=[n for n in names if n]
    archive=BACKUP/(path.name+'-ignored.zip')
    assert not archive.exists(), 'Do not overwrite an existing backup'
    entries=[]
    with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_STORED,allowZip64=True) as z:
        for name in names:
            rel=Path(name)
            assert not rel.is_absolute() and '..' not in rel.parts
            source=path/rel
            if source.is_symlink():
                info=zipfile.ZipInfo(name);info.create_system=3;info.external_attr=0o120777<<16
                target=os.readlink(source);z.writestr(info,target)
                entries.append({'path':name,'symlink':target})
            else:
                assert source.is_file(), 'Unexpected ignored directory or missing file'
                before=digest(source);z.write(source,name)
                assert digest(source)==before, 'File changed during backup'
                entries.append({'path':name,'bytes':source.stat().st_size,'sha256':before})
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None
        assert len(z.infolist())==len(entries)
    manifest=BACKUP/(path.name+'-manifest.json')
    manifest.write_text(json.dumps({'worktree':meta,'entries':entries},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    report['worktrees'].append({'path':str(path),'head':meta['HEAD'],'branch':meta.get('branch'),
                              'ignoredCount':len(entries),'archive':str(archive),'archiveBytes':archive.stat().st_size,
                              'archiveSHA256':digest(archive),'manifest':str(manifest),'verified':True})
    print(path.name+': '+str(len(entries))+' ignored files archived and verified',flush=True)
    (BACKUP/'verified-worktrees.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('All backups verified; no worktree removed by this script.',flush=True)
