"""Create isolated local replay; preserves the previous local database."""
from pathlib import Path
import re, shutil
root = Path('C:/Users/adrie/Documents/Coelo')
target = Path('C:/Users/adrie/Documents/Coelo-backups/r11-local')
config = (root/'packages/coelo_database/supabase/config.toml').read_text(encoding='utf-8-sig')
config = config.replace('project_id = "coelo_database"', 'project_id = "coelo_r11"')
config = re.sub(r'\b543(2[0-9])\b', lambda m: str(int(m[0])+50), config)
config = config.replace('inspector_port = 8083', 'inspector_port = 8183')
(target/'supabase/migrations').mkdir(parents=True, exist_ok=True)
(target/'supabase/config.toml').write_text(config, encoding='utf-8')
shutil.copy2(root/'packages/coelo_database/migrations/20260910000000_baseline_producao.sql', target/'supabase/migrations')
shutil.copy2(root/'packages/coelo_database/supabase/seed.sql', target/'supabase/seed.sql')
print('Isolated replay configured; no remote link or credentials copied')
