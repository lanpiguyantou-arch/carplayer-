# Hand-authored supplementary content: 陕旅版英语六上(2026), 统编语文六上(2026), 阅读理解答题方法.
import json, random, os
random.seed(6)
HERE = os.path.dirname(os.path.abspath(__file__))
T, D, Q = [], [], []

def topic(id, n, s, g, v, u, dm, de, mc=()):
    T.append(dict(id=id, n=n, s=s, g=g, v=v, u=u, dm=dm, de=de, mc=list(mc)))
def dep(t, p, r, h=True):
    D.append(dict(t=t, p=p, h=h, r=r))
qc = {}
def q(t, p, a, ex='', ty='choice', c=None, df=0, ac=None):
    qc[t] = qc.get(t, 0) + 1
    e = dict(id=f'{t}_q{qc[t]}', t=t, df=df, ty=ty, p=p, a=a, ex=ex)
    if c:
        keys = 'ABCD'
        e['c'] = [dict(k=keys[i], x=x, f=None) for i, x in enumerate(c)]
    if ac: e['ac'] = ac
    Q.append(e)
def ch(t, p, right, wrong, ex='', df=0):
    opts = [right] + list(wrong)
    random.shuffle(opts)
    q(t, p, 'ABCD'[opts.index(right)], ex, c=opts, df=df)

# ------------------------------------------------------------------ 陕旅版英语六上
V = '陕旅版六上(2026)'
titles = {1: 'They Were Here Just Now', 2: 'My Hometown', 3: 'What Did You Do Last Weekend?', 4: 'Where Did You Go on Your Holiday?',
          5: 'A Sports Meet', 6: 'We Had a Good Time', 7: "We'd Like a Plate of Beef", 8: 'New Year Is Coming'}
vocab = {}; cur = None
for line in open(os.path.join(HERE, 'slb6s_vocab.txt'), encoding='utf-8'):
    line = line.strip()
    if not line: continue
    if line.startswith('#'): cur = int(line[1:]); vocab[cur] = []; continue
    en, zh = line.split('|'); vocab[cur].append((en, zh))
allw = [w for u in vocab for w in vocab[u]]

for u in range(1, 9):
    U = f'Unit {u} {titles[u]}'
    vid = f'slb6_u{u}_w'
    topic(vid, f'Unit {u} 单词短语', 'english', 6, V, U, '词汇', f'陕旅版六上 Unit {u} 单元词汇（共 {len(vocab[u])} 个）：' + '，'.join(e for e, _ in vocab[u]),
          ['看到英文能说出中文意思', '看到中文能拼写出英文'])
    for en, zh in vocab[u]:
        others = [z for e, z in allw if z != zh]
        ch(vid, f'「{en}」的中文意思是？', zh, random.sample(others, 3), f'{en}：{zh}')
    for en, zh in vocab[u]:
        q(vid, f'拼写英文：{zh}', en, f'{zh}：{en}', ty='spell', df=1)
    if u > 1: dep(vid, f'slb6_u{u-1}_w', '按单元顺序积累词汇。', h=False)

S = lambda u: f'slb6_u{u}_s'
def sent(u, desc, mc):
    topic(S(u), f'Unit {u} 重点句型', 'english', 6, V, f'Unit {u} {titles[u]}', '句型', desc, mc)
    dep(S(u), f'slb6_u{u}_w', '先会单词，再练句型。')

sent(1, '一般过去时 be 动词：was / were。It was in its mother\'s arms a moment ago. They were here just now.', ['主语是 I / he / she / it 用 was', '主语是 you / we / they 用 were'])
ch(S(1), 'The book ___ on the desk just now.', 'was', ['were', 'is', 'are'], 'just now 表示刚才，用过去式；book 是单数，用 was。')
ch(S(1), 'They ___ here a moment ago.', 'were', ['was', 'are', 'is'], 'a moment ago 用过去式，they 用 were。')
ch(S(1), 'The baby ant ___ in its mother\'s arms a moment ago.', 'was', ['were', 'is', 'be'], '单数主语 + 过去时间 → was。')
ch(S(1), '— Where were the butterflies? — They ___ near the lake.', 'were', ['was', 'are', 'did'], '回答过去的问题仍用过去式，复数用 were。')
ch(S(1), '“leaf”的复数是？', 'leaves', ['leafs', 'leafes', 'leaf'], 'f 结尾变 v 加 es：leaf → leaves。', df=1)

sent(2, '询问过去在不在某地：Were you at home yesterday afternoon? Yes, I was. / No, they weren\'t.', ['Were you…? 用 I was / I wasn\'t 回答', 'Were they…? 用 they were / they weren\'t 回答'])
ch(S(2), '— Were you at home yesterday afternoon? — Yes, I ___.', 'was', ['were', 'am', 'did'], '问 you，答 I，过去式用 was。')
ch(S(2), '— Were your parents at home? — No, they ___.', "weren't", ["wasn't", "didn't", "aren't"], 'they 的否定过去式是 weren\'t。')
ch(S(2), 'There ___ a few hotels in front of the river ten years ago.', 'were', ['was', 'are', 'is'], 'a few hotels 是复数，ten years ago 用过去式。')
ch(S(2), 'There ___ no public toilet in my village before.', 'was', ['were', 'is', 'are'], 'public toilet 单数，before 表示以前。')
ch(S(2), '“mouse”的复数是？', 'mice', ['mouses', 'mices', 'mouse'], 'mouse 的复数是不规则的 mice。', df=1)

