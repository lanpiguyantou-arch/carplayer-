package com.kg.ddfz

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import org.json.JSONObject
import java.net.URLEncoder
import java.util.Locale

// ---------------- 数据
data class Item(
    val id: String, val lesson: Int, val lessonTitle: String, val type: String, val q: String,
    val blanks: List<String>, val alt: List<List<String>>, val a: String, val keys: List<String>, val syn: List<List<String>>,
    val memory: String, val diagram: String
) {
    val isFill get() = type == "fill"
    val answerText: String get() = if (isFill) {
        var s = q; blanks.forEach { b -> s = s.replaceFirst("____", "【$b】") }; s
    } else a
}
data class LessonData(val id: Int, val title: String, val items: List<Item>)

fun loadBank(ctx: Context): List<LessonData> {
    val o = JSONObject(ctx.assets.open("bank.json").bufferedReader(Charsets.UTF_8).readText())
    val ls = o.getJSONArray("lessons")
    return (0 until ls.length()).map { li ->
        val l = ls.getJSONObject(li)
        val lid = l.getInt("id"); val title = l.getString("title")
        val arr = l.getJSONArray("items")
        LessonData(lid, title, (0 until arr.length()).map { k ->
            val it = arr.getJSONObject(k)
            fun strs(key: String): List<String> = it.optJSONArray(key)?.let { a -> (0 until a.length()).map { a.getString(it) } } ?: emptyList()
            val altA = it.optJSONArray("alt")
            val alt = (0 until (altA?.length() ?: 0)).map { i -> altA!!.optJSONArray(i)?.let { a -> (0 until a.length()).map { a.getString(it) } } ?: emptyList() }
            val synA = it.optJSONArray("syn")
            val syn = (0 until (synA?.length() ?: 0)).map { i -> synA!!.optJSONArray(i)?.let { a -> (0 until a.length()).map { a.getString(it) } } ?: emptyList() }
            Item("$lid-$k", lid, title, it.optString("type", "qa"), it.getString("q"), strs("blanks"), alt,
                it.optString("a"), strs("keys"), syn, it.optString("memory"), it.optString("diagram"))
        })
    }
}

// ---------------- 设置与进度
class Prefs(ctx: Context) {
    private val sp = ctx.getSharedPreferences("ddfz", Context.MODE_PRIVATE)
    var speed: Float
        get() = sp.getFloat("speed", 1.0f)
        set(v) { sp.edit().putFloat("speed", v).apply() }
    var engine: Int // 0 在线真人发音 1 系统语音
        get() = sp.getInt("engine", 0)
        set(v) { sp.edit().putInt("engine", v).apply() }
    var listenMode: Int // 0 自动（语音识别→声音检测→手动） 1 只检测声音 2 手动
        get() = sp.getInt("listenMode", 0)
        set(v) { sp.edit().putInt("listenMode", v).apply() }
    var waitSec: Int
        get() = sp.getInt("waitSec", 10)
        set(v) { sp.edit().putInt("waitSec", v).apply() }
    var review: String
        get() = sp.getString("review", "{}") ?: "{}"
        set(v) { sp.edit().putString("review", v).apply() }
    var stats: String
        get() = sp.getString("stats", "{}") ?: "{}"
        set(v) { sp.edit().putString("stats", v).apply() }
}

// ---------------- 中文朗读：百度在线（分段）→ 失败用系统中文语音
class Speaker(private val ctx: Context, private val prefs: Prefs) {
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var player: MediaPlayer? = null
    private val main = Handler(Looper.getMainLooper())
    private var gen = 0
    private var onTtsDone: (() -> Unit)? = null

