"""Regenerate the bundled block catalog from a pinned minecraft-data revision."""
import json
from pathlib import Path
from urllib.request import urlopen

REVISION = '33a0f3e7323e124a81960a6d6c62df797d69cd85'
BASE = f'https://raw.githubusercontent.com/PrismarineJS/minecraft-data/{REVISION}'
rows = {}
# Java names/sizes take precedence for shared display names; retain both ID aliases.
for path in ['pc/26.1', 'bedrock/1.26.30']:
    with urlopen(f'{BASE}/data/{path}/blocks.json', timeout=30) as response:
        blocks = json.load(response)
    for block in blocks:
        key = block['displayName'].casefold()
        if key in rows:
            rows[key]['aliases'].append(block['name'])
        else:
            rows[key] = dict(name=block['displayName'], id=block['name'],
                             stackSize=block['stackSize'], aliases=[block['name']])
for row in rows.values():
    row['aliases'] = sorted(set(row['aliases']))
data = dict(source='PrismarineJS/minecraft-data', revision=REVISION,
            javaVersion='26.1', bedrockVersion='1.26.30',
            blocks=sorted(rows.values(), key=lambda row: row['name'].casefold()))
target = Path(__file__).resolve().parent.parent / 'assets/catalog/blocks.json'
target.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')
print(f'Wrote {len(rows)} block names to {target}')
