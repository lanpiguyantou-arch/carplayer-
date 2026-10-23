import json,os
H=os.path.dirname(os.path.abspath(__file__))
T={1:'They Were Here Just Now',2:'My Hometown',3:'What Did You Do Last Weekend?',4:'Where Did You Go on Your Holiday?',5:'A Sports Meet',6:'We Had a Good Time',7:"We'd Like a Plate of Beef",8:'New Year Is Coming'}
def read(f):
    d={};c=None
    for l in open(os.path.join(H,f),encoding='utf-8'):
        l=l.strip()
        if not l: continue
        if l.startswith('#'): c=int(l[1:]); d[c]=[]; continue
        d[c].append(l)
    return d
v=read('slb6s_vocab.txt'); s=read('sentences.txt')
units=[dict(n=u,t=T[u],w=[dict(e=x.split('|')[0],z=x.split('|')[1]) for x in v[u]],s=s[u]) for u in range(1,9)]
out=os.path.join(H,'..','app','src','main','assets','slb6s.json')
json.dump(units,open(out,'w',encoding='utf-8'),ensure_ascii=False)
print(sum(len(u['w']) for u in units),'words',sum(len(u['s']) for u in units),'sentences')
