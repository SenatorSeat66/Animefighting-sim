package app.starreader.starreader

import android.annotation.SuppressLint
import android.net.Uri
import android.os.Bundle
import android.webkit.*
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback

/** User-controlled source login. No injected scripts or challenge bypass. */
class SourceBrowserActivity : ComponentActivity() {
    private lateinit var web: WebView

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        val url = intent.getStringExtra("url").orEmpty()
        if (Uri.parse(url).scheme !in listOf("https", "http")) {
            finish()
            return
        }
        val layout =
            LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                fitsSystemWindows = true
            }
        val bar = LinearLayout(this)
        bar.addView(
            Button(this).apply {
                text = "Done"
                setOnClickListener { finish() }
            }
        )
        val location =
            TextView(this).apply {
                text = Uri.parse(url).host
                setPadding(12, 20, 8, 12)
            }
        bar.addView(location, LinearLayout.LayoutParams(0, -2, 1f))
        layout.addView(bar)
        web = WebView(this)
        web.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            allowFileAccess = false
            allowContentAccess = false
            mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
        }
        intent.getStringExtra("userAgent")?.let { web.settings.userAgentString = it }
        CookieManager.getInstance().setAcceptCookie(true)
        web.webViewClient =
            object : WebViewClient() {
                override fun shouldOverrideUrlLoading(
                    view: WebView,
                    request: WebResourceRequest,
                ): Boolean = request.url.scheme !in listOf("https", "http")

                override fun onPageFinished(view: WebView, url: String) {
                    location.text = Uri.parse(url).host
                    CookieManager.getInstance().flush()
                }
            }
        layout.addView(web, LinearLayout.LayoutParams(-1, 0, 1f))
        setContentView(layout)
        onBackPressedDispatcher.addCallback(
            this,
            object : OnBackPressedCallback(true) {
                override fun handleOnBackPressed() {
                    if (web.canGoBack()) web.goBack() else finish()
                }
            },
        )
        web.loadUrl(url)
    }

    override fun onDestroy() {
        if (::web.isInitialized) {
            web.stopLoading()
            web.destroy()
        }
        super.onDestroy()
    }
}
