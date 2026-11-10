package eu.kanade.tachiyomi.network.interceptor

import okhttp3.Interceptor
import okhttp3.Response
import java.io.IOException

/** Compatibility contract: recognize access challenges and ask the user to open
 * the source browser. StarReader does not inject challenge-solving scripts. */
class CloudflareInterceptor : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val response = chain.proceed(chain.request())
        if (response.header("cf-mitigated") == "challenge") {
            response.close()
            throw IOException("This website requires verification. Open its website from My sources, complete verification, then retry.")
        }
        return response
    }
}
