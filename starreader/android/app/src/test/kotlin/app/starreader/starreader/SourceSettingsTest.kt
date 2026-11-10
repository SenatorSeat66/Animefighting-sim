package app.starreader.starreader

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import androidx.preference.Preference
import androidx.preference.PreferenceScreen
import eu.kanade.tachiyomi.source.ConfigurableSource
import eu.kanade.tachiyomi.source.Source
import eu.kanade.tachiyomi.source.online.HttpSource
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class SourceSettingsTest {
    @Before
    fun isolateApplicationContext() {
        // Robolectric replaces the Application between tests; production keeps one per process.
        // Drop the previous test's host so Injekt and the preference Activity share this app.
        ExtensionHost::class.java.getDeclaredField("instance").apply {
            isAccessible = true
            set(null, null)
        }
    }

    class PreferenceHostActivity : AppCompatActivity() {
        override fun onCreate(state: Bundle?) {
            setTheme(R.style.SourceSettingsTheme)
            super.onCreate(state)
        }
    }

    @Test
    fun sourcePreferencesRemainScopedAndMissingHostClassesShowAnError() {
        val host = ExtensionHost.get(RuntimeEnvironment.getApplication())
        val field =
            ExtensionHost::class.java.getDeclaredField("sources").apply { isAccessible = true }
        @Suppress("UNCHECKED_CAST") val sources = field.get(host) as MutableMap<String, Source>
        for (missingApi in listOf(false, true)) {
            val source =
                object : HttpSource(), ConfigurableSource {
                    override val name = "Preference contract fixture"
                    override val lang = "en"
                    override val baseUrl = "https://example.invalid"
                    override val supportsLatest = false

                    override fun setupPreferenceScreen(screen: PreferenceScreen) {
                        if (missingApi) throw NoClassDefFoundError("UnsupportedHostPreference")
                        screen.addPreference(
                            Preference(screen.context).apply {
                                key = "quality"
                                title = "Image quality"
                            }
                        )
                    }
                }
            sources[source.id.toString()] = source
            val controller = Robolectric.buildActivity(PreferenceHostActivity::class.java).setup()
            try {
                val activity = controller.get()
                val fragment =
                    SourceSettingsActivity.SettingsFragment().apply {
                        arguments = Bundle().apply { putString("source", source.id.toString()) }
                    }
                activity.supportFragmentManager
                    .beginTransaction()
                    .replace(android.R.id.content, fragment)
                    .commitNow()
                if (missingApi) {
                    assertEquals(
                        "This setting needs an unsupported host feature",
                        fragment.preferenceScreen.getPreference(0).title,
                    )
                    assertTrue(
                        fragment.preferenceScreen
                            .getPreference(0)
                            .summary
                            .toString()
                            .contains("UnsupportedHostPreference")
                    )
                } else {
                    source.getSourcePreferences().edit().putString("quality", "high").commit()
                    assertEquals(
                        "high",
                        fragment.preferenceManager.sharedPreferences?.getString("quality", null),
                    )
                    assertEquals(
                        "Image quality",
                        fragment.findPreference<Preference>("quality")?.title,
                    )
                }
            } finally {
                controller.pause().stop().destroy()
                sources.remove(source.id.toString())
            }
        }
    }
}
