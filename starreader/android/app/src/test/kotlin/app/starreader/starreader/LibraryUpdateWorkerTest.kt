package app.starreader.starreader

import androidx.work.NetworkType
import java.util.concurrent.TimeUnit
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class LibraryUpdateWorkerTest {
    @Test
    fun scheduledUpdatesRespectOptInCadenceAndResourceConstraints() {
        val work = LibraryUpdateWorker.request(12, true).workSpec
        assertEquals(TimeUnit.HOURS.toMillis(12), work.intervalDuration)
        assertEquals(TimeUnit.HOURS.toMillis(12), work.initialDelay)
        assertEquals(NetworkType.UNMETERED, work.constraints.requiredNetworkType)
        assertTrue(work.constraints.requiresBatteryNotLow())
        assertEquals(
            NetworkType.CONNECTED,
            LibraryUpdateWorker.request(6, false).workSpec.constraints.requiredNetworkType,
        )
    }

    @Test(expected = IllegalArgumentException::class)
    fun disabledScheduleCannotCreateBackgroundWork() {
        LibraryUpdateWorker.request(0, true)
    }
}
