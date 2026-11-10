package eu.kanade.tachiyomi

object AppInfo {
    fun getVersionCode(): Int = 2
    fun getVersionName(): String = "0.2.0"
    fun getSupportedImageMimeTypes(): List<String> = listOf("image/jpeg", "image/png", "image/webp", "image/gif")
}
