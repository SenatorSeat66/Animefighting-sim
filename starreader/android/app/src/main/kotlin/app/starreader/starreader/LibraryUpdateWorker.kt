package app.starreader.starreader

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.work.*
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.TimeUnit
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.*

class LibraryUpdateBridge(private val app: StarReaderApplication, engine: FlutterEngine) {
    private val ready = CompletableDeferred<Unit>()
    private val channel =
        MethodChannel(engine.dartExecutor.binaryMessenger, "app.starreader/library_updates")

    init {
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "ready" -> {
                        ready.complete(Unit)
                        result.success(null)
                    }
                    "configure" -> {
                        val hours = call.argument<Int>("hours") ?: 0
                        require(hours in listOf(0, 6, 12, 24, 72))
                        val manager = WorkManager.getInstance(app)
                        app.getSharedPreferences("library_updates", Context.MODE_PRIVATE)
                            .edit()
                            .putBoolean("notify", call.argument<Boolean>("notify") == true)
                            .apply()
                        if (call.argument<Boolean>("notify") == true)
                            app.activity.get()?.requestDownloadNotifications()
                        val operation =
                            if (hours == 0) manager.cancelUniqueWork(LibraryUpdateWorker.NAME)
                            else
                                manager.enqueueUniquePeriodicWork(
                                    LibraryUpdateWorker.NAME,
                                    ExistingPeriodicWorkPolicy.UPDATE,
                                    LibraryUpdateWorker.request(
                                        hours,
                                        call.argument<Boolean>("wifi") != false,
                                    ),
                                )
                        operation.result.addListener(
                            {
                                try {
                                    operation.result.get()
                                    result.success(null)
                                } catch (e: Exception) {
                                    result.error(
                                        "update_schedule",
                                        e.cause?.message ?: e.message,
                                        null,
                                    )
                                }
                            },
                            androidx.core.content.ContextCompat.getMainExecutor(app),
                        )
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("update_schedule", e.message, null)
            }
        }
    }

    suspend fun run(id: String): Map<*, *> {
        withTimeout(60_000) { ready.await() }
        return withContext(Dispatchers.Main) {
            suspendCancellableCoroutine { continuation ->
                channel.invokeMethod(
                    "run",
                    mapOf("id" to id),
                    object : MethodChannel.Result {
                        override fun success(value: Any?) {
                            if (continuation.isActive)
                                continuation.resume(value as? Map<*, *> ?: emptyMap<String, Any>())
                        }

                        override fun error(code: String, message: String?, details: Any?) {
                            if (continuation.isActive)
                                continuation.resumeWithException(
                                    IllegalStateException(message ?: code)
                                )
                        }

                        override fun notImplemented() {
                            error("missing", "Library update bridge unavailable", null)
                        }
                    },
                )
                continuation.invokeOnCancellation {
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        channel.invokeMethod("cancel", mapOf("id" to id))
                    }
                }
            }
        }
    }
}

class LibraryUpdateWorker(context: Context, parameters: WorkerParameters) :
    CoroutineWorker(context, parameters) {
    override suspend fun doWork(): Result {
        return try {
            val app = applicationContext as StarReaderApplication
            val bridge =
                withContext(Dispatchers.Main) {
                    app.engine()
                    app.updateBridge!!
                }
            val report = withTimeout(8 * 60_000L) { bridge.run(id.toString()) }
            if (report["busy"] == true) return Result.retry()
            val found = (report["newChapters"] as? Number)?.toInt() ?: 0
            if (found > 0) notifyChapters(found)
            Result.success(
                workDataOf(
                    "newChapters" to found,
                    "failed" to ((report["failed"] as? Number)?.toInt() ?: 0),
                )
            )
        } catch (e: TimeoutCancellationException) {
            if (runAttemptCount < 2) Result.retry() else Result.failure()
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            if (runAttemptCount < 2) Result.retry() else Result.failure()
        }
    }

    private fun notifyChapters(count: Int) {
        if (
            !applicationContext
                .getSharedPreferences("library_updates", Context.MODE_PRIVATE)
                .getBoolean("notify", false)
        )
            return
        if (
            Build.VERSION.SDK_INT >= 33 &&
                androidx.core.content.ContextCompat.checkSelfPermission(
                    applicationContext,
                    android.Manifest.permission.POST_NOTIFICATIONS,
                ) != android.content.pm.PackageManager.PERMISSION_GRANTED
        )
            return
        val manager = applicationContext.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26)
            manager.createNotificationChannel(
                NotificationChannel(
                    "library_updates",
                    "New chapters",
                    NotificationManager.IMPORTANCE_DEFAULT,
                )
            )
        val open =
            PendingIntent.getActivity(
                applicationContext,
                20,
                Intent(applicationContext, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        manager.notify(
            2003,
            NotificationCompat.Builder(applicationContext, "library_updates")
                .setSmallIcon(R.drawable.ic_star_notification)
                .setContentTitle("Your next chapter is here")
                .setContentText("$count new chapters in your library")
                .setContentIntent(open)
                .setAutoCancel(true)
                .build(),
        )
    }

    companion object {
        const val NAME = "starreader-library-updates"

        fun request(hours: Int, wifi: Boolean): PeriodicWorkRequest {
            require(hours in listOf(6, 12, 24, 72))
            return PeriodicWorkRequestBuilder<LibraryUpdateWorker>(hours.toLong(), TimeUnit.HOURS)
                .setInitialDelay(hours.toLong(), TimeUnit.HOURS)
                .setConstraints(
                    Constraints.Builder()
                        .setRequiredNetworkType(
                            if (wifi) NetworkType.UNMETERED else NetworkType.CONNECTED
                        )
                        .setRequiresBatteryNotLow(true)
                        .build()
                )
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 15, TimeUnit.MINUTES)
                .build()
        }
    }
}
