package app.starreader.starreader

import android.content.Intent
import android.content.pm.ServiceInfo
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = StarReaderApplication::class)
class DownloadServiceTest {
    @Test
    fun foregroundNotificationHasPauseActionAndTimeoutStopsService() {
        val controller = Robolectric.buildService(DownloadService::class.java).create()
        val service = controller.get()
        val shadow = shadowOf(service)
        assertEquals(2002, shadow.lastForegroundNotificationId)
        assertNotNull(shadow.lastForegroundNotification)
        assertEquals("Pause downloads", shadow.lastForegroundNotification.actions.single().title)
        assertEquals(
            android.app.Service.START_NOT_STICKY,
            service.onStartCommand(Intent().setAction(DownloadService.START), 0, 1),
        )
        DownloadService.update("Fixture title", 2, 8, 3)
        service.onTimeout(1, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        assertTrue(shadow.isStoppedBySelf)
        controller.destroy()
        assertTrue(shadow.isForegroundStopped)
    }
}
