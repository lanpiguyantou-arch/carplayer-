import json, glob, os, re
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
units = []
for f in sorted(glob.glob(os.path.join(root, 'content', 'unit*.json')), key=lambda p: int(re.findall(r'\d+', os.path.basename(p))[0])):
    units.append(json.load(open(f, encoding='utf-8')))
units.sort(key=lambda u: u['unit'])
js = 'window.DATA=' + json.dumps(units, ensure_ascii=False, separators=(',', ':')) + ';\n'
open(os.path.join(root, 'www', 'data.js'), 'w', encoding='utf-8').write(js)
print('units', len(units), 'bytes', len(js))
