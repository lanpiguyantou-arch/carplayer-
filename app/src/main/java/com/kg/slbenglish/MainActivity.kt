package com.kg.slbenglish

import android.app.Activity
import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.text.InputType
import android.view.Gravity
import android.view.View
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.*
import org.json.JSONArray
import java.net.URLEncoder
import java.util.Locale

data class Word(val en: String, val zh: String, val unit: Int)
data class Line(val en: String, val zh: String) {
    val who: String get() = Regex("^([A-Z][A-Za-z ]{1,15}): ").find(en)?.groupValues?.get(1) ?: ""
    val say: String get() = if (who.isEmpty()) en else en.substring(who.length + 2)
}
data class Lesson(val n: Int, val title: String, val words: List<Word>, val sentences: List<Line>, val textTitle: String, val text: List<Line>)

class Speaker(private val ctx: Context, private val prefs: Prefs) {
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var player: MediaPlayer? = null
    private val main = Handler(Looper.getMainLooper())
    var onDone: (() -> Unit)? = null

    init {
        tts = TextToSpeech(ctx) { st ->
            if (st == TextToSpeech.SUCCESS) {
                val r = tts?.setLanguage(Locale.US) ?: TextToSpeech.LANG_NOT_SUPPORTED
                ttsReady = r != TextToSpeech.LANG_MISSING_DATA && r != TextToSpeech.LANG_NOT_SUPPORTED
                tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                    override fun onStart(id: String?) {}
                    override fun onDone(id: String?) { main.post { onDone?.invoke() } }
                    @Deprecated("") override fun onError(id: String?) {}
                })
            }
        }
    }

    fun speak(text: String, slow: Boolean = false) {
        stop()
        val rate = prefs.speed * (if (slow) 0.6f else 1f)
        if (prefs.engine == 0) playOnline(text, rate) else playTts(text, rate)
    }

    private fun playTts(text: String, rate: Float) {
        if (!ttsReady) {
            Toast.makeText(ctx, "本机没有英文语音引擎，已改用在线真人发音", Toast.LENGTH_SHORT).show()
            playOnline(text, rate, fallback = false); return
        }
        tts?.setSpeechRate(rate)
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "u" + System.nanoTime())
    }

    private fun youdao(t: String) = "https://dict.youdao.com/dictvoice?audio=" + URLEncoder.encode(t, "UTF-8").replace("+", "%20") + "&type=" + prefs.accent
    private fun baidu(t: String) = "https://fanyi.baidu.com/gettts?lan=" + (if (prefs.accent == 1) "uk" else "en") + "&text=" + URLEncoder.encode(t, "UTF-8").replace("+", "%20") + "&spd=5&source=web"

    private fun playOnline(text: String, rate: Float, fallback: Boolean = true) {
        // 单词用有道真人发音；句子有道不支持，用百度整句朗读；失败依次换源
        val urls = if (text.trim().contains(' ')) listOf(baidu(text), youdao(text)) else listOf(youdao(text), baidu(text))
        playUrls(text, urls, 0, rate, fallback)
    }

    private fun playUrls(text: String, urls: List<String>, idx: Int, rate: Float, fallback: Boolean) {
        if (idx >= urls.size) {
            if (fallback && ttsReady) playTts(text, rate)
            else Toast.makeText(ctx, "在线发音失败，请检查网络", Toast.LENGTH_SHORT).show()
            return
        }
        val url = urls[idx]
        try {
            val mp = MediaPlayer()
            player = mp
            mp.setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
            mp.setDataSource(url)
            mp.setOnPreparedListener {
                try {
                    if (Build.VERSION.SDK_INT >= 23) it.playbackParams = it.playbackParams.setSpeed(rate.coerceIn(0.3f, 2f))
                } catch (_: Exception) {}
                it.start()
            }
            mp.setOnCompletionListener { onDone?.invoke() }
            mp.setOnErrorListener { _, _, _ ->
                main.post { if (player === mp) playUrls(text, urls, idx + 1, rate, fallback) }
                true
            }
            mp.prepareAsync()
        } catch (e: Exception) {
            playUrls(text, urls, idx + 1, rate, fallback)
        }
    }

    fun stop() {
        try { player?.release() } catch (_: Exception) {}
        player = null
        tts?.stop()
    }

    fun shutdown() { stop(); tts?.shutdown() }
}