sent(3, '一般过去时实义动词：What did you do last Saturday? I cleaned the room, washed the clothes and cooked dinner.', ['问过去做了什么：What did you do…?', '回答用动词过去式，规则动词加 -ed'])
ch(S(3), '— What did you do last Saturday? — I ___ the room.', 'cleaned', ['clean', 'cleans', 'cleaning'], 'last Saturday 是过去时间，用过去式 cleaned。')
ch(S(3), 'She ___ the clothes and cooked dinner yesterday.', 'washed', ['washes', 'wash', 'washing'], '与 cooked 并列，都用过去式。')
ch(S(3), '— What ___ you do last weekend? — I borrowed a book.', 'did', ['do', 'does', 'were'], '问过去做了什么用 did。')
ch(S(3), 'Please read ___ in the reading room.', 'quietly', ['quiet', 'quite', 'quick'], '修饰动词 read 用副词 quietly。', df=1)
q(S(3), '写出 study 的过去式', 'studied', '辅音字母 + y 结尾，变 y 为 i 再加 ed。', ty='spell', df=1)
q(S(3), '写出 stop 的过去式', 'stopped', '重读闭音节，双写末尾辅音字母再加 ed。', ty='spell', df=2)

sent(4, '询问假期去哪、怎么去：Where did Li Shan go on her holiday? She went to Qingdao. How did they go there? They went there by train.', ['Where did … go? → … went to …', 'How did … go there? → by train / by plane / on foot'])
ch(S(4), '— Where did Li Shan go on her holiday? — She ___ to Qingdao.', 'went', ['go', 'goes', 'going'], 'go 的过去式是 went。')
ch(S(4), '— How did they go there? — They went there ___ train.', 'by', ['on', 'in', 'take'], '乘坐交通工具用 by + 交通工具。')
ch(S(4), 'We ___ seafood and played beach volleyball last summer.', 'ate', ['eat', 'eated', 'eats'], 'eat 的过去式是 ate。')
ch(S(4), '— ___ did you go to Beijing? — On National Day.', 'When', ['Where', 'How', 'What'], '回答的是时间，用 When。')
ch(S(4), 'It is ___ to book the tickets early.', 'necessary', ['exciting', 'national', 'quietly'], 'It is necessary to… 有必要做……')

sent(5, '运动会：What sport did you take part in? I took part in the long jump. Did you win? Yes, I did.', ['take part in 的过去式是 took part in', 'Did…? 用 Yes, … did. / No, … didn\'t. 回答'])
ch(S(5), '— What sport did you take part in? — I ___ part in the long jump.', 'took', ['take', 'taked', 'takes'], 'take 的过去式是 took。')
ch(S(5), '— Did you win? — Yes, I ___.', 'did', ['was', 'do', 'win'], 'Did 开头的问句用 did 回答。')
ch(S(5), 'He fell down on the way, but he ___ his best.', 'tried', ['try', 'tryed', 'tries'], 'try → tried。')
ch(S(5), 'Finally, our class ___ the race.', 'won', ['win', 'wined', 'wins'], 'win 的过去式是 won。', df=1)

sent(6, '校园义卖：Did you take part in the school sale yesterday morning? What did you sell? I sold some color paper, magazines, a robot …', ['sell 的过去式是 sold', '一般过去时的一般疑问句：Did + 主语 + 动词原形？'])
ch(S(6), '— What did you sell? — I ___ some magazines.', 'sold', ['sell', 'selled', 'sells'], 'sell → sold。')
ch(S(6), '— Did you take part in the school sale? — Yes, I ___.', 'did', ['do', 'was', 'took'], 'Did 问句用 did 回答。')
ch(S(6), 'Did you ___ any notebooks to the sale?', 'bring', ['brought', 'brings', 'bringing'], 'Did 后面跟动词原形。')
ch(S(6), 'The funny show made us ___.', 'laugh', ['laughed', 'laughs', 'to laugh'], 'make sb. do sth. 后接动词原形。', df=1)

sent(7, '点餐：Would you like something to drink? Yes, please. What kind of drinks would you like, juice or water? A bottle of water.', ['Would you like…? 肯定回答 Yes, please.', '量词短语：a cup of / a glass of / a bottle of / a bowl of / a plate of / a piece of'])
ch(S(7), '— Would you like something to drink? — ___', 'Yes, please.', ['Yes, I would like.', 'Yes, I do.', 'No, I don\'t.'], 'Would you like…? 的肯定回答是 Yes, please.')
ch(S(7), 'I\'d like a ___ of porridge.', 'bowl', ['bottle', 'piece', 'glass'], '一碗粥：a bowl of porridge。')
ch(S(7), 'Can I have a ___ of pizza?', 'piece', ['cup', 'bowl', 'bottle'], '一块披萨：a piece of pizza。')
ch(S(7), 'We\'d like two ___ of beef.', 'plates', ['plate', 'plates of', 'plate of'], '两盘：two plates of，名词 plate 变复数。', df=1)
ch(S(7), '— What kind of drinks would you like, juice or water? — ___', 'A bottle of water.', ['Yes, please.', 'I like it.', 'No, thanks.'], '选择疑问句不用 yes/no 回答。')

sent(8, '新年：What did you do this year? I read some books about science. Do you have a plan for the new year? Yes, I do. I wish to join our ping-pong team.', ['回顾过去用一般过去时', 'wish to do 希望做某事'])
ch(S(8), '— Do you have a plan for the new year? — Yes, I ___.', 'do', ['did', 'am', 'have'], 'Do 开头问句用 do 回答。')
ch(S(8), 'I wish ___ our ping-pong team.', 'to join', ['join', 'joining', 'joined'], 'wish to do sth.')
ch(S(8), 'During the Spring Festival, we put up ___ and hang lanterns.', 'couplets', ['couplet', 'greetings', 'dates'], 'put up couplets 贴对联。')
ch(S(8), 'We visit ___ and friends at the Spring Festival.', 'relatives', ['relative', 'relatived', 'relations of'], 'visit relatives and friends 走亲访友。')

