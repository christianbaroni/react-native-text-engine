package com.rntextengine

import android.app.Application
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.PorterDuff
import android.os.Build
import android.os.Bundle
import android.os.Process
import android.view.Choreographer
import android.view.View
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.facebook.react.bridge.ReadableNativeMap
import com.facebook.react.fabric.FabricUIManager
import com.facebook.react.internal.ChoreographerProvider
import com.facebook.react.internal.featureflags.ReactNativeFeatureFlags
import com.facebook.react.internal.featureflags.ReactNativeFeatureFlagsDefaults
import com.facebook.react.modules.core.ReactChoreographer
import com.facebook.react.shell.MainReactPackage
import com.facebook.react.soloader.OpenSourceMergedSoMapping
import com.facebook.react.uimanager.DisplayMetricsHolder
import com.facebook.react.uimanager.ReactStylesDiffMap
import com.facebook.react.uimanager.StateWrapper
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewManager
import com.facebook.react.uimanager.ViewManagerRegistry
import com.facebook.react.views.text.ReactTextViewManager
import com.facebook.soloader.SoLoader
import kotlin.math.roundToInt
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class RNTextEngineTextComparisonBenchmark {
    private external fun checkNativeMeasurement(): String
    private external fun runNativeComparison(manager: FabricUIManager, density: Float, prepared: Boolean, implementation: Int): String
    private external fun runNativeFirstDraw(manager: FabricUIManager, density: Float, implementation: Int): String

    private lateinit var textManager: ViewManager<*, *>
    private val engineManager = RNTextEngineTextViewManager()
    private val preparedManager = RNTextEnginePreparedTextViewManager()
    private lateinit var themedContext: ThemedReactContext
    private lateinit var bitmap: Bitmap
    private lateinit var canvas: Canvas

    private fun mountAndDraw(implementation: Int, props: ReadableNativeMap, state: StateWrapper, width: Int, height: Int, expectedText: String?) {
        val manager = when (implementation) {
            0 -> textManager
            1 -> engineManager
            2 -> preparedManager
            else -> error("Unknown implementation: $implementation")
        }
        drawMounted(manager, props, state, width, height, expectedText)
    }

    private fun <T : View> drawMounted(manager: ViewManager<T, *>, props: ReadableNativeMap, state: StateWrapper, width: Int, height: Int, expectedText: String?) {
        val view = manager.createView(2, themedContext, ReactStylesDiffMap(props), state, null)
        try {
            view.measure(View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY))
            view.layout(0, 0, width, height)
            canvas.drawColor(Color.TRANSPARENT, PorterDuff.Mode.CLEAR)
            val saveCount = canvas.save()
            try {
                view.draw(canvas)
            } finally {
                canvas.restoreToCount(saveCount)
            }
            if (expectedText != null) {
                val actualText = if (view is RNTextEngineTextContainer) {
                    requireNotNull(view.displayView.resolveLayout(width)).text
                } else {
                    view.javaClass.getMethod("getText").invoke(view) as CharSequence
                }
                check(actualText.toString() == expectedText) { "Mounted text differs from the measured input" }
                check(width > 0 && height > 0 && width <= bitmap.width && height <= bitmap.height)
                val pixels = IntArray(bitmap.width * bitmap.height)
                bitmap.getPixels(pixels, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)
                var inkCount = 0
                var right = 0
                var bottom = 0
                pixels.forEachIndexed { index, pixel ->
                    if (Color.alpha(pixel) != 0) {
                        inkCount++
                        right = maxOf(right, index % bitmap.width)
                        bottom = maxOf(bottom, index / bitmap.width)
                    }
                }
                check(inkCount in 1 until width * height) { "Mounted ${manager.name} did not draw transparent text" }
                check(right <= width && bottom <= height) { "Mounted text exceeds measured bounds: $right,$bottom vs $width,$height" }
            }
        } finally {
            state.destroyState()
            manager.onDropViewInstance(view)
        }
    }

    @Test
    fun compareTextLayout() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val arguments = InstrumentationRegistry.getArguments()
        assumeTrue("Run with yarn perf:compare:android", arguments.getString("rnteComparison") == "true")
        val run = requireNotNull(arguments.getString("rnteRun")).toInt()
        val prepared = requireNotNull(arguments.getString("rntePreparedTextLayout")).toBooleanStrict()
        require(run in 1..3)
        val implementation = when (arguments.getString("rnteImplementation")) {
            "rn" -> 0
            "textview" -> 1
            "preparedtextview" -> 2
            else -> error("Choose rnteImplementation=rn, textview, or preparedtextview")
        }
        val application = ApplicationProvider.getApplicationContext<Application>()
        SoLoader.init(application, OpenSourceMergedSoMapping)
        System.loadLibrary("rnte-native-tests")
        ReactNativeFeatureFlags.override(object : ReactNativeFeatureFlagsDefaults() {
            override fun enablePreparedTextLayout() = prepared
        })
        DisplayMetricsHolder.initDisplayMetricsIfNotInitialized(application)
        val context = InstrumentedReactContext(application)
        RNTextEngineBindings.initialize(context)
        RNTextEngineBindings.cleanup()
        lateinit var manager: FabricUIManager
        instrumentation.runOnMainSync {
            ReactChoreographer.initialize(object : ChoreographerProvider {
                override fun getChoreographer() = object : ChoreographerProvider.Choreographer {
                    private val choreographer = Choreographer.getInstance()
                    override fun postFrameCallback(callback: Choreographer.FrameCallback) = choreographer.postFrameCallback(callback)
                    override fun removeFrameCallback(callback: Choreographer.FrameCallback) = choreographer.removeFrameCallback(callback)
                }
            })
            textManager = requireNotNull(MainReactPackage().createViewManager(context, ReactTextViewManager.REACT_CLASS))
            manager = FabricUIManager(context, ViewManagerRegistry(listOf(textManager))) {}
            themedContext = ThemedReactContext(context, application, "TextComparison", 1)
        }
        try {
            val density = application.resources.displayMetrics.density
            // Native validation precedes all timing; an exception prevents result emission.
            val measurementChecksum = checkNativeMeasurement()
            val results = JSONArray(runNativeComparison(manager, density, prepared, implementation))
            instrumentation.runOnMainSync {
                val pixels = (320 * density).roundToInt()
                bitmap = Bitmap.createBitmap(pixels, pixels, Bitmap.Config.ARGB_8888)
                canvas = Canvas(bitmap)
                try {
                    val drawResults = JSONArray(runNativeFirstDraw(manager, density, implementation))
                    for (index in 0 until drawResults.length()) results.put(drawResults.getJSONObject(index))
                } finally {
                    bitmap.recycle()
                }
            }
            assertTrue(results.length() == if (implementation == 2) 2 else 8)
            val meta = JSONObject()
                .put("platform", "android")
                .put("implementation", listOf("RN Text", "TextView", "PreparedTextView")[implementation])
                .put("deviceName", Build.MODEL)
                .put("osVersion", Build.VERSION.RELEASE)
                .put("apiLevel", Build.VERSION.SDK_INT)
                .put("abi", Build.SUPPORTED_ABIS[0])
                .put("density", density)
                .put("run", run)
                .put("pid", Process.myPid())
                .put("configuration", if (BuildConfig.DEBUG) "Debug" else "Release")
                .put("host", "native-only")
                .put("geometryValidated", true)
                .put("warmups", 10)
                .put("samples", 9)
                .put("enablePreparedTextLayout", ReactNativeFeatureFlags.enablePreparedTextLayout())
                .put("disableTextLayoutManagerCacheAndroid", ReactNativeFeatureFlags.disableTextLayoutManagerCacheAndroid())
                .put("preparedTextCacheSize", ReactNativeFeatureFlags.preparedTextCacheSize())
                .put("measurementChecksum", measurementChecksum)
            emit("RNTEXT_BENCHMARK_META", meta)
            for (index in 0 until results.length()) {
                emit("RNTEXT_BENCHMARK_RESULT", results.getJSONObject(index))
            }
        } finally {
            instrumentation.runOnMainSync { manager.invalidate() }
            RNTextEngineBindings.cleanup()
        }
    }

    private fun emit(marker: String, payload: JSONObject) {
        InstrumentationRegistry.getInstrumentation().sendStatus(0, Bundle().apply {
            putString("stream", "$marker $payload\n")
        })
    }
}
