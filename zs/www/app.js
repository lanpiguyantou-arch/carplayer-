(function(){
const $=s=>document.querySelector(s);
const M=$('#main');
const esc=s=>String(s==null?'':s).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const store={get(k,d){try{const v=localStorage.getItem('zs_'+k);return v==null?d:JSON.parse(v)}catch(e){return d}},set(k,v){localStorage.setItem('zs_'+k,JSON.stringify(v))}};
function toast(t){const e=$('#toast');e.textContent=t;e.style.display='block';clearTimeout(e._t);e._t=setTimeout(()=>e.style.display='none',1800)}

/* ---------- 台账数据 ---------- */
let LED;
function loadLedger(){
  const saved=store.get('ledger',null);
  if(saved&&saved.v===1)LED=saved.d;
  else{LED=LEDGER0.map((r,i)=>Object.assign({id:'r'+i},r));}
}
function saveLedger(){store.set('ledger',{v:1,d:LED});syncRemind()}
function syncRemind(){try{const dates=LED.filter(active).map(r=>r.due).filter(Boolean);const o={warn:warnDays(),dates};
 if(window.Native&&Native.setDue)Native.setDue(JSON.stringify(o));
 else if(window.webkit&&webkit.messageHandlers&&webkit.messageHandlers.remind)webkit.messageHandlers.remind.postMessage(JSON.stringify(o));}catch(e){}}
window.syncRemind=syncRemind;
const today=()=>{const d=new Date();d.setHours(0,0,0,0);return d};
function daysLeft(due){if(!due)return null;const d=new Date(due+'T00:00:00');return Math.round((d-today())/86400000)}
function warnDays(){return store.get('warn',30)}
function stCls(r){const n=daysLeft(r.due);if(r.note&&/停用|报废|拆除/.test(r.note))return['停用','#8a95a1',9e9];if(n==null)return['无日期','#8a95a1',9e8];if(n<0)return['过期'+(-n)+'天','#d64541',n];if(n<=warnDays())return['剩'+n+'天','#e88a1a',n];if(n<=60)return['剩'+n+'天','#c9a400',n];return['剩'+n+'天','#2e9d5b',n]}
function addCycle(dateStr,cyc){
  if(!dateStr)return'';const d=new Date(dateStr+'T00:00:00');let m=12;
  const mm=String(cyc||'').match(/(\d+(?:\.\d+)?)\s*(个?月|年)/);if(mm)m=mm[2]=='年'?Math.round(parseFloat(mm[1])*12):parseInt(mm[1]);
  d.setMonth(d.getMonth()+m);d.setDate(d.getDate()-1);
  return d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0');
}
function active(r){return!(r.note&&/停用|报废|拆除/.test(r.note))}

/* ---------- 路由 ---------- */
let stack=[];let curTab='home';
const App=window.App={
  tab(t){stack=[];curTab=t;this.render({p:t})},
  go(p,a){stack.push(this.cur);this.render(Object.assign({p},a||{}))},
  back(){if(stack.length){this.render(stack.pop())}},
  render(s){this.cur=s;$('#back').style.visibility=stack.length?'visible':'hidden';
    document.querySelectorAll('#tab a').forEach(a=>a.classList.toggle('on',a.dataset.t==curTab));
    (V[s.p]||V.home)(s);window.scrollTo(0,s.y||0)},
  refresh(){const y=window.scrollY;this.cur.y=y;this.render(this.cur)}
};
function title(t){$('#title').textContent=t}
const V={};

/* ---------- 首页 ---------- */
V.home=function(){
  title('仪表助手');
  const act=LED.filter(active);
  let od=0,w=0,s60=0;act.forEach(r=>{const n=daysLeft(r.due);if(n==null)return;if(n<0)od++;else if(n<=warnDays())w++;else if(n<=60)s60++});
  const next=act.filter(r=>daysLeft(r.due)!=null&&daysLeft(r.due)>=0).sort((a,b)=>a.due<b.due?-1:1)[0];
  M.innerHTML=`
  <div class="card"><input id="q" placeholder="搜索 位号 / 设备 / 资料 / 联锁…" onkeydown="if(event.key=='Enter')App.go('search',{q:this.value})"></div>
  <div class="card" onclick="App.tab('ledger');setTimeout(()=>Ledger.setF('due'),0)"><h3>校验到期提醒</h3>
   <div class="stat"><div class="red"><b>${od}</b>已过期</div><div class="org"><b>${w}</b>${warnDays()}天内</div><div class="yel"><b>${s60}</b>60天内</div></div>
   <p class="muted" style="margin:8px 0 0">${next?`最近到期：${esc(next.due)}（${esc(next.tag)} 等），在用仪表共 ${act.length} 台`:'暂无即将到期'}</p></div>
  <div class="grid">
   <div class="gi" onclick="App.tab('ledger')"><b>📋</b>设备台账</div>
   <div class="gi" onclick="App.tab('tools')"><b>🧮</b>热工计算</div>
   <div class="gi" onclick="App.go('sel')"><b>🔩</b>探头选型</div>
   <div class="gi" onclick="App.go('art',{id:'b3500'})"><b>🗄️</b>3500卡件</div>
   <div class="gi" onclick="App.go('art',{id:'probe-install'})"><b>📐</b>探头安装</div>
   <div class="gi" onclick="App.go('calc',{k:'probecal'})"><b>📈</b>探头校验</div>
   <div class="gi" onclick="App.go('art',{id:'trex'})"><b>📟</b>TREX手操器</div>
   <div class="gi" onclick="App.go('art',{id:'fisher'})"><b>🔧</b>FISHER整定</div>
   <div class="gi" onclick="App.go('art',{id:'pid'})"><b>🎛️</b>PID设定</div>
   <div class="gi" onclick="App.tab('sis')"><b>🛡️</b>SIS画面</div>
   <div class="gi" onclick="App.go('doc',{d:0})"><b>📕</b>康吉森培训</div>
   <div class="gi" onclick="App.go('doc',{d:1})"><b>📗</b>浙大培训</div>
  </div>`;
};

/* ---------- 台账 ---------- */
const Ledger=window.Ledger={sheet:'全部',f:'all',q:'',lim:80,
  setF(f){this.f=f;this.lim=80;App.render({p:'ledger'})},
  setS(s){this.sheet=s;this.lim=80;App.render({p:'ledger'})}};
V.ledger=function(){
  title('设备台账');
  const sheets=['全部',...new Set(LED.map(r=>r.sheet))];
  const q=Ledger.q.trim().toLowerCase();
  let list=LED.filter(r=>(Ledger.sheet=='全部'||r.sheet==Ledger.sheet));
  if(q)list=list.filter(r=>[r.tag,r.name,r.loc,r.unit,r.model,r.range,(r.extra&&r.extra['出厂编号'])].join(' ').toLowerCase().includes(q));
  if(Ledger.f=='due')list=list.filter(r=>active(r)&&daysLeft(r.due)!=null&&daysLeft(r.due)<=warnDays());
  if(Ledger.f=='60')list=list.filter(r=>active(r)&&daysLeft(r.due)!=null&&daysLeft(r.due)<=60);
  if(Ledger.f=='over')list=list.filter(r=>active(r)&&daysLeft(r.due)!=null&&daysLeft(r.due)<0);
  list.sort((a,b)=>stCls(a)[2]-stCls(b)[2]||String(a.tag).localeCompare(b.tag));
  const F=[['all','全部'],['over','已过期'],['due',warnDays()+'天内'],['60','60天内']];
  M.innerHTML=`<div class="row"><input id="lq" placeholder="位号/名称/安装地点/编号" value="${esc(Ledger.q)}" oninput="Ledger.q=this.value;clearTimeout(window._lt);window._lt=setTimeout(()=>{Ledger.lim=80;App.render({p:'ledger'});const e=document.getElementById('lq');e.focus();e.setSelectionRange(e.value.length,e.value.length)},350)"><button class="b" style="flex:0 0 auto" onclick="App.go('edit',{id:null})">＋新增</button></div>
  <div class="chips">${sheets.map(s=>`<span class="${s==Ledger.sheet?'on':''}" onclick="Ledger.setS('${s}')">${s}</span>`).join('')}</div>
  <div class="chips">${F.map(([k,t])=>`<span class="${k==Ledger.f?'on':''}" onclick="Ledger.setF('${k}')">${t}</span>`).join('')}<span onclick="App.go('lset')">⚙️ 设置/导出</span></div>
  <p class="muted">共 ${list.length} 条</p>
  ${list.slice(0,Ledger.lim).map(r=>{const[s,c]=stCls(r);return`<div class="li" onclick="App.go('rec',{id:'${r.id}'})"><div class="m"><b>${esc(r.tag||'(无位号)')}</b> <span class="muted">${esc(r.name)}</span><div>${esc(r.loc)}</div><div>${esc(r.model)} ${esc(r.range)} · 有效期 ${esc(r.due||'-')}</div></div><span class="tag" style="background:${c}">${s}</span></div>`}).join('')}
  ${list.length>Ledger.lim?`<button class="b2" style="width:100%" onclick="Ledger.lim+=200;App.refresh()">显示更多（还有 ${list.length-Ledger.lim} 条）</button>`:''}`;
};
V.rec=function(s){
  const r=LED.find(x=>x.id==s.id);if(!r)return App.back();
  title(r.tag||'设备详情');const[st,c]=stCls(r);
  const ex=Object.entries(r.extra||{}).map(([k,v])=>`<span>${esc(k)}</span><span>${esc(v)}</span>`).join('');
  M.innerHTML=`<div class="card"><h3>${esc(r.tag)} <span class="tag" style="background:${c}">${st}</span></h3>
  <div class="kv"><span>设备名称</span><span>${esc(r.name)}</span><span>装置</span><span>${esc(r.unit)}</span><span>安装地点</span><span>${esc(r.loc)}</span><span>型号规格</span><span>${esc(r.model)}</span><span>技术参数</span><span>${esc(r.range)}</span><span>校验周期</span><span>${esc(r.cycle)}</span><span>上次校验</span><span>${esc(r.last||'-')}</span><span>有效期至</span><span>${esc(r.due||'-')}</span>${ex}<span>变更记录</span><span>${esc(r.note||'-')}</span><span>所属表</span><span>${esc(r.sheet)} / ${esc(r.group)}</span></div></div>
  <div class="card"><h3>登记本次校验</h3><div class="row"><label>校验日期</label><input type="date" id="cd" value="${new Date().toISOString().slice(0,10)}"></div>
  <p class="muted">按周期“${esc(r.cycle||'1年')}”自动计算新有效期。</p><button class="b" onclick="Ledger.cal('${r.id}')">✓ 已校验，更新有效期</button></div>
  <div class="row"><button class="b2" onclick="App.go('edit',{id:'${r.id}'})">编辑</button><button class="bd" onclick="Ledger.del('${r.id}')">删除</button></div>`;
};
Ledger.cal=function(id){const r=LED.find(x=>x.id==id);const d=$('#cd').value;if(!d)return;r.last=d;r.due=addCycle(d,r.cycle);r.note=((r.note||'')+` ${d}校验`).trim();saveLedger();toast('已更新，有效期至 '+r.due);App.refresh()};
Ledger.del=function(id){if(!confirm('确定删除这条记录？'))return;LED=LED.filter(x=>x.id!=id);saveLedger();App.back()};
const FIELDS=[['tag','位号'],['name','设备名称'],['unit','装置名称'],['loc','安装地点'],['model','型号规格'],['range','技术参数'],['cycle','校验周期'],['last','上次校验'],['due','有效期至'],['note','变更记录']];
V.edit=function(s){
  const r=s.id?LED.find(x=>x.id==s.id):{sheet:Ledger.sheet=='全部'?'压力变送器':Ledger.sheet,group:'',cycle:'1年',extra:{}};
  title(s.id?'编辑':'新增设备');
  const sheets=[...new Set(LED.map(x=>x.sheet))];
  M.innerHTML=`<div class="card"><div class="row"><label>分类</label><select id="f_sheet">${sheets.map(x=>`<option ${x==r.sheet?'selected':''}>${x}</option>`).join('')}</select></div>
  ${FIELDS.map(([k,t])=>`<div class="row"><label>${t}</label><input id="f_${k}" ${k=='last'||k=='due'?'type="date"':''} value="${esc(r[k]||'')}" ${k=='cycle'?'placeholder="如 6个月 / 1年"':''}></div>`).join('')}
  <div class="row"><label>出厂编号</label><input id="f_sn" value="${esc((r.extra||{})['出厂编号']||'')}"></div>
  <p class="muted">只填“上次校验”时，有效期按周期自动算。</p>
  <button class="b" style="width:100%" onclick="Ledger.save('${s.id||''}')">保存</button></div>`;
};
Ledger.save=function(id){
  let r=id?LED.find(x=>x.id==id):null;
  if(!r){r={id:'u'+Date.now(),extra:{},group:''};LED.unshift(r)}
  r.sheet=$('#f_sheet').value;FIELDS.forEach(([k])=>r[k]=$('#f_'+k).value.trim());
  r.extra=r.extra||{};const sn=$('#f_sn').value.trim();if(sn)r.extra['出厂编号']=sn;
  if(r.last&&!r.due)r.due=addCycle(r.last,r.cycle);
  saveLedger();toast('已保存');App.back();
};
V.lset=function(){
  title('台账设置');
  M.innerHTML=`<div class="card"><h3>提醒</h3><div class="row"><label>提前提醒天数</label><input type="number" id="wd" value="${warnDays()}"></div><button class="b" onclick="localStorage.setItem('zs_warn',JSON.stringify(+document.getElementById('wd').value||30));syncRemind();toast('已保存')">保存</button><p class="muted">手机系统通知：每天早上8:30检查，有到期/即将到期的仪表会提醒（首次需允许通知权限）。</p></div>
  <div class="card"><h3>导出</h3><p class="muted">导出当前全部台账为 CSV（可用 Excel/WPS 打开）。</p><button class="b" onclick="Ledger.exp(false)">导出全部</button> <button class="b2" onclick="Ledger.exp(true)">只导出${warnDays()}天内到期</button></div>
  <div class="card"><h3>恢复</h3><p class="muted">清除手机上的修改，恢复为原始 Excel 台账数据。</p><button class="bd" onclick="if(confirm('确定恢复原始台账？你的修改会丢失')){localStorage.removeItem('zs_ledger');loadLedger();toast('已恢复')}">恢复原始数据</button></div>`;
};
window.loadLedger=loadLedger;
Ledger.exp=function(onlyDue){
  let L=LED;if(onlyDue)L=L.filter(r=>active(r)&&daysLeft(r.due)!=null&&daysLeft(r.due)<=warnDays());
  const H=['分类','位号','设备名称','装置名称','安装地点','型号规格','技术参数','出厂编号','校验周期','上次校验','有效期','变更记录'];
  const q=v=>'"'+String(v||'').replace(/"/g,'""')+'"';
  const csv='\ufeff'+H.join(',')+'\n'+L.map(r=>[r.sheet,r.tag,r.name,r.unit,r.loc,r.model,r.range,(r.extra||{})['出厂编号'],r.cycle,r.last,r.due,r.note].map(q).join(',')).join('\n');
  const name=(onlyDue?'到期仪表_':'设备台账_')+new Date().toISOString().slice(0,10)+'.csv';
  if(window.Native&&Native.shareFile){Native.shareFile(name,csv);return}
  if(window.webkit&&webkit.messageHandlers&&webkit.messageHandlers.share){webkit.messageHandlers.share.postMessage({name,data:csv});return}
  const a=document.createElement('a');a.href=URL.createObjectURL(new Blob([csv],{type:'text/csv'}));a.download=name;a.click();
};

/* ---------- 计算工具 ---------- */
const CALCS=[['ma','4~20mA ⇄ 工程量'],['rtd','热电阻 Pt100/Cu50'],['tc','热电偶 mV ⇄ ℃'],['err','允许误差与校验点'],['flow','差压流量（开方）'],['level','差压液位/双法兰迁移'],['unit','压力单位换算'],['vib','振动 位移/速度/加速度'],['gap','探头间隙 ⇄ 电压'],['probecal','探头校验 ISF/DSL']];
V.tools=function(){title('热工计算');
  M.innerHTML=`<div class="card" onclick="App.go('sel')"><h3>🔩 本特利探头/延长电缆/前置器 选型</h3><p class="muted" style="margin:0">选择系统长度和规格，自动给出匹配的订货号组合</p></div>`+
  CALCS.map(([k,t])=>`<div class="li" onclick="App.go('calc',{k:'${k}'})"><div class="m"><b>${t}</b></div><span>›</span></div>`).join('');
};
const n=id=>parseFloat(($('#'+id)||{}).value);
const fx=(v,d=3)=>isFinite(v)?(+v.toFixed(d)).toString():'-';
// Pt100 CVD
function ptR(t,R0=100){const A=3.9083e-3,B=-5.775e-7,C=-4.183e-12;return t>=0?R0*(1+A*t+B*t*t):R0*(1+A*t+B*t*t+C*(t-100)*t*t*t)}
function ptT(R,R0=100){let lo=-200,hi=850;for(let i=0;i<60;i++){const m=(lo+hi)/2;ptR(m,R0)<R?lo=m:hi=m}return(lo+hi)/2}
function tcMv(type,t){const d=TC[type];const i=t-d.t0;const a=Math.floor(i);if(a<0||a>=d.mv.length-1)return NaN;return d.mv[a]+(d.mv[a+1]-d.mv[a])*(i-a)}
function tcT(type,mv){const d=TC[type];const v=d.mv;for(let i=0;i<v.length-1;i++){if((v[i]<=mv&&mv<=v[i+1])){return d.t0+i+(mv-v[i])/(v[i+1]-v[i])}}return NaN}
const CV={
ma:{h:`<div class="row"><label>量程下限</label><input id="lo" type="number" value="0"></div><div class="row"><label>量程上限</label><input id="hi" type="number" value="100"></div>
<div class="row"><label>电流 mA</label><input id="ma" type="number" placeholder="输入电流求工程量"></div><div class="row"><label>工程量</label><input id="pv" type="number" placeholder="或输入工程量求电流"></div>
<div class="row"><label>开方输出</label><select id="sq"><option value="0">否（线性）</option><option value="1">是（差压流量）</option></select></div><div id="o" class="res"></div>`,
f(){const lo=n('lo'),hi=n('hi'),sq=$('#sq').value=='1';let ma=n('ma'),pv=n('pv');let o='';
 if(isFinite(ma)){let p=(ma-4)/16;if(sq)p=Math.sqrt(Math.max(p,0));o=`工程量 = ${fx(lo+p*(hi-lo))}　（${fx(p*100,2)}%）`}
 else if(isFinite(pv)){let p=(pv-lo)/(hi-lo);if(sq)p=p*p;o=`电流 = ${fx(4+16*p)} mA　（${fx(p*100,2)}%）`}
 $('#o').innerHTML=o+`<div class="muted">4/8/12/16/20 mA = 0/25/50/75/100%；250Ω上电压 1~5 V</div>`}},
rtd:{h:`<div class="row"><label>类型</label><select id="ty"><option>Pt100</option><option>Pt1000</option><option>Cu50</option><option>Cu100</option></select></div>
<div class="row"><label>温度 ℃</label><input id="t" type="number" placeholder="输入温度求电阻"></div><div class="row"><label>电阻 Ω</label><input id="r" type="number" placeholder="或输入电阻求温度"></div><div id="o" class="res"></div>`,
f(){const ty=$('#ty').value;const t=n('t'),r=n('r');let o='';
 if(ty.startsWith('Pt')){const R0=ty=='Pt100'?100:1000;if(isFinite(t))o=`R = ${fx(ptR(t,R0),3)} Ω`;else if(isFinite(r))o=`t = ${fx(ptT(r,R0),2)} ℃`}
 else{const R0=ty=='Cu50'?50:100,a=4.28e-3;if(isFinite(t))o=`R = ${fx(R0*(1+a*t),3)} Ω`;else if(isFinite(r))o=`t = ${fx((r/R0-1)/a,2)} ℃`}
 $('#o').innerHTML=o+`<div class="muted">Pt100 按 IEC 60751（ITS-90）；Cu 按 α=0.00428，适用 -50~150℃</div>`}},
tc:{h:`<div class="row"><label>分度号</label><select id="ty">${Object.keys(TC).map(k=>`<option>${k}</option>`).join('')}</select></div>
<div class="row"><label>冷端温度 ℃</label><input id="cj" type="number" value="25"></div>
<div class="row"><label>热端温度 ℃</label><input id="t" type="number" placeholder="求应测mV"></div><div class="row"><label>实测 mV</label><input id="mv" type="number" placeholder="或输入实测mV求温度"></div><div id="o" class="res"></div>`,
f(){const ty=$('#ty').value,cj=n('cj')||0,t=n('t'),mv=n('mv');const e0=tcMv(ty,cj);let o='';
 if(isFinite(t)){const E=tcMv(ty,t);o=`E(t,0) = ${fx(E)} mV<br>冷端${cj}℃时应测：${fx(E-e0)} mV`}
 else if(isFinite(mv)){o=`热端温度 = ${fx(tcT(ty,mv+e0),1)} ℃<div class="muted">（已加冷端补偿 E(${cj},0)=${fx(e0)} mV）</div>`}
 $('#o').innerHTML=o+`<div class="muted">分度表依据 NIST ITS-90，1℃步长插值</div>`}},
err:{h:`<div class="row"><label>量程下限</label><input id="lo" type="number" value="0"></div><div class="row"><label>量程上限</label><input id="hi" type="number" value="1.6"></div><div class="row"><label>精度等级</label><input id="cl" type="number" value="1.6"></div><div class="row"><label>输出</label><select id="out"><option value="pv">工程量</option><option value="ma">4~20mA</option></select></div><div id="o"></div>`,
f(){const lo=n('lo'),hi=n('hi'),cl=n('cl');const sp=hi-lo,al=sp*cl/100;const ma=$('#out').value=='ma';
 let h=`<div class="res">允许误差 ±${fx(al,4)}（量程${fx(sp)}×${cl}%）${ma?`，电流 ±${fx(16*cl/100,3)} mA`:''}</div><table><tr><th>%</th><th>标准值</th>${ma?'<th>电流mA</th>':''}<th>允许范围</th></tr>`;
 [0,25,50,75,100].forEach(p=>{const v=lo+sp*p/100;h+=`<tr><td>${p}</td><td>${fx(v,4)}</td>${ma?`<td>${fx(4+16*p/100,2)}</td>`:''}<td>${ma?fx(4+16*p/100-16*cl/100,3)+'~'+fx(4+16*p/100+16*cl/100,3)+' mA':fx(v-al,4)+'~'+fx(v+al,4)}</td></tr>`});
 $('#o').innerHTML=h+'</table><p class="muted">压力表还要求：回程误差≤允许误差，轻敲位移≤允许误差的1/2。</p>'}},
flow:{h:`<div class="row"><label>满量程流量</label><input id="qm" type="number" value="100"></div><div class="row"><label>满量程差压</label><input id="pm" type="number" value="40" placeholder="kPa"></div><div class="row"><label>实测差压</label><input id="p" type="number" placeholder="求流量"></div><div class="row"><label>流量</label><input id="q" type="number" placeholder="或求差压"></div><div id="o" class="res"></div>`,
f(){const qm=n('qm'),pm=n('pm'),p=n('p'),q=n('q');let o='';
 if(isFinite(p))o=`流量 = ${fx(qm*Math.sqrt(Math.max(p,0)/pm))}　（${fx(Math.sqrt(Math.max(p,0)/pm)*100,2)}%）`;else if(isFinite(q))o=`差压 = ${fx(pm*(q/qm)**2)}　（差压${fx((q/qm)**2*100,2)}%，线性输出电流 ${fx(4+16*(q/qm)**2)} mA）`;
 $('#o').innerHTML=o+`<div class="muted">Q = Qmax·√(ΔP/ΔPmax)</div>`}},
level:{h:`<p class="muted">双法兰差压液位计（负压侧毛细管充硅油）</p><div class="row"><label>介质密度</label><input id="r1" type="number" value="1000" placeholder="kg/m³"></div><div class="row"><label>测量范围H</label><input id="h" type="number" value="2" placeholder="m，上下法兰间可测高度"></div><div class="row"><label>硅油密度</label><input id="r0" type="number" value="930"></div><div class="row"><label>法兰间距</label><input id="d" type="number" value="2" placeholder="m，上下取压口距离"></div><div class="row"><label>零点以下高度</label><input id="z" type="number" value="0" placeholder="m，零液位高于下法兰"></div><div id="o"></div>`,
f(){const g=9.80665,r1=n('r1'),h=n('h'),r0=n('r0'),d=n('d'),z=n('z')||0;
 const sp=r1*g*h/1000,lo=(r1*g*z-r0*g*d)/1000,hi=lo+sp;
 $('#o').innerHTML=`<div class="res">量程 ${fx(sp)} kPa；下限 ${fx(lo)} kPa；上限 ${fx(hi)} kPa</div><p class="muted">ΔP = ρ介质·g·h − ρ硅油·g·d；负迁移量 ${fx(r0*g*d/1000)} kPa。单法兰/开口罐：ΔP=ρgh。</p>`}},
unit:{h:`<div class="row"><input id="v" type="number" value="1"><select id="u"><option>MPa</option><option>kPa</option><option>Pa</option><option>bar</option><option>kgf/cm²</option><option>psi</option><option>mmH2O</option><option>mmHg</option><option>atm</option></select></div><div id="o"></div>`,
f(){const F={'MPa':1e6,'kPa':1e3,'Pa':1,'bar':1e5,'kgf/cm²':98066.5,'psi':6894.757,'mmH2O':9.80665,'mmHg':133.322,'atm':101325};const pa=n('v')*F[$('#u').value];
 $('#o').innerHTML='<table>'+Object.keys(F).map(k=>`<tr><td>${k}</td><td>${fx(pa/F[k],5)}</td></tr>`).join('')+'</table>'}},
vib:{h:`<div class="row"><label>转速 r/min</label><input id="rpm" type="number" value="3000"></div><div class="row"><label>位移 μm p-p</label><input id="d" type="number" placeholder="输入其一"></div><div class="row"><label>速度 mm/s rms</label><input id="v" type="number"></div><div class="row"><label>加速度 g 峰值</label><input id="a" type="number"></div><div id="o"></div>`,
f(){const f=n('rpm')/60,w=2*Math.PI*f;let D=n('d'),V=n('v'),A=n('a');let vp;
 if(isFinite(D))vp=w*D/2/1000;else if(isFinite(V))vp=V*Math.SQRT2;else if(isFinite(A))vp=A*9806.65/w;else{$('#o').innerHTML='';return}
 D=vp/w*2*1000;$('#o').innerHTML=`<div class="res">f = ${fx(f,2)} Hz</div><table><tr><td>位移峰峰值</td><td>${fx(D,2)} μm（${fx(D/25.4,3)} mil）</td></tr><tr><td>速度峰值</td><td>${fx(vp,3)} mm/s</td></tr><tr><td>速度有效值</td><td>${fx(vp/Math.SQRT2,3)} mm/s</td></tr><tr><td>加速度峰值</td><td>${fx(vp*w/9806.65,4)} g（${fx(vp*w/1000,3)} m/s²）</td></tr></table><p class="muted">单一频率正弦振动：v峰=2πf·(D/2)，a峰=2πf·v峰</p>`}},
gap:{h:`<div class="row"><label>系统</label><select id="sf"><option value="7.87">3300XL 8mm（7.87 V/mm）</option><option value="3.94">3300XL 11mm（3.94 V/mm）</option></select></div><div class="row"><label>间隙 mm</label><input id="g" type="number"></div><div class="row"><label>电压 V</label><input id="v" type="number" placeholder="如 -10"></div><div id="o" class="res"></div>`,
f(){const s=n('sf'),g=n('g'),v=n('v');let o='';if(isFinite(g))o=`电压 ≈ ${fx(-g*s,2)} V`;else if(isFinite(v))o=`间隙 ≈ ${fx(Math.abs(v)/s,3)} mm（${fx(Math.abs(v)/s/0.0254,1)} mil）`;
 $('#o').innerHTML=o+`<div class="muted">近似线性换算，实际以校验曲线为准。8mm径向振动常调 -10 V（约1.27 mm）</div>`}},
probecal:{h:`<div class="row"><label>系统</label><select id="sf"><option value="7.87">3300XL 8mm</option><option value="3.94">3300XL 11mm</option></select></div><div class="row"><label>起始间隙</label><input id="g0" type="number" value="0.25"></div><div class="row"><label>步长 mm</label><input id="st" type="number" value="0.25"></div><p class="muted">依次填写各点电压（V，负号可省略）：</p><div id="pts">${[...Array(9)].map((_,i)=>`<div class="row"><label id="pl${i}">点${i+1}</label><input id="p${i}" type="number" inputmode="decimal"></div>`).join('')}</div><button class="b2" onclick="CV.probecal.ex()">填入示例数据</button><div id="o"></div>`,
ex(){[-1.96,-3.93,-5.90,-7.86,-9.84,-11.80,-13.77,-15.74,-17.70].forEach((v,i)=>$('#p'+i).value=v);CV.probecal.f()},
f(){const S=n('sf'),g0=n('g0'),st=n('st');const P=[];for(let i=0;i<9;i++){$('#pl'+i).textContent=fx(g0+i*st,2)+' mm';const v=n('p'+i);if(isFinite(v))P.push([g0+i*st,Math.abs(v)])}
 if(P.length<3){$('#o').innerHTML='';return}
 const k=P.length,sx=P.reduce((a,p)=>a+p[0],0),sy=P.reduce((a,p)=>a+p[1],0),sxx=P.reduce((a,p)=>a+p[0]*p[0],0),sxy=P.reduce((a,p)=>a+p[0]*p[1],0);
 const asf=(k*sxy-sx*sy)/(k*sxx-sx*sx),b=(sy-asf*sx)/k;
 const isfLo=S*0.9,isfHi=S*1.1,asfLo=S*0.95,asfHi=S*1.05,dslLim=S>5?0.025:0.05;
 let h=`<table><tr><th>间隙mm</th><th>电压V</th><th>ISF V/mm</th><th>DSL mm</th></tr>`;let ok=true;
 P.forEach((p,i)=>{const isf=i?(p[1]-P[i-1][1])/(p[0]-P[i-1][0]):NaN;const dsl=(p[1]-(asf*p[0]+b))/asf;const a=!i||(isf>=isfLo&&isf<=isfHi),c=Math.abs(dsl)<=dslLim;ok=ok&&a&&c;
  h+=`<tr><td>${fx(p[0],2)}</td><td>-${fx(p[1],2)}</td><td class="${a?'':'ng'}">${i?fx(isf,2):'-'}</td><td class="${c?'':'ng'}">${fx(dsl,3)}</td></tr>`});
 const aok=asf>=asfLo&&asf<=asfHi;ok=ok&&aok;
 $('#o').innerHTML=`<div class="res">ASF = ${fx(asf,3)} V/mm <span class="${aok?'ok':'ng'}">${aok?'合格':'超差'}</span>（要求 ${fx(asfLo,2)}~${fx(asfHi,2)}）</div>`+h+`</table><div class="res ${ok?'ok':'ng'}">结论：${ok?'合格':'不合格'}</div><p class="muted">判定：ISF ${fx(isfLo,2)}~${fx(isfHi,2)} V/mm，DSL ±${dslLim} mm（按常用标准，具体以规程为准）</p>`}},
};
window.CV=CV;
V.calc=function(s){const c=CV[s.k];title((CALCS.find(x=>x[0]==s.k)||[])[1]||'计算');M.innerHTML=`<div class="card">${c.h}</div>`;
  M.querySelectorAll('select').forEach(e=>e.addEventListener('input',()=>c.f()));
  M.querySelectorAll('input').forEach(e=>{if(!['ma','pv'].includes(e.id))return;e.addEventListener('input',()=>{if(!e.value)return;const o=e.id=='ma'?'pv':'ma';$('#'+o).value=''})});
  // 互斥输入：清除同组其他输入
  const groups=[['t','r'],['t','mv'],['g','v'],['d','v','a'],['p','q'],['ma','pv']];
  M.querySelectorAll('input').forEach(e=>e.addEventListener('input',()=>{if(!e.value){c.f();return}groups.forEach(g=>{if(g.includes(e.id))g.forEach(o=>{if(o!=e.id&&$('#'+o)&&s.k!='probecal'&&s.k!='level')$('#'+o).value=''})});c.f()}));
  c.f()};

/* ---------- 探头选型 ---------- */
V.sel=function(){title('探头选型');
 M.innerHTML=`<div class="card"><h3>3300 XL 电涡流系统选型</h3>
 <div class="row"><label>探头规格</label><select id="s_ty"><option value="8">8 mm（7.87 V/mm）</option><option value="11">11 mm（3.94 V/mm）</option></select></div>
 <div class="row"><label>安装螺纹</label><select id="s_th"><option value="m">公制 M10×1（8mm）/ M14×1.5（11mm）</option><option value="e">英制 3/8-24 UNF（8mm）/ 5/8-18 UNF（11mm）</option></select></div>
 <div class="row"><label>铠装</label><select id="s_ar"><option value="0">不带铠装</option><option value="1">带铠装</option></select></div>
 <div class="row"><label>系统长度</label><select id="s_len"><option value="5">5 m</option><option value="9">9 m</option></select></div>
 <div class="row"><label>探头电缆长</label><select id="s_pl"><option value="05">0.5 m</option><option value="10" selected>1.0 m</option><option value="50">5.0 m（5m系统免延长）</option><option value="90">9.0 m（9m系统免延长）</option></select></div>
 <div class="row"><label>接头保护器</label><select id="s_cp"><option value="01">01 带接头保护器 ClickLoc</option><option value="02">02 微型同轴接头</option><option value="00">00 不装接头保护器</option></select></div>
 <div class="row"><label>前置器安装</label><select id="s_mt"><option value="1">DIN导轨</option><option value="0">面板</option></select></div>
 <div class="row"><label>认证</label><select id="s_ap"><option value="00">00 无</option><option value="05">05 多重认证（防爆区）</option></select></div>
 <div class="row"><label>壳体总长</label><input id="s_cl" placeholder="B码，按安装孔深度确定，如 05" value="05"></div>
 <div class="row"><label>无螺纹长度</label><input id="s_ul" value="00"></div>
 <div id="o"></div></div><div class="art"><p>选型规则：探头电缆长 + 延长电缆长 = 系统长度，三件同系列；铠装用于电缆易受机械损伤的场合；防爆区选带认证型号并配安全栅/隔离。</p><button class="b2" onclick="App.go('art',{id:'probe'})">查看参数注释</button></div>`;
 const f=()=>{const ty=$('#s_ty').value,th=$('#s_th').value,ar=$('#s_ar').value,L=+$('#s_len').value,pl=$('#s_pl').value,cp=$('#s_cp').value,mt=$('#s_mt').value,ap=$('#s_ap').value;
  const plm=+pl/10;let ext=L-plm;let warn='';
  if(ext<0||(pl=='50'&&L==9)||(pl=='90'&&L==5)){warn='探头电缆长度超过系统长度，请改选';ext=null}
  let probe,cable,prox,sens,rng;
  if(ty=='8'){probe=(th=='e'?(ar=='1'?'330102':'330101'):(ar=='1'?'330104':'330103'));cable='330130';prox='330180';sens='7.87 V/mm（200 mV/mil）';rng='2 mm（80 mil）'}
  else{probe=(th=='e'?(ar=='1'?'330704':'330703'):(ar=='1'?'330706':'330705'));cable='330730';prox='330780';sens='3.94 V/mm（100 mV/mil）';rng='4 mm（160 mil）'}
  const extCode=ext==null?'':String(Math.round(ext*10)).padStart(3,'0');
  const B=$('#s_cl').value.trim()||'05',A=$('#s_ul').value.trim()||'00';
  $('#o').innerHTML=warn?`<p class="ng">${warn}</p>`:`<table>
  <tr><th>部件</th><th>订货号</th><th>说明</th></tr>
  <tr><td>探头</td><td><b>${probe}-${A}-${B}-${pl}-${cp}-${ap}</b></td><td>无螺纹${A}，壳长${B}，电缆${plm} m</td></tr>
  <tr><td>延长电缆</td><td><b>${ext>0?cable+'-'+extCode+'-'+(ar=='1'?'01':'00')+'-'+ap:'不需要'}</b></td><td>${ext>0?ext.toFixed(1)+' m'+(ar=='1'?'，铠装':''):'探头电缆已等于系统长度'}</td></tr>
  <tr><td>前置器</td><td><b>${prox}-${L}${mt}-${ap}</b></td><td>${L} m系统，${mt=='1'?'DIN导轨':'面板'}安装</td></tr></table>
  <p class="muted">灵敏度 ${sens}，线性范围 ${rng}，电源 -24 VDC。${ty=='11'?'11mm型号请按官方订货资料核对螺纹/铠装对应关系。':''}订货前请以 Bently Nevada 官方订货手册核对选项码。</p>`};
 M.querySelectorAll('input,select').forEach(e=>e.addEventListener('input',f));f();
};

/* ---------- SIS ---------- */
V.sis=function(){title('SIS 画面');
 const gs=[...new Set(SIS.map(x=>x.g))];
 M.innerHTML=`<div class="art" style="margin-bottom:12px"><details><summary><b>画面读法 / 逻辑符号说明</b></summary>${SIS_INTRO}</details></div>`+
 gs.map(g=>`<div class="sec">${g}</div>`+SIS.map((x,i)=>x.g==g?`<div class="li" onclick="App.go('sisv',{i:${i}})"><img src="img/sis/${x.f}" style="width:84px;height:52px;object-fit:cover;border-radius:6px"><div class="m"><b>${esc(x.t)}</b><div>${esc(x.d.replace(/<[^>]+>/g,'').slice(0,40))}…</div></div></div>`:'').join('')).join('');
};
let zoom=1;
V.sisv=function(s){const i=s.i,x=SIS[i];title(x.t);
 M.innerHTML=`<div class="pager"><button class="b2" onclick="App.render({p:'sisv',i:${(i+SIS.length-1)%SIS.length}})">‹ 上一页</button><span class="pn">${i+1} / ${SIS.length}</span><button class="b2" onclick="App.render({p:'sisv',i:${(i+1)%SIS.length}})">下一页 ›</button></div>
 <div class="viewer" id="vw"><img id="vimg" src="img/sis/${x.f}" style="width:${zoom*100}%"></div>
 <div class="pager"><button class="b2" onclick="Z(-1)">－ 缩小</button><span class="pn muted">左右滑动翻页，双击放大</span><button class="b2" onclick="Z(1)">＋ 放大</button></div>
 <div class="art"><h2>${esc(x.t)}</h2>${s.hl?hl(x.d,s.hl):x.d}</div>`;
 swipe($('#vw'),d=>App.render({p:'sisv',i:(i+d+SIS.length)%SIS.length}));
 $('#vimg').ondblclick=()=>Z(zoom>=2?-9:1);
};
window.Z=function(d){zoom=d<-5?1:Math.min(4,Math.max(1,zoom+d*0.75));const im=$('#vimg');if(im)im.style.width=(zoom*100)+'%'};
function swipe(el,cb){let x0=null,y0=0;el.addEventListener('touchstart',e=>{if(e.touches.length>1||zoom>1){x0=null;return}x0=e.touches[0].clientX;y0=e.touches[0].clientY},{passive:true});
 el.addEventListener('touchend',e=>{if(x0==null)return;const dx=e.changedTouches[0].clientX-x0,dy=e.changedTouches[0].clientY-y0;if(Math.abs(dx)>60&&Math.abs(dx)>Math.abs(dy)*1.5)cb(dx<0?1:-1);x0=null})}

/* ---------- 资料 ---------- */
V.kb=function(){title('资料');
 const cs=[...new Set(KB.map(a=>a.c))];
 M.innerHTML=`<div class="sec">培训资料（原文，可搜索）</div>`+DOCS.map((d,i)=>`<div class="li" onclick="App.go('doc',{d:${i}})"><img src="${d.dir}p-${'1'.padStart(d.pad,'0')}.jpg" style="width:52px;height:52px;object-fit:cover;border-radius:6px"><div class="m"><b>${esc(d.t)}</b><div>${d.n} 页</div></div></div>`).join('')+
 cs.map(c=>`<div class="sec">${c}</div>`+KB.filter(a=>a.c==c).map(a=>`<div class="li" onclick="App.go('art',{id:'${a.id}'})"><div class="m"><b>${esc(a.t)}</b></div><span>›</span></div>`).join('')).join('');
};
V.art=function(s){const a=KB.find(x=>x.id==s.id);title(a.t);M.innerHTML=`<div class="art"><h2>${esc(a.t)}</h2>${s.hl?hl(a.h,s.hl):a.h}</div>`;
 if(a.id=='probe-cal')M.insertAdjacentHTML('beforeend',`<p><button class="b" style="width:100%" onclick="App.go('calc',{k:'probecal'})">打开探头校验计算</button></p>`);
 if(a.id=='probe')M.insertAdjacentHTML('beforeend',`<p><button class="b" style="width:100%" onclick="App.go('sel')">打开选型工具</button></p>`)};
V.doc=function(s){const d=DOCS[s.d];const pg=s.pg||1;title(d.t);
 const src=d.dir+'p-'+String(pg).padStart(d.pad,'0')+'.jpg';
 M.innerHTML=`<div class="row"><input id="dq" placeholder="在本资料中搜索" value="${esc(s.q||'')}" onkeydown="if(event.key=='Enter')App.render({p:'doc',d:${s.d},pg:${pg},q:this.value})"><button class="b" style="flex:0 0 auto" onclick="App.render({p:'doc',d:${s.d},pg:${pg},q:document.getElementById('dq').value})">搜</button></div>
 <div id="dres"></div>
 <div class="pager"><button class="b2" onclick="App.render({p:'doc',d:${s.d},pg:${Math.max(1,pg-1)},q:'${esc(s.q||'')}'})">‹</button><span class="pn"><input id="pgi" type="number" value="${pg}" style="width:70px;text-align:center" onchange="App.render({p:'doc',d:${s.d},pg:Math.min(${d.n},Math.max(1,+this.value||1)),q:'${esc(s.q||'')}'})"> / ${d.n}</span><button class="b2" onclick="App.render({p:'doc',d:${s.d},pg:${Math.min(d.n,pg+1)},q:'${esc(s.q||'')}'})">›</button></div>
 <div class="viewer" id="vw" style="max-height:none"><img id="vimg" src="${src}" style="width:${zoom*100}%"></div>
 <div class="pager"><button class="b2" onclick="Z(-1)">－</button><span class="pn muted">左右滑动翻页</span><button class="b2" onclick="Z(1)">＋</button></div>
 <details class="art"><summary class="muted">本页文字${d.id=='kjs'?'（图片识别，可能有误）':''}</summary><pre style="white-space:pre-wrap;font:inherit;font-size:13px">${s.q?hl(esc(d.txt[pg-1]),s.q):esc(d.txt[pg-1])}</pre></details>`;
 swipe($('#vw'),dd=>{const np=pg+dd;if(np>=1&&np<=d.n)App.render({p:'doc',d:s.d,pg:np,q:s.q})});
 if(s.q){const hits=[];d.txt.forEach((t,i)=>{if(norm(t).includes(norm(s.q)))hits.push(i+1)});
  $('#dres').innerHTML=hits.length?`<div class="chips">${hits.map(h=>`<span class="${h==pg?'on':''}" onclick="App.render({p:'doc',d:${s.d},pg:${h},q:'${esc(s.q)}'})">第${h}页</span>`).join('')}</div>`:`<p class="muted">没有找到“${esc(s.q)}”</p>`}
};

/* ---------- 搜索 ---------- */
const norm=s=>String(s||'').toLowerCase().replace(/\s+/g,'');
function hl(html,q){if(!q)return html;const re=new RegExp('('+q.replace(/[.*+?^${}()|[\]\\]/g,'\\$&')+')','gi');return html.replace(/(<[^>]+>)|([^<]+)/g,(m,tag,txt)=>tag?tag:txt.replace(re,'<mark>$1</mark>'))}
function snip(t,q){const p=norm(t);t=String(t).replace(/\s+/g,'');const i=p.indexOf(norm(q));if(i<0)return'';return esc(t.slice(Math.max(0,i-18),i))+'<mark>'+esc(t.substr(i,q.replace(/\s+/g,'').length))+'</mark>'+esc(t.substr(i+q.replace(/\s+/g,'').length,30))}
V.search=function(s){title('搜索');const q=(s.q||'').trim();
 M.innerHTML=`<div class="row"><input id="sq" placeholder="位号、设备、联锁、关键词…" value="${esc(q)}" onkeydown="if(event.key=='Enter')App.render({p:'search',q:this.value})"><button class="b" style="flex:0 0 auto" onclick="App.render({p:'search',q:document.getElementById('sq').value})">搜索</button></div><div id="sr"></div>`;
 if(!q){$('#sq').focus();$('#sr').innerHTML='<p class="muted">可搜索：台账位号/安装地点、知识文章、SIS联锁说明、康吉森和浙大培训资料全文。</p>';return}
 const nq=norm(q);let h='';
 const L=LED.filter(r=>norm([r.tag,r.name,r.loc,r.model,r.range].join(' ')).includes(nq));
 if(L.length)h+=`<div class="sec">设备台账（${L.length}）</div>`+L.slice(0,30).map(r=>{const[st,c]=stCls(r);return`<div class="li" onclick="App.go('rec',{id:'${r.id}'})"><div class="m"><b>${hl(esc(r.tag),q)}</b> <span class="muted">${esc(r.name)}</span><div>${hl(esc(r.loc),q)}</div></div><span class="tag" style="background:${c}">${st}</span></div>`}).join('')+(L.length>30?`<button class="b2" style="width:100%;margin-bottom:8px" onclick="Ledger.q='${esc(q)}';Ledger.sheet='全部';Ledger.f='all';App.tab('ledger')">在台账中查看全部 ${L.length} 条</button>`:'');
 const S=SIS.map((x,i)=>[x,i]).filter(([x])=>norm(x.t+x.d.replace(/<[^>]+>/g,'')).includes(nq));
 if(S.length)h+=`<div class="sec">SIS 联锁（${S.length}）</div>`+S.map(([x,i])=>`<div class="li" onclick="App.go('sisv',{i:${i},hl:'${esc(q)}'})"><div class="m"><b>${esc(x.t)}</b><div>${snip(x.t+'：'+x.d.replace(/<[^>]+>/g,''),q)}</div></div></div>`).join('');
 const K=KB.filter(a=>norm(a.t+a.h.replace(/<[^>]+>/g,'')).includes(nq));
 if(K.length)h+=`<div class="sec">知识文章（${K.length}）</div>`+K.map(a=>`<div class="li" onclick="App.go('art',{id:'${a.id}',hl:'${esc(q)}'})"><div class="m"><b>${esc(a.t)}</b><div>${snip(a.h.replace(/<[^>]+>/g,''),q)}</div></div></div>`).join('');
 DOCS.forEach((d,di)=>{const P=[];d.txt.forEach((t,i)=>{if(norm(t).includes(nq))P.push(i)});
  if(P.length)h+=`<div class="sec">${esc(d.t)}（${P.length}页）</div>`+P.slice(0,20).map(i=>`<div class="li" onclick="App.go('doc',{d:${di},pg:${i+1},q:'${esc(q)}'})"><div class="m"><b>第${i+1}页</b><div>${snip(d.txt[i],q)}</div></div></div>`).join('')});
 $('#sr').innerHTML=h||`<p class="muted">没有找到“${esc(q)}”</p>`;
};

loadLedger();
App.tab('home');
setTimeout(syncRemind,800);
})();