# phonics
P = 'slb6_phonics'
topic(P, '字母组合发音（th sh ch tr dr wh ph ck）', 'english', 6, V, 'Phonics 语音', '语音', '本册语音：th、sh、ch（Unit 1、3），tr、dr（Unit 5），wh（Unit 7），ph、ck（Unit 8）。',
      ['th 有 /θ/（think）和 /ð/（this）两种读音', 'ph 读 /f/，ck 读 /k/', 'wh 多数读 /w/，在 who 中读 /h/'])
ch(P, '下列单词中 ph 的读音与 f 相同的是？', 'photo', ['shop', 'chair', 'think'], 'ph 读 /f/。')
ch(P, '哪个单词含有 /ʃ/（sh）音？', 'fish', ['chair', 'think', 'duck'], 'sh 读 /ʃ/。')
ch(P, '哪个单词中 ch 的发音和 lunch 相同？', 'teacher', ['school', 'fish', 'phone'], 'ch 一般读 /tʃ/，school 中读 /k/ 是例外。', df=1)
ch(P, '哪个单词的划线部分 ck 读 /k/？（选完全含 ck 的）', 'duck', ['dog', 'dress', 'tree'], 'ck 读 /k/。')
ch(P, '哪个单词以 /dr/ 开头？', 'dress', ['tree', 'three', 'ship'], 'dr 读 /dr/。')
ch(P, '哪个单词以 /tr/ 开头？', 'train', ['drum', 'three', 'chair'], 'tr 读 /tr/。')
ch(P, 'wh 读 /h/ 的是？', 'who', ['what', 'where', 'white'], 'who 中 wh 读 /h/，其他读 /w/。', df=1)
ch(P, 'th 读 /θ/（不振动声带）的是？', 'thank', ['this', 'that', 'mother'], 'thank 读清音 /θ/。', df=1)

# irregular verbs
IV = 'slb6_irregular'
topic(IV, '常用不规则动词过去式', 'english', 6, V, 'Irregular Verbs 不规则动词', '语法', '一般过去时里，很多常用动词的过去式不是加 -ed，需要单独记。',
      ['be → was / were', 'go → went，do → did，have → had', 'see → saw，eat → ate，take → took，sell → sold'])
for v, p in [('go', 'went'), ('do', 'did'), ('have', 'had'), ('see', 'saw'), ('eat', 'ate'), ('take', 'took'), ('sell', 'sold'), ('buy', 'bought'),
             ('make', 'made'), ('read', 'read'), ('win', 'won'), ('fall', 'fell'), ('find', 'found'), ('bring', 'brought'), ('come', 'came'),
             ('get', 'got'), ('swim', 'swam'), ('ride', 'rode'), ('run', 'ran'), ('sing', 'sang'), ('tell', 'told'), ('lose', 'lost'),
             ('hear', 'heard'), ('think', 'thought'), ('forget', 'forgot'), ('put', 'put'), ('hurt', 'hurt'), ('meet', 'met')]:
    q(IV, f'写出 {v} 的过去式', p, f'{v} → {p}', ty='spell', df=1)
for u in (3, 4, 5, 6): dep(S(u), IV, '回答过去发生的事要用动词过去式。')
dep(S(2), S(1), '先掌握 was / were，再用它提问。')

# ------------------------------------------------------------------ 统编语文六上
CV = '统编语文六上(2026)'
def cu(n, name): return f'第{n}单元 {name}'
def ctopic(id, n, unit, dm, de, mc=()): topic(id, n, 'chinese', 6, CV, unit, dm, de, mc)

u1 = cu('一', '亲近自然，热爱生活')
ctopic('cn6_u1_poem', '古诗词三首（宿建德江 等）', u1, '古诗文', '《宿建德江》（唐·孟浩然）、《六月二十七日望湖楼醉书》（宋·苏轼）、《西江月·夜行黄沙道中》（宋·辛弃疾）。', ['会背会默写', '说出作者和朝代', '体会诗人描写的景色和心情'])
ch('cn6_u1_poem', '“野旷天低树，江清月近人。”出自哪首诗？', '《宿建德江》', ['《江南春》', '《浪淘沙》', '《书湖阴先生壁》'], '孟浩然《宿建德江》。')
q('cn6_u1_poem', '补全诗句：移舟泊烟渚，日暮客______。', '愁新', '“移舟泊烟渚，日暮客愁新。”', ty='spell')
q('cn6_u1_poem', '补全诗句：黑云翻墨未遮山，白雨______乱入船。', '跳珠', '苏轼用“跳珠”比喻雨点。', ty='spell')
ch('cn6_u1_poem', '“卷地风来忽吹散，望湖楼下水如天。”作者是？', '苏轼', ['孟浩然', '辛弃疾', '杜牧'], '苏轼《六月二十七日望湖楼醉书》。')
q('cn6_u1_poem', '补全词句：稻花香里说丰年，听取______一片。', '蛙声', '辛弃疾《西江月·夜行黄沙道中》。', ty='spell')
ch('cn6_u1_poem', '《西江月·夜行黄沙道中》中“西江月”是什么？', '词牌名', ['题目', '地名', '作者的号'], '“西江月”是词牌名，“夜行黄沙道中”是题目。', df=1)
ch('cn6_u1_poem', '“白雨跳珠乱入船”用了什么修辞？', '比喻', ['拟人', '夸张', '排比'], '把雨点比作跳动的珍珠。', df=1)
ctopic('cn6_u1_read', '从所读的内容想开去', u1, '语文要素', '单元要素：积极思考，从所读的内容想开去（《草原》《丁香结》）。读到一处内容，联想到生活经验、其他文章或更深的道理。', ['先读懂文字本身', '再联系生活或学过的内容展开联想', '说出联想到了什么、得到什么启发'])
ch('cn6_u1_read', '《草原》的作者是？', '老舍', ['宗璞', '鲁迅', '冰心'], '《草原》作者老舍。')
ch('cn6_u1_read', '《丁香结》的作者是？', '宗璞', ['老舍', '鲁迅', '杨绛'], '宗璞写《丁香结》，由丁香结联想到人生中的愁怨。')
ch('cn6_u1_read', '由“丁香结”联想到“人生中的问题和不顺心的事”，这是在运用什么阅读方法？', '从所读的内容想开去', ['预测', '提问', '点面结合'], '由事物联想到人生，就是“想开去”。', df=1)
ch('cn6_u1_read', '“蒙汉情深何忍别，天涯碧草话斜阳”出自哪篇课文？', '《草原》', ['《丁香结》', '《开国大典》', '《桥》'], '《草原》结尾写蒙汉人民的深厚情谊。', df=1)

