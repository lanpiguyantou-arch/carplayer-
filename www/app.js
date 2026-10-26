(function(){
const D = window.DATA || [];
const $ = s => document.querySelector(s);
const esc = s => String(s == null ? '' : s).replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const cn = ['','一','二','三','四','五','六','七','八'];
const store = {
  get(k, d){ try { const v = localStorage.getItem('yw_'+k); return v ? JSON.parse(v) : d; } catch(e){ return d; } },
  set(k, v){ try { localStorage.setItem('yw_'+k, JSON.stringify(v)); } catch(e){} }
};
let _au=null,_gen=0;
function nativeSpeak(t){
  try {
    if (window.Native && Native.speak) return Native.speak(t);
    if (window.webkit && webkit.messageHandlers && webkit.messageHandlers.speak) return webkit.messageHandlers.speak.postMessage(t);
    if (window.speechSynthesis){ speechSynthesis.cancel(); const u = new SpeechSynthesisUtterance(t); u.lang='zh-CN'; u.rate=0.8; speechSynthesis.speak(u); }
  } catch(e){}
}
function nativeStop(){ try { if (window.Native && Native.stop) Native.stop(); else if (window.webkit && webkit.messageHandlers && webkit.messageHandlers.stop) webkit.messageHandlers.stop.postMessage(''); else if (window.speechSynthesis) speechSynthesis.cancel(); } catch(e){} }
function chunks(t){
  const parts = t.replace(/([。！？；!?;\n])/g,'$1\u0001').split('\u0001');
  const out=[]; let cur='';
  const add=s=>{ if ((cur+s).length>100 && cur){ out.push(cur); cur=''; } cur+=s; };
  for (const seg of parts){
    if (seg.length>100) seg.replace(/([，、,：:])/g,'$1\u0001').split('\u0001').forEach(add); else add(seg);
  }
  if (cur) out.push(cur);
  return out.map(x=>x.replace(/\s+/g,' ').trim()).filter(Boolean);
}
function speak(t){
  t = String(t || '').replace(/[（(][^）)]*[）)]/g, '').trim();
  stopSpeak();
  if (!t) return;
  if (store.get('voice','online')!=='online') return nativeSpeak(t);
  const g=++_gen, q=chunks(t); let i=0;
  const fail=()=>{ if (g!==_gen) return; _gen++; nativeSpeak(q.slice(i).join('')); };
  const play=()=>{
    if (g!==_gen || i>=q.length) return;
    const a=new Audio('https://fanyi.baidu.com/gettts?lan=zh&spd=4&source=web&text='+encodeURIComponent(q[i]));
    _au=a; a.onended=()=>{ i++; play(); }; a.onerror=fail;
    const p=a.play(); if (p && p.catch) p.catch(fail);
  };
  play();
}
function stopSpeak(){ _gen++; if (_au){ try{_au.pause();}catch(e){} _au=null; } nativeStop(); }
window.__spk = speak;
const spkBtn = t => `<button class="spk" onclick="__spk(decodeURIComponent('${encodeURIComponent(t).replace(/'/g,'%27')}'))">🔊</button>`;
const paras = t => String(t||'').split(/\n+/).filter(x=>x.trim()).map(p=>`<p>${esc(p.trim())}</p>`).join('');

let stack = [], tab = 'home';
function render(view){
  const v = view || stack[stack.length-1];
  $('#title').textContent = v.title;
  $('#back').style.visibility = stack.length > 1 ? 'visible' : 'hidden';
  $('#main').innerHTML = v.html();
  if (v.after) v.after();
  window.scrollTo(0,0);
}
function push(v){ stack.push(v); render(); }
const App = window.App = {
  back(){ stopSpeak(); if (stack.length > 1){ stack.pop(); render(); } },
  tab(t){ stopSpeak(); tab = t; document.querySelectorAll('nav button').forEach(b=>b.classList.toggle('on', b.dataset.t===t)); stack = [roots[t]()]; render(); }
};
document.querySelectorAll('nav button').forEach(b => b.onclick = () => App.tab(b.dataset.t));
let H = {}; let hid = 0;
function on(fn){ const k = 'h'+(hid++); H[k] = fn; return `App.h('${k}')`; }
App.h = k => H[k] && H[k]();

/* ---------- 课本 ---------- */
function homeView(){
  return { title:'统编版六年级上册语文', html(){
    H = {};
    if (!D.length) return '<div class="card">内容加载失败</div>';
    const vo = store.get('voice','online');
    const bar = `<div class="tabs2"><button class="${vo==='online'?'on':''}" onclick="${on(()=>{store.set('voice','online');render();speak('在线真人发音，听起来更自然');})}">🔊 在线真人发音</button><button class="${vo!=='online'?'on':''}" onclick="${on(()=>{store.set('voice','native');render();speak('手机语音，不用联网');})}">手机语音(离线)</button></div>`;
    return bar + D.map(u => `<div class="item" onclick="${on(()=>push(unitView(u)))}"><div><b>第${cn[u.unit]}单元</b><small>${esc(u.lessons.map(l=>l.title).join('、'))}</small></div></div>`).join('');
  }};
}
function unitView(u){
  return { title:`第${cn[u.unit]}单元`, html(){
    H = {};
    let s = u.theme ? `<div class="card" style="font-size:15px;color:#6b6157">${esc(u.theme)}</div>` : '';
    s += u.lessons.map(l => `<div class="item" onclick="${on(()=>push(lessonView(u,l)))}"><div><b>${l.n ? l.n+' ' : ''}${esc(l.title)}</b><small>${esc(l.kind||'')}${l.chars&&l.chars.length?' · 生字'+l.chars.length:''}${l.words&&l.words.length?' · 词语'+l.words.length:''}${l.recite||(l.poems||[]).some(p=>p.recite)?' · 背诵':''}</small></div></div>`).join('');
    if (u.garden) s += `<div class="item" onclick="${on(()=>push(gardenView(u)))}"><div><b>语文园地${cn[u.unit]}</b><small>日积月累等</small></div></div>`;
    if (u.zuowen) s += `<div class="item" onclick="${on(()=>push(essayView(u)))}"><div><b>习作：${esc(u.zuowen.title)}</b><small>要求 · 思路 · 范文</small></div></div>`;
    if (u.kouyu) s += `<div class="card"><h4>口语交际：${esc(u.kouyu.title)}</h4><ul>${(u.kouyu.points||[]).map(p=>`<li>${esc(p)}</li>`).join('')}</ul></div>`;
    return s;
  }};
}
function charCard(c){
  return `<div class="card zi"><div class="bigc">${esc(c.c)}</div><div style="flex:1">
  <div class="row"><span class="py">${esc(c.py)}</span> ${spkBtn(c.c+'，'+((c.words||[])[0]||'')+'的'+c.c)}</div>
  <div class="row"><span class="lbl">组词</span>${esc((c.words||[]).join('　'))}</div>
  <div class="row"><span class="lbl">解释</span>${esc(c.jie)}</div>
  <div class="row"><span class="lbl">造句</span>${esc(c.zao)}</div></div></div>`;
}
function wordCard(w){
  return `<div class="card"><div class="row"><b style="font-size:21px">${esc(w.w)}</b>　<span class="py">${esc(w.py)}</span> ${spkBtn(w.w)}</div>
  <div class="row"><span class="lbl">解释</span>${esc(w.jie)}</div><div class="row"><span class="lbl">造句</span>${esc(w.zao)}</div></div>`;
}
function poemCard(p){
  return `<div class="card"><div class="poem"><h3>${esc(p.title)}</h3><div class="au">[${esc(p.dynasty)}] ${esc(p.author)} ${spkBtn(p.title+'。'+p.dynasty+'，'+p.author+'。'+p.text)}</div>${esc(p.text).replace(/\n/g,'<br>')}</div>
  ${p.zhu&&p.zhu.length?`<h4>注释</h4><ol>${p.zhu.map(z=>`<li>${esc(z)}</li>`).join('')}</ol>`:''}
  ${p.yi?`<h4>译文</h4><div class="prose">${paras(p.yi)}</div>`:''}</div>`;
}
function jxView(j){
  const sec=(t,b)=>b?`<div class="card"><h4>${t}</h4>${b}</div>`:'';
  const li=a=>a&&a.length?`<ul>${a.map(x=>`<li>${esc(x)}</li>`).join('')}</ul>`:'';
  let s='';
  if(j.zhuzhi) s+=`<div class="card jx-main"><h4>📌 中心思想</h4><div class="prose">${esc(j.zhuzhi)}</div>${spkBtn(j.zhuzhi)}</div>`;
  s+=sec('✍️ 作者与背景',(j.zuozhe?`<p>${esc(j.zuozhe)}</p>`:'')+(j.beijing?`<p>${esc(j.beijing)}</p>`:''));
  (j.poems||[]).forEach(p=>{s+=sec(`📜 ${esc(p.title)}${p.author?' · '+esc(p.author):''}`,(p.shiyi?`<p><b>诗意：</b>${esc(p.shiyi)}</p>`:'')+(p.shangxi?`<p><b>赏析：</b>${esc(p.shangxi)}</p>`:'')+(p.qinggan?`<p><b>情感：</b>${esc(p.qinggan)}</p>`:''));});
  if(j.jiegou&&j.jiegou.length) s+=sec('🧩 课文结构',`<ol class="jx-st">${j.jiegou.map(x=>`<li><b>${esc(x.duan)}</b>：${esc(x.yi)}</li>`).join('')}</ol>`);
  if(j.zhongdian&&j.zhongdian.length) s+=sec('🔍 重点句赏析',j.zhongdian.map(x=>`<div class="jx-ju">“${esc(x.ju)}”</div><div class="jx-xi">${esc(x.xi)}</div>`).join(''));
  s+=sec('🎨 写作手法',li(j.xiefa));
  if(j.kehou&&j.kehou.length) s+=sec('❓ 课后题思路',j.kehou.map((x,i)=>`<details class="jx-q"><summary>${i+1}. ${esc(x.q)}</summary><div>${esc(x.a).replace(/\n/g,'<br>')}</div></details>`).join(''));
  s+=sec('⚠️ 易考点',li(j.kaodian));
  return s;
}
function lessonView(u,l){
  const parts = [];
  if (l.jx && l.jx.kewen) parts.push(['课文', () => `<div class="card kewen">${spkBtn(l.jx.kewen)}<div class="prose">${paras(l.jx.kewen)}</div></div>`]);
  if (l.jx) parts.push(['解析', () => jxView(l.jx)]);
  if (l.poems && l.poems.length) parts.push([l.jx&&l.jx.kewen?'注释译文':'原文', () => l.poems.map(poemCard).join('')]);
  if (l.chars && l.chars.length) parts.push(['生字', () => l.chars.map(charCard).join('')]);
  if (l.words && l.words.length) parts.push(['词语', () => l.words.map(wordCard).join('')]);
  if (l.recite) parts.push(['背诵', () => `<div class="card"><h4>${esc(l.recite.req)}</h4><div class="prose">${paras(l.recite.text)}</div><button class="btn" onclick="${on(()=>push(reciteView({title:l.title,req:l.recite.req,text:l.recite.text})))}">开始背诵练习</button> ${spkBtn(l.recite.text)}</div>`]);
  if (l.chars && l.chars.length) parts.push(['听写', () => `<div class="card">本课生字 ${l.chars.length} 个${l.words&&l.words.length?'，词语 '+l.words.length+' 个':''}。<br><button class="btn" onclick="${on(()=>push(dictRun(l.chars.map(c=>mkC(c,u,l)),'生字听写')))}">听写生字</button>${l.words&&l.words.length?`<button class="btn" onclick="${on(()=>push(dictRun(l.words.map(w=>mkW(w,u,l)),'词语听写')))}">听写词语</button>`:''}</div>`]);
  let cur = 0;
  return { title: (l.n?l.n+' ':'')+l.title, html(){
    H = {};
    if (!parts.length) return '<div class="card">本课暂无字词内容</div>';
    const t = `<div class="tabs2">${parts.map((p,i)=>`<button class="${i===cur?'on':''}" onclick="${on(()=>{cur=i;render();})}">${p[0]}</button>`).join('')}</div>`;
    return t + parts[cur][1]();
  }};
}
function gardenView(u){
  const g = u.garden || {};
  return { title:`语文园地${cn[u.unit]}`, html(){
    H = {};
    let s = '';
    if (g.riji && g.riji.length) s += `<div class="card"><h4>日积月累</h4>${g.riji.map(r=>`<div style="margin-bottom:12px"><b>${esc(r.title)}</b> ${spkBtn(r.text)}<div class="prose" style="font-family:'STKaiti','KaiTi',serif;font-size:19px">${paras(r.text)}</div>${r.jie?`<div style="color:#6b6157;font-size:15px">${esc(r.jie)}</div>`:''}</div>`).join('')}</div>`;
    (g.others||[]).forEach(o => s += `<div class="card"><h4>${esc(o.title)}</h4><div class="prose">${paras(o.text)}</div></div>`);
    return s || '<div class="card">暂无</div>';
  }};
}
function essayView(u){
  const z = u.zuowen; let cur = 0;
  return { title:'习作：'+z.title, html(){
    H = {};
    const fw = z.fanwen || [];
    let s = `<div class="card"><h4>习作要求</h4><div class="prose">${paras(z.req)}</div></div>`;
    s += `<div class="card"><h4>写作思路</h4><ol>${(z.silu||[]).map(x=>`<li>${esc(x)}</li>`).join('')}</ol></div>`;
    if (z.tips && z.tips.length) s += `<div class="card"><h4>注意 / 加分点</h4><ul>${z.tips.map(x=>`<li>${esc(x)}</li>`).join('')}</ul></div>`;
    if (fw.length){
      if (fw.length>1) s += `<div class="tabs2">${fw.map((f,i)=>`<button class="${i===cur?'on':''}" onclick="${on(()=>{cur=i;render();})}">范文${i+1}</button>`).join('')}</div>`;
      const f = fw[cur];
      s += `<div class="card"><h4 style="text-align:center">${esc(f.title)}</h4><div class="prose">${paras(f.text)}</div><div class="stat">约 ${String(f.text).replace(/\s/g,'').length} 字</div></div>`;
    }
    return s;
  }};
}

/* ---------- 听写 ---------- */
const mkC = (c,u,l) => ({k:'c', a:c.c, py:c.py, hint:(c.words||[])[0]||'', say:c.c+'，'+((c.words||[])[0]||'')+'的'+c.c, src:`第${cn[u.unit]}单元 ${l.title}`});
const mkW = (w,u,l) => ({k:'w', a:w.w, py:w.py, hint:'', say:w.w, src:`第${cn[u.unit]}单元 ${l.title}`});
function dictHome(){
  const sel = store.get('dsel', [1]); let kind = store.get('dkind', 'w'); let order = store.get('dorder','seq');
  return { title:'听写', html(){
    H = {};
    let s = `<div class="card"><h4>选择单元</h4><div class="chips">${D.map(u=>`<button class="chip ${sel.includes(u.unit)?'on':''}" onclick="${on(()=>{const i=sel.indexOf(u.unit); i>=0?sel.splice(i,1):sel.push(u.unit); store.set('dsel',sel); render();})}">第${cn[u.unit]}单元</button>`).join('')}</div>
    <h4>内容</h4><div class="chips">${[['c','生字'],['w','词语'],['a','生字+词语']].map(([k,n])=>`<button class="chip ${kind===k?'on':''}" onclick="${on(()=>{kind=k;store.set('dkind',k);render();})}">${n}</button>`).join('')}</div>
    <h4>顺序</h4><div class="chips">${[['seq','按课本顺序'],['rnd','随机打乱']].map(([k,n])=>`<button class="chip ${order===k?'on':''}" onclick="${on(()=>{order=k;store.set('dorder',k);render();})}">${n}</button>`).join('')}</div>`;
    const items = collect(sel, kind);
    s += `<div class="stat">共 ${items.length} 个</div><button class="btn" style="width:100%" onclick="${on(()=>{ if(!items.length) return; let it=items.slice(); if(order==='rnd') it.sort(()=>Math.random()-.5); push(dictRun(it,'听写')); })}">开始听写</button></div>`;
    s += `<div class="card" style="font-size:14px;color:#6b6157">用法：手机念，孩子在本子上写。写完点“看答案”对照，写错的点“错了”，会自动进错字本。</div>`;
    return s;
  }};
}
function collect(sel, kind){
  const out = [];
  D.filter(u=>sel.includes(u.unit)).forEach(u => u.lessons.forEach(l => {
    if (kind!=='w') (l.chars||[]).forEach(c=>out.push(mkC(c,u,l)));
    if (kind!=='c') (l.words||[]).forEach(w=>out.push(mkW(w,u,l)));
  }));
  return out;
}
function addWrong(it){ const w = store.get('wrong', {}); const e = w[it.a] || Object.assign({}, it, {n:0}); e.n++; e.t = Date.now(); w[it.a] = e; store.set('wrong', w); }
function okWrong(it){ const w = store.get('wrong', {}); if (w[it.a]){ w[it.a].ok = (w[it.a].ok||0)+1; if (w[it.a].ok>=2) delete w[it.a]; store.set('wrong', w);} }
function dictRun(items, name){
  let i = 0, show = false, showPy = store.get('showpy', false); const res = [];
  const v = { title:name, html(){
    H = {};
    if (i >= items.length){
      const bad = res.filter(r=>!r.ok);
      return `<div class="card"><div class="dict-word">${items.length-bad.length} / ${items.length}</div><div class="stat">正确率 ${items.length?Math.round((items.length-bad.length)*100/items.length):0}%</div>
      ${bad.length?`<h4>写错的</h4><div class="chips">${bad.map(r=>`<span class="chip">${esc(r.it.a)}</span>`).join('')}</div><button class="btn" onclick="${on(()=>{items=bad.map(r=>r.it);i=0;res.length=0;show=false;render();setTimeout(()=>speak(items[0].say),300);})}">错的再听一遍</button>`:'<div class="stat">全对，真棒！</div>'}
      <button class="btn g" onclick="App.back()">返回</button></div>`;
    }
    const it = items[i];
    return `<div class="stat">${i+1} / ${items.length}　${esc(it.src)}</div>
    <div class="card" style="text-align:center">
      <div class="py" style="font-size:24px;min-height:34px">${showPy||show?esc(it.py):''}</div>
      <div class="dict-word bigc" style="min-height:70px">${show?esc(it.a):'？'}</div>
      ${show&&it.hint?`<div class="stat">${esc(it.hint)}</div>`:''}
      <button class="btn" onclick="${on(()=>speak(it.say))}">🔊 再读一遍</button>
      <button class="btn g" onclick="${on(()=>{showPy=!showPy;store.set('showpy',showPy);render();})}">${showPy?'隐藏拼音':'显示拼音'}</button><br>
      ${show?`<button class="btn ok" onclick="${on(()=>{res.push({it,ok:true});okWrong(it);next();})}">✓ 写对了</button><button class="btn no" onclick="${on(()=>{res.push({it,ok:false});addWrong(it);next();})}">✗ 写错了</button>`
            :`<button class="btn" style="width:80%" onclick="${on(()=>{show=true;render();})}">看答案</button>`}
    </div>`;
  }, after(){ if (i===0 && !show && !v._s){ v._s=1; setTimeout(()=>speak(items[0].say),400);} } };
  function next(){ i++; show=false; render(); if (i<items.length) setTimeout(()=>speak(items[i].say),300); }
  return v;
}

/* ---------- 背诵 ---------- */
function reciteList(){
  const out = [];
  D.forEach(u => {
    u.lessons.forEach(l => {
      (l.poems||[]).forEach(p => { if (p.recite !== false) out.push({u:u.unit, title:p.title, sub:`[${p.dynasty}] ${p.author}`, req:'背诵全文', text:p.text, poem:true}); });
      if (l.recite && !(l.poems||[]).length) out.push({u:u.unit, title:l.title, sub:l.recite.req, req:l.recite.req, text:l.recite.text});
    });
    ((u.garden||{}).riji||[]).forEach(r => out.push({u:u.unit, title:r.title, sub:'日积月累 · 园地'+cn[u.unit], req:'日积月累', text:r.text, poem:true}));
  });
  return out;
}
function reciteHome(){
  return { title:'背诵', html(){
    H = {};
    const done = store.get('recited', {}); const all = reciteList();
    let s = `<div class="stat" style="margin-bottom:8px">已背 ${all.filter(r=>done[r.title]).length} / ${all.length}</div>`;
    let last = 0;
    all.forEach(r => {
      if (r.u !== last){ last = r.u; s += `<div class="unit-h">第${cn[r.u]}单元</div>`; }
      s += `<div class="item" onclick="${on(()=>push(reciteView(r)))}"><div><b>${done[r.title]?'✅ ':''}${esc(r.title)}</b><small>${esc(r.sub)}</small></div></div>`;
    });
    return s;
  }};
}
function reciteView(r){
  let mode = 0; const open = {};
  const marks = '，。！？；：、“”‘’《》（）—…\n ,.!?;:"\'';
  return { title:r.title, html(){
    H = {};
    const done = store.get('recited', {});
    let body = '';
    const lines = String(r.text).split('\n');
    let idx = 0;
    body = lines.map(line => {
      let first = true;
      const inner = Array.from(line).map(ch => {
        const k = idx++;
        if (marks.includes(ch)){ first = true; return esc(ch); }
        let hidden = mode===2 || (mode===1 && !first);
        first = false;
        if (open[k]) hidden = false;
        return hidden ? `<span class="hide" data-k="${k}">${esc(ch)}</span>` : esc(ch);
      }).join('');
      return r.poem ? inner : `<p>${inner}</p>`;
    }).join(r.poem ? '<br>' : '');
    return `<div class="card"><div class="stat">${esc(r.req)}</div></div>
    <div class="tabs2">${['看原文','首字提示','全部遮住'].map((n,i)=>`<button class="${mode===i?'on':''}" onclick="${on(()=>{mode=i;for(const k in open)delete open[k];render();})}">${n}</button>`).join('')}</div>
    <div class="card" id="rtext"><div class="${r.poem?'poem':'prose'}">${body}</div></div>
    <div class="stat">遮住时点灰块可以偷看一个字</div>
    <button class="btn" onclick="${on(()=>speak(r.text))}">🔊 朗读</button><button class="btn g" onclick="${on(stopSpeak)}">停止</button>
    <button class="btn ${done[r.title]?'g':'ok'}" onclick="${on(()=>{const d=store.get('recited',{}); d[r.title]?delete d[r.title]:d[r.title]=Date.now(); store.set('recited',d); render();})}">${done[r.title]?'取消已背':'✓ 我背会了'}</button>`;
  }, after(){
    const el = document.getElementById('rtext');
    if (el) el.onclick = e => { const k = e.target && e.target.dataset && e.target.dataset.k; if (k !== undefined){ open[k] = 1; e.target.classList.remove('hide'); } };
  }};
}

/* ---------- 作文 ---------- */
function essayHome(){
  return { title:'作文', html(){
    H = {};
    return D.filter(u=>u.zuowen).map(u => `<div class="item" onclick="${on(()=>push(essayView(u)))}"><div><b>第${cn[u.unit]}单元：${esc(u.zuowen.title)}</b><small>${(u.zuowen.fanwen||[]).length} 篇范文 · 写作思路</small></div></div>`).join('');
  }};
}

/* ---------- 错字本 ---------- */
function wrongHome(){
  return { title:'错字本', html(){
    H = {};
    const w = store.get('wrong', {}); const list = Object.values(w).sort((a,b)=>b.n-a.n);
    if (!list.length) return '<div class="card" style="text-align:center;color:#8a7f74">还没有错字。听写时点“写错了”会自动记到这里，连续写对两次自动移出。</div>';
    let s = `<button class="btn" style="width:100%" onclick="${on(()=>push(dictRun(list.slice().sort(()=>Math.random()-.5),'错字重听')))}">错字重新听写（${list.length}个）</button>`;
    s += list.map(e => `<div class="card" style="display:flex;justify-content:space-between;align-items:center"><div><b style="font-size:22px">${esc(e.a)}</b> <span class="py">${esc(e.py)}</span><div class="stat" style="text-align:left">${esc(e.src)} · 错 ${e.n} 次</div></div><button class="btn g" onclick="${on(()=>{const x=store.get('wrong',{});delete x[e.a];store.set('wrong',x);render();})}">移除</button></div>`).join('');
    return s;
  }};
}

const roots = { home:homeView, dict:dictHome, recite:reciteHome, essay:essayHome, wrong:wrongHome };
App.tab('home');
})();
