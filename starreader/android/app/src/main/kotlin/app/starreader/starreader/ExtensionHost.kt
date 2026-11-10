package app.starreader.starreader

import android.content.Context
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.os.Build
import eu.kanade.tachiyomi.network.NetworkHelper
import eu.kanade.tachiyomi.source.ConfigurableSource
import eu.kanade.tachiyomi.source.Source
import eu.kanade.tachiyomi.source.SourceFactory
import eu.kanade.tachiyomi.source.model.*
import eu.kanade.tachiyomi.source.online.HttpSource
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.ConcurrentHashMap
import kotlinx.coroutines.*
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import mihon.data.dalvik.DelegateLastClassLoaderCompat
import okhttp3.Request
import uy.kohesive.injekt.Injekt
import uy.kohesive.injekt.api.addSingleton

/** Native Android host. APKs are private, signed plugins, never Android activities. */
class ExtensionHost private constructor(val context: Context) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO.limitedParallelism(4))
    private val network = NetworkHelper(context)
    private val directory = File(context.filesDir, "extensions").apply { mkdirs() }
    private val preferences =
        context.getSharedPreferences("extension_registry", Context.MODE_PRIVATE)
    private val installed = ConcurrentHashMap<String, Map<String, Any?>>()
    private val sources = ConcurrentHashMap<String, Source>()
    private val owners = ConcurrentHashMap<String, String>()
    private val mutation = kotlinx.coroutines.sync.Mutex()
    @Volatile private var loaded = false

    init {
        Injekt.addSingleton<Context>(context)
        Injekt.addSingleton<android.app.Application>(
            context.applicationContext as android.app.Application
        )
        Injekt.addSingleton(network)
        Injekt.addSingleton(eu.kanade.tachiyomi.network.JavaScriptEngine(context))
        Injekt.addSingleton(
            Json {
                ignoreUnknownKeys = true
                explicitNulls = false
            }
        )
    }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                ensureLoaded()
                val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
                val value: Any? =
                    when (call.method) {
                        "list" -> installed.values.sortedBy { it["name"].toString() }
                        "diagnostics" ->
                            mapOf(
                                "androidApi" to Build.VERSION.SDK_INT,
                                "abis" to Build.SUPPORTED_ABIS.toList(),
                                "appVersion" to BuildConfig.VERSION_NAME,
                                "buildNumber" to BuildConfig.VERSION_CODE,
                                "extensionApis" to listOf("1.4", "1.6"),
                            )
                        "install" -> mutate { install(args) }
                        "remove" ->
                            mutate {
                                remove(args["package"].toString())
                                null
                            }
                        "search" -> search(args)
                        "update" -> update(args)
                        "pages" -> pages(args)
                        "image" -> image(args)
                        "filters" -> filters(source(args).getFilterList())
                        "settings" ->
                            withContext(Dispatchers.Main) {
                                val source = source(args)
                                require(source is ConfigurableSource) {
                                    "This source has no settings"
                                }
                                context.startActivity(
                                    Intent(context, SourceSettingsActivity::class.java)
                                        .putExtra("source", source.id.toString())
                                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                )
                                null
                            }
                        "browser" ->
                            withContext(Dispatchers.Main) {
                                val source =
                                    source(args) as? HttpSource
                                        ?: error("This source has no website")
                                context.startActivity(
                                    Intent(context, SourceBrowserActivity::class.java)
                                        .putExtra("url", source.getHomeUrl())
                                        .putExtra("name", source.name)
                                        .putExtra(
                                            "userAgent",
                                            source.headers["User-Agent"]
                                                ?: network.defaultUserAgentProvider(),
                                        )
                                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                )
                                null
                            }
                        else -> throw IllegalArgumentException("Unknown extension operation")
                    }
                withContext(Dispatchers.Main) { result.success(value) }
            } catch (e: Throwable) {
                if (e is VirtualMachineError || e is ThreadDeath) throw e
                val cause = generateSequence(e) { it.cause }.last()
                withContext(Dispatchers.Main) {
                    result.error(
                        "extension_error",
                        "${cause.javaClass.simpleName}: ${cause.message ?: "Source operation failed"}",
                        null,
                    )
                }
            }
        }
    }

    private suspend fun <T> mutate(block: suspend () -> T): T {
        mutation.lock()
        return try {
            block()
        } finally {
            mutation.unlock()
        }
    }

    private suspend fun ensureLoaded() {
        if (loaded) return
        mutate {
            if (!loaded) {
                // Recover an interrupted update before enumerating its executable APK.
                directory
                    .listFiles()
                    ?.filter { it.extension == "previous" }
                    ?.forEach { backup ->
                        val pkg = backup.nameWithoutExtension
                        val certificate = preferences.getString(pkg, null)
                        val current = File(directory, "$pkg.apk")
                        if (
                            certificate != null &&
                                runCatching { validate(current, pkg, certificate) }.isFailure
                        ) {
                            current.delete()
                            backup.renameTo(current)
                        } else if (current.exists()) backup.delete()
                    }
                directory
                    .listFiles()
                    ?.filter { it.extension == "apk" }
                    ?.forEach { file ->
                        try {
                            load(
                                file,
                                preferences.getString(file.nameWithoutExtension, null)
                                    ?: error("Untrusted plugin"),
                            )
                        } catch (e: Throwable) {
                            if (e is VirtualMachineError || e is ThreadDeath) throw e
                            installed[file.nameWithoutExtension] =
                                mapOf(
                                    "package" to file.nameWithoutExtension,
                                    "name" to file.nameWithoutExtension.substringAfterLast('.'),
                                    "error" to e.toString(),
                                    "sources" to emptyList<Any>(),
                                )
                        }
                    }
                loaded = true
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun packageInfo(file: File): PackageInfo {
        val flags =
            PackageManager.GET_META_DATA or
                PackageManager.GET_CONFIGURATIONS or
                if (Build.VERSION.SDK_INT >= 28) PackageManager.GET_SIGNING_CERTIFICATES
                else PackageManager.GET_SIGNATURES
        return context.packageManager.getPackageArchiveInfo(file.absolutePath, flags)
            ?: error("Invalid extension APK")
    }

    @Suppress("DEPRECATION")
    private fun certificates(info: PackageInfo): List<String> {
        val signatures =
            if (Build.VERSION.SDK_INT >= 28) info.signingInfo?.apkContentsSigners
            else info.signatures
        return signatures.orEmpty().map { signature ->
            MessageDigest.getInstance("SHA-256").digest(signature.toByteArray()).joinToString("") {
                "%02x".format(it)
            }
        }
    }

    private fun validate(
        file: File,
        expectedPackage: String,
        expectedCertificate: String,
    ): PackageInfo {
        require(expectedPackage.matches(Regex("[a-zA-Z][a-zA-Z0-9_]*(\\.[a-zA-Z0-9_]+)+"))) {
            "Invalid package identifier"
        }
        require(expectedCertificate.matches(Regex("[a-fA-F0-9]{64}"))) {
            "Invalid repository signing certificate"
        }
        val info = packageInfo(file)
        require(info.packageName == expectedPackage) {
            "Package does not match the repository entry"
        }
        require(certificates(info).contains(expectedCertificate.lowercase())) {
            "Extension signing certificate does not match the trusted repository"
        }
        require(info.reqFeatures.orEmpty().any { it.name == "tachiyomi.extension" }) {
            "APK is not a Mihon extension"
        }
        require(Build.VERSION.SDK_INT >= (info.applicationInfo?.minSdkVersion ?: 24)) {
            "This extension requires Android API ${info.applicationInfo?.minSdkVersion} or later"
        }
        val metadata = info.applicationInfo?.metaData ?: error("Missing extension metadata")
        val version =
            metadata.getFloat("tachiyomix.extensionLib").takeIf { it != 0f }?.toString()
                ?: info.versionName?.substringBeforeLast('.')
        require(version in listOf("1.4", "1.6")) {
            "Unsupported extension API $version (supported: 1.4, 1.6)"
        }
        require(!metadata.getString("tachiyomi.extension.class").isNullOrBlank()) {
            "Missing extension source class"
        }
        return info
    }

    private fun load(file: File, certificate: String): Map<String, Any?> {
        val pkg = file.nameWithoutExtension
        val info = validate(file, pkg, certificate)
        val app = info.applicationInfo ?: error("Missing application info")
        app.sourceDir = file.absolutePath
        app.publicSourceDir = file.absolutePath
        val loader = DelegateLastClassLoaderCompat(file.absolutePath, null, context.classLoader)
        val instances =
            app.metaData.getString("tachiyomi.extension.class")!!.split(';').flatMap { name ->
                val qualified = name.trim().let { if (it.startsWith('.')) pkg + it else it }
                when (
                    val instance =
                        Class.forName(qualified, true, loader)
                            .getDeclaredConstructor()
                            .newInstance()
                ) {
                    is Source -> listOf(instance)
                    is SourceFactory -> instance.createSources()
                    else -> error("Unsupported extension entry point")
                }
            }
        require(instances.size <= 500) { "Too many sources in one extension" }
        instances.forEach { source ->
            val id = source.id.toString()
            require(owners[id] == null || owners[id] == pkg) {
                "Source ID conflicts with another installed extension"
            }
        }
        val entry =
            mapOf(
                "package" to pkg,
                "name" to
                    (app.metaData.getString("tachiyomix.name")
                        ?: context.packageManager
                            .getApplicationLabel(app)
                            .toString()
                            .removePrefix("Tachiyomi: ")),
                "version" to info.versionName,
                "code" to
                    if (Build.VERSION.SDK_INT >= 28) info.longVersionCode
                    else @Suppress("DEPRECATION") info.versionCode.toLong(),
                "certificate" to certificate,
                "sources" to
                    instances.map { source ->
                        mapOf(
                            "id" to source.id.toString(),
                            "name" to source.name,
                            "language" to source.lang,
                            "latest" to source.supportsLatest,
                            "settings" to (source is ConfigurableSource),
                            "url" to ((source as? HttpSource)?.getHomeUrl() ?: ""),
                        )
                    },
            )
        // Publish only after every source descriptor was built successfully.
        // A plugin getter can fail with a missing host API during enumeration.
        owners.entries
            .filter { it.value == pkg }
            .forEach {
                sources.remove(it.key)
                owners.remove(it.key)
            }
        instances.forEach {
            sources[it.id.toString()] = it
            owners[it.id.toString()] = pkg
        }
        installed[pkg] = entry
        return entry
    }

    private suspend fun install(args: Map<*, *>): Map<String, Any?> {
        val pkg = args["package"].toString()
        val certificate = args["certificate"].toString().lowercase()
        require(pkg.matches(Regex("[a-zA-Z][a-zA-Z0-9_]*(\\.[a-zA-Z0-9_]+)+"))) {
            "Invalid package"
        }
        val previous = preferences.getString(pkg, null)
        require(previous == null || previous == certificate) {
            "Publisher certificate changed. Remove the old extension before trusting a new publisher."
        }
        val url = args["url"].toString()
        require(url.startsWith("https://")) { "Extension downloads require HTTPS" }
        val temporary = File.createTempFile("extension-", ".apk", context.cacheDir)
        val destination = File(directory, "$pkg.apk")
        val rollback = File(directory, "$pkg.previous")
        try {
            network.client.newCall(Request.Builder().url(url).build()).execute().use { response ->
                require(response.isSuccessful && response.request.url.isHttps) {
                    "Extension download failed: HTTP ${response.code}"
                }
                require(response.body.contentLength() <= 64L * 1024 * 1024) {
                    "Extension exceeds 64 MB"
                }
                temporary.outputStream().use { out ->
                    response.body.byteStream().use { input ->
                        val buffer = ByteArray(32768)
                        var total = 0L
                        while (true) {
                            val count = input.read(buffer)
                            if (count < 0) break
                            total += count
                            require(total <= 64L * 1024 * 1024) { "Extension exceeds 64 MB" }
                            out.write(buffer, 0, count)
                        }
                    }
                }
            }
            val info = validate(temporary, pkg, certificate)
            val expected = (args["code"] as? Number)?.toLong()
            @Suppress("DEPRECATION")
            val actual =
                if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()
            require(expected == null || expected == actual) {
                "Extension version does not match the catalogue; refresh and retry"
            }
            val oldCode = (installed[pkg]?.get("code") as? Number)?.toLong() ?: 0
            require(actual >= oldCode) { "Extension downgrades are not allowed" }
            if (rollback.exists()) rollback.delete()
            if (destination.exists())
                require(destination.renameTo(rollback)) { "Could not retain previous extension" }
            destination.outputStream().use { output ->
                require(destination.setReadOnly()) { "Could not protect extension code" }
                temporary.inputStream().use { it.copyTo(output) }
            }
            val result = load(destination, certificate)
            check(preferences.edit().putString(pkg, certificate).commit()) {
                "Could not save extension trust"
            }
            rollback.delete()
            return result
        } catch (e: Throwable) {
            if (rollback.exists()) {
                destination.delete()
                rollback.renameTo(destination)
                if (previous != null) runCatching { load(destination, previous) }
            } else if (previous == null) {
                destination.delete()
                installed.remove(pkg)
                owners.entries
                    .filter { it.value == pkg }
                    .forEach {
                        sources.remove(it.key)
                        owners.remove(it.key)
                    }
            }
            throw e
        } finally {
            temporary.delete()
        }
    }

    private fun remove(pkg: String) {
        require(pkg.matches(Regex("[a-zA-Z][a-zA-Z0-9_]*(\\.[a-zA-Z0-9_]+)+")))
        val file = File(directory, "$pkg.apk")
        check(!file.exists() || file.delete()) { "Could not remove extension" }
        preferences.edit().remove(pkg).apply()
        installed.remove(pkg)
        owners.entries
            .filter { it.value == pkg }
            .forEach {
                sources.remove(it.key)
                owners.remove(it.key)
            }
    }

    suspend fun prepare() = ensureLoaded()

    fun getSource(id: String): Source? = sources[id]

    private fun source(args: Map<*, *>): Source =
        sources[args["source"].toString()]
            ?: error("Source not installed. Install its extension in Sources.")

    private fun id(source: Source, url: String) = ExtensionIdentity.manga(source.id, url)

    private fun decodeId(value: String) = ExtensionIdentity.decodeTail(value)

    private fun mapManga(source: Source, manga: SManga): Map<String, Any?> =
        mapOf(
            "id" to id(source, manga.url),
            "title" to manga.title,
            "cover" to manga.thumbnail_url.orEmpty(),
            "description" to manga.description.orEmpty(),
            "author" to listOfNotNull(manga.author, manga.artist).distinct().joinToString(" · "),
            "status" to
                when (manga.status) {
                    1 -> "ongoing"
                    2,
                    4 -> "completed"
                    5 -> "cancelled"
                    6 -> "hiatus"
                    else -> "unknown"
                },
            "tags" to manga.getGenres().orEmpty(),
            "source" to "ext:${source.id}",
            "metadata" to mapOf("url" to manga.url, "memo" to manga.memo.toString()),
        )

    private fun manga(args: Map<*, *>): SManga {
        val value = args["manga"] as Map<*, *>
        val meta = value["metadata"] as? Map<*, *>
        return SManga.create().apply {
            url = meta?.get("url")?.toString() ?: decodeId(value["id"].toString())
            title = value["title"]?.toString() ?: ""
            memo =
                meta?.get("memo")?.toString()?.let { Json.decodeFromString<JsonObject>(it) }
                    ?: JsonObject(emptyMap())
        }
    }

    private fun chapter(value: Map<*, *>): SChapter {
        val meta = value["metadata"] as? Map<*, *>
        return SChapter.create().apply {
            url = meta?.get("url")?.toString() ?: decodeId(value["id"].toString())
            name = value["title"]?.toString() ?: ""
            chapter_number = value["number"]?.toString()?.toFloatOrNull() ?: -1f
            memo =
                meta?.get("memo")?.toString()?.let { Json.decodeFromString<JsonObject>(it) }
                    ?: JsonObject(emptyMap())
        }
    }

    private suspend fun search(args: Map<*, *>): Map<String, Any> {
        val source = source(args)
        val page = ((args["page"] as? Number)?.toInt() ?: 1).coerceIn(1, 10000)
        val query = args["query"]?.toString().orEmpty()
        val filterList = source.getFilterList()
        applyFilters(filterList, args["filters"] as? List<*> ?: emptyList<Any>())
        val result =
            when {
                query.isNotBlank() || (args["filters"] as? List<*>)?.isNotEmpty() == true ->
                    source.getSearchManga(page, query, filterList)
                args["latest"] == true && source.supportsLatest -> source.getLatestUpdates(page)
                else -> source.getPopularManga(page)
            }
        require(result.mangas.size <= 1000) { "Source returned too many titles" }
        return mapOf(
            "items" to result.mangas.map { mapManga(source, it) },
            "more" to result.hasNextPage,
        )
    }

    private suspend fun update(args: Map<*, *>): Map<String, Any> {
        val source = source(args)
        val old = manga(args)
        val update = source.getMangaUpdate(old, emptyList(), true, true)
        if (update.manga.url.isBlank()) update.manga.url = old.url
        require(update.chapters.size <= 30000) { "Source returned too many chapters" }
        val mangaId = (args["manga"] as Map<*, *>)["id"].toString()
        return mapOf(
            "manga" to mapManga(source, update.manga),
            "chapters" to
                update.chapters.reversed().map {
                    mapOf(
                        "id" to ExtensionIdentity.chapter(mangaId, it.url),
                        "mangaId" to mangaId,
                        "title" to it.name,
                        "number" to
                            if (it.chapter_number < 0) ""
                            else it.chapter_number.toString().removeSuffix(".0"),
                        "language" to source.lang,
                        "pages" to 0,
                        "metadata" to mapOf("url" to it.url, "memo" to it.memo.toString()),
                    )
                },
        )
    }

    private suspend fun pages(args: Map<*, *>): List<Map<String, Any?>> {
        val source = source(args)
        val pages = source.getPageList(chapter(args["chapter"] as Map<*, *>))
        require(pages.isNotEmpty() && pages.size <= 10000) { "Invalid chapter page count" }
        return pages.mapIndexed { index, page ->
            mapOf(
                "source" to source.id.toString(),
                "index" to index,
                "url" to page.url,
                "imageUrl" to page.imageUrl,
            )
        }
    }

    private suspend fun image(args: Map<*, *>): ByteArray {
        val source = source(args) as? HttpSource ?: error("Source does not support HTTP images")
        val response =
            if (args["cover"] == true) {
                val url = args["url"].toString()
                require(url.startsWith("https://") || url.startsWith("http://"))
                source.client
                    .newCall(Request.Builder().url(url).headers(source.headers).build())
                    .execute()
            } else {
                val page =
                    Page(
                        (args["index"] as? Number)?.toInt() ?: 0,
                        args["url"]?.toString().orEmpty(),
                        args["imageUrl"] as? String,
                    )
                if (page.imageUrl.isNullOrBlank()) page.imageUrl = source.getImageUrl(page)
                source.getImage(page)
            }
        return response.use {
            require(it.isSuccessful) {
                "Image HTTP ${it.code}. Open the source website if sign-in is required."
            }
            require(it.body.contentLength() <= 40L * 1024 * 1024) { "Page exceeds 40 MB" }
            val output = java.io.ByteArrayOutputStream()
            it.body.byteStream().use { input ->
                val buffer = ByteArray(32768)
                while (true) {
                    val count = input.read(buffer)
                    if (count < 0) break
                    require(output.size() + count <= 40 * 1024 * 1024) { "Page exceeds 40 MB" }
                    output.write(buffer, 0, count)
                }
            }
            output.toByteArray()
        }
    }

    private fun filters(list: List<*>): List<Map<String, Any?>> = list.mapNotNull { filter ->
        val f = filter as? Filter<*> ?: return@mapNotNull null
        val map = mutableMapOf<String, Any?>("name" to f.name)
        when (f) {
            is Filter.Header -> map["type"] = "header"
            is Filter.Separator -> map["type"] = "separator"
            is Filter.CheckBox -> {
                map["type"] = "check"
                map["value"] = f.state
            }
            is Filter.TriState -> {
                map["type"] = "tri"
                map["value"] = f.state
            }
            is Filter.Select<*> -> {
                map["type"] = "select"
                map["value"] = f.state
                map["values"] = f.values.map { it.toString() }
            }
            is Filter.Text -> {
                map["type"] = "text"
                map["value"] = f.state
            }
            is Filter.Sort -> {
                map["type"] = "sort"
                map["value"] = f.state?.index ?: 0
                map["ascending"] = f.state?.ascending ?: true
                map["values"] = f.values.toList()
            }
            is Filter.Group<*> -> {
                map["type"] = "group"
                map["children"] = filters(f.state)
            }
            else -> map["type"] = "unsupported"
        }
        map
    }

    private fun applyFilters(list: List<*>, values: List<*>) {
        list.zip(values).forEach { (f, raw) ->
            val value = raw as? Map<*, *> ?: return@forEach
            when (f) {
                is Filter.CheckBox -> f.state = value["value"] == true
                is Filter.TriState ->
                    f.state = ((value["value"] as? Number)?.toInt() ?: 0).coerceIn(0, 2)
                is Filter.Select<*> ->
                    f.state =
                        ((value["value"] as? Number)?.toInt() ?: 0).coerceIn(
                            0,
                            (f.values.size - 1).coerceAtLeast(0),
                        )
                is Filter.Text -> f.state = value["value"]?.toString().orEmpty().take(2000)
                is Filter.Sort ->
                    f.state =
                        Filter.Sort.Selection(
                            ((value["value"] as? Number)?.toInt() ?: 0).coerceIn(
                                0,
                                (f.values.size - 1).coerceAtLeast(0),
                            ),
                            value["ascending"] != false,
                        )
                is Filter.Group<*> ->
                    applyFilters(f.state, value["children"] as? List<*> ?: emptyList<Any>())
            }
        }
    }

    companion object {
        @Volatile private var instance: ExtensionHost? = null

        fun get(context: Context): ExtensionHost =
            instance
                ?: synchronized(this) {
                    instance ?: ExtensionHost(context.applicationContext).also { instance = it }
                }
    }
}