u2 = cu('二', '重温革命岁月')
ctopic('cn6_u2_poem', '七律·长征', u2, '古诗文', '毛泽东《七律·长征》，写红军长征不怕困难的英雄气概。', ['会背会默写', '理解“万水千山只等闲”的意思'])
q('cn6_u2_poem', '补全诗句：红军不怕远征难，万水千山______。', '只等闲', '“只等闲”表现红军不把困难放在眼里。', ty='spell')
q('cn6_u2_poem', '补全诗句：金沙水拍云崖暖，______横铁索寒。', '大渡桥', '“金沙水拍云崖暖，大渡桥横铁索寒。”', ty='spell')
ch('cn6_u2_poem', '“五岭逶迤腾细浪”把五岭比作什么？', '细小的波浪', ['泥丸', '铁索', '千里雪'], '绵延的五岭在红军眼里像细浪。')
ch('cn6_u2_poem', '全诗的诗眼（统领全诗的句子）是？', '红军不怕远征难', ['三军过后尽开颜', '更喜岷山千里雪', '乌蒙磅礴走泥丸'], '首句“不怕”统领全诗。', df=1)
ctopic('cn6_u2_dmjh', '点面结合写场面', u2, '语文要素', '“面”是对整个场面、人物群体的概括描写；“点”是对某个人、某个细节的具体描写。点面结合让场面既有气势又生动。', ['找出写整体场面的句子（面）', '找出写具体某人某事的句子（点）', '说出好处：既展现整体气势，又突出个体形象'])
ch('cn6_u2_dmjh', '“五位壮士一面向顶峰攀登，一面依托大树和岩石向敌人射击。”这句侧重写？', '面', ['点', '环境', '心理'], '写的是五位壮士整体，属于“面”。')
ch('cn6_u2_dmjh', '《狼牙山五壮士》中单独写马宝玉、葛振林等每个人怎样战斗，这属于？', '点', ['面', '环境描写', '插叙'], '对个体的具体描写是“点”。')
ch('cn6_u2_dmjh', '点面结合写场面的好处是？', '既展现整体场面，又突出个体人物', ['只突出一个人', '让文章更短', '交代故事背景'], '点面结合的作用。')
ch('cn6_u2_dmjh', '《开国大典》中写群众入场、全场欢呼主要是写“面”，写毛主席宣布中央人民政府成立是写？', '点', ['面', '环境', '对话'], '聚焦到具体人物和事件是“点”。', df=1)
dep('cn6_u2_dmjh', 'rm_scene', '点面结合属于写作手法分析的一种。', h=False)

u3 = cu('三', '有目的地阅读')
ctopic('cn6_u3_purpose', '根据阅读目的选用阅读方法', u3, '语文要素', '《竹节人》《宇宙生命之谜》《故宫博物院》：目的不同，读法不同。找信息就跳读、浏览；要弄懂原理就细读；要动手做就重点读步骤。', ['先明确阅读目的', '与目的有关的部分细读，无关的略读或跳过', '边读边圈画关键信息'])
ch('cn6_u3_purpose', '如果阅读目的是“为家人参观故宫设计一条路线”，应该重点读？', '介绍各宫殿位置和顺序的部分', ['故宫的建造历史', '作者的生平', '所有部分一样仔细'], '跟目的相关的信息要细读。')
ch('cn6_u3_purpose', '想“知道宇宙中其他星球有没有生命”，读《宇宙生命之谜》最合适的方法是？', '抓住每段关键句，弄清科学家的观点和理由', ['只看题目', '只读第一段', '逐字背诵'], '带着问题读，抓关键句。')
ch('cn6_u3_purpose', '《竹节人》中，为了“学会做竹节人”，应重点读？', '制作竹节人的材料和步骤', ['老师没收竹节人的情节', '同学的心理描写', '文章的结尾'], '目的决定重点。')
ch('cn6_u3_purpose', '查找资料、只想找到一个数字时，适合用？', '跳读、浏览', ['逐字精读', '大声朗读全文', '背诵'], '找特定信息用跳读。')

u4 = cu('四', '走进小说的世界')
ctopic('cn6_u4_novel', '小说三要素：情节、环境、人物', u4, '语文要素', '《桥》《穷人》《金色的鱼钩》。小说三要素是人物、情节、环境。环境描写能烘托气氛、推动情节、衬托人物。', ['理清情节：开端—发展—高潮—结局', '找出环境描写并说出作用', '通过语言、动作、神态、心理描写分析人物形象'])
ch('cn6_u4_novel', '小说的三要素是？', '人物、情节、环境', ['时间、地点、人物', '开头、中间、结尾', '记叙、描写、抒情'], '人物、情节、环境。')
ch('cn6_u4_novel', '《桥》中反复描写洪水“像一群受惊的野马”，主要作用是？', '渲染情况危急，烘托老支书的形象', ['介绍地点', '说明洪水的成因', '交代时间'], '环境描写烘托人物。', df=1)
ch('cn6_u4_novel', '《桥》的结尾才揭示老支书和小伙子是父子，这种写法是？', '设置悬念、结尾点题', ['开门见山', '首尾呼应', '借物喻人'], '出人意料又在情理之中。', df=1)
ch('cn6_u4_novel', '《穷人》的作者是？', '列夫·托尔斯泰', ['鲁迅', '老舍', '雨果'], '俄国作家列夫·托尔斯泰。')
ch('cn6_u4_novel', '《穷人》中桑娜抱回西蒙的孩子后忐忑不安的想法，属于什么描写？', '心理描写', ['外貌描写', '环境描写', '动作描写'], '写人物内心想法是心理描写。')
dep('cn6_u4_novel', 'rm_character', '分析小说人物要用人物形象分析的方法。')
dep('cn6_u4_novel', 'rm_env', '小说要关注环境描写的作用。')

