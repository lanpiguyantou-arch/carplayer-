# Converts xiaoyang111222/cn-math-taxonomy data (CC BY-NC 4.0) into the app's compact bundle.
import json,re,sys,os
src=sys.argv[1]; out=sys.argv[2]
t=json.load(open(os.path.join(src,'topics.json')));d=json.load(open(os.path.join(src,'dependencies.json')));q=json.load(open(os.path.join(src,'questions.json')))
subj={'cnm':'math','cne':'english','cnp':'physics'}
T=[]
for x in t:
    if x.get('external'): continue
    toks=x['chapter'].split(' ')
    vol=toks[0]; rest=toks[1:]
    if rest and re.fullmatch(r'[\d.]+',rest[-1]): rest=rest[:-1]
    T.append(dict(id=x['id'],n=x['name'],s=subj.get(x['id'][:3],'math'),g=x['grade'],v=vol,u=' '.join(rest) or vol,dm=x.get('domain',''),de=x.get('description',''),mc=x.get('mastery_criteria',[])))
ids={x['id'] for x in T}
D=[dict(t=x['topicId'],p=x['prerequisiteId'],h=x.get('strength')!='soft',r=x.get('reason','')) for x in d if x['topicId'] in ids and x['prerequisiteId'] in ids]
Q=[]
for x in q:
    if x['topicId'] not in ids: continue
    e=dict(id=x['id'],t=x['topicId'],df={'basic':0,'standard':1,'advanced':2}.get(x.get('difficulty'),1),ty=x['type'],p=x['prompt'],a=str(x['answer']),ex=x.get('explanation',''))
    if x.get('choices'): e['c']=[dict(k=c['key'],x=c.get('text',''),f=c.get('figure')) for c in x['choices']]
    if x.get('figure'): e['f']=x['figure']
    if isinstance(x.get('accept'),list): e['ac']=[str(a) for a in x['accept']]
    if x.get('unordered'): e['uo']=True
    if x.get('percent'): e['pc']=True
    if x.get('hideChoiceText'): e['hc']=True
    Q.append(e)
ex=os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','Sources','Resources','extra.json')
if os.path.exists(ex):
    e=json.load(open(ex,encoding='utf-8'))
    T=e['topics']+T; D=e['deps']+D; Q=e['questions']+Q
os.makedirs(os.path.dirname(out),exist_ok=True)
json.dump(dict(topics=T,deps=D,questions=Q),open(out,'w'),ensure_ascii=False,separators=(',',':'))
print(len(T),len(D),len(Q))
