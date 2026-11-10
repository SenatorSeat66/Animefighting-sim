package app.starreader.starreader

import android.app.Application
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference

/** One Flutter isolate owns the SQLite queue, including while its activity detaches. */
class StarReaderApplication : Application() {
    private var cachedEngine: FlutterEngine? = null
    var updateBridge: LibraryUpdateBridge? = null
        private set

    private var downloadChannel: MethodChannel? = null
    var activity = WeakReference<MainActivity>(null)

    fun engine(): FlutterEngine {
        cachedEngine?.let {
            return it
        }
        check(Looper.myLooper() == Looper.getMainLooper())
        return FlutterEngine(this).also { engine ->
            cachedEngine = engine
            updateBridge = LibraryUpdateBridge(this, engine)
            MethodChannel(engine.dartExecutor.binaryMessenger, "app.starreader/extensions")
                .setMethodCallHandler { call, result ->
                    ExtensionHost.get(this).handle(call, result)
                }
            downloadChannel =
                MethodChannel(engine.dartExecutor.binaryMessenger, "app.starreader/downloads")
                    .also { channel ->
                        channel.setMethodCallHandler { call, result ->
                            try {
                                when (call.method) {
                                    "start" -> {
                                        activity.get()?.requestDownloadNotifications()
                                        val intent =
                                            Intent(this, DownloadService::class.java)
                                                .setAction(DownloadService.START)
                                        if (Build.VERSION.SDK_INT >= 26)
                                            startForegroundService(intent)
                                        else startService(intent)
                                        result.success(null)
                                    }
                                    "update" -> {
                                        DownloadService.update(
                                            call.argument<String>("title").orEmpty(),
                                            call.argument<Int>("done") ?: 0,
                                            call.argument<Int>("total") ?: 0,
                                            call.argument<Int>("remaining") ?: 0,
                                        )
                                        result.success(null)
                                    }
                                    "stop" -> {
                                        DownloadService.finish(this)
                                        result.success(null)
                                    }
                                    "notificationSettings" -> {
                                        val intent =
                                            if (Build.VERSION.SDK_INT >= 26)
                                                Intent(
                                                        android.provider.Settings
                                                            .ACTION_APP_NOTIFICATION_SETTINGS
                                                    )
                                                    .putExtra(
                                                        android.provider.Settings.EXTRA_APP_PACKAGE,
                                                        packageName,
                                                    )
                                            else
                                                Intent(
                                                    android.provider.Settings
                                                        .ACTION_APPLICATION_DETAILS_SETTINGS,
                                                    android.net.Uri.parse("package:$packageName"),
                                                )
                                        startActivity(
                                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                        )
                                        result.success(null)
                                    }
                                    else -> result.notImplemented()
                                }
                            } catch (e: Exception) {
                                result.error("download_service", e.message, null)
                            }
                        }
                    }
            engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        }
    }

    fun pauseDownloads() {
        Handler(Looper.getMainLooper()).post { downloadChannel?.invokeMethod("pause", null) }
    }
}
