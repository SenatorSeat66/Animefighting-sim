package app.starreader.starreader

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import androidx.preference.PreferenceFragmentCompat
import eu.kanade.tachiyomi.source.ConfigurableSource
import kotlinx.coroutines.*

class SourceSettingsActivity : AppCompatActivity() {
    private val loadingScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    override fun onCreate(state: Bundle?) {
        super.onCreate(null) // Rebuild plugin preferences after its source is loaded.
        supportActionBar?.setDisplayHomeAsUpEnabled(true)
        title = "Source settings"
        loadingScope.launch {
            try {
                withContext(Dispatchers.IO) {
                    ExtensionHost.get(this@SourceSettingsActivity).prepare()
                }
                if (!isFinishing && !isDestroyed)
                    supportFragmentManager
                        .beginTransaction()
                        .replace(
                            android.R.id.content,
                            SettingsFragment().apply { arguments = intent.extras },
                        )
                        .commit()
            } catch (e: Exception) {
                if (e is CancellationException) throw e
                android.widget.Toast.makeText(
                        this@SourceSettingsActivity,
                        "Source settings unavailable: ${e.message}",
                        android.widget.Toast.LENGTH_LONG,
                    )
                    .show()
                finish()
            }
        }
    }

    override fun onDestroy() {
        loadingScope.cancel()
        super.onDestroy()
    }

    override fun onSupportNavigateUp(): Boolean {
        finish()
        return true
    }

    class SettingsFragment : PreferenceFragmentCompat() {
        override fun onCreatePreferences(state: Bundle?, rootKey: String?) {
            val source =
                ExtensionHost.get(requireContext())
                    .getSource(arguments?.getString("source").orEmpty()) as? ConfigurableSource
            preferenceManager.sharedPreferencesName = "source_${source?.id}"
            preferenceScreen = preferenceManager.createPreferenceScreen(requireContext())
            if (source == null) {
                activity?.finish()
                return
            }
            try {
                source.setupPreferenceScreen(preferenceScreen)
            } catch (e: Throwable) {
                if (e is VirtualMachineError || e is ThreadDeath) throw e
                androidx.preference.Preference(requireContext()).also {
                    it.title = "This setting needs an unsupported host feature"
                    it.summary = e.message
                    preferenceScreen.addPreference(it)
                }
            }
        }
    }
}
