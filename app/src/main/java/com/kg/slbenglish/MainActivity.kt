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
data class Lesson(val n: Int, val title: String, val words: List<Word>, val sentences: List<String>)

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

    private fun playOnline(text: String, rate: Float, fallback: Boolean = true) {
        val url = "https://dict.youdao.com/dictvoice?audio=" + URLEncoder.encode(text, "UTF-8") + "&type=" + prefs.accent
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
                if (fallback && ttsReady) playTts(text, rate)
                else Toast.makeText(ctx, "在线发音失败，请检查网络", Toast.LENGTH_SHORT).show()
                true
            }
            mp.prepareAsync()
        } catch (e: Exception) {
            if (fallback && ttsReady) playTts(text, rate)
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
            val s = o.getJSONArray("s")
            Lesson(n, o.getString("t"),
                (0 until w.length()).map { Word(w.getJSONObject(it).getString("e"), w.getJSONObject(it).getString("z"), n) },
                (0 until s.length()).map { s.getString(it) })
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
            body.addView(button("① 单词表（点读）") { showWords(u.words, "Unit ${u.n} 单词") }, lp(top = 14))
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
            for (s in u.sentences) {
                val c = card()
                c.addView(text(s, 18f, bold = true))
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
