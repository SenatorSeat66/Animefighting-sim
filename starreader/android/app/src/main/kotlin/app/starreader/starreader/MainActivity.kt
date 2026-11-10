package app.starreader.starreader

import android.view.KeyEvent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun provideFlutterEngine(context: android.content.Context): FlutterEngine =
        (application as StarReaderApplication).engine()

    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun onResume() {
        super.onResume()
        (application as StarReaderApplication).activity = java.lang.ref.WeakReference(this)
    }

    fun requestDownloadNotifications() {
        if (
            android.os.Build.VERSION.SDK_INT >= 33 &&
                checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) !=
                    android.content.pm.PackageManager.PERMISSION_GRANTED
        ) {
            val preferences = getSharedPreferences("permissions", MODE_PRIVATE)
            if (!preferences.getBoolean("download_notifications_requested", false)) {
                preferences.edit().putBoolean("download_notifications_requested", true).apply()
                requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 2002)
            }
        }
    }

    private var readerChannel: MethodChannel? = null
    private var volumeNavigation = false
    private var reading = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        (application as StarReaderApplication).activity = java.lang.ref.WeakReference(this)
        readerChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.starreader/reader")
        readerChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "configure" -> {
                    reading = true
                    ReaderWindow.enter(window)
                    volumeNavigation = call.argument<Boolean>("volume") == true
                    if (call.argument<Boolean>("awake") == true)
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    result.success(null)
                }
                "brightness" -> {
                    val value = (call.arguments as? Number)?.toFloat() ?: -1f
                    window.attributes =
                        window.attributes.apply { screenBrightness = value.coerceIn(-1f, 1f) }
                    result.success(null)
                }
                "reset" -> {
                    resetReader()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus && reading) ReaderWindow.enter(window)
    }

    private fun resetReader() {
        reading = false
        ReaderWindow.leave(window)
        volumeNavigation = false
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.attributes = window.attributes.apply { screenBrightness = -1f }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (
            volumeNavigation &&
                (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN || keyCode == KeyEvent.KEYCODE_VOLUME_UP)
        ) {
            readerChannel?.invokeMethod(
                if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) "next" else "previous",
                null,
            )
            return true
        }
        return super.onKeyDown(keyCode, event)
    }

    override fun onDestroy() {
        resetReader()
        val app = application as StarReaderApplication
        if (app.activity.get() === this) {
            readerChannel?.setMethodCallHandler(null)
            app.activity.clear()
        }
        super.onDestroy()
    }
}
