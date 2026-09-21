package com.rntextengine

import android.app.Application
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.util.DisplayMetrics
import android.view.View
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.facebook.react.bridge.ReadableNativeMap
import com.facebook.react.soloader.OpenSourceMergedSoMapping
import com.facebook.react.uimanager.DisplayMetricsHolder
import com.facebook.react.uimanager.PixelUtil
import com.facebook.react.uimanager.ReactStylesDiffMap
import com.facebook.react.uimanager.StateWrapper
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.soloader.SoLoader
import org.junit.Assert.assertTrue
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class RNTextEngineTextViewTest {
    private external fun checkPreparedContentState(density: Float)
    private external fun checkNestedFontScaling(density: Float, fontSize: Double, lineHeight: Double, letterSpacing: Double)
    private external fun checkConcurrentMeasurement(density: Float)
    private external fun checkMeasurementBoundaries(density: Float)
    private external fun checkTextEnvironment()

    private lateinit var application: Application
    private lateinit var context: InstrumentedReactContext
    private lateinit var themedContext: ThemedReactContext
    private val engineManager = RNTextEngineTextViewManager()
    private var preparedStateView: RNTextEngineTextViewManager.RNTextEngineTextView? = null
    private lateinit var environmentConfiguration: Configuration

    @Before
    fun setUp() {
        application = ApplicationProvider.getApplicationContext()
        SoLoader.init(application, OpenSourceMergedSoMapping)
        SoLoader.loadLibrary("fabricjni")
        System.loadLibrary("rnte-native-tests")
        DisplayMetricsHolder.initDisplayMetricsIfNotInitialized(application)
        context = InstrumentedReactContext(application)
        RNTextEngineBindings.initialize(context)
        RNTextEngineBindings.cleanup()
    }

    @After
    fun tearDown() {
        RNTextEngineBindings.cleanup()
    }

    private fun checkPreparedColor(handle: Long, color: Int) {
        val content = requireNotNull(RNTextEngineBindings.preparedText(handle))
        val text = content.textWithLineHeight as android.text.Spanned
        val paint = android.text.TextPaint(content.style.textPaint)
        text.getSpans(1, 2, android.text.style.CharacterStyle::class.java).forEach { it.updateDrawState(paint) }
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
            if (firstState) assertTrue(layout.text === content.displayText())
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
    fun nativePreparedContentSurvivesStateHandoff() {
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
            }
        }
    }

    @Test
    @Suppress("DEPRECATION")
    fun nestedTextUsesPlatformFontScaling() {
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
            application.resources.updateConfiguration(originalConfiguration, application.resources.displayMetrics)
            DisplayMetricsHolder.setScreenDisplayMetrics(originalMetrics)
        }
    }

    @Test
    @Suppress("DEPRECATION")
    fun textViewRevisionsTrackPlatformEnvironment() {
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
        }
    }

    @Test
    fun concurrentTextViewMeasurements() {
        checkConcurrentMeasurement(application.resources.displayMetrics.density)
    }

    @Test
    fun textViewMeasurementBoundaries() {
        checkMeasurementBoundaries(application.resources.displayMetrics.density)
    }

}
