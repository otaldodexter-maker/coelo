"""Read-only pixel comparison; run from this directory after preserving after.png."""
from pathlib import Path
import json
from PIL import Image

root = Path(__file__).resolve().parent
before = Image.open(root / 'before.png').convert('RGBA')
after = Image.open(root / 'after.png').convert('RGBA')
regions = {
    'all': (0, 0, 1440, 1000),
    'shell': (0, 0, 284, 1000),
    'content': (284, 0, 1440, 1000),
    'toolbar': (284, 0, 1440, 250),
    'create_card': (307, 252, 845, 475),
}
print(json.dumps({
    name: sum(a != b for a, b in zip(before.crop(rect).getdata(), after.crop(rect).getdata()))
    for name, rect in regions.items()
}, indent=2))
