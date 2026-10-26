package com.kg.yibiao

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Toast

class MainActivity : Activity() {
    private lateinit var web: WebView

    inner class Bridge {
        @JavascriptInterface fun setDue(json: String) {
            getSharedPreferences("zs", MODE_PRIVATE).edit().putString("due", json).apply()
            Remind.schedule(this@MainActivity)
        }
        @JavascriptInterface fun shareFile(name: String, data: String) {
            runOnUiThread {
                try {
                    if (Build.VERSION.SDK_INT >= 29) {
                        val cv = ContentValues().apply {
                            put(MediaStore.Downloads.DISPLAY_NAME, name)
                            put(MediaStore.Downloads.MIME_TYPE, "text/csv")
                        }
                        val uri: Uri? = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, cv)
                        if (uri != null) {
                            contentResolver.openOutputStream(uri)?.use { it.write(data.toByteArray(Charsets.UTF_8)) }
                            Toast.makeText(this@MainActivity, "已保存到 下载/Download/$name", Toast.LENGTH_LONG).show()
                            val i = Intent(Intent.ACTION_SEND).apply {
                                type = "text/csv"; putExtra(Intent.EXTRA_STREAM, uri)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            startActivity(Intent.createChooser(i, "发送台账"))
                            return@runOnUiThread
                        }
                    }
                    val i = Intent(Intent.ACTION_SEND).apply { type = "text/plain"; putExtra(Intent.EXTRA_TEXT, data); putExtra(Intent.EXTRA_SUBJECT, name) }
                    startActivity(Intent.createChooser(i, "发送台账"))
                } catch (e: Exception) {
                    Toast.makeText(this@MainActivity, "导出失败：" + e.message, Toast.LENGTH_LONG).show()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.statusBarColor = Color.parseColor("#0E4C7A")
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission("android.permission.POST_NOTIFICATIONS") != android.content.pm.PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf("android.permission.POST_NOTIFICATIONS"), 1)
        }
        web = WebView(this)
        web.settings.javaScriptEnabled = true
        web.settings.domStorageEnabled = true
        web.settings.allowFileAccess = true
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
}