class Prefs(ctx: Context) {
    private val sp = ctx.getSharedPreferences("slb", Context.MODE_PRIVATE)
    var speed: Float
        get() = sp.getFloat("speed", 0.9f)
        set(v) { sp.edit().putFloat("speed", v).apply() }
    var engine: Int  // 0 online human voice, 1 system TTS
        get() = sp.getInt("engine", 0)
        set(v) { sp.edit().putInt("engine", v).apply() }
    var accent: Int  // 1 UK, 2 US
        get() = sp.getInt("accent", 2)
        set(v) { sp.edit().putInt("accent", v).apply() }
    var wrong: Set<String>
        get() = sp.getStringSet("wrong", emptySet()) ?: emptySet()
        set(v) { sp.edit().putStringSet("wrong", HashSet(v)).apply() }
    var showZh: Boolean
        get() = sp.getBoolean("showZh", true)
        set(v) { sp.edit().putBoolean("showZh", v).apply() }
    var myTexts: String
        get() = sp.getString("myTexts", "[]") ?: "[]"
        set(v) { sp.edit().putString("myTexts", v).apply() }
    fun learned(u: Int) = sp.getInt("learned$u", 0)
    fun setLearned(u: Int, v: Int) { sp.edit().putInt("learned$u", maxOf(v, learned(u))).apply() }
}

class MainActivity : Activity() {
    private lateinit var prefs: Prefs
    private lateinit var speaker: Speaker
    private lateinit var units: List<Lesson>
    private val back = ArrayList<() -> Unit>()
    private val blue = Color.parseColor("#1E88E5")
    private val green = Color.parseColor("#43A047")
    private val red = Color.parseColor("#E53935")
    private val bg = Color.parseColor("#F4F6FA")

    override fun onCreate(b: Bundle?) {
        super.onCreate(b)
        prefs = Prefs(this)
        speaker = Speaker(this, prefs)
        units = loadUnits()
        showHome()
    }

    override fun onDestroy() { speaker.shutdown(); super.onDestroy() }

    @Deprecated("")
    override fun onBackPressed() {
        speaker.stop(); speaker.onDone = null
        if (back.size > 1) { back.removeAt(back.size - 1); val prev = back.removeAt(back.size - 1); prev() }
        else super.onBackPressed()
    }

    private fun loadUnits(): List<Lesson> {
        val txt = assets.open("slb6s.json").bufferedReader(Charsets.UTF_8).readText()
        val arr = JSONArray(txt)
        return (0 until arr.length()).map { i ->
            val o = arr.getJSONObject(i)
            val n = o.getInt("n")
            val w = o.getJSONArray("w")
            fun lines(k: String): List<Line> { val a = o.getJSONArray(k); return (0 until a.length()).map { Line(a.getJSONObject(it).getString("e"), a.getJSONObject(it).getString("z")) } }
            Lesson(n, o.getString("t"),
                (0 until w.length()).map { Word(w.getJSONObject(it).getString("e"), w.getJSONObject(it).getString("z"), n) },
                lines("s"), o.getString("xt"), lines("x"))
        }
    }