    init {
        tts = TextToSpeech(ctx) { st ->
            if (st == TextToSpeech.SUCCESS) {
                val r = tts?.setLanguage(Locale.CHINA) ?: TextToSpeech.LANG_NOT_SUPPORTED
                ttsReady = r != TextToSpeech.LANG_MISSING_DATA && r != TextToSpeech.LANG_NOT_SUPPORTED
                tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                    override fun onStart(id: String?) {}
                    override fun onDone(id: String?) { main.post { val d = onTtsDone; onTtsDone = null; d?.invoke() } }
                    @Deprecated("") override fun onError(id: String?) { main.post { val d = onTtsDone; onTtsDone = null; d?.invoke() } }
                })
            }
        }
    }

    private fun clean(t: String) = t.replace("____", "，").replace(Regex("[【】《》“”\"'（）()]"), "")
        .replace("；", "，").replace(";", "，").replace("\n", "，").trim()

    private fun chunks(t: String): List<String> {
        val out = ArrayList<String>(); val sb = StringBuilder()
        for (c in t) {
            sb.append(c)
            if ((c in "。！？!?" && sb.length >= 8) || (c in "，、：:," && sb.length >= 40) || sb.length >= 70) { out.add(sb.toString()); sb.clear() }
        }
        if (sb.isNotBlank()) out.add(sb.toString())
        return out.filter { it.isNotBlank() }
    }

    fun speak(text: String, done: (() -> Unit)? = null) {
        stop()
        val my = ++gen
        val t = clean(text)
        if (t.isEmpty()) { done?.let { main.post(it) }; return }
        val parts = chunks(t)
        if (prefs.engine == 1 && ttsReady) sys(parts, 0, my, done) else online(parts, 0, my, done)
    }

    private fun online(parts: List<String>, i: Int, my: Int, done: (() -> Unit)?) {
        if (my != gen) return
        if (i >= parts.size) { done?.invoke(); return }
        val spd = (5 * prefs.speed).toInt().coerceIn(2, 9)
        val url = "https://fanyi.baidu.com/gettts?lan=zh&text=" + URLEncoder.encode(parts[i], "UTF-8").replace("+", "%20") + "&spd=$spd&source=web"
        try {
            val mp = MediaPlayer(); player = mp
            mp.setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
            mp.setDataSource(url)
            mp.setOnPreparedListener { if (my == gen) it.start() }
            mp.setOnCompletionListener { main.post { if (my == gen) online(parts, i + 1, my, done) } }
            mp.setOnErrorListener { _, _, _ -> main.post { if (my == gen) { if (ttsReady) sys(parts, i, my, done) else online(parts, i + 1, my, done) } }; true }
            mp.prepareAsync()
        } catch (_: Exception) { if (ttsReady) sys(parts, i, my, done) else done?.invoke() }
    }

    private fun sys(parts: List<String>, i: Int, my: Int, done: (() -> Unit)?) {
        if (my != gen) return
        if (i >= parts.size) { done?.invoke(); return }
        tts?.setLanguage(Locale.CHINA)
        tts?.setSpeechRate(prefs.speed)
        onTtsDone = { if (my == gen) sys(parts, i + 1, my, done) }
        tts?.speak(parts[i], TextToSpeech.QUEUE_FLUSH, null, "d" + System.nanoTime())
    }

    fun stop() {
        gen++
        onTtsDone = null
        try { player?.release() } catch (_: Exception) {}
        player = null
        tts?.stop()
    }

    fun shutdown() { stop(); tts?.shutdown() }
}

// ---------------- 收音：语音识别 → 声音检测 → 手动
interface ListenCallback {
    fun onState(msg: String)
    fun onPartial(text: String)
    fun onEnd(text: String, heard: Boolean)
    fun onTimeout()
}

class Listener(private val ctx: Context, private val prefs: Prefs) {
    private val main = Handler(Looper.getMainLooper())
    private var sr: SpeechRecognizer? = null
    private var recBroken = false
    private var session = 0
    private var cb: ListenCallback? = null
    private var acc = StringBuilder()
    private var heard = false
    private var continuous = false
    private var startAt = 0L
    private var vadThread: Thread? = null
    @Volatile private var vadRun = false
    var mode = "" ; private set

