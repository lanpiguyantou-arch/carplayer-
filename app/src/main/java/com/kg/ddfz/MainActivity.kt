package com.kg.ddfz

import android.Manifest
import android.app.Activity
import android.app.UiModeManager
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.StateListDrawable
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.ViewGroup
import android.view.ViewTreeObserver
import android.widget.*
import org.json.JSONObject
import java.util.Collections
import java.util.WeakHashMap

class MainActivity : Activity() {
    private lateinit var prefs: Prefs
    private lateinit var speaker: Speaker
    private lateinit var listener: Listener
    private lateinit var lessons: List<LessonData>
    private val allItems: List<Item> by lazy { lessons.flatMap { it.items } }
    private val back = ArrayList<() -> Unit>()

    private val blue = Color.parseColor("#1E88E5")
    private val green = Color.parseColor("#43A047")
    private val red = Color.parseColor("#E53935")
    private val purple = Color.parseColor("#5E35B1")
    private val orange = Color.parseColor("#FB8C00")
    private val teal = Color.parseColor("#00897B")
    private val brand = Color.parseColor("#C62828")
    private val bg = Color.parseColor("#FFF8F0")

    override fun onCreate(b: Bundle?) {
        super.onCreate(b)
        prefs = Prefs(this)
        speaker = Speaker(this, prefs)
        listener = Listener(this, prefs)
        lessons = loadBank(this)
        val vto = window.decorView.viewTreeObserver
        vto.addOnGlobalLayoutListener(ViewTreeObserver.OnGlobalLayoutListener {
            curRoot?.let { decorate(it) }
            if (!window.decorView.isInTouchMode && currentFocus == null) curBody?.let { firstFocusable(it)?.requestFocus() }
        })
        vto.addOnGlobalFocusChangeListener(ViewTreeObserver.OnGlobalFocusChangeListener { old, new -> onFocusMove(old, new) })
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED)
            requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 1)
        showHome()
    }

    override fun onDestroy() { listener.stop(); speaker.shutdown(); super.onDestroy() }
    override fun onPause() { super.onPause(); listener.stop(); speaker.stop() }

    @Deprecated("") override fun onBackPressed() {
        listener.stop(); speaker.stop(); onLeave?.invoke(); onLeave = null
        if (back.size > 1) { back.removeAt(back.size - 1); val prev = back.removeAt(back.size - 1); prev() } else super.onBackPressed()
    }
    private var onLeave: (() -> Unit)? = null
    private var replay: (() -> Unit)? = null

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        when (keyCode) {
            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE, KeyEvent.KEYCODE_MEDIA_PLAY, KeyEvent.KEYCODE_MENU -> {
                if (event == null || event.repeatCount == 0) replay?.invoke(); return true
            }
        }
        return super.onKeyDown(keyCode, event)
    }

    // ================= TV / 大屏
    private val isTv: Boolean by lazy { (getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager)?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION }
    private val noTouch: Boolean by lazy { !packageManager.hasSystemFeature(PackageManager.FEATURE_TOUCHSCREEN) }
    private val tvLike: Boolean get() = isTv || noTouch
    private val isBig: Boolean get() = isTv || resources.configuration.screenWidthDp >= 900
    private val fs: Float get() = if (isBig) 1.3f else 1f
    private val decorated: MutableSet<View> = Collections.newSetFromMap(WeakHashMap<View, Boolean>())
    private var curRoot: View? = null
    private var curBody: LinearLayout? = null
    private var preferFocus: View? = null

    private fun focusRing(): StateListDrawable = StateListDrawable().apply {
        addState(intArrayOf(android.R.attr.state_focused), GradientDrawable().apply {
            setColor(Color.TRANSPARENT); cornerRadius = dp(12).toFloat(); setStroke(dp(if (isBig) 4 else 3), Color.parseColor("#FFB300"))
        })
        addState(intArrayOf(), ColorDrawable(Color.TRANSPARENT))
    }
    private fun decorate(v: View) {
        if (v is ViewGroup) {
            if (tvLike && v !is ScrollView && v !== curRoot) v.clipChildren = false
            for (i in 0 until v.childCount) decorate(v.getChildAt(i))
        }
        if (decorated.contains(v)) return
        val actionable = v.hasOnClickListeners() || v is Button || v is SeekBar
        if (!actionable) return
        decorated.add(v); v.isFocusable = true; v.foreground = focusRing()
    }
    private fun firstFocusable(v: View): View? {
        if (!v.isShown) return null
        if (decorated.contains(v) && v.isFocusable) return v
        if (v is ViewGroup) for (i in 0 until v.childCount) { val f = firstFocusable(v.getChildAt(i)); if (f != null) return f }
        return null
    }
    private fun onFocusMove(old: View?, new: View?) {
        old?.animate()?.scaleX(1f)?.scaleY(1f)?.setDuration(100)?.start()
        if (new != null && decorated.contains(new) && !new.isInTouchMode) {
            val s = if (new.width > dp(480)) 1.02f else 1.06f
            new.animate().scaleX(s).scaleY(s).setDuration(120).start()
            new.post { if (new.isAttachedToWindow) scrollToFocus(new) }
        }
    }
    private fun scrollToFocus(v: View) {
        var p: Any? = v.parent; var sv: ScrollView? = null
        while (p is View) { if (p is ScrollView) { sv = p; break }; p = p.parent }
        val scroll = sv ?: return; val content = scroll.getChildAt(0) ?: return
        var y = 0; var c: View = v
        while (c !== content) { y += c.top; c = (c.parent as? View) ?: return }
        scroll.smoothScrollTo(0, maxOf(0, minOf(y + v.height / 2 - scroll.height / 2, content.height - scroll.height)))
    }
    private fun focus(v: View) { if (!v.isInTouchMode || tvLike) v.post { v.requestFocus() } }

    // ================= UI 工具
    private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()
    private fun round(color: Int, r: Int = 14, stroke: Int? = null) = GradientDrawable().apply {
        setColor(color); cornerRadius = dp(r).toFloat(); if (stroke != null) setStroke(dp(2), stroke)
    }
    private fun text(s: String, size: Float = 16f, color: Int = Color.parseColor("#222222"), bold: Boolean = false) =
        TextView(this).apply { text = s; textSize = size * fs; setTextColor(color); setLineSpacing(0f, 1.15f); if (bold) setTypeface(typeface, Typeface.BOLD) }
    private fun button(s: String, color: Int = blue, onClick: () -> Unit) = Button(this).apply {
        text = s; isAllCaps = false; setTextColor(Color.WHITE); textSize = 16f * fs
        val mh = if (isBig) 56 else 44
        background = round(color, 10); setPadding(dp(12), dp(6), dp(12), dp(6)); minHeight = dp(mh); minimumHeight = dp(mh)
        isFocusable = true; setOnClickListener { onClick() }
    }
    private fun lp(top: Int = 8) = LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(top) }
    private fun wlp(left: Int = 0) = LinearLayout.LayoutParams(0, -2, 1f).apply { leftMargin = dp(left) }
    private fun card(color: Int = Color.WHITE) = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL; background = round(color); setPadding(dp(16), dp(14), dp(16), dp(14))
    }
    private fun row() = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; isBaselineAligned = false }

    private fun page(title: String, self: () -> Unit, build: (LinearLayout) -> Unit) {
        back.add(self); listener.stop(); speaker.stop(); replay = null; onLeave = null
        val root = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setBackgroundColor(bg) }
        val bar = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL; setBackgroundColor(brand); setPadding(dp(12), dp(28), dp(12), dp(12)) }
        if (back.size > 1) bar.addView(text("‹ 返回", 17f, Color.WHITE).apply { setPadding(0, 0, dp(16), 0); setOnClickListener { onBackPressed() } })
        bar.addView(text(title, 19f, Color.WHITE, true).apply { maxLines = 1 })
        root.addView(bar)
        val scroll = ScrollView(this)
        val body = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(dp(14), dp(10), dp(14), dp(60)) }
        scroll.addView(body)
        if (isBig) { val side = maxOf(0, (resources.displayMetrics.widthPixels - dp(1100)) / 2); scroll.setPadding(side, 0, side, 0) }
        root.addView(scroll, LinearLayout.LayoutParams(-1, 0, 1f))
        build(body)
        setContentView(root)
        curRoot = root; curBody = body
        decorate(root)
        root.post {
            val pf = preferFocus; preferFocus = null
            if (!root.isInTouchMode || tvLike) (pf?.takeIf { it.isShown } ?: firstFocusable(body))?.requestFocus()
        }
    }
    private fun addGrid(body: LinearLayout, cards: List<View>, cols: Int, top: Int) {
        cards.chunked(cols).forEach { chunk ->
            val r = row()
            chunk.forEachIndexed { k, c -> c.minimumHeight = dp(90); r.addView(c, LinearLayout.LayoutParams(0, -2, 1f).apply { if (k > 0) leftMargin = dp(14) }) }
            repeat(cols - chunk.size) { r.addView(View(this).apply { visibility = View.INVISIBLE }, LinearLayout.LayoutParams(0, dp(90), 1f).apply { leftMargin = dp(14) }) }
            body.addView(r, lp(top))
        }
    }

    // ================= 错题与遗忘曲线
    private val curve = intArrayOf(1, 2, 4, 7, 15, 30)
    private fun today() = (System.currentTimeMillis() + java.util.TimeZone.getDefault().getOffset(System.currentTimeMillis())) / 86400000L
    private fun rmap(): JSONObject = try { JSONObject(prefs.review) } catch (_: Exception) { JSONObject() }
    private fun markWrong(it: Item) {
        val m = rmap(); val o = m.optJSONObject(it.id) ?: JSONObject()
        o.put("st", 0).put("d", today() + 1).put("w", o.optInt("w") + 1).put("last", today())
        m.put(it.id, o); prefs.review = m.toString()
    }
    private fun markRight(it: Item, inReview: Boolean) {
        val m = rmap(); val o = m.optJSONObject(it.id) ?: return
        if (!inReview && o.optLong("d") > today()) return
        val st = o.optInt("st") + 1
        o.put("st", st).put("d", today() + if (st >= curve.size) 99999 else curve[st])
        m.put(it.id, o); prefs.review = m.toString()
    }
    private fun wrongItems(): List<Item> { val m = rmap(); return allItems.filter { m.optJSONObject(it.id)?.let { o -> o.optInt("st") < curve.size } == true } }
    private fun dueItems(): List<Item> { val m = rmap(); val t = today(); return allItems.filter { m.optJSONObject(it.id)?.let { o -> o.optInt("st") < curve.size && o.optLong("d") <= t } == true } }
    private fun masteredCount(): Int { val m = rmap(); return allItems.count { m.optJSONObject(it.id)?.optInt("st", 0)?.let { s -> s >= curve.size } == true } }

    // ================= 首页
    private fun showHome(): Unit = page("道德与法治 六年级上册 · 问答", ::showHome) { body ->
        body.addView(text(if (tvLike) "方向键选择，确认键进入。题目会读出来，读到横线处请孩子说出答案。" else "选一课开始。题目会读出来，读到横线处请孩子说出答案。", 14f, Color.GRAY), lp())
        val due = dueItems().size; val wrong = wrongItems().size
        val fn = ArrayList<View>()
        fn.add(card(Color.parseColor("#EDE7F6")).apply {
            addView(text("📅 今日复习（$due）", 18f, purple, true))
            addView(text("错题按 1-2-4-7-15-30 天遗忘曲线回来复习", 13f, Color.GRAY), lp(4))
            setOnClickListener { if (due == 0) Toast.makeText(this@MainActivity, "今天没有要复习的错题 👍", Toast.LENGTH_SHORT).show() else startQuiz(dueItems(), "今日复习", true) }
        })
        fn.add(card(Color.parseColor("#FFEBEE")).apply {
            addView(text("📕 错题本（$wrong）", 18f, red, true))
            addView(text("已牢记 ${masteredCount()} 题 · 点开查看和重练", 13f, Color.GRAY), lp(4))
            setOnClickListener { showWrong() }
        })
        fn.add(card(Color.parseColor("#E8F5E9")).apply {
            addView(text("🎲 全册随机 10 题", 18f, green, true))
            addView(text("填空和问答混合抽问", 13f, Color.GRAY), lp(4))
            setOnClickListener { startQuiz(allItems.shuffled().take(10), "全册随机", false) }
        })
        val lc = lessons.map { l ->
            card().apply {
                val nf = l.items.count { it.isFill }
                addView(text("第${l.id}课  ${l.title}", 18f, bold = true))
                addView(text("填空 $nf · 问答 ${l.items.size - nf}", 13f, Color.GRAY), lp(4))
                setOnClickListener { showLesson(l) }
            }
        }
        val st = card().apply {
            addView(text("⚙ 设置", 18f, bold = true))
            addView(text((if (prefs.engine == 0) "在线真人发音" else "系统语音") + " · 等待 ${prefs.waitSec} 秒", 13f, Color.GRAY), lp(4))
            setOnClickListener { showSettings() }
        }
        if (isBig) {
            addGrid(body, fn, 3, 12)
            body.addView(text("课程", 18f, bold = true), lp(20))
            addGrid(body, lc + st, 3, 12)
        } else {
            fn.forEach { body.addView(it, lp(10)) }
            body.addView(text("课程", 18f, bold = true), lp(18))
            lc.forEach { body.addView(it, lp(10)) }
            body.addView(st, lp(14))
        }
    }

    private fun showLesson(l: LessonData): Unit = page("第${l.id}课 ${l.title}", { showLesson(l) }) { body ->
        val fills = l.items.filter { it.isFill }; val qas = l.items.filter { !it.isFill }
        val r1 = row()
        r1.addView(button("▶ 按顺序问全部（${l.items.size}）", brand) { startQuiz(l.items, "第${l.id}课", false) }, wlp())
        r1.addView(button("🎲 随机问", green) { startQuiz(l.items.shuffled(), "第${l.id}课 随机", false) }, wlp(10))
        body.addView(r1, lp())
        val r2 = row()
        r2.addView(button("✏ 只问填空（${fills.size}）", blue) { startQuiz(fills, "第${l.id}课 填空", false) }, wlp())
        r2.addView(button("💬 只问问答（${qas.size}）", teal) { startQuiz(qas, "第${l.id}课 问答", false) }, wlp(10))
        body.addView(r2, lp())
        body.addView(text("题目一览（点一题从这题开始问）", 15f, Color.GRAY, true), lp(18))
        l.items.forEachIndexed { k, it ->
            val c = card()
            c.addView(text((if (it.isFill) "✏ 填空  " else "💬 问答  ") + it.q, 16f))
            if (rmap().has(it.id)) c.addView(text("📕 在错题本里", 13f, red), lp(4))
            c.setOnClickListener { startQuiz(l.items.drop(k), "第${l.id}课", false) }
            body.addView(c, lp(8))
        }
    }

    private fun showWrong(): Unit = page("错题本", ::showWrong) { body ->
        val list = wrongItems()
        if (list.isEmpty()) { body.addView(text("还没有错题，继续加油！", 18f), lp(20)); return@page }
        body.addView(button("▶ 把错题全部练一遍（${list.size}）", red) { startQuiz(list.shuffled(), "错题重练", true) }, lp())
        val m = rmap()
        list.forEach { item ->
            val it = item
            val o = m.getJSONObject(it.id)
            val c = card()
            c.addView(text("第${it.lesson}课 · " + (if (it.isFill) "填空" else "问答") + " · 错 ${o.optInt("w")} 次 · 复习进度 ${o.optInt("st")}/${curve.size}", 13f, Color.GRAY))
            c.addView(text(it.q, 16f, bold = true), lp(4))
            c.addView(text("答案：" + (if (it.isFill) it.blanks.joinToString("、") else it.a), 15f, green), lp(6))
            if (it.memory.isNotEmpty()) c.addView(text("🧠 " + it.memory, 14f, purple), lp(6))
            c.setOnClickListener { speaker.speak(item.answerText) }
            body.addView(c, lp(10))
        }
        body.addView(button("清空错题本", Color.GRAY) {
            android.app.AlertDialog.Builder(this).setMessage("清空全部错题和复习进度？").setPositiveButton("清空") { _, _ -> prefs.review = "{}"; back.removeAt(back.size - 1); showWrong() }.setNegativeButton("取消", null).show()
        }, lp(24))
    }

    private fun showSettings(): Unit = page("设置", ::showSettings) { body ->
        body.addView(text("朗读声音", 17f, bold = true), lp())
        val r = row()
        r.addView(button((if (prefs.engine == 0) "✓ " else "") + "在线真人发音", if (prefs.engine == 0) brand else Color.GRAY) { prefs.engine = 0; back.removeAt(back.size - 1); showSettings() }, wlp())
        r.addView(button((if (prefs.engine == 1) "✓ " else "") + "系统语音（离线）", if (prefs.engine == 1) brand else Color.GRAY) { prefs.engine = 1; back.removeAt(back.size - 1); showSettings() }, wlp(10))
        body.addView(r, lp())
        body.addView(text("语速 " + String.format("%.1f", prefs.speed), 17f, bold = true), lp(18))
        val r2 = row()
        r2.addView(button("慢一点", blue) { prefs.speed = maxOf(0.6f, prefs.speed - 0.1f); back.removeAt(back.size - 1); showSettings() }, wlp())
        r2.addView(button("试听", green) { speaker.speak("法律规范着我们的行为，保护着我们的权利。") }, wlp(10))
        r2.addView(button("快一点", blue) { prefs.speed = minOf(1.6f, prefs.speed + 0.1f); back.removeAt(back.size - 1); showSettings() }, wlp(10))
        body.addView(r2, lp())
        body.addView(text("等孩子开口的时间：${prefs.waitSec} 秒（超时会问要不要看答案）", 17f, bold = true), lp(18))
        val r3 = row()
        listOf(10, 15, 20, 30).forEachIndexed { k, s -> r3.addView(button((if (prefs.waitSec == s) "✓ " else "") + "$s 秒", if (prefs.waitSec == s) brand else Color.GRAY) { prefs.waitSec = s; back.removeAt(back.size - 1); showSettings() }, wlp(if (k > 0) 8 else 0)) }
        body.addView(r3, lp())
        body.addView(text("收音方式", 17f, bold = true), lp(18))
        val names = listOf("自动（能识别就识别文字）", "只检测说话声音", "不用麦克风，说完手动按")
        names.forEachIndexed { k, n -> body.addView(button((if (prefs.listenMode == k) "✓ " else "") + n, if (prefs.listenMode == k) brand else Color.GRAY) { prefs.listenMode = k; back.removeAt(back.size - 1); showSettings() }, lp()) }
        body.addView(text("说明：手机上一般能把孩子说的话识别成文字并自动判对错。电视如果没有语音识别服务，会自动改成“检测说话声音”，说完由家长按“答对了/答错了”。小米/红米电视遥控器的语音键通常被小爱同学占用，第三方应用不一定能用遥控器麦克风收音；收不到声音时请选“说完手动按”。", 14f, Color.GRAY), lp(14))
    }

    // ================= 问答练习
    private fun startQuiz(items: List<Item>, title: String, isReview: Boolean) {
        if (items.isEmpty()) { Toast.makeText(this, "没有题目", Toast.LENGTH_SHORT).show(); return }
        val st = QuizState(items, title, isReview)
        showQuiz(st)
    }
    inner class QuizState(val items: List<Item>, val title: String, val isReview: Boolean) {
        var i = 0; var right = 0; val wrong = ArrayList<Item>()
    }

    private fun showQuiz(s: QuizState) {
        page(s.title, { showQuiz(s) }) { body ->
            if (s.i >= s.items.size) { summary(body, s); return@page }
            val item = s.items[s.i]
            body.addView(text("第 ${s.i + 1} / ${s.items.size} 题 · 第${item.lesson}课 ${item.lessonTitle} · " + (if (item.isFill) "填空题" else "问答题"), 14f, Color.GRAY), lp())
            if (item.isFill) FillRun(body, s, item).begin() else QaRun(body, s, item).begin()
        }
    }

    private fun next(s: QuizState, item: Item, ok: Boolean) {
        if (ok) { s.right++; markRight(item, s.isReview) } else { s.wrong.add(item); markWrong(item) }
        s.i++
        back.removeAt(back.size - 1)
        showQuiz(s)
    }

    private fun summary(body: LinearLayout, s: QuizState) {
        val c = card()
        c.addView(text("完成啦！🎉", 24f, green, true))
        c.addView(text("答对 ${s.right} 题，没答好 ${s.wrong.size} 题", 18f), lp(8))
        if (s.wrong.isNotEmpty()) c.addView(text("没答好的已放进错题本，明天开始按遗忘曲线复习。", 14f, Color.GRAY), lp(6))
        body.addView(c, lp())
        val bWrong = if (s.wrong.isNotEmpty()) button("🔁 马上再练没答好的（${s.wrong.size}）", red) { val w = ArrayList(s.wrong); back.removeAt(back.size - 1); startQuiz(w, "再练一遍", false) } else null
        bWrong?.let { body.addView(it, lp(14)) }
        s.wrong.forEach { body.addView(text("• " + (if (it.isFill) it.answerText else it.q + "\n   答：" + it.a), 15f), lp(6)) }
        val bHome = button("回到首页", blue) { back.clear(); showHome() }
        body.addView(bHome, lp(16))
        speaker.speak(if (s.wrong.isEmpty()) "太棒了，全部答对！" else "完成啦，答对${s.right}题。")
        preferFocus = bWrong ?: bHome
    }

    // ---- 公共：状态行 + 操作区
    private inner class Panel(body: LinearLayout) {
        val status = text("", 17f, blue, true)
        val heard = text("", 17f, Color.DKGRAY)
        val actions = LinearLayout(this@MainActivity).apply { orientation = LinearLayout.VERTICAL }
        init {
            body.addView(status, lp(14)); body.addView(heard, lp(6)); body.addView(actions, lp(10))
        }
        fun clear() { actions.removeAllViews() }
        fun add(v: View, top: Int = 8) { actions.addView(v, lp(top)) }
        fun buttons(vararg bs: Button): Button { val r = row(); bs.forEachIndexed { k, b -> r.addView(b, wlp(if (k > 0) 10 else 0)) }; actions.addView(r, lp(8)); decorate(r); return bs[0] }
    }

    // ---- 填空题：读到横线处收音
    private inner class FillRun(val body: LinearLayout, val s: QuizState, val item: Item) {
        val segs = item.q.split("____")
        var k = 0 // 当前空
        var ok = true
        val filled = ArrayList<String?>()
        val qView = text("", 22f, bold = true)
        val p: Panel
        init {
            val c = card(); c.addView(qView); body.addView(c, lp(8))
            p = Panel(body)
            replay = { readFrom(k) }
            onLeave = { listener.stop() }
            render()
        }
        fun render() {
            val sb = StringBuilder()
            for (j in segs.indices) {
                sb.append(segs[j])
                if (j < segs.size - 1) sb.append(when { j < filled.size -> "【${filled[j] ?: "？"}】"; j == k -> " ___🎤___ "; else -> " ______ " })
            }
            qView.text = sb.toString()
        }
        fun begin() { readFrom(0) }
        fun readFrom(j: Int) {
            listener.stop(); p.clear(); p.heard.text = ""
            p.status.text = "🔊 正在读题…"
            p.add(button("⏭ 跳过朗读，直接回答", Color.GRAY) { speaker.stop(); listen() }.also { focus(it) })
            val pre = if (j == 0) segs[0] else segs[j]
            speaker.speak(if (j == 0) "填空题。$pre" else pre) {
                if (k < item.blanks.size) listen() else finish()
            }
        }
        fun listen() {
            p.clear(); p.heard.text = ""
            p.status.text = "🎤 请说出横线上的答案"
            val done = button("✓ 我答完了", green) { listener.finishNow() }
            p.buttons(done, button("🔁 再读一遍", blue) { readFrom(k) })
            focus(done)
            listener.start(false, object : ListenCallback {
                override fun onState(msg: String) { p.status.text = msg }
                override fun onPartial(text: String) { p.heard.text = "听到：$text" }
                override fun onEnd(text: String, heard: Boolean) = answered(text, heard)
                override fun onTimeout() = timeout()
            })
        }
        fun answered(said: String, heard: Boolean) {
            p.clear()
            if (said.isNotEmpty()) {
                val right = Judge.fill(said, item.blanks[k], item.alt.getOrNull(k) ?: emptyList())
                p.heard.text = "你说的：$said"
                if (right) {
                    p.status.text = "✅ 答对了！"; p.status.setTextColor(green)
                    speaker.speak("答对了")
                    filled.add(item.blanks[k]); render()
                    focus(p.buttons(button("继续 ▶", green) { advance() }))
                } else {
                    p.status.text = "🤔 好像不太对，再想想？"; p.status.setTextColor(orange)
                    focus(p.buttons(button("🎤 再说一次", blue) { listen() }, button("👀 查看答案", orange) { reveal() }))
                    p.add(button("其实我答对了（识别错了）", Color.GRAY) { filled.add(item.blanks[k]); render(); advance() })
                }
            } else {
                // 没有文字识别：由家长判断
                p.status.text = if (heard) "👂 听到回答了！对不对？" else "回答完了吗？"; p.status.setTextColor(blue)
                focus(p.buttons(button("✓ 答对了，继续", green) { filled.add(item.blanks[k]); render(); advance() }, button("✗ 答错了", red) { reveal() }))
                p.add(button("👀 查看答案", orange) { reveal() })
            }
        }
        fun timeout() {
            p.clear()
            p.status.text = "⏰ ${prefs.waitSec} 秒没听到回答。要不要看正确答案？"; p.status.setTextColor(orange)
            speaker.speak("没听到回答，要不要看正确答案？")
            focus(p.buttons(button("👀 查看答案", orange) { reveal() }, button("🎤 再想想", blue) { listen() }))
            p.add(button("其实已经答完了", Color.GRAY) { answered("", true) })
        }
        fun reveal() {
            listener.stop(); ok = false
            p.clear()
            p.status.text = "正确答案：${item.blanks[k]}"; p.status.setTextColor(green)
            filled.add(item.blanks[k]); render()
            speaker.speak("正确答案是：${item.blanks[k]}")
            if (item.memory.isNotEmpty()) p.add(text("🧠 记忆小窍门：${item.memory}", 16f, purple))
            focus(p.buttons(button("记住了，继续 ▶", green) { advance() }, button("🔊 再听一遍", blue) { speaker.speak(item.answerText) }))
        }
        fun advance() {
            listener.stop()
            k++
            p.status.setTextColor(blue)
            if (k < item.blanks.size) readFrom(k) else {
                // 读完最后一段
                val tail = segs.last()
                if (tail.isNotBlank()) { p.clear(); p.status.text = "🔊"; speaker.speak(tail) { finish() } } else finish()
            }
        }
        fun finish() {
            p.clear()
            p.status.text = if (ok) "🎉 这题全对！" else "📕 这题已记进错题本"; p.status.setTextColor(if (ok) green else red)
            p.heard.text = ""
            focus(p.buttons(button("下一题 ▶", brand) { next(s, item, ok) }, button("🔊 完整读一遍", blue) { speaker.speak(item.answerText) }))
        }
    }

    // ---- 问答题：读题→收音→看要点→记忆方法
    private inner class QaRun(val body: LinearLayout, val s: QuizState, val item: Item) {
        val p: Panel
        var ok = true
        var said = ""
        init {
            val c = card(); c.addView(text(item.q, 22f, bold = true)); body.addView(c, lp(8))
            p = Panel(body)
            replay = { read() }
            onLeave = { listener.stop() }
        }
        fun begin() = read()
        fun read() {
            listener.stop(); p.clear(); p.heard.text = ""
            p.status.text = "🔊 正在读题…"; p.status.setTextColor(blue)
            p.add(button("⏭ 跳过朗读，直接回答", Color.GRAY) { speaker.stop(); listen() }.also { focus(it) })
            speaker.speak("问答题。" + item.q) { listen() }
        }
        fun listen() {
            p.clear(); p.heard.text = ""
            p.status.text = "🎤 请说出你的答案，说完点“我答完了”"; p.status.setTextColor(blue)
            val done = button("✓ 我答完了", green) { listener.finishNow() }
            p.buttons(done, button("🔁 再读一遍题", blue) { read() })
            focus(done)
            listener.start(true, object : ListenCallback {
                override fun onState(msg: String) { p.status.text = msg }
                override fun onPartial(text: String) { p.heard.text = "听到：$text" }
                override fun onEnd(text: String, heard: Boolean) = answered(text, heard)
                override fun onTimeout() = timeout()
            })
        }
        fun answered(text: String, heard: Boolean) {
            said = text; p.clear()
            if (text.isNotEmpty() && item.keys.isNotEmpty()) {
                p.heard.text = "你说的：$text"
                val hits = item.keys.indices.map { Judge.key(text, item, it) }
                val n = hits.count { it }
                ok = n * 10 >= item.keys.size * 6
                p.status.text = if (ok) "✅ 答得不错！说到了 $n / ${item.keys.size} 个要点" else "🤔 说到了 $n / ${item.keys.size} 个要点，还差一点"
                p.status.setTextColor(if (ok) green else orange)
                speaker.speak(if (ok) "答得不错！" else "还差一点哦")
                p.add(text("要点：" + item.keys.mapIndexed { i, k -> if (hits[i]) "✓$k" else "○？" }.joinToString("   "), 16f, Color.DKGRAY))
                focus(p.buttons(button("继续 ▶", green) { after() }, button("🎤 再答一次", blue) { listen() }))
                p.add(button("👀 查看参考答案", orange) { reveal() })
                if (!ok) p.add(button("👨‍👩‍👧 家长改判：其实答对了", Color.GRAY) { ok = true; p.status.text = "✅ 家长判定：答对了"; p.status.setTextColor(green); after() })
            } else {
                p.status.text = if (heard) "👂 听到回答了！答得完整吗？" else "回答完了吗？"; p.status.setTextColor(blue)
                focus(p.buttons(button("✓ 答全了，继续", green) { ok = true; after() }, button("✗ 没答全", red) { ok = false; reveal() }))
                p.add(button("👀 查看参考答案", orange) { reveal() })
            }
        }
        fun timeout() {
            p.clear()
            p.status.text = "⏰ ${prefs.waitSec} 秒没听到回答。要不要看正确答案？"; p.status.setTextColor(orange)
            speaker.speak("没听到回答，要不要看正确答案？")
            focus(p.buttons(button("👀 查看答案", orange) { reveal() }, button("🎤 再想想", blue) { listen() }))
            p.add(button("其实已经答完了", Color.GRAY) { answered("", true) })
        }
        fun after() {
            // 答对也给一次看答案/记忆方法的机会
            p.clear()
            focus(p.buttons(button("下一题 ▶", brand) { next(s, item, ok) }, button("👀 对一对参考答案", orange) { reveal(keepOk = true) }))
            p.add(button("🧠 怎么记住这题", purple) { memory() })
        }
        fun reveal(keepOk: Boolean = false) {
            listener.stop(); if (!keepOk) ok = false
            p.clear()
            p.status.text = "参考答案"; p.status.setTextColor(green)
            p.add(card(Color.parseColor("#E8F5E9")).apply { addView(text(item.a, 18f)) })
            if (item.keys.isNotEmpty()) p.add(text("必须说到的要点：" + item.keys.joinToString("、"), 16f, brand, true))
            speaker.speak(item.a)
            focus(p.buttons(button("看完了，继续 ▶", green) { p.clear(); focus(p.buttons(button("下一题 ▶", brand) { next(s, item, ok) }, button("🧠 怎么记住这题", purple) { memory() })) }, button("🔊 再听一遍", blue) { speaker.speak(item.a) }))
            p.add(button("🧠 教我怎么记", purple) { memory() })
        }
        fun memory() {
            listener.stop(); p.clear()
            p.status.text = "🧠 记忆方法"; p.status.setTextColor(purple)
            val c = card(Color.parseColor("#F3E5F5"))
            if (item.keys.isNotEmpty()) {
                c.addView(text("第一步 · 抓关键词", 16f, purple, true))
                c.addView(text(item.keys.mapIndexed { i, k -> "${i + 1}. $k" }.joinToString("\n"), 18f), lp(4))
            }
            if (item.memory.isNotEmpty()) {
                c.addView(text("第二步 · 口诀/联想", 16f, purple, true), lp(12))
                c.addView(text(item.memory, 18f, Color.parseColor("#4A148C"), true), lp(4))
            }
            if (item.diagram.isNotEmpty()) {
                c.addView(text("第三步 · 看图理解", 16f, purple, true), lp(12))
                c.addView(text(item.diagram, 17f).apply { typeface = Typeface.MONOSPACE; setBackgroundColor(Color.WHITE); setPadding(dp(10), dp(8), dp(10), dp(8)) }, lp(4))
            }
            c.addView(text("最后 · 闭上眼睛，按关键词顺序把答案说一遍；明天再复习一次。", 15f, Color.DKGRAY), lp(12))
            p.add(c)
            speaker.speak((if (item.keys.isNotEmpty()) "先记关键词：" + item.keys.joinToString("，") + "。" else "") + item.memory)
            focus(p.buttons(button("🎤 闭眼复述一遍", blue) { listen() }, button("下一题 ▶", brand) { next(s, item, ok) }))
            p.add(button("🔊 再读一遍口诀", purple) { speaker.speak(item.memory) })
        }
    }
}
