// StarReader host implementation of Mihon's extension network contract.
package eu.kanade.tachiyomi.network

import android.content.Context
import okhttp3.Cache
import okhttp3.OkHttpClient
import java.io.File
import java.util.concurrent.TimeUnit

class NetworkHelper(context: Context) {
    val cookieJar = AndroidCookieJar()
    val client: OkHttpClient = OkHttpClient.Builder()
        .addInterceptor(eu.kanade.tachiyomi.network.interceptor.UncaughtExceptionInterceptor())
        .addInterceptor(eu.kanade.tachiyomi.network.interceptor.UserAgentInterceptor(::defaultUserAgentProvider))
        .addInterceptor(eu.kanade.tachiyomi.network.interceptor.CloudflareInterceptor())
        .cookieJar(cookieJar)
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(45, TimeUnit.SECONDS)
        .callTimeout(90, TimeUnit.SECONDS)
        .cache(Cache(File(context.cacheDir, "extension_http"), 24L * 1024 * 1024))
        .build()
    // No automatic challenge bypass. Users can authenticate in the source browser.
    val cloudflareClient: OkHttpClient get() = client
    fun defaultUserAgentProvider() = "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36"
}