    private fun hasMic() = ctx.checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED

    fun start(longAnswer: Boolean, callback: ListenCallback) {
        stop()
        val my = ++session
        cb = callback; acc = StringBuilder(); heard = false; continuous = longAnswer; startAt = System.currentTimeMillis()
        val m = prefs.listenMode
        when {
            !hasMic() -> manual(my)
            m == 0 && !recBroken && SpeechRecognizer.isRecognitionAvailable(ctx) -> recog(my)
            m <= 1 -> vad(my)
            else -> manual(my)
        }
        // 超时：等待 N 秒还没开口
        val wait = prefs.waitSec * 1000L
        main.postDelayed({ if (my == session && !heard) { stop(); callback.onTimeout() } }, wait)
        // 问答题最长 90 秒
        main.postDelayed({ if (my == session) finish(my) }, if (longAnswer) 90000L else 30000L)
    }

    fun finishNow() { finish(session) }

    private fun finish(my: Int) {
        if (my != session) return
        val c = cb; val t = acc.toString(); val h = heard || t.isNotEmpty()
        stop()
        c?.onEnd(t, h)
    }

    fun stop() {
        session++
        main.removeCallbacksAndMessages(null)
        vadRun = false
        try { sr?.cancel() } catch (_: Exception) {}
        try { sr?.destroy() } catch (_: Exception) {}
        sr = null
    }

    // ---- 语音识别
    private fun recog(my: Int) {
        mode = "识别"
        try {
            val r = SpeechRecognizer.createSpeechRecognizer(ctx); sr = r
            r.setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(p: Bundle?) { if (my == session) cb?.onState("🎤 请说出答案…") }
                override fun onBeginningOfSpeech() { if (my == session) { heard = true; cb?.onState("🎤 正在听…") } }
                override fun onRmsChanged(v: Float) {}
                override fun onBufferReceived(b: ByteArray?) {}
                override fun onEndOfSpeech() {}
                override fun onError(e: Int) {
                    if (my != session) return
                    when (e) {
                        SpeechRecognizer.ERROR_NO_MATCH, SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> {
                            if (acc.isNotEmpty()) { if (continuous && System.currentTimeMillis() - startAt < 85000) again(my) else finish(my) }
                            else again(my) // 继续等，直到超时
                        }
                        else -> { recBroken = true; vad(my) } // 识别服务不可用（如电视没有识别服务）→ 改用声音检测
                    }
                }
                override fun onResults(b: Bundle?) {
                    if (my != session) return
                    val t = b?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull().orEmpty()
                    if (t.isNotEmpty()) { heard = true; if (acc.isNotEmpty()) acc.append("，"); acc.append(t); cb?.onPartial(acc.toString()) }
                    if (continuous && System.currentTimeMillis() - startAt < 85000) again(my) else if (acc.isNotEmpty()) finish(my) else again(my)
                }
                override fun onPartialResults(b: Bundle?) {
                    if (my != session) return
                    val t = b?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull().orEmpty()
                    if (t.isNotEmpty()) { heard = true; cb?.onPartial((if (acc.isNotEmpty()) "$acc，" else "") + t) }
                }
                override fun onEvent(t: Int, b: Bundle?) {}
            })
            listenOnce(r)
        } catch (_: Exception) { recBroken = true; vad(my) }
    }

    private fun listenOnce(r: SpeechRecognizer) {
        val i = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "zh-CN")
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, ctx.packageName)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, if (continuous) 3000L else 1500L)
        }
        r.startListening(i)
    }

    private fun again(my: Int) {
        main.postDelayed({ if (my == session) { val r = sr; if (r != null) try { listenOnce(r) } catch (_: Exception) { finish(my) } } }, 150)
    }

    // ---- 声音检测（没有识别服务时）：检测到说话，再安静一会儿就算答完
    private fun vad(my: Int) {
        mode = "声音"
        try { sr?.destroy() } catch (_: Exception) {}
        sr = null
        val rate = 16000
        val bufSize = maxOf(AudioRecord.getMinBufferSize(rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT), 3200)
        val rec = try { AudioRecord(MediaRecorder.AudioSource.VOICE_RECOGNITION, rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, bufSize) } catch (_: Exception) { null }
        if (rec == null || rec.state != AudioRecord.STATE_INITIALIZED) { try { rec?.release() } catch (_: Exception) {}; manual(my); return }
        cb?.onState("🎤 请说出答案…（说完按“我答完了”）")
        vadRun = true
        val endSilence = if (continuous) 4000L else 2000L
        vadThread = Thread {
            val buf = ShortArray(1600)
            var noise = 0.0; var n = 0; var lastVoice = 0L; var any = false
            try {
                rec.startRecording()
                while (vadRun && my == session) {
                    val r = rec.read(buf, 0, buf.size)
                    if (r <= 0) continue
                    var s = 0.0; for (k in 0 until r) s += buf[k].toDouble() * buf[k]
                    val rms = Math.sqrt(s / r)
                    if (n < 4) { noise += rms; n++; continue }
                    val base = noise / 4
                    val now = System.currentTimeMillis()
                    if (rms > maxOf(base * 2.8, 500.0)) {
                        lastVoice = now
                        if (!any) { any = true; main.post { if (my == session) { heard = true; cb?.onState("🎤 听到了，继续说…") } } }
                    } else if (any && now - lastVoice > endSilence) {
                        main.post { if (my == session) finish(my) }
                        break
                    }
                }
            } catch (_: Exception) {
                main.post { if (my == session) manual(my) }
            } finally {
                try { rec.stop() } catch (_: Exception) {}
                rec.release()
            }
        }.also { it.start() }
    }

    // ---- 手动：孩子说完，按确认键 / 点“我答完了”
    private fun manual(my: Int) {
        mode = "手动"
        if (my == session) cb?.onState("🗣 请大声说出答案，说完按“我答完了”")
    }

    fun markHeard() { heard = true }
}

