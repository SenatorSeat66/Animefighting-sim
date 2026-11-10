package app.starreader.starreader

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import java.lang.ref.WeakReference

/** User-initiated downloads only; never starts itself after boot or process death. */
class DownloadService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null
    private var stopping = false
    private var title = "Preparing your chapters"
    private var done = 0
    private var total = 0
    private var remaining = 0

    override fun onCreate() {
        super.onCreate()
        instance = WeakReference(this)
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26)
            manager.createNotificationChannel(
                NotificationChannel(
                        CHANNEL,
                        "Chapter downloads",
                        NotificationManager.IMPORTANCE_LOW,
                    )
                    .apply {
                        description = "Progress and pause controls for downloads you start"
                        setShowBadge(false)
                    }
            )
        val notification = notification()
        if (Build.VERSION.SDK_INT >= 29)
            startForeground(ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        else startForeground(ID, notification)
        wakeLock =
            (getSystemService(POWER_SERVICE) as PowerManager)
                .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "StarReader:downloads")
                .apply {
                    setReferenceCounted(false)
                    acquire(10 * 60 * 1000L)
                }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == PAUSE) {
            (application as StarReaderApplication).pauseDownloads()
            stopping = true
            stopSelf()
        }
        return START_NOT_STICKY
    }

    private fun notification(): Notification {
        val open =
            PendingIntent.getActivity(
                this,
                10,
                Intent(this, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        val pause =
            PendingIntent.getService(
                this,
                11,
                Intent(this, DownloadService::class.java).setAction(PAUSE),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        return NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_star_notification)
            .setContentTitle(title.take(100))
            .setContentText(
                if (total > 0) "$done / $total pages · $remaining chapters left"
                else "Connecting to your source"
            )
            .setContentIntent(open)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setProgress(
                total.coerceAtLeast(1),
                done.coerceIn(0, total.coerceAtLeast(1)),
                total == 0,
            )
            .addAction(0, "Pause downloads", pause)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .build()
    }

    private fun progress(name: String, completed: Int, count: Int, queued: Int) {
        title = name
        done = completed
        total = count
        remaining = queued
        // Renew the bounded lock while pages are actively completing.
        wakeLock?.acquire(10 * 60 * 1000L)
        getSystemService(NotificationManager::class.java).notify(ID, notification())
    }

    override fun onTimeout(startId: Int, fgsType: Int) {
        (application as StarReaderApplication).pauseDownloads()
        stopping = true
        stopSelf()
    }

    override fun onDestroy() {
        if (!stopping) (application as StarReaderApplication).pauseDownloads()
        if (wakeLock?.isHeld == true) wakeLock?.release()
        instance.clear()
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        const val START = "app.starreader.DOWNLOAD_START"
        const val PAUSE = "app.starreader.DOWNLOAD_PAUSE"
        private const val CHANNEL = "starreader_downloads"
        private const val ID = 2002
        private var instance = WeakReference<DownloadService>(null)

        fun update(title: String, done: Int, total: Int, remaining: Int) {
            instance.get()?.progress(title, done, total, remaining)
        }

        fun finish(context: Context) {
            instance.get()?.stopping = true
            context.stopService(Intent(context, DownloadService::class.java))
        }
    }
}
