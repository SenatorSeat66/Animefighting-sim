package mihon.data.dalvik

import dalvik.system.DelegateLastClassLoader
import dalvik.system.PathClassLoader
import java.net.URL
import java.util.Collections
import java.util.Enumeration

@Suppress("FunctionName")
fun DelegateLastClassLoaderCompat(
    dexPath: String,
    librarySearchPath: String?,
    parent: ClassLoader,
): ClassLoader {
    return DelegateLastPathClassLoader(dexPath, librarySearchPath, parent)
}

/**
 * A [PathClassLoader] that looks up classes like [DelegateLastClassLoader]: the boot class loader first, then its own
 * dex path, then the parent.
 */
private class DelegateLastPathClassLoader(
    dexPath: String,
    librarySearchPath: String?,
    parent: ClassLoader,
) : PathClassLoader(dexPath, librarySearchPath, parent) {

    private val bootClassLoader: ClassLoader? = Any::class.java.classLoader

    override fun loadClass(name: String?, resolve: Boolean): Class<*> {
        findLoadedClass(name)?.let { return it }

        if (bootClassLoader != null) {
            try {
                return bootClassLoader.loadClass(name)
            } catch (_: ClassNotFoundException) {}
        }

        val fromSuper = try {
            return findClass(name)
        } catch (e: ClassNotFoundException) {
            e
        }

        return try {
            parent.loadClass(name)
        } catch (_: ClassNotFoundException) {
            throw fromSuper
        }
    }

    override fun getResource(name: String?): URL? {
        return bootClassLoader?.getResource(name)
            ?: findResource(name)
            ?: parent?.getResource(name)
    }

    override fun getResources(name: String?): Enumeration<URL> {
        val resources = buildList {
            bootClassLoader?.getResources(name)?.let { addAll(it.toList()) }
            findResources(name)?.let { addAll(it.toList()) }
            parent?.getResources(name)?.let { addAll(it.toList()) }
        }
        return Collections.enumeration(resources)
    }
}
