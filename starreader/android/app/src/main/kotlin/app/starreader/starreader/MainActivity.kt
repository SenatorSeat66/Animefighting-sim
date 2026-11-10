package app.starreader.starreader

import android.view.KeyEvent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var readerChannel: MethodChannel? = null
    private var volumeNavigation = false
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        readerChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.starreader/reader")
        readerChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "configure" -> {
                    volumeNavigation = call.argument<Boolean>("volume") == true
                    if (call.argument<Boolean>("awake") == true) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    result.success(null)
                }
                "brightness" -> {
                    val value = (call.arguments as? Number)?.toFloat() ?: -1f
                    window.attributes = window.attributes.apply { screenBrightness = value.coerceIn(-1f, 1f) }
                    result.success(null)
                }
                "reset" -> { resetReader(); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }
    private fun resetReader() {
        volumeNavigation = false
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.attributes = window.attributes.apply { screenBrightness = -1f }
    }
    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (volumeNavigation && (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN || keyCode == KeyEvent.KEYCODE_VOLUME_UP)) {
            readerChannel?.invokeMethod(if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) "next" else "previous", null)
            return true
        }
        return super.onKeyDown(keyCode, event)
    }
    override fun onDestroy() { resetReader(); readerChannel?.setMethodCallHandler(null); super.onDestroy() }
}
