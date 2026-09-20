package com.rntextengine

import android.app.Application
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.PorterDuff
import android.os.Build
import android.os.Bundle
import android.os.Process
import android.util.DisplayMetrics
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
import com.facebook.react.uimanager.PixelUtil
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
    private external fun checkPreparedContentState(density: Float)
    private external fun checkNestedFontScaling(density: Float, fontSize: Double, lineHeight: Double, letterSpacing: Double)
    private external fun checkConcurrentMeasurement(density: Float)
    private external fun checkMeasurementBoundaries(density: Float)
    private external fun checkTextEnvironment()
    private external fun runNativeComparison(manager: FabricUIManager, density: Float, prepared: Boolean, engine: Boolean): String
    private external fun runNativeFirstDraw(manager: FabricUIManager, density: Float, engine: Boolean): String

    private lateinit var textManager: ViewManager<*, *>
    private val engineManager = RNTextEngineTextViewManager()
    private lateinit var themedContext: ThemedReactContext
    private lateinit var bitmap: Bitmap
    private lateinit var canvas: Canvas

    private fun mountAndDraw(engine: Boolean, props: ReadableNativeMap, state: StateWrapper, width: Int, height: Int, expectedText: String?) {
        drawMounted(if (engine) engineManager else textManager, props, state, width, height, expectedText)
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
                val actualText = if (view is RNTextEngineTextViewManager.RNTextEngineTextView) {
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

    private var preparedStateView: RNTextEngineTextViewManager.RNTextEngineTextView? = null

    private fun checkPreparedColor(handle: Long, color: Int) {
        val content = requireNotNull(RNTextEngineBindings.preparedText(handle))
        val text = content.textWithLineHeight as android.text.Spanned
        val paint = android.text.TextPaint(content.style.textPaint)
        text.getSpans(1, 2, RNTextEngineTextPaintSpan::class.java).single().updateDrawState(paint)
        assertTrue("Nested color changed: expected=$color actual=${paint.color}", color == paint.color)
    }

    private fun applyPreparedState(props: ReadableNativeMap, state: StateWrapper, expectedText: String, width: Int, height: Int) {
        try {
            val firstState = preparedStateView == null
            val diff = ReactStylesDiffMap(props)
            val view = preparedStateView?.also {
                engineManager.updateProperties(it, diff)
                engineManager.updateState(it, diff, state)?.let { content -> engineManager.updateExtraData(it, content) }
            } ?: engineManager.createView(2, themedContext, diff, state, null).also { preparedStateView = it }
            val map = requireNotNull(state.stateDataMapBuffer)
            val handle = (map.getInt(1).toLong() shl 32) or (map.getInt(0).toLong() and 0xFFFFFFFFL)
            val content = requireNotNull(RNTextEngineBindings.preparedText(handle))
            assertTrue(content.text == expectedText)
            view.measure(View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY))
            view.layout(0, 0, width, height)
            val layout = requireNotNull(view.displayView.resolveLayout(width))
            assertTrue(layout.text.toString() == expectedText)
            if (firstState) assertTrue(layout.text === content.displayText(true))
            assertTrue(layout.paint.textSize == PixelUtil.toPixelFromDIP(if (firstState) 18f else 42f))
            if (content.source?.nested == true && content.source.runs.isNotEmpty()) {
                val spans = (layout.text as android.text.Spanned).getSpans(0, layout.text.length, RNTextEngineTextPaintSpan::class.java)
                val paint = android.text.TextPaint(layout.paint)
                spans.last().updateMeasureState(paint)
                assertTrue(paint.textSize == PixelUtil.toPixelFromDIP(26f))
            }
            view.setSelectable(true)
            assertTrue(view.selectionView?.text.toString() == expectedText)
            view.setSelectable(false)
            if (firstState) {
                engineManager.updateProperties(view, ReactStylesDiffMap(com.facebook.react.bridge.JavaOnlyMap.of("fontSize", 42.0)))
                val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                try { view.draw(Canvas(bitmap)) } finally { bitmap.recycle() }
                assertTrue(view.displayView.resolveLayout(width)?.paint?.textSize == PixelUtil.toPixelFromDIP(42f))
            }
        } finally {
            state.destroyState()
        }
    }

    @Test
    fun nativePreparedContentSurvivesStateHandoff() {
        assumeTrue(InstrumentationRegistry.getArguments().getString("rntePreparedState") == "true")
        val application = ApplicationProvider.getApplicationContext<Application>()
        SoLoader.init(application, OpenSourceMergedSoMapping)
        SoLoader.loadLibrary("fabricjni")
        System.loadLibrary("rnte-text-comparison")
        DisplayMetricsHolder.initDisplayMetricsIfNotInitialized(application)
        val context = BenchmarkReactApplicationContext(application)
        RNTextEngineBindings.initialize(context)
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            themedContext = ThemedReactContext(context, application, "PreparedState", 1)
            try {
                checkPreparedContentState(application.resources.displayMetrics.density)
                val view = requireNotNull(preparedStateView)
                engineManager.updateProperties(view, ReactStylesDiffMap(com.facebook.react.bridge.JavaOnlyMap.of("selectable", true)))
                assertTrue(view.selectionView?.text.toString() == "A😀 ZSS😀")
                val bitmap = Bitmap.createBitmap(640, 200, Bitmap.Config.ARGB_8888)
                try {
                    view.draw(Canvas(bitmap))
                    val pixels = IntArray(640 * 200)
                    bitmap.getPixels(pixels, 0, 640, 0, 0, 640, 200)
                    assertTrue(pixels.any { Color.alpha(it) != 0 })
                } finally {
                    bitmap.recycle()
                }
            } finally {
                preparedStateView?.let(engineManager::onDropViewInstance)
                preparedStateView = null
                RNTextEngineBindings.cleanup()
            }
        }
    }

    @Test
    @Suppress("DEPRECATION")
    fun nestedTextUsesPlatformFontScaling() {
        assumeTrue(InstrumentationRegistry.getArguments().getString("rnteFontScaling") == "true")
        val application = ApplicationProvider.getApplicationContext<Application>()
        SoLoader.init(application, OpenSourceMergedSoMapping)
        SoLoader.loadLibrary("fabricjni")
        System.loadLibrary("rnte-text-comparison")
        DisplayMetricsHolder.initDisplayMetricsIfNotInitialized(application)
        RNTextEngineBindings.initialize(BenchmarkReactApplicationContext(application))
        val originalConfiguration = Configuration(application.resources.configuration)
        val originalMetrics = DisplayMetrics().apply { setTo(DisplayMetricsHolder.getScreenDisplayMetrics()) }
        try {
            for (fontScale in floatArrayOf(1f, 1.5f, 2f)) {
                application.resources.updateConfiguration(
                    Configuration(originalConfiguration).apply { this.fontScale = fontScale },
                    application.resources.displayMetrics,
                )
                DisplayMetricsHolder.setScreenDisplayMetrics(application.resources.displayMetrics)
                val density = PixelUtil.getDisplayMetricDensity()
                checkNestedFontScaling(density,
                    (PixelUtil.toPixelFromSP(18f) / density).toDouble(),
                    (PixelUtil.toPixelFromSP(40f) / density).toDouble(),
                    (PixelUtil.toPixelFromSP(2f) / density).toDouble())
            }
        } finally {
            RNTextEngineBindings.cleanup()
            application.resources.updateConfiguration(originalConfiguration, application.resources.displayMetrics)
            DisplayMetricsHolder.setScreenDisplayMetrics(originalMetrics)
        }
    }

    private lateinit var environmentConfiguration: Configuration

    @Suppress("DEPRECATION")
    private fun updateTextEnvironment(stage: Int): Float {
        val application = ApplicationProvider.getApplicationContext<Application>()
        val configuration = Configuration(environmentConfiguration).apply {
            fontScale = when (stage) { 0 -> 1f; 1, 2 -> 1.5f; else -> 2f }
            if (stage >= 5) densityDpi += 80
        }
        application.resources.updateConfiguration(configuration, application.resources.displayMetrics)
        if (stage != 1 && stage != 3) {
            DisplayMetricsHolder.setScreenDisplayMetrics(DisplayMetrics().apply { setTo(application.resources.displayMetrics) })
        }
        val primary = if (stage >= 6) java.util.Locale.forLanguageTag("tr-TR") else java.util.Locale.US
        val secondary = if (stage == 7) java.util.Locale.forLanguageTag("th-TH") else java.util.Locale.JAPAN
        android.os.LocaleList.setDefault(android.os.LocaleList(primary, secondary))
        return PixelUtil.getDisplayMetricDensity()
    }

    private fun environmentFontScale(): Float =
        ApplicationProvider.getApplicationContext<Application>().resources.configuration.fontScale

    private fun checkEnvironmentContent(handle: Long) {
        val content = requireNotNull(RNTextEngineBindings.preparedText(handle))
        assertTrue(content.text == "initial child".uppercase(java.util.Locale.getDefault()))
        assertTrue(content.style.textPaint.textLocales == android.os.LocaleList.getAdjustedDefault())
    }

    @Test
    @Suppress("DEPRECATION")
    fun textViewRevisionsTrackPlatformEnvironment() {
        assumeTrue(InstrumentationRegistry.getArguments().getString("rnteConcurrency") == "true")
        val application = ApplicationProvider.getApplicationContext<Application>()
        SoLoader.init(application, OpenSourceMergedSoMapping)
        SoLoader.loadLibrary("fabricjni")
        System.loadLibrary("rnte-text-comparison")
        DisplayMetricsHolder.initDisplayMetricsIfNotInitialized(application)
        RNTextEngineBindings.initialize(BenchmarkReactApplicationContext(application))
        environmentConfiguration = Configuration(application.resources.configuration)
        val metrics = DisplayMetricsHolder.getScreenDisplayMetrics()
        val locales = android.os.LocaleList.getDefault()
        val locale = java.util.Locale.getDefault()
        try {
            checkTextEnvironment()
        } finally {
            application.resources.updateConfiguration(environmentConfiguration, application.resources.displayMetrics)
            DisplayMetricsHolder.setScreenDisplayMetrics(metrics)
            android.os.LocaleList.setDefault(locales)
            java.util.Locale.setDefault(locale)
            RNTextEngineBindings.cleanup()
        }
    }

    @Test
    fun concurrentTextViewMeasurements() {
        assumeTrue(InstrumentationRegistry.getArguments().getString("rnteConcurrency") == "true")
        val application = ApplicationProvider.getApplicationContext<Application>()
        SoLoader.init(application, OpenSourceMergedSoMapping)
        SoLoader.loadLibrary("fabricjni")
        System.loadLibrary("rnte-text-comparison")
        DisplayMetricsHolder.initDisplayMetricsIfNotInitialized(application)
        RNTextEngineBindings.initialize(BenchmarkReactApplicationContext(application))
        try {
            checkConcurrentMeasurement(application.resources.displayMetrics.density)
        } finally {
            RNTextEngineBindings.cleanup()
        }
    }

    @Test
    fun textViewMeasurementBoundaries() {
        assumeTrue(InstrumentationRegistry.getArguments().getString("rnteConcurrency") == "true")
        val application = ApplicationProvider.getApplicationContext<Application>()
        SoLoader.init(application, OpenSourceMergedSoMapping)
        SoLoader.loadLibrary("fabricjni")
        System.loadLibrary("rnte-text-comparison")
        DisplayMetricsHolder.initDisplayMetricsIfNotInitialized(application)
        RNTextEngineBindings.initialize(BenchmarkReactApplicationContext(application))
        try {
            checkMeasurementBoundaries(application.resources.displayMetrics.density)
        } finally {
            RNTextEngineBindings.cleanup()
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
        val engine = when (arguments.getString("rnteImplementation")) {
            "rn" -> false
            "textview" -> true
            else -> error("Choose rnteImplementation=rn or textview")
        }
        val application = ApplicationProvider.getApplicationContext<Application>()
        SoLoader.init(application, OpenSourceMergedSoMapping)
        System.loadLibrary("rnte-text-comparison")
        ReactNativeFeatureFlags.override(object : ReactNativeFeatureFlagsDefaults() {
            override fun enablePreparedTextLayout() = prepared
        })
        DisplayMetricsHolder.initDisplayMetricsIfNotInitialized(application)
        val context = BenchmarkReactApplicationContext(application)
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
            val results = JSONArray(runNativeComparison(manager, density, prepared, engine))
            instrumentation.runOnMainSync {
                val pixels = (320 * density).roundToInt()
                bitmap = Bitmap.createBitmap(pixels, pixels, Bitmap.Config.ARGB_8888)
                canvas = Canvas(bitmap)
                try {
                    val drawResults = JSONArray(runNativeFirstDraw(manager, density, engine))
                    for (index in 0 until drawResults.length()) results.put(drawResults.getJSONObject(index))
                } finally {
                    bitmap.recycle()
                }
            }
            assertTrue(results.length() == 8)
            val meta = JSONObject()
                .put("platform", "android")
                .put("implementation", if (engine) "TextView" else "RN Text")
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