u5 = cu('五', '围绕中心意思写')
ctopic('cn6_u5_center', '文章怎样围绕中心意思来写', u5, '语文要素', '《灯光》《盼》：选择能表现中心的材料，从不同方面或几件事来写，重点部分写详细。', ['先找中心意思（常在题目、开头或结尾）', '看文章从哪几个方面/几件事来写', '体会重点部分写得具体详细'])
ch('cn6_u5_center', '《盼》围绕哪个字来写？', '盼', ['雨', '雨衣', '妈妈'], '全文围绕“盼”展开，写盼下雨、盼穿雨衣。')
ch('cn6_u5_center', '《盼》的作者是？', '铁凝', ['王愿坚', '老舍', '冰心'], '铁凝。')
ch('cn6_u5_center', '《灯光》的作者是？', '王愿坚', ['铁凝', '谈歌', '杨旭'], '王愿坚。')
ch('cn6_u5_center', '写“我的妈妈很勤劳”，下面哪个材料最能表现中心？', '妈妈每天天不亮就起床做饭、下班还忙家务', ['妈妈喜欢看电视', '妈妈长得很漂亮', '妈妈的生日是五月'], '选材要紧扣中心。')
dep('cn6_u5_center', 'rm_theme', '围绕中心写，先要会找中心思想。')

u6 = cu('六', '守护家园')
ctopic('cn6_u6_poem', '古诗三首（浪淘沙·江南春·书湖阴先生壁）', u6, '古诗文', '刘禹锡《浪淘沙（其一）》、杜牧《江南春》、王安石《书湖阴先生壁》。', ['会背会默写', '说出作者和朝代'])
q('cn6_u6_poem', '补全诗句：九曲黄河万里沙，浪淘风簸自______。', '天涯', '刘禹锡《浪淘沙（其一）》。', ty='spell')
q('cn6_u6_poem', '补全诗句：千里莺啼绿映红，水村山郭______。', '酒旗风', '杜牧《江南春》。', ty='spell')
q('cn6_u6_poem', '补全诗句：南朝四百八十寺，多少楼台______中。', '烟雨', '杜牧《江南春》。', ty='spell')
q('cn6_u6_poem', '补全诗句：一水护田将绿绕，两山排闼______来。', '送青', '王安石《书湖阴先生壁》，用了拟人。', ty='spell')
ch('cn6_u6_poem', '“一水护田将绿绕，两山排闼送青来”用了什么修辞？', '拟人', ['比喻', '夸张', '设问'], '“护”“送”把山水当人来写。', df=1)
ctopic('cn6_u6_key', '抓住关键语句把握中心意思', u6, '语文要素', '《只有一个地球》等：关键句常出现在开头、结尾、过渡处或反复出现的地方，抓住它们就能把握文章观点。', ['找开头、结尾的总起句、总结句', '找反复出现的句子', '用自己的话概括中心意思'])
ch('cn6_u6_key', '《只有一个地球》要告诉我们的主要观点是？', '我们要精心保护地球，保护地球的生态环境', ['地球很大', '可以移民到别的星球', '地球资源取之不尽'], '文章结尾点明中心。')
ch('cn6_u6_key', '说明文《只有一个地球》中“同茫茫宇宙相比，地球是渺小的”用了？', '作比较', ['举例子', '打比方', '列数字'], '拿地球和宇宙比。', df=1)
ch('cn6_u6_key', '关键语句最常出现在文章的？', '开头、结尾和反复出现的地方', ['只在中间', '只在题目', '对话里'], '关键句的位置。')
ch('cn6_u6_key', '《青山不老》中“青山”不老，实际是赞美？', '老人改造自然的精神永存', ['山上树多', '山的年龄', '风景优美'], '借物喻人，精神不老。', df=1)
dep('cn6_u6_key', 'rm_theme', '抓关键句是把握中心的主要方法。')
dep('cn6_u6_key', 'rm_explain', '本单元有说明文，要认识说明方法。', h=False)

