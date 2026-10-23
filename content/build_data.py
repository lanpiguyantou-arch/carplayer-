import json,os
H=os.path.dirname(os.path.abspath(__file__))
T={1:'They Were Here Just Now',2:'My Hometown',3:'What Did You Do Last Weekend?',4:'Where Did You Go on Your Holiday?',5:'A Sports Meet',6:'We Had a Good Time',7:"We'd Like a Plate of Beef",8:'New Year Is Coming'}
def read(f, titled=False):
    d={};c=None;tt={}
    for l in open(os.path.join(H,f),encoding='utf-8'):
        l=l.strip()
        if not l: continue
        if l.startswith('#'):
            parts=l[1:].split(' ',1); c=int(parts[0]); d[c]=[]
            if len(parts)>1: tt[c]=parts[1]
            continue
        d[c].append(l)
    return (d,tt) if titled else d
v=read('slb6s_vocab.txt'); s=read('sentences.txt'); x,xt=read('texts.txt',True)
def pair(l):
    a,b=(l.split('|')+[''])[:2]; return dict(e=a,z=b)
units=[dict(n=u,t=T[u],w=[pair(i) for i in v[u]],s=[pair(i) for i in s[u]],xt=xt[u],x=[pair(i) for i in x[u]]) for u in range(1,9)]
out=os.path.join(H,'..','app','src','main','assets','slb6s.json'); os.makedirs(os.path.dirname(out),exist_ok=True)
json.dump(units,open(out,'w',encoding='utf-8'),ensure_ascii=False)
print(sum(len(u['w']) for u in units),'words',sum(len(u['s']) for u in units),'sentences',sum(len(u['x']) for u in units),'text lines')