// ---------------- 判分
object Judge {
    private val cnNum = mapOf('零' to '0', '〇' to '0', '一' to '1', '二' to '2', '两' to '2', '三' to '3', '四' to '4', '五' to '5', '六' to '6', '七' to '7', '八' to '8', '九' to '9')
    fun norm(s: String): String {
        var t = s.replace(Regex("[\\s，。、！？,.!?；;：:“”\"'《》【】（）()·]"), "")
        // 简单中文数字：十二→12，二十→20，十→10
        t = t.replace(Regex("([一二三四五六七八九])十([一二三四五六七八九])")) { m -> "" + cnNum[m.groupValues[1][0]] + cnNum[m.groupValues[2][0]] }
            .replace(Regex("([一二三四五六七八九])十")) { m -> "" + cnNum[m.groupValues[1][0]] + "0" }
            .replace(Regex("十([一二三四五六七八九])")) { m -> "1" + cnNum[m.groupValues[1][0]] }
            .replace("十", "10")
        val sb = StringBuilder(); for (c in t) sb.append(cnNum[c] ?: c)
        return sb.toString().lowercase(Locale.ROOT)
    }
    fun hit(said: String, target: String): Boolean {
        val s = norm(said); val t = norm(target)
        if (t.isEmpty()) return false
        if (s.contains(t)) return true
        if (t.length <= 2) return false
        // 字重合率
        val used = BooleanArray(s.length); var m = 0
        for (c in t) { val i = s.indices.firstOrNull { !used[it] && s[it] == c }; if (i != null) { used[i] = true; m++ } }
        return m >= Math.ceil(t.length * 0.75)
    }
    fun fill(said: String, blank: String, alts: List<String>) = hit(said, blank) || alts.any { hit(said, it) }
    fun key(said: String, item: Item, i: Int) = hit(said, item.keys[i]) || (item.syn.getOrNull(i) ?: emptyList()).any { hit(said, it) }
}