u7 = cu('七', '科学发现')
ctopic('cn6_u7_wyw', '文言文二则（两小儿辩日 等）', u7, '古诗文', '《两小儿辩日》出自《列子·汤问》，两个小孩从不同角度争论太阳远近，孔子不能决。', ['读准停顿', '理解重点字词', '说出故事的道理'])
ch('cn6_u7_wyw', '“孔子东游，见两小儿辩斗”中“辩斗”的意思是？', '争论', ['打架', '比赛', '游戏'], '辩斗：争论。')
ch('cn6_u7_wyw', '一个小孩认为太阳早上近，他的理由是？', '日初出大如车盖，日中如盘盂', ['日初出沧沧凉凉', '日中如探汤', '孔子说的'], '从大小（视觉）来判断。')
ch('cn6_u7_wyw', '另一个小孩认为中午太阳近，理由是？', '日初出沧沧凉凉，及其日中如探汤', ['日初出大如车盖', '日中如盘盂', '中午更亮'], '从冷热（感觉）来判断。')
q('cn6_u7_wyw', '补全句子：孰为汝多______乎？', '知', '“孰为汝多知乎？”谁说你知识丰富呢？', ty='spell', df=1)
ch('cn6_u7_wyw', '这个故事告诉我们？', '学无止境，要实事求是、敢于探索', ['太阳早上更近', '孔子什么都知道', '小孩爱吵架'], '孔子“不能决”也体现实事求是。', df=1)
ctopic('cn6_u7_main', '综合运用多种方法把握主要内容', u7, '语文要素', '《表里的生物》《他们那时候多有趣啊》等：可以用串联段意、抓关键句、借助题目、按起因经过结果等方法概括主要内容。', ['借助题目', '串联各部分大意', '抓住起因、经过、结果'])
ch('cn6_u7_main', '概括叙事文主要内容时，最常用的公式是？', '谁+在什么情况下+做了什么事+结果怎样', ['作者+题目', '时间+地点', '开头一句+结尾一句'], '叙事文概括公式。')
ch('cn6_u7_main', '《表里的生物》中，“我”认为表里有个活的东西，是因为？', '听到表里发出滴答滴答的声音', ['看到表里有虫子', '父亲告诉他的', '书上写的'], '由声音推断有生物，体现好奇心。')
dep('cn6_u7_main', 'rm_summary', '概括主要内容的方法。')

u8 = cu('八', '走近鲁迅')
ctopic('cn6_u8_luxun', '借助资料理解课文：走近鲁迅', u8, '语文要素', '《少年闰土》《好的故事》《我的伯父鲁迅先生》《有的人》。借助背景资料、作者资料理解课文。', ['了解鲁迅：原名周树人，浙江绍兴人，代表作《呐喊》《彷徨》等', '查资料了解写作背景', '用资料帮助理解难懂的句子'])
ch('cn6_u8_luxun', '鲁迅的原名是？', '周树人', ['周作人', '周晔', '周建人'], '鲁迅原名周树人。')
ch('cn6_u8_luxun', '《少年闰土》选自鲁迅的小说？', '《故乡》', ['《祝福》', '《社戏》', '《孔乙己》'], '节选自小说《故乡》，收入《呐喊》。', df=1)
ch('cn6_u8_luxun', '《少年闰土》中闰土给“我”讲了哪四件新鲜事？', '雪地捕鸟、海边拾贝、看瓜刺猹、看跳鱼儿', ['放风筝、钓鱼、爬山、游泳', '读书、写字、画画、唱歌', '种瓜、养鸡、捕鱼、打猎'], '四件新鲜事。')
ch('cn6_u8_luxun', '“有的人活着，他已经死了；有的人死了，他还活着。”作者是？', '臧克家', ['鲁迅', '周晔', '毛泽东'], '臧克家《有的人——纪念鲁迅有感》。')
ch('cn6_u8_luxun', '《我的伯父鲁迅先生》的作者周晔是鲁迅的？', '侄女', ['女儿', '学生', '妻子'], '周晔是鲁迅的侄女。', df=1)

# ------------------------------------------------------------------ 阅读理解答题方法
RV = '阅读理解答题方法'
def rm(id, n, unit, de, steps, dm='阅读方法'):
    topic(id, n, 'chinese', 6, RV, unit, dm, de, steps)
R1 = '基础方法'; R2 = '记叙文·小说'; R3 = '说明文'; R4 = '英语阅读'

rm('rm_word', '理解词语的意思', R1, '答题方法：联系上下文、拆字组词、找近反义词、联系生活实际。答题时先说词语本义，再说在文中的含义。',
   ['本义：这个词本来是什么意思', '文中义：放回句子，结合上下文说在这里指什么', '必要时说出表达的情感'])
ch('rm_word', '“他的话像一盆冷水，把我的热情浇灭了。”“冷水”在句中指？', '让人失望、扫兴的话', ['真正的冷水', '洗脸用的水', '天气很冷'], '联系上下文，理解比喻义。')
ch('rm_word', '理解词语时，“联系上下文”是指？', '看这个词前后的句子来推断意思', ['只查字典', '只看题目', '跳过不读'], '方法定义。')
ch('rm_word', '“小明的作文写得‘真好’，老师把它当反面例子念给全班听。”这里的“真好”实际是？', '反语，表示写得不好', ['真的写得很好', '表扬', '无意义'], '引号可表示反语、讽刺。', df=1)

rm('rm_sentence', '理解句子的含义', R1, '含义深刻的句子：先读懂字面意思，再联系上下文、中心说出深层含义（表达了什么情感或道理）。',
   ['字面意思：句子表面说了什么', '深层含义：结合上下文和中心，实际表达什么', '情感/道理：表达了作者怎样的感情'])
ch('rm_sentence', '答“这句话有什么含义”时，比较完整的回答应包括？', '字面意思 + 深层含义 + 表达的情感', ['只写字面意思', '只写“写得好”', '抄原句'], '含义题三步法。')
ch('rm_sentence', '“青山是不会老的。”在《青山不老》中更深的含义是？', '老人的精神会像青山一样永存', ['山不会变老', '山上没有老人', '青山颜色不变'], '由物到人。', df=1)
dep('rm_sentence', 'rm_word', '先会理解词语，再理解句子。')

rm('rm_rhetoric', '修辞手法及作用', R1, '常见修辞：比喻（像、好像）、拟人（把物当人写）、排比（三个以上结构相同）、夸张、设问（自问自答）、反问（加强语气）。答题格式：用了××修辞，把××比作××/写出了××的××特点，表达了××情感。',
   ['判断修辞手法', '说出写了什么对象的什么特点', '说出表达效果或情感'])
