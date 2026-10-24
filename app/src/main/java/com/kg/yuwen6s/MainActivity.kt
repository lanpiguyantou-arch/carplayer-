package com.kg.yuwen6s

import android.app.Activity
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.speech.tts.TextToSpeech
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.WebViewClient
import java.util.Locale

class MainActivity : Activity() {
    private lateinit var web: WebView
    private var tts: TextToSpeech? = null

    inner class Bridge {
        @JavascriptInterface fun speak(t: String) {
            tts?.setSpeechRate(0.85f)
            tts?.speak(t, TextToSpeech.QUEUE_FLUSH, null, "yw")
        }
        @JavascriptInterface fun stop() { tts?.stop() }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.statusBarColor = Color.parseColor("#B8322A")
        tts = TextToSpeech(this) { st -> if (st == TextToSpeech.SUCCESS) tts?.setLanguage(Locale.SIMPLIFIED_CHINESE) }
        web = WebView(this)
        web.settings.javaScriptEnabled = true
        web.settings.domStorageEnabled = true
        web.settings.textZoom = 100
        web.webViewClient = WebViewClient()
        web.webChromeClient = WebChromeClient()
        web.addJavascriptInterface(Bridge(), "Native")
        setContentView(web)
        web.loadUrl("file:///android_asset/www/index.html")
    }

    override fun onBackPressed() {
        web.evaluateJavascript("(function(){var b=document.getElementById('back');if(b&&b.style.visibility!=='hidden'){App.back();return 1}return 0})()") { r ->
            if (r != "1") super.onBackPressed()
        }
    }

    override fun onDestroy() { tts?.shutdown(); super.onDestroy() }
}
