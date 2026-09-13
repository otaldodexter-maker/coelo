"""Copy the four visually inspected renders of the authorized footer change.

These are automated layout baselines, not Owner A/A+ visual approvals.
"""
from pathlib import Path
import shutil

root = Path(__file__).resolve().parents[5]
screens = root / 'apps/superadmin/test/features/account/presentation/screens'
for width, theme in ((375, 'light'), (768, 'light'), (1024, 'dark'), (1440, 'dark')):
    name = f'profile_{width}_{theme}'
    shutil.copy2(screens / 'failures' / f'{name}_testImage.png', screens / 'goldens' / f'{name}.png')
    print(name)