ch('rm_rhetoric', '“春风像妈妈的手，抚摸着我的脸。”用了？', '比喻', ['拟人', '排比', '反问'], '把春风比作妈妈的手。')
ch('rm_rhetoric', '“小草从地里探出头来，好奇地张望。”用了？', '拟人', ['比喻', '夸张', '设问'], '小草“探头”“张望”是人的动作。')
ch('rm_rhetoric', '“难道我们不应该保护地球吗？”用了？', '反问', ['设问', '比喻', '排比'], '用疑问形式表达肯定意思，加强语气。')
ch('rm_rhetoric', '“白发三千丈”用了？', '夸张', ['比喻', '拟人', '对偶'], '故意夸大。')
ch('rm_rhetoric', '排比句的作用一般是？', '增强气势，加强语气，使表达更有力', ['使事物形象生动', '引起读者思考', '说明数据准确'], '排比的作用。', df=1)

rm('rm_para', '段落（句子）在文中的作用', R1, '开头：开篇点题、总领全文、设置悬念、引出下文、奠定感情基调。中间：承上启下（过渡）。结尾：总结全文、点明中心、首尾呼应、深化主题、引人深思。',
   ['先看位置：开头 / 中间 / 结尾', '内容上：写了什么，与中心的关系', '结构上：总领 / 过渡 / 总结 / 呼应'])
ch('rm_para', '文章开头一段的作用通常不包括？', '承上启下', ['总领全文', '引出下文', '设置悬念'], '承上启下是中间过渡段的作用。')
ch('rm_para', '结尾写“我又想起了那盏灯光”，开头也写到灯光，这是？', '首尾呼应', ['开门见山', '设置悬念', '承上启下'], '开头结尾内容照应。')
ch('rm_para', '“小明不仅学习好，而且乐于助人。”放在两部分之间，作用是？', '承上启下', ['总领全文', '总结全文', '点明中心'], '前半句承上，后半句启下。', df=1)

rm('rm_summary', '概括主要内容', R1, '方法：①六要素法（时间、地点、人物、起因、经过、结果）②段意合并法 ③抓题目扩展法 ④抓中心句法。', ['写人记事：谁+做了什么+结果怎样', '写景状物：写了什么+有什么特点', '语句简洁，不抄原文、不写细节'])
ch('rm_summary', '下面哪个是概括主要内容的合理回答？', '文章写了老支书在洪水中组织村民过桥，自己和儿子却被洪水吞没的故事。', ['洪水很大。', '老支书很伟大，我很感动。', '黎明的时候，雨突然大了。'], '抓人物+事件+结果。')
ch('rm_summary', '概括主要内容时应该避免？', '写很多细节和描写的句子', ['写清人物', '写清事件', '语句简洁'], '概括要简洁。')

rm('rm_theme', '把握中心思想和情感', R1, '中心思想格式：本文通过写××（主要内容），表达了作者××的感情 / 赞美了××的品质 / 揭示了××的道理。中心句常在开头、结尾或反复出现。',
   ['先概括主要内容', '再写“表达了/赞美了/揭示了……”', '可找中心句、文题、议论抒情句帮助'])
ch('rm_theme', '中心思想的规范答题格式是？', '本文通过写……，表达了/赞美了/揭示了……', ['我喜欢这篇文章', '本文写了很多事', '作者是……'], '内容+情感/道理。')
ch('rm_theme', '下列最可能是文章中心句的是？', '结尾的“原来，最美的风景就在我们身边。”', ['“那天下着小雨。”', '“我穿上了外套。”', '“他说：‘走吧。’”'], '议论抒情、总结性的句子常是中心句。', df=1)
dep('rm_theme', 'rm_summary', '先概括内容，才能归纳中心。')

rm('rm_title', '题目的含义和作用', R2, '题目作用：交代主要内容/对象、作为线索、点明中心、设置悬念、一语双关。含义：表层（字面）+ 深层（象征/比喻义）。',
   ['说出表面意思', '说出深层含义（象征什么）', '说出作用：线索、点明中心、吸引读者等'])
ch('rm_title', '《桥》这个题目除了指那座窄窄的木桥，还象征？', '老支书用生命为村民架起的生命桥、党群连心桥', ['桥很危险', '桥是木头做的', '洪水的名字'], '题目一语双关。', df=1)
ch('rm_title', '以“一件难忘的事”为题，最主要的作用是？', '交代文章的主要内容', ['设置悬念', '象征', '反语'], '题目点明写什么。')
dep('rm_title', 'rm_sentence', '理解题目深层含义需要理解句子含义。', h=False)

rm('rm_character', '人物形象分析', R2, '通过人物的外貌、语言、动作、神态、心理描写和他做的事来分析。答题格式：××是一个××（品质）的人，从××（具体事例/描写）可以看出。',
   ['找出描写人物的句子', '判断描写方法', '概括品质+结合文中事例说明'])
ch('rm_character', '“老支书像一座山，站在木桥前。”这句写出了老支书？', '沉着冷静、在危急时刻稳如泰山', ['长得很高大', '年纪很大', '很胖'], '比喻写出人物镇定。')
ch('rm_character', '分析人物形象的答题格式是？', '品质 + 文中具体事例或描写', ['只写“他很好”', '抄原文一段', '写自己的感受'], '要有依据。')
ch('rm_character', '“他攥紧拳头，咬着嘴唇，一声不吭。”主要是什么描写？', '动作和神态描写', ['语言描写', '环境描写', '心理描写'], '攥、咬是动作，一声不吭是神态。')
ch('rm_character', '桑娜明知生活艰难，仍然抱回邻居的孩子，表现了她？', '善良、富有同情心', ['胆小', '懒惰', '自私'], '从做的事看品质。', df=1)
dep('rm_character', 'rm_summary', '分析人物要先读懂人物做了什么事。')

