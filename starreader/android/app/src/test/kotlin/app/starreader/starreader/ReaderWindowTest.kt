package app.starreader.starreader

import android.app.Activity
import android.os.Build
import android.view.View
import android.view.WindowInsets
import android.widget.FrameLayout
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsControllerCompat
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.util.ReflectionHelpers

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [24, 35, 36])
class ReaderWindowTest {
    @Suppress("DEPRECATION")
    @Test
    fun readerRequestsImmersiveBarsAndRestoresThemOnExit() {
        val activity = Robolectric.buildActivity(Activity::class.java).setup()
        try {
            val window = activity.get().window
            activity.get().setContentView(FrameLayout(activity.get()))
            ReaderWindow.enter(window)
            val controller = WindowCompat.getInsetsController(window, window.decorView)
            assertEquals(
                WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE,
                controller.systemBarsBehavior,
            )
            if (Build.VERSION.SDK_INT >= 30) {
                val requested =
                    ReflectionHelpers.callInstanceMethod<Int>(
                        window.insetsController,
                        "getRequestedVisibleTypes",
                    )
                assertEquals(
                    0,
                    requested and
                        (WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars()),
                )
            } else {
                assertTrue(
                    window.decorView.systemUiVisibility and View.SYSTEM_UI_FLAG_HIDE_NAVIGATION != 0
                )
            }
            ReaderWindow.leave(window)
            if (Build.VERSION.SDK_INT >= 30) {
                val requested =
                    ReflectionHelpers.callInstanceMethod<Int>(
                        window.insetsController,
                        "getRequestedVisibleTypes",
                    )
                val bars = WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars()
                assertEquals(bars, requested and bars)
            } else {
                assertEquals(
                    0,
                    window.decorView.systemUiVisibility and View.SYSTEM_UI_FLAG_HIDE_NAVIGATION,
                )
            }
        } finally {
            activity.pause().stop().destroy()
        }
    }
}