    // ---------- UI helpers
    private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()
    private fun round(color: Int, r: Int = 14, stroke: Int? = null) = GradientDrawable().apply {
        setColor(color); cornerRadius = dp(r).toFloat(); if (stroke != null) setStroke(dp(1), stroke)
    }
    private fun text(s: String, size: Float = 16f, color: Int = Color.parseColor("#222222"), bold: Boolean = false) =
        TextView(this).apply { text = s; textSize = size; setTextColor(color); if (bold) setTypeface(typeface, Typeface.BOLD) }
    private fun button(s: String, color: Int = blue, onClick: () -> Unit) = Button(this).apply {
        text = s; isAllCaps = false; setTextColor(Color.WHITE); textSize = 15f
        background = round(color, 10); setPadding(dp(12), dp(6), dp(12), dp(6)); minHeight = dp(40); minimumHeight = dp(40)
        setOnClickListener { onClick() }
    }
    private fun lp(w: Int = LinearLayout.LayoutParams.MATCH_PARENT, top: Int = 8) =
        LinearLayout.LayoutParams(w, LinearLayout.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(top) }
    private fun card() = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL; background = round(Color.WHITE); setPadding(dp(14), dp(12), dp(14), dp(12))
    }

    private fun page(title: String, self: () -> Unit, build: (LinearLayout) -> Unit) {
        back.add(self)
        speaker.onDone = null
        val root = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setBackgroundColor(bg) }
        val bar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL
            setBackgroundColor(blue); setPadding(dp(12), dp(28), dp(12), dp(12))
        }
        if (back.size > 1) bar.addView(text("‹ 返回", 17f, Color.WHITE).apply {
            setPadding(0, 0, dp(16), 0); setOnClickListener { onBackPressed() } })
        bar.addView(text(title, 19f, Color.WHITE, true).apply { maxLines = 1 })
        root.addView(bar)
        root.addView(speedBar())
        val scroll = ScrollView(this)
        val body = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(dp(14), dp(8), dp(14), dp(40)) }
        scroll.addView(body)
        root.addView(scroll, LinearLayout.LayoutParams(-1, 0, 1f))
        build(body)
        setContentView(root)
    }

    private fun speedBar(): View {
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL
            setBackgroundColor(Color.WHITE); setPadding(dp(12), dp(4), dp(12), dp(4))
        }
        val label = text(speedLabel(), 14f)
        val seek = SeekBar(this).apply {
            max = 12; progress = ((prefs.speed - 0.3f) / 0.1f).toInt().coerceIn(0, 12)
            setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(s: SeekBar?, p: Int, u: Boolean) { prefs.speed = 0.3f + p * 0.1f; label.text = speedLabel() }
                override fun onStartTrackingTouch(s: SeekBar?) {}
                override fun onStopTrackingTouch(s: SeekBar?) {}
            })
        }
        row.addView(label, LinearLayout.LayoutParams(dp(92), -2))
        row.addView(seek, LinearLayout.LayoutParams(0, -2, 1f))
        return row
    }
    private fun speedLabel() = "语速 " + String.format(Locale.US, "%.1f", prefs.speed) + "x"

    // ---------- Home
    private fun showHome(): Unit = page("陕旅版英语 六年级上册", ::showHome) { body ->
        body.addView(text("新版（2026）· 点单元开始学习。顶部滑条随时调语速。", 14f, Color.GRAY), lp())
        for (u in units) {
            val c = card()
            c.addView(text("Unit ${u.n}  ${u.title}", 17f, bold = true))
            c.addView(text("${u.words.size} 个单词短语 · ${u.sentences.size} 个重点句 · 已掌握 ${prefs.learned(u.n)}", 13f, Color.GRAY), lp(top = 4))
            c.setOnClickListener { showUnit(u) }
            body.addView(c, lp(top = 10))
        }
        val mt = card()
        mt.addView(text("我的课文（自己添加）", 17f, Color.parseColor("#00897B"), true))
        mt.addView(text("粘贴课本里的英文，自动分句、点读、翻译", 13f, Color.GRAY), lp(top = 4))
        mt.setOnClickListener { showMyTexts() }
        body.addView(mt, lp(top = 14))
        val w = card()
        w.addView(text("错词本（${prefs.wrong.size}）", 17f, red, true))
        w.addView(text("听写和卡片里记错的词会自动收进来", 13f, Color.GRAY), lp(top = 4))
        w.setOnClickListener { showWrong() }
        body.addView(w, lp(top = 14))
        val s = card()
        s.addView(text("发音设置", 17f, bold = true))
        s.addView(text(settingLabel(), 13f, Color.GRAY), lp(top = 4))
        s.setOnClickListener { showSettings() }
        body.addView(s, lp(top = 10))
    }

    private fun settingLabel() = (if (prefs.engine == 0) "在线真人发音" else "手机系统语音") + " · " + (if (prefs.accent == 2) "美音" else "英音")

    private fun showSettings(): Unit = page("发音设置", ::showSettings) { body ->
        body.addView(text("发音来源", 16f, bold = true), lp())
        val g = RadioGroup(this)
        val r0 = RadioButton(this).apply { text = "在线真人发音（需联网，最自然）"; id = 100 }
        val r1 = RadioButton(this).apply { text = "手机系统语音（可离线，需手机支持英文）"; id = 101 }
        g.addView(r0); g.addView(r1); g.check(if (prefs.engine == 0) 100 else 101)
        g.setOnCheckedChangeListener { _, id -> prefs.engine = if (id == 100) 0 else 1 }
        body.addView(g, lp())
        body.addView(text("口音（在线发音）", 16f, bold = true), lp(top = 16))
        val a = RadioGroup(this)
        val a2 = RadioButton(this).apply { text = "美音"; id = 202 }
        val a1 = RadioButton(this).apply { text = "英音"; id = 201 }
        a.addView(a2); a.addView(a1); a.check(if (prefs.accent == 2) 202 else 201)
        a.setOnCheckedChangeListener { _, id -> prefs.accent = if (id == 202) 2 else 1 }
        body.addView(a, lp())
        body.addView(button("试听：They were here just now.") { speaker.speak("They were here just now.") }, lp(top = 16))
        body.addView(button("慢速试听", green) { speaker.speak("They were here just now.", slow = true) }, lp())
    }

    // ---------- Unit
    private fun showUnit(u: Lesson): Unit {
        val self = { showUnit(u) }
        page("Unit ${u.n}", self) { body ->
            body.addView(text(u.title, 20f, bold = true), lp())
            body.addView(button("📖 课文点读（${u.textTitle}，带翻译）", Color.parseColor("#00897B")) { showPointRead("Unit ${u.n} 课文", u.textTitle, u.text) }, lp(top = 14))
            body.addView(button("① 单词表（点读）") { showWords(u.words, "Unit ${u.n} 单词") }, lp())
            body.addView(button("② 重点句（正常 / 慢速 / 循环跟读）") { showSentences(u) }, lp())
            body.addView(button("③ 记忆卡片（看中文想英文）", green) { showCards(u.words.shuffled(), "Unit ${u.n} 卡片", u.n) }, lp())
            body.addView(button("④ 听音拼写（听写）", Color.parseColor("#FB8C00")) { showDictation(u.words.shuffled(), "Unit ${u.n} 听写", u.n) }, lp())
            body.addView(button("⑤ 连续播放全部单词", Color.parseColor("#8E24AA")) { playAll(u.words.map { it.en }) }, lp())
        }
    }

    private fun playAll(list: List<String>) {
        var i = 0
        fun next() {
            if (i >= list.size) { speaker.onDone = null; return }
            val t = list[i++]
            Handler(Looper.getMainLooper()).postDelayed({ speaker.speak(t) }, 700)
        }
        speaker.onDone = { next() }
        Toast.makeText(this, "开始连续播放，按返回停止", Toast.LENGTH_SHORT).show()
        next()
    }

    private fun showWords(words: List<Word>, title: String): Unit {
        val self = { showWords(words, title) }
        page(title, self) { body ->
            body.addView(text("点单词听发音，点“慢”听慢速。", 13f, Color.GRAY), lp())
            for (w in words) {
                val row = LinearLayout(this).apply {
                    orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL
                    background = round(Color.WHITE, 10); setPadding(dp(12), dp(10), dp(8), dp(10))
                }
                val col = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
                col.addView(text(w.en, 18f, blue, true))
                col.addView(text(w.zh, 14f, Color.DKGRAY))
                row.addView(col, LinearLayout.LayoutParams(0, -2, 1f))
                row.addView(text("🔊", 22f).apply { setPadding(dp(10), 0, dp(10), 0); setOnClickListener { speaker.speak(w.en) } })
                row.addView(text("慢", 16f, green, true).apply { setPadding(dp(10), 0, dp(6), 0); setOnClickListener { speaker.speak(w.en, true) } })
                row.setOnClickListener { speaker.speak(w.en) }
                body.addView(row, lp(top = 6))
            }
        }
    }

    private fun showSentences(u: Lesson): Unit {
        val self = { showSentences(u) }
        page("Unit ${u.n} 重点句", self) { body ->
            body.addView(text("“循环”会一遍遍慢速重复，方便跟读；再点一次停止。", 13f, Color.GRAY), lp())
            for (line in u.sentences) {
                val s = line.en
                val c = card()
                c.addView(text(s, 18f, bold = true))
                if (prefs.showZh && line.zh.isNotEmpty()) c.addView(text(line.zh, 14f, Color.DKGRAY), lp(top = 4))
                val btns = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
                btns.addView(button("▶ 正常") { speaker.onDone = null; speaker.speak(s) }, LinearLayout.LayoutParams(0, -2, 1f))
                btns.addView(button("🐢 慢速", green) { speaker.onDone = null; speaker.speak(s, true) },
                    LinearLayout.LayoutParams(0, -2, 1f).apply { leftMargin = dp(8) })
                btns.addView(button("🔁 循环", Color.parseColor("#8E24AA")) {
                    if (speaker.onDone != null) { speaker.onDone = null; speaker.stop() }
                    else {
                        speaker.onDone = { Handler(Looper.getMainLooper()).postDelayed({ if (speaker.onDone != null) speaker.speak(s, true) }, 2500) }
                        speaker.speak(s, true)
                    }
                }, LinearLayout.LayoutParams(0, -2, 1f).apply { leftMargin = dp(8) })
                c.addView(btns, lp())
                body.addView(c, lp(top = 10))
            }
        }
    }

    private fun showCards(words: List<Word>, title: String, unitN: Int): Unit {
        if (words.isEmpty()) { Toast.makeText(this, "没有单词", Toast.LENGTH_SHORT).show(); return }
        var i = 0; var known = 0
        lateinit var render: () -> Unit
        val self = { showCards(words, title, unitN) }
        page(title, self) { body ->
            val holder = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
            body.addView(holder, lp())
            render = {
                holder.removeAllViews()
                if (i >= words.size) {
                    holder.addView(text("完成！记住 $known / ${words.size}", 22f, green, true), lp(top = 30))
                    if (unitN > 0) prefs.setLearned(unitN, known)
                    holder.addView(button("再来一遍") { i = 0; known = 0; render() }, lp(top = 20))
                } else {
                    val w = words[i]
                    holder.addView(text("${i + 1} / ${words.size}", 14f, Color.GRAY), lp())
                    val c = card().apply { gravity = Gravity.CENTER; minimumHeight = dp(200) }
                    c.addView(text(w.zh, 26f, bold = true).apply { gravity = Gravity.CENTER }, lp())
                    val ans = text(w.en, 28f, blue, true).apply { gravity = Gravity.CENTER; visibility = View.INVISIBLE }
                    c.addView(ans, lp(top = 20))
                    holder.addView(c, lp(top = 10))
                    val show = button("翻开看答案") { ans.visibility = View.VISIBLE; speaker.speak(w.en) }
                    holder.addView(show, lp(top = 14))
                    val row = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
                    row.addView(button("✓ 记住了", green) { known++; prefs.wrong = prefs.wrong - w.en; i++; render() }, LinearLayout.LayoutParams(0, -2, 1f))
                    row.addView(button("✗ 没记住", red) { prefs.wrong = prefs.wrong + w.en; i++; render() },
                        LinearLayout.LayoutParams(0, -2, 1f).apply { leftMargin = dp(10) })
                    holder.addView(row, lp(top = 10))
                }
            }
            render()
        }
    }

    private fun norm(s: String) = s.lowercase(Locale.US).replace("’", "'").replace(Regex("[\\s.!?]"), "")

    private fun showDictation(words: List<Word>, title: String, unitN: Int): Unit {
        if (words.isEmpty()) { Toast.makeText(this, "没有单词", Toast.LENGTH_SHORT).show(); return }
        var i = 0; var right = 0
        lateinit var render: () -> Unit
        val self = { showDictation(words, title, unitN) }
        page(title, self) { body ->
            val holder = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
            body.addView(holder, lp())
            render = {
                holder.removeAllViews()
                if (i >= words.size) {
                    holder.addView(text("听写完成！正确 $right / ${words.size}", 22f, green, true), lp(top = 30))
                    if (unitN > 0) prefs.setLearned(unitN, right)
                    holder.addView(button("再听写一遍") { i = 0; right = 0; render() }, lp(top = 20))
                } else {
                    val w = words[i]
                    var checked = false
                    holder.addView(text("${i + 1} / ${words.size}    提示：${w.zh}", 16f, Color.DKGRAY), lp())
                    val row = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
                    row.addView(button("🔊 再听一遍") { speaker.speak(w.en) }, LinearLayout.LayoutParams(0, -2, 1f))
                    row.addView(button("🐢 慢速", green) { speaker.speak(w.en, true) }, LinearLayout.LayoutParams(0, -2, 1f).apply { leftMargin = dp(10) })
                    holder.addView(row, lp(top = 10))
                    val input = EditText(this).apply {
                        hint = "在这里拼写英文"; textSize = 20f; isSingleLine = true
                        inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS or InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD
                        imeOptions = EditorInfo.IME_ACTION_DONE
                        background = round(Color.WHITE, 10, Color.LTGRAY); setPadding(dp(12), dp(10), dp(12), dp(10))
                    }
                    holder.addView(input, lp(top = 14))
                    val result = text("", 18f, bold = true)
                    holder.addView(result, lp(top = 10))
                    lateinit var action: Button
                    val check = {
                        if (!checked) {
                            checked = true
                            if (norm(input.text.toString()) == norm(w.en)) {
                                right++; result.setTextColor(green); result.text = "✓ 正确：${w.en}"
                                prefs.wrong = prefs.wrong - w.en
                            } else {
                                result.setTextColor(red); result.text = "✗ 正确拼写：${w.en}\n你写的：${input.text}"
                                prefs.wrong = prefs.wrong + w.en
                            }
                            action.text = if (i + 1 >= words.size) "看结果" else "下一个"
                        } else { i++; render() }
                    }
                    action = button("提交") { check() }
                    input.setOnEditorActionListener { _, _, _ -> check(); true }
                    holder.addView(action, lp(top = 10))
                    input.requestFocus()
                    (getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager).showSoftInput(input, 0)
                    Handler(Looper.getMainLooper()).postDelayed({ speaker.speak(w.en) }, 400)
                }
            }
            render()
        }
    }

    // ---------- 课文点读
    private fun showPointRead(title: String, sub: String, lines: List<Line>): Unit {
        val self = { showPointRead(title, sub, lines) }
        page(title, self) { body ->
            body.addView(text(sub, 20f, bold = true), lp())
            body.addView(text("点一句读一句，长按这句慢速读。", 13f, Color.GRAY), lp(top = 4))
            val ctl = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
            val cards = ArrayList<LinearLayout>()
            val zhViews = ArrayList<TextView>()
            var cur = -1
            fun mark(i: Int) {
                cards.forEachIndexed { k, c -> c.background = if (k == i) round(Color.parseColor("#E3F2FD"), 14, blue) else round(Color.WHITE) }
                cur = i
                if (i >= 0) { val sv = body.parent as? ScrollView; sv?.post { sv.smoothScrollTo(0, maxOf(0, cards[i].top - dp(80))) } }
            }
            fun readFrom(i: Int, slow: Boolean) {
                if (i >= lines.size) { speaker.onDone = null; mark(-1); return }
                mark(i)
                speaker.onDone = { Handler(Looper.getMainLooper()).postDelayed({ if (speaker.onDone != null) readFrom(i + 1, slow) }, 600) }
                speaker.speak(lines[i].say, slow)
            }
            ctl.addView(button("▶ 全文连读") { readFrom(0, false) }, LinearLayout.LayoutParams(0, -2, 1f))
            ctl.addView(button("🐢 慢速连读", green) { readFrom(0, true) }, LinearLayout.LayoutParams(0, -2, 1f).apply { leftMargin = dp(8) })
            ctl.addView(button("⏹ 停", red) { speaker.onDone = null; speaker.stop(); mark(-1) }, LinearLayout.LayoutParams(0, -2, 0.6f).apply { leftMargin = dp(8) })
            body.addView(ctl, lp(top = 10))
            val zhBtn = button(if (prefs.showZh) "隐藏中文翻译" else "显示中文翻译", Color.GRAY) {}
            zhBtn.setOnClickListener {
                prefs.showZh = !prefs.showZh
                zhViews.forEach { it.visibility = if (prefs.showZh) View.VISIBLE else View.GONE }
                zhBtn.text = if (prefs.showZh) "隐藏中文翻译" else "显示中文翻译"
            }
            body.addView(zhBtn, lp())
            lines.forEachIndexed { i, l ->
                val c = card()
                if (l.who.isNotEmpty()) c.addView(text(l.who, 13f, Color.parseColor("#FB8C00"), true))
                c.addView(text(l.say, 19f, Color.parseColor("#0D47A1"), true))
                val zh = text(if (l.zh.isEmpty()) "（翻译中…）" else l.zh, 15f, Color.DKGRAY)
                zh.visibility = if (prefs.showZh) View.VISIBLE else View.GONE
                zhViews.add(zh)
                c.addView(zh, lp(top = 4))
                c.setOnClickListener { speaker.onDone = null; mark(i); speaker.speak(l.say) }
                c.setOnLongClickListener { speaker.onDone = null; mark(i); speaker.speak(l.say, true); true }
                cards.add(c)
                body.addView(c, lp(top = 8))
            }
        }
    }

    // ---------- 我的课文
    private fun loadMyTexts(): org.json.JSONArray = try { JSONArray(prefs.myTexts) } catch (_: Exception) { JSONArray() }
    private fun linesOf(o: org.json.JSONObject): List<Line> { val a = o.getJSONArray("l"); return (0 until a.length()).map { Line(a.getJSONObject(it).getString("e"), a.getJSONObject(it).optString("z")) } }

    private fun showMyTexts(): Unit {
        val self = { showMyTexts() }
        page("我的课文", self) { body ->
            body.addView(button("＋ 添加一篇课文", Color.parseColor("#00897B")) { showAddText() }, lp())
            val arr = loadMyTexts()
            if (arr.length() == 0) body.addView(text("还没有课文。点上面添加，把课本上的英文打进来或粘贴进来。", 15f, Color.GRAY), lp(top = 16))
            for (i in arr.length() - 1 downTo 0) {
                val o = arr.getJSONObject(i)
                val c = card()
                c.addView(text(o.getString("t"), 17f, bold = true))
                c.addView(text("${o.getJSONArray("l").length()} 句 · 长按删除", 13f, Color.GRAY), lp(top = 4))
                c.setOnClickListener { val ls = linesOf(o); translateMissing(i); showPointRead("我的课文", o.getString("t"), ls) }
                c.setOnLongClickListener {
                    android.app.AlertDialog.Builder(this).setMessage("删除《${o.getString("t")}》？")
                        .setPositiveButton("删除") { _, _ -> arr.remove(i); prefs.myTexts = arr.toString(); back.removeAt(back.size - 1); showMyTexts() }
                        .setNegativeButton("取消", null).show(); true
                }
                body.addView(c, lp(top = 10))
            }
        }
    }

    private fun splitEn(t: String): List<String> {
        val rows = t.lines().map { it.trim() }.filter { it.isNotEmpty() }
        return rows.flatMap { r -> r.split(Regex("(?<=[.!?])\\s+(?=[A-Z\"'])")).map { it.trim() }.filter { it.isNotEmpty() } }
    }
    private fun splitZh(t: String): List<String> {
        val rows = t.lines().map { it.trim() }.filter { it.isNotEmpty() }
        return rows.flatMap { r -> r.split(Regex("(?<=[。！？!?])")).map { it.trim() }.filter { it.isNotEmpty() } }
    }

    private fun showAddText(): Unit {
        val self = { showAddText() }
        page("添加课文", self) { body ->
            val title = EditText(this).apply { hint = "标题，如 Unit 1 Part B"; background = round(Color.WHITE, 10, Color.LTGRAY); setPadding(dp(12), dp(10), dp(12), dp(10)) }
            body.addView(title, lp())
            body.addView(text("英文课文（一行一句最准确，也可整段粘贴自动分句）", 14f, Color.DKGRAY), lp(top = 12))
            val en = EditText(this).apply {
                minLines = 6; gravity = Gravity.TOP; hint = "Colin: Look! There is a baby panda.\nAlice: Where is its mother?"
                inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE or InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS
                background = round(Color.WHITE, 10, Color.LTGRAY); setPadding(dp(12), dp(10), dp(12), dp(10))
            }
            body.addView(en, lp())
            body.addView(text("中文翻译（可不填，不填会自动在线翻译）", 14f, Color.DKGRAY), lp(top = 12))
            val zh = EditText(this).apply {
                minLines = 4; gravity = Gravity.TOP
                inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE
                background = round(Color.WHITE, 10, Color.LTGRAY); setPadding(dp(12), dp(10), dp(12), dp(10))
            }
            body.addView(zh, lp())
            body.addView(button("保存并开始点读", Color.parseColor("#00897B")) {
                val es = splitEn(en.text.toString())
                if (es.isEmpty()) { Toast.makeText(this, "先输入英文课文", Toast.LENGTH_SHORT).show(); return@button }
                val zs = splitZh(zh.text.toString())
                val arr = loadMyTexts()
                val la = JSONArray()
                es.forEachIndexed { i, e -> la.put(org.json.JSONObject().put("e", e).put("z", if (zs.size == es.size) zs[i] else "")) }
                val t = title.text.toString().ifBlank { "课文 " + (arr.length() + 1) }
                arr.put(org.json.JSONObject().put("t", t).put("l", la))
                prefs.myTexts = arr.toString()
                val idx = arr.length() - 1
                translateMissing(idx)
                back.removeAt(back.size - 1)
                showPointRead("我的课文", t, linesOf(arr.getJSONObject(idx)))
            }, lp(top = 16))
        }
    }

    private fun translateMissing(idx: Int) {
        val arr = loadMyTexts()
        if (idx >= arr.length()) return
        val la = arr.getJSONObject(idx).getJSONArray("l")
        val todo = (0 until la.length()).filter { la.getJSONObject(it).optString("z").isEmpty() }
        if (todo.isEmpty()) return
        Thread {
            var ok = 0
            for (k in todo) {
                try {
                    val e = la.getJSONObject(k).getString("e")
                    val u = java.net.URL("https://api.mymemory.translated.net/get?langpair=en%7Czh-CN&q=" + URLEncoder.encode(e, "UTF-8"))
                    val c = u.openConnection() as java.net.HttpURLConnection
                    c.connectTimeout = 8000; c.readTimeout = 8000
                    val r = c.inputStream.bufferedReader().readText()
                    val z = org.json.JSONObject(r).getJSONObject("responseData").getString("translatedText")
                    if (z.isNotBlank()) { la.getJSONObject(k).put("z", z); ok++ }
                } catch (_: Exception) {}
            }
            runOnUiThread {
                val cur = loadMyTexts()
                if (idx < cur.length()) { cur.getJSONObject(idx).put("l", la); prefs.myTexts = cur.toString() }
                Toast.makeText(this, if (ok > 0) "已自动翻译 $ok 句，返回再打开即可看到" else "自动翻译失败，请检查网络", Toast.LENGTH_SHORT).show()
            }
        }.start()
    }

    private fun showWrong(): Unit {
        val all = units.flatMap { it.words }
        val list = all.filter { it.en in prefs.wrong }
        val self = { showWrong() }
        page("错词本", self) { body ->
            if (list.isEmpty()) { body.addView(text("太棒了，还没有错词。", 18f), lp(top = 20)); return@page }
            body.addView(button("错词卡片复习", green) { showCards(list.shuffled(), "错词卡片", 0) }, lp())
            body.addView(button("错词听写", Color.parseColor("#FB8C00")) { showDictation(list.shuffled(), "错词听写", 0) }, lp())
            body.addView(button("清空错词本", red) { prefs.wrong = emptySet(); back.removeAt(back.size - 1); showWrong() }, lp())
            for (w in list) {
                val row = card()
                row.addView(text("${w.en}   ${w.zh}   (Unit ${w.unit})", 16f))
                row.setOnClickListener { speaker.speak(w.en) }
                body.addView(row, lp(top = 6))
            }
        }
    }
}
