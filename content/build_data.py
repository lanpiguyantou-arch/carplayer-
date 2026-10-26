import json, glob, os, re
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
units = []
for f in sorted(glob.glob(os.path.join(root, 'content', 'unit*.json')), key=lambda p: int(re.findall(r'\d+', os.path.basename(p))[0])):
    units.append(json.load(open(f, encoding='utf-8')))
units.sort(key=lambda u: u['unit'])
for u in units:
    jf = os.path.join(root, 'content', 'jiexi', 'unit%d.json' % u['unit'])
    if os.path.exists(jf):
        jx = json.load(open(jf, encoding='utf-8'))
        byt = {l['title']: l for l in jx.get('lessons', [])}
        for l in u['lessons']:
            j = byt.get(l['title'])
            if j:
                l['jx'] = {k: v for k, v in j.items() if k not in ('n', 'title')}
        print('unit', u['unit'], 'jiexi', sum(1 for l in u['lessons'] if 'jx' in l), '/', len(u['lessons']))
js = 'window.DATA=' + json.dumps(units, ensure_ascii=False, separators=(',', ':')) + ';\n'
open(os.path.join(root, 'www', 'data.js'), 'w', encoding='utf-8').write(js)
print('units', len(units), 'bytes', len(js))
