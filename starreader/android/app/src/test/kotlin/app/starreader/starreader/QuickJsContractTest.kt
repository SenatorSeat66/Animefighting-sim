package app.starreader.starreader

import app.cash.quickjs.QuickJs
import app.cash.quickjs.QuickJsException
import org.junit.Assert.*
import org.junit.Assume.assumeTrue
import org.junit.Before
import org.junit.Test

/** Executes the same vendored JNI and JS engine on the host CPU; no Android device. */
class QuickJsContractTest {
    @Before
    fun nativeHostAvailable() {
        assumeTrue(System.getenv("STARREADER_QUICKJS_HOST_LIB") != null)
    }

    interface Functions {
        fun answer(value: Int): Int
    }

    interface Callback {
        fun join(value: String): String
    }

    @Test
    fun primitivesModernSyntaxAndUnicodeMatchTheExtensionContract() {
        QuickJs.create().use { js ->
            assertEquals(42, js.evaluate("[1,2,3].map(x => x * 7).reduce((a,b)=>a+b,0)"))
            assertEquals("星の物語 🌙", js.evaluate("JSON.parse('{\"title\":\"星の物語 🌙\"}').title"))
            assertEquals(true, js.evaluate("({story:{ready:true}})?.story?.ready ?? false"))
            assertNull(js.evaluate("undefined"))
            assertEquals("b-b", js.evaluate("'a-a'.replaceAll('a','b')"))
            assertEquals("undefined", js.evaluate("typeof std"))
            assertEquals("undefined", js.evaluate("typeof os"))
        }
    }

    @Test
    fun compiledScriptsAndJavaBindingsRemainUsable() {
        QuickJs.create().use { js ->
            val bytes = js.compile("40 + 2", "fixture.js")
            assertEquals(42, js.execute(bytes))
            js.evaluate("var functions = {answer: value => value + 1}")
            assertEquals(42, js.get("functions", Functions::class.java).answer(41))
            js.set(
                "callback",
                Callback::class.java,
                object : Callback {
                    override fun join(value: String) = "star:$value"
                },
            )
            assertEquals("star:reader", js.evaluate("callback.join('reader')"))
        }
    }

    @Test
    fun malformedScriptsAndMemoryPressureReturnErrors() {
        QuickJs.create().use { js ->
            assertThrows(QuickJsException::class.java) { js.evaluate("(() => {") }
            assertThrows(QuickJsException::class.java) {
                js.evaluate("new Array(30000000).fill('x')")
            }
        }
    }

    @Test(timeout = 30000)
    fun runawayScriptsAreInterrupted() {
        QuickJs.create().use { js ->
            assertThrows(QuickJsException::class.java) { js.evaluate("while (true) {}") }
            assertEquals(2, js.evaluate("1 + 1"))
        }
    }
}
