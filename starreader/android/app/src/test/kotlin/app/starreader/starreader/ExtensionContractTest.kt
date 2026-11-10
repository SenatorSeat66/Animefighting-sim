package app.starreader.starreader

import android.content.Context
import eu.kanade.tachiyomi.network.NetworkHelper
import eu.kanade.tachiyomi.source.SourceFactory
import eu.kanade.tachiyomi.source.model.*
import eu.kanade.tachiyomi.source.online.HttpSource
import java.io.File
import java.net.URLClassLoader
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.Json
import org.junit.Assert.*
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import rx.Observable
import uy.kohesive.injekt.Injekt
import uy.kohesive.injekt.api.addSingleton

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], manifest = Config.NONE)
class ExtensionContractTest {
    private fun <T> withClock(block: () -> T): T {
        // Robolectric's elapsedRealtime is frozen; real rate limiters need its clock to advance.
        val ticker = java.util.concurrent.Executors.newSingleThreadScheduledExecutor()
        ticker.scheduleAtFixedRate(
            {
                org.robolectric.shadows.ShadowSystemClock.advanceBy(
                    java.time.Duration.ofMillis(200)
                )
            },
            0,
            200,
            java.util.concurrent.TimeUnit.MILLISECONDS,
        )
        return try {
            block()
        } finally {
            ticker.shutdownNow()
        }
    }

    private fun configure() {
        val context: Context = RuntimeEnvironment.getApplication()
        Injekt.addSingleton(context)
        Injekt.addSingleton<android.app.Application>(RuntimeEnvironment.getApplication())
        Injekt.addSingleton(NetworkHelper(context))
        Injekt.addSingleton(
            Json {
                ignoreUnknownKeys = true
                explicitNulls = false
            }
        )
    }

    @Test
    fun legacyRxSourcesBridgeToSuspendApi() = runBlocking {
        configure()
        val source =
            object : HttpSource() {
                override val name = "Contract fixture"
                override val lang = "en"
                override val baseUrl = "https://example.invalid"
                override val supportsLatest = false

                @Suppress("DEPRECATION")
                override fun fetchPopularManga(page: Int): Observable<MangasPage> =
                    Observable.just(
                        MangasPage(
                            listOf(
                                SManga.create().apply {
                                    url = "/book"
                                    title = "Fixture"
                                }
                            ),
                            false,
                        )
                    )

                @Suppress("DEPRECATION")
                override fun fetchMangaDetails(manga: SManga): Observable<SManga> =
                    Observable.just(manga.copy().apply { description = "Details" })

                @Suppress("DEPRECATION")
                override fun fetchChapterList(manga: SManga): Observable<List<SChapter>> =
                    Observable.just(
                        listOf(
                            SChapter.create().apply {
                                url = "/chapter"
                                name = "One"
                            }
                        )
                    )

                @Suppress("DEPRECATION")
                override fun fetchPageList(chapter: SChapter): Observable<List<Page>> =
                    Observable.just(listOf(Page(0, imageUrl = "$baseUrl/page.png")))
            }
        val page = source.getPopularManga(1)
        assertEquals("Fixture", page.mangas.single().title)
        val update = source.getMangaUpdate(page.mangas.single(), emptyList(), true, true)
        assertEquals("Details", update.manga.description)
        assertEquals("One", update.chapters.single().name)
        assertEquals(
            "https://example.invalid/page.png",
            source.getPageList(update.chapters.single()).single().imageUrl,
        )
        assertEquals(source.id, source.id)
    }

    @Test
    fun chapterIdentityMatchesBackupAndSeparatesRelativeUrlsAcrossTitles() {
        val first = ExtensionIdentity.chapter(ExtensionIdentity.manga(42, "/manga-1"), "/chapter")
        val second = ExtensionIdentity.chapter(ExtensionIdentity.manga(42, "/manga-2"), "/chapter")
        assertEquals("ext:42:L21hbmdhLTE:L2NoYXB0ZXI", first)
        assertNotEquals(first, second)
        assertEquals("/chapter", ExtensionIdentity.decodeTail(first))
        assertEquals("/chapter", ExtensionIdentity.decodeTail("ext:42:L2NoYXB0ZXI"))
    }

    /** Opt-in ABI smoke check against a publisher JAR; no emulator or device involved. */
    @Test
    fun publishedMangaDexExtensionLoadsAndExposesFilters() {
        val path = System.getenv("STARREADER_EXTENSION_JAR")
        assumeTrue("Set STARREADER_EXTENSION_JAR to a verified publisher JAR", path != null)
        configure()
        URLClassLoader(arrayOf(File(path!!).toURI().toURL()), javaClass.classLoader).use { loader ->
            val factory =
                loader
                    .loadClass("keiyoushi.source.Generated")
                    .getDeclaredConstructor()
                    .newInstance() as SourceFactory
            val sources = factory.createSources()
            assertTrue(sources.isNotEmpty())
            val english = sources.first { it.lang == "en" } as HttpSource
            assertEquals("MangaDex", english.name)
            assertTrue(english.id > 0)
            assertTrue(english.getFilterList().isNotEmpty())
            assertTrue(english.headers.size > 0)
            if (System.getenv("STARREADER_LIVE_EXTENSION_PROBE") == "1")
                withClock {
                    runBlocking {
                        val result = english.getPopularManga(1)
                        assertTrue(result.mangas.isNotEmpty())
                        println(
                            "Live publisher source catalogue: ${result.mangas.size} titles, more=${result.hasNextPage}"
                        )
                        var verified = false
                        for (manga in result.mangas.take(5)) {
                            val update = english.getMangaUpdate(manga, emptyList(), true, true)
                            if (update.chapters.isEmpty()) continue
                            val pages = english.getPageList(update.chapters.first())
                            if (pages.isEmpty()) continue
                            val first = pages.first()
                            if (first.imageUrl.isNullOrBlank())
                                first.imageUrl = english.getImageUrl(first)
                            english.getImage(first).use { response ->
                                assertTrue(response.isSuccessful)
                                val bytes = response.body.bytes()
                                assertTrue(bytes.size > 12)
                                assertTrue((bytes[0].toInt() and 255) in listOf(255, 137, 82, 71))
                                println(
                                    "Live publisher source details: ${update.chapters.size} chapters; ${pages.size} pages; first image ${bytes.size} bytes"
                                )
                            }
                            verified = true
                            break
                        }
                        assertTrue(
                            "A popular title should have at least one readable chapter",
                            verified,
                        )
                    }
                }
            println(
                "Publisher extension ABI: ${sources.size} sources; English ${english.id}; ${english.getFilterList().size} filters"
            )
        }
    }
}
