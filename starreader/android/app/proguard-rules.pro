# Extensions link against these public contracts at runtime. Never rename or strip them.
-keep class eu.kanade.tachiyomi.** { *; }
-keep class uy.kohesive.injekt.** { *; }
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-keep class rx.** { *; }
-keep class org.jsoup.** { *; }
-keep class kotlinx.serialization.** { *; }
-keep class kotlinx.coroutines.** { *; }
-keep class kotlin.** { *; }
-keep class androidx.preference.** { *; }
-keepattributes Signature,InnerClasses,EnclosingMethod,RuntimeVisibleAnnotations,AnnotationDefault

-keep class app.cash.quickjs.** { *; }

# Public helper namespaces used by separately compiled extension code.
-keep class mihon.core.common.extensions.** { *; }
-keep class tachiyomi.core.common.util.lang.** { *; }
