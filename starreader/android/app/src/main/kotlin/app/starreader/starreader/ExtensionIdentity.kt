package app.starreader.starreader

import android.util.Base64

/** Mirrors Mihon's UNIQUE(manga_id, remote_url), including URL-only chapter APIs. */
object ExtensionIdentity {
    private fun encode(value: String) =
        Base64.encodeToString(
            value.toByteArray(Charsets.UTF_8),
            Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING,
        )

    fun manga(source: Long, url: String) = "ext:$source:${encode(url)}"

    fun chapter(mangaId: String, url: String) = "$mangaId:${encode(url)}"

    fun decodeTail(value: String) =
        String(
            Base64.decode(
                value.substringAfterLast(':'),
                Base64.URL_SAFE or Base64.NO_WRAP,
            ),
            Charsets.UTF_8,
        )
}
