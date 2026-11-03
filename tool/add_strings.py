"""Adds strings to both ARB files from a Python dict file and keeps keys sorted.

    python tool/add_strings.py strings.py

The file defines S = {key: (english, russian[, placeholders])}; a placeholder is a name (String)
or a (name, type) pair, listed in the order they appear in the English text.
"""
import json
import runpy
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

S = runpy.run_path(sys.argv[1])['S']
for lang, idx in (('en', 0), ('ru', 1)):
    path = ROOT / f'lib/l10n/app_{lang}.arb'
    d = json.loads(path.read_text(encoding='utf-8'))
    for k, v in S.items():
        d[k] = v[idx]
        if lang == 'en' and len(v) > 2:
            d['@' + k] = {'placeholders': {
                (p if isinstance(p, str) else p[0]): {'type': 'String' if isinstance(p, str) else p[1]} for p in v[2]}}
    rest = {k: v for k, v in d.items() if k != '@@locale'}
    out = {'@@locale': lang}
    for k in sorted(x for x in rest if not x.startswith('@')):
        out[k] = rest[k]
        if '@' + k in rest:
            out['@' + k] = rest['@' + k]
    path.write_text(json.dumps(out, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(f'{len(S)} strings')