rm('rm_env', '环境描写的作用', R2, '自然环境描写作用：交代时间地点、渲染气氛、烘托人物心情、推动情节发展、暗示人物命运。答题格式：通过描写××，渲染了××气氛，烘托了人物××的心情/形象。',
   ['找出环境描写句', '说出渲染了什么气氛', '联系人物或情节说明作用'])
ch('rm_env', '“窗外寒风呼啸，屋里又黑又冷。”放在开头，主要作用是？', '交代环境，渲染寒冷凄凉的气氛', ['说明天气预报', '介绍人物外貌', '表达作者喜悦'], '环境描写渲染气氛。')
ch('rm_env', '小说中暴雨越来越大的描写，对情节的作用常常是？', '推动情节发展，使情况越来越危急', ['让文章变长', '与情节无关', '介绍人物'], '环境推动情节。', df=1)

rm('rm_scene', '写作手法：点面结合、对比、伏笔', R2, '点面结合（整体+个体）、对比（突出特点）、衬托、伏笔照应（前文埋下、后文呼应）、借物喻人、首尾呼应、详略得当。',
   ['先判断手法', '说出写了什么', '说出好处'])
ch('rm_scene', '前文写“他总是摸摸口袋里的那个小盒子”，结尾揭晓是送给妈妈的礼物，这是？', '伏笔照应', ['点面结合', '对比', '排比'], '前文埋伏笔，后文照应。', df=1)
ch('rm_scene', '把老人的勤劳和年轻人的懒惰放在一起写，用的是？', '对比', ['伏笔', '拟人', '点面结合'], '对比突出特点。')
ch('rm_scene', '“借物喻人”的意思是？', '借写某种事物来比喻、赞美某种人', ['只写物不写人', '把人比作物的比喻句', '写人物外貌'], '如借青山写老人。')

rm('rm_explain', '说明文：说明方法及作用', R3, '常见说明方法：举例子、列数字、打比方、作比较、分类别、下定义、列图表、摹状貌。答题格式：用了××说明方法，具体/准确/生动地说明了××的××特点。',
   ['判断说明方法', '找到说明的对象', '写出作用：举例子—具体；列数字—准确；打比方—生动形象；作比较—突出特点'])
ch('rm_explain', '“地球的半径约6400千米。”用了？', '列数字', ['举例子', '打比方', '作比较'], '用数据说明，准确。')
ch('rm_explain', '“地球像一叶扁舟，在宇宙中航行。”作为说明方法是？', '打比方', ['作比较', '下定义', '分类别'], '说明文中的比喻叫打比方，作用是生动形象。')
ch('rm_explain', '列数字的作用是？', '准确地说明事物的特点', ['生动形象', '增强气势', '设置悬念'], '数字使说明准确。')
ch('rm_explain', '说明文的语言特点是？', '准确、严密', ['夸张、生动', '含蓄', '口语化'], '如“约”“大概”等词体现准确。', df=1)

rm('rm_feel', '联系生活谈感受（开放题）', R2, '答题格式：观点 + 理由（结合文章）+ 联系生活实际 + 今后打算。不能只写一句话，也不能完全脱离文章。',
   ['先亮明观点', '结合文中内容说理由', '举一个自己生活中的例子', '写今后怎么做'])
ch('rm_feel', '“读了这篇文章你有什么启发？”最完整的回答结构是？', '观点 + 结合文章 + 联系生活 + 今后打算', ['只写“很感动”', '抄一段原文', '复述故事'], '开放题四步。')
ch('rm_feel', '下面哪个回答最好？', '我明白了要珍惜粮食。文中农民辛苦劳作一年才有收成，我平时有时剩饭，以后要做到“光盘”。', ['很好。', '我也要珍惜。', '农民很辛苦，因为文章写了农民。'], '有观点、有文章依据、有生活联系、有打算。')

rm('rm_english', '英语阅读理解技巧', R4, '先读题目再读文章；细节题回原文定位关键词（人名、数字、时间）；判断题注意 always / never 等绝对词；猜词靠上下文；主旨题看首尾段。',
   ['先看问题，划出关键词', '回原文找出处，对照选项', '注意时态：did / was 问过去，用过去式答', '不认识的词根据上下文猜'])
ch('rm_english', '做英语阅读时，比较好的第一步是？', '先读问题，带着问题读文章', ['逐词翻译全文', '直接猜答案', '只看最后一句'], '带着问题读更高效。')
ch('rm_english', 'Li Shan went to Qingdao by train last summer. She ate seafood there.  Q: How did Li Shan go to Qingdao?', 'By train.', ['By plane.', 'By bus.', 'On foot.'], '回原文定位 by train。')
ch('rm_english', 'Tom took part in the high jump. He fell down, but he didn\'t give up.  Q: Did Tom give up?', 'No, he didn\'t.', ['Yes, he did.', 'Yes, he was.', 'No, he wasn\'t.'], 'didn\'t give up = 没有放弃；Did 问句用 did 回答。')
ch('rm_english', 'Amy: Would you like a glass of juice?  Ben: No, thanks. A cup of tea, please.  Q: What does Ben want?', 'A cup of tea.', ['A glass of juice.', 'A bottle of water.', 'A bowl of porridge.'], '注意转折：No, thanks 之后才是他要的。', df=1)
dep('rm_english', 'slb6_irregular', '读懂过去发生的事要认识过去式。', h=False)

out = os.path.join(HERE, '..', 'Sources', 'Resources', 'extra.json')
os.makedirs(os.path.dirname(out), exist_ok=True)
json.dump(dict(topics=T, deps=D, questions=Q), open(out, 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
ids = {t['id'] for t in T}
bad = [d for d in D if d['t'] not in ids or d['p'] not in ids]
print(len(T), len(D), len(Q), 'bad deps:', bad)
