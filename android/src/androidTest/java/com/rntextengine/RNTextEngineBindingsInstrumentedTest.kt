package com.rntextengine

import android.app.Application
import android.content.res.Configuration
import android.text.Layout
import android.text.TextPaint
import android.util.DisplayMetrics
import android.view.View
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.facebook.react.bridge.JavaOnlyArray
import com.facebook.react.bridge.Callback
import com.facebook.react.bridge.CatalystInstance
import com.facebook.react.bridge.JavaScriptContextHolder
import com.facebook.react.bridge.JavaScriptModule
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.RuntimeExecutor
import com.facebook.react.bridge.UIManager
import com.facebook.react.soloader.OpenSourceMergedSoMapping
import com.facebook.react.turbomodule.core.interfaces.CallInvokerHolder
import com.facebook.react.uimanager.DisplayMetricsHolder
import com.facebook.react.uimanager.PixelUtil
import com.facebook.yoga.YogaMeasureMode
import com.facebook.yoga.YogaMeasureOutput
import com.facebook.soloader.SoLoader
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.roundToInt
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.assertThrows
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

private data class InstrumentedPackedLine(
    val bottom: Double,
    val end: Double,
    val start: Double,
    val width: Double,
)

private fun resolvePreparedHandle(node: RNTextEngineTextShadowNode): Long {
    val method = RNTextEngineTextShadowNode::class.java.getDeclaredMethod("ensurePreparedHandle")
    method.isAccessible = true
    return method.invoke(node) as Long
}

private class InstrumentedTestReactApplicationContext(application: Application) : ReactApplicationContext(application) {
    override fun <T : JavaScriptModule> getJSModule(jsInterface: Class<T>): T {
        throw UnsupportedOperationException("JS modules are not used in RNTextEngine instrumentation tests.")
    }

    override fun <T : NativeModule> hasNativeModule(nativeModuleInterface: Class<T>): Boolean = false

    override fun getNativeModules(): MutableCollection<NativeModule> = mutableListOf()

    override fun <T : NativeModule> getNativeModule(nativeModuleInterface: Class<T>): T? = null

    override fun getNativeModule(moduleName: String): NativeModule? = null

    override fun getCatalystInstance(): CatalystInstance {
        throw UnsupportedOperationException("CatalystInstance is not used in RNTextEngine instrumentation tests.")
    }

    @Deprecated("Legacy bridge API")
    override fun hasActiveCatalystInstance(): Boolean = false

    override fun hasActiveReactInstance(): Boolean = false

    @Deprecated("Legacy bridge API")
    override fun hasCatalystInstance(): Boolean = false

    override fun hasReactInstance(): Boolean = false

    override fun destroy() = Unit

    override fun handleException(e: Exception) {
        throw e
    }

    @Deprecated("Legacy bridge API")
    override fun isBridgeless(): Boolean = false

    override fun getJavaScriptContextHolder(): JavaScriptContextHolder? = null

    override fun getRuntimeExecutor(): RuntimeExecutor? = null

    override fun getJSCallInvokerHolder(): CallInvokerHolder? = null

    override fun getFabricUIManager(): UIManager? = null

    override fun getSourceURL(): String? = null

    override fun registerSegment(segmentId: Int, path: String, callback: Callback) = Unit
}

private fun expectedAnchoredContentHeight(hostHeight: Int, insets: RNTextEngineCapHeightInsetsPx): Int {
    return hostHeight + kotlin.math.floor(insets.top.toDouble()).toInt() + ceil(insets.bottom.toDouble()).toInt()
}

@RunWith(AndroidJUnit4::class)
class RNTextEngineBindingsInstrumentedTest {
    private lateinit var application: Application

    @Before
    fun setUp() {
        application = ApplicationProvider.getApplicationContext()
        SoLoader.init(application, OpenSourceMergedSoMapping)
        DisplayMetricsHolder.initDisplayMetricsIfNotInitialized(application)
        RNTextEngineBindings.initialize(InstrumentedTestReactApplicationContext(application))
        RNTextEngineBindings.cleanup()
    }

    @After
    fun tearDown() {
        RNTextEngineBindings.cleanup()
    }

    @Test
    fun nativeSizePreservesSignedMetricsAndHandleLifetime() {
        for (text in listOf("", "A")) {
            for (lineHeight in listOf(23.7, -1.0, -0.0)) {
                val handle = RNTextEngineBindings.prepare(
                    text = text,
                    color = null,
                    fontFamily = null,
                    fontSize = 17.3,
                    fontWeight = null,
                    fontStyle = null,
                    letterSpacing = 0.15,
                    lineHeight = lineHeight,
                    allowFontScaling = false,
                    includeFontPadding = false,
                    tabularNumbers = false,
                    textBreakStrategy = null,
                )
                try {
                    for ((mode, code) in listOf(null to 3, "clip" to 0, "head" to 1, "middle" to 2, "tail" to 3)) {
                        val expected = RNTextEngineBindings.layout(handle, 80.25, 2, mode, false)
                        val actual = RNTextEngineBindings.measureTextView(handle, 80.25, 2, code, false)
                        assertEquals(expected[0].toFloat().toRawBits(), YogaMeasureOutput.getWidth(actual).toRawBits())
                        assertEquals(expected[1].toFloat().toRawBits(), YogaMeasureOutput.getHeight(actual).toRawBits())
                    }
                } finally {
                    RNTextEngineBindings.release(handle)
                }
                assertThrows(IllegalStateException::class.java) {
                    RNTextEngineBindings.measureTextView(handle, 80.25, 2, 3, false)
                }
            }
        }
    }

    @Test
    fun layoutNextLineReturnsTheSecondWrappedLineNotTheWholeRemainingSubstring() {
        val text =
            "The measure is the length of a line of text -- the distance the eye travels before returning to the left edge."
        val width =
            (RNTextEngineBindings.measureWidth(
                text = text,
                color = null,
                fontFamily = null,
                fontSize = 16.0,
                fontWeight = null,
                fontStyle = null,
                letterSpacing = Double.NaN,
                lineHeight = 20.0,
                allowFontScaling = false,
                includeFontPadding = false,
                tabularNumbers = false,
                textBreakStrategy = null,
            ) * 0.5).coerceAtLeast(40.0)
        val handle =
            RNTextEngineBindings.prepare(
                text = text,
                color = null,
                fontFamily = null,
                fontSize = 16.0,
                fontWeight = null,
                fontStyle = null,
                letterSpacing = Double.NaN,
                lineHeight = 20.0,
                allowFontScaling = false,
                includeFontPadding = false,
                tabularNumbers = false,
                textBreakStrategy = null,
            )

        try {
            val lines = unpackLines(RNTextEngineBindings.layoutLines(handle, width, 0, null, false))
            assertTrue("width=$width lines=$lines", lines.size >= 2)

            val secondLine = requireNotNull(RNTextEngineBindings.layoutNextLine(handle, lines[1].start.toInt(), width, false))

            assertEquals(lines[1].start, secondLine[0], 0.0001)
            assertEquals(lines[1].end, secondLine[1], 0.0001)
            assertTrue(secondLine[1] < text.length.toDouble())
        } finally {
            RNTextEngineBindings.release(handle)
        }
    }

    @Test
    fun layoutNextLineMatchesLayoutLinesWhenTrailingWhitespaceIsTrimmed() {
        val handle =
            RNTextEngineBindings.prepare(
                text = "Alpha   ",
                color = null,
                fontFamily = null,
                fontSize = 16.0,
                fontWeight = null,
                fontStyle = null,
                letterSpacing = Double.NaN,
                lineHeight = 20.0,
                allowFontScaling = false,
                includeFontPadding = false,
                tabularNumbers = false,
                textBreakStrategy = null,
            )

        try {
            val packedLines = RNTextEngineBindings.layoutLines(handle, 240.0, 0, null, false)
            val nextLine = requireNotNull(RNTextEngineBindings.layoutNextLine(handle, 0, 240.0, false))
            val lines = unpackLines(packedLines)

            assertEquals(1, lines.size)
            assertEquals(5.0, lines[0].end, 0.0001)
            assertEquals(lines[0].end, nextLine[1], 0.0001)
            assertEquals(lines[0].width, nextLine[2], 0.0001)
            assertEquals(lines[0].bottom, nextLine[3], 0.0001)
        } finally {
            RNTextEngineBindings.release(handle)
        }
    }

    @Test
    fun layoutNextLineMatchesLayoutLinesAcrossWidthsOnDevice() {
        val texts =
            listOf(
                "Flow line one needs exact next-line geometry around changing widths.",
                " Alpha beta gamma delta epsilon zeta eta theta",
                "Alpha   beta gamma   delta epsilon",
                "supercalifragilisticexpialidocious needs fallback when a word itself overflows",
                "Alpha beta.\nGamma delta",
            )
        val widths = doubleArrayOf(110.0, 140.0, 180.0, 240.0)

        texts.forEach { text ->
            val handle =
                RNTextEngineBindings.prepare(
                    text = text,
                    color = null,
                    fontFamily = null,
                    fontSize = 16.0,
                    fontWeight = null,
                    fontStyle = null,
                    letterSpacing = 0.1,
                    lineHeight = 20.0,
                    allowFontScaling = false,
                    includeFontPadding = false,
                    tabularNumbers = false,
                    textBreakStrategy = "highQuality",
                )

            try {
                widths.forEach { width ->
                    assertNextLineMatchesLayoutLines(handle, width, anchorToCapHeight = false)
                    assertNextLineMatchesLayoutLines(handle, width, anchorToCapHeight = true)
                }
            } finally {
                RNTextEngineBindings.release(handle)
            }
        }
    }

    @Test
    fun ellipsizedSingleLineLayoutKeepsTheAssignedWidthOnDevice() {
        val handle =
            RNTextEngineBindings.prepare(
                text = "0x3d3c7f1d1b4c88d6d9b0c8a5e4f2aa71",
                color = null,
                fontFamily = null,
                fontSize = 16.0,
                fontWeight = "700",
                fontStyle = null,
                letterSpacing = 0.2,
                lineHeight = 20.0,
                allowFontScaling = false,
                includeFontPadding = false,
                tabularNumbers = false,
                textBreakStrategy = null,
            )

        try {
            val prepared = requireNotNull(RNTextEngineBindings.resolvePreparedTextViewData(handle))
            val intrinsicWidthDp = RNTextEngineBindings.measurePreparedWidth(handle)
            var widthDp = max(1.0, intrinsicWidthDp * 0.5)
            var layout = buildEllipsizedSingleLineLayout(prepared, widthDp)

            while (layout.getEllipsisCount(0) == 0 && widthDp > 1.0) {
                widthDp = max(1.0, widthDp * 0.75)
                layout = buildEllipsizedSingleLineLayout(prepared, widthDp)
            }

            assertTrue("intrinsicWidthDp=$intrinsicWidthDp constrainedWidthDp=$widthDp", layout.getEllipsisCount(0) > 0)

            val packed = RNTextEngineBindings.layout(handle, widthDp, 1, "middle", false)
            val expectedWidthDp = layout.width.toDouble() / PixelUtil.getDisplayMetricDensity()
            assertEquals(expectedWidthDp, packed[0], 0.0001)
            assertEquals(1.0, packed[2], 0.0001)
            assertTrue("packed=${packed.contentToString()}", packed[3] <= packed[0] + 0.0001)
        } finally {
            RNTextEngineBindings.release(handle)
        }
    }

    @Test
    fun textShadowNodeLocalDataReplacesPaperMeasurementTextOnDevice() {
        val node = RNTextEngineTextShadowNode()
        node.measureAllowFontScaling = false
        node.measureFontSize = 16.0
        node.measureLineHeight = 20.0
        node.measureText = "gas"

        val shortHandle = resolvePreparedHandle(node)
        val shortWidth = RNTextEngineBindings.measurePreparedWidth(shortHandle)
        RNTextEngineBindings.release(shortHandle)

        node.setLocalData(RNTextEngineTextLocalData("gas gas gas"))

        val longHandle = resolvePreparedHandle(node)
        val longWidth = RNTextEngineBindings.measurePreparedWidth(longHandle)
        RNTextEngineBindings.release(longHandle)

        assertTrue("shortWidth=$shortWidth longWidth=$longWidth", longWidth > shortWidth)
    }

    @Test
    fun textShadowNodeLocalDataFiltersInlineRunsOutsideTheEffectiveTextOnDevice() {
        val node = RNTextEngineTextShadowNode()
        node.measureAllowFontScaling = false
        node.measureFontSize = 16.0
        node.measureLineHeight = 20.0
        node.measureText = "WIDE"
        node.measureRunCount = 1
        node.measureRunStarts = JavaOnlyArray.of(0)
        node.measureRunEnds = JavaOnlyArray.of(4)
        node.measureRunStyleMasks = JavaOnlyArray.of(1 shl 2)
        node.measureRunFontSizes = JavaOnlyArray.of(24.0)
        node.setLocalData(RNTextEngineTextLocalData("I"))

        val handle = resolvePreparedHandle(node)
        val width = RNTextEngineBindings.measurePreparedWidth(handle)
        RNTextEngineBindings.release(handle)

        assertTrue("width=$width", width > 0.0)
    }

    @Test
    @Suppress("DEPRECATION")
    fun nestedPaperTextUsesConfigurationFontScaleWhenScreenMetricsAreUnscaled() {
        val originalConfiguration = Configuration(application.resources.configuration)
        val configuration = Configuration(originalConfiguration).apply { fontScale = 1.5f }
        val originalMetrics = DisplayMetrics().apply { setTo(DisplayMetricsHolder.getScreenDisplayMetrics()) }
        val unscaledMetrics = DisplayMetrics().apply {
            setTo(originalMetrics)
            scaledDensity = density
        }
        val parent = RNTextEngineTextShadowNode()
        val child = RNTextEngineTextShadowNode()
        try {
            application.resources.updateConfiguration(configuration, application.resources.displayMetrics)
            DisplayMetricsHolder.setScreenDisplayMetrics(unscaledMetrics)
            assertEquals(1.5, RNTextEngineBindings.currentFontScaleMultiplier(), 0.0)
            parent.measureRnteHasAllowFontScaling = true
            parent.measureFontSize = 16.0
            parent.measureLineHeight = 24.0
            parent.measureRnteHasLetterSpacing = true
            parent.measureLetterSpacing = 2.0
            parent.measureText = "Parent "
            child.measureRnteIsVirtualTextSpan = true
            child.measureText = "child"
            parent.addChildAt(child, 0)

            for (allowFontScaling in booleanArrayOf(true, false)) {
                parent.measureAllowFontScaling = allowFontScaling
                val handle = resolvePreparedHandle(parent)
                val prepared = requireNotNull(RNTextEngineBindings.resolvePreparedTextViewData(handle))
                val measurement = measurePreparedAutoSizeText(handle, 0f, YogaMeasureMode.UNDEFINED, 0f, YogaMeasureMode.UNDEFINED, 0, null, false)
                val multiplier = if (allowFontScaling) 1.5f else 1f

                assertEquals("Parent child", prepared.text.toString())
                assertEquals(PixelUtil.toPixelFromDIP(16f * multiplier), prepared.textPaint.textSize, 0.001f)
                assertEquals(PixelUtil.toPixelFromDIP(24f * multiplier), measurement.heightPx, 0.001f)
                assertEquals(
                    PixelUtil.toPixelFromDIP(2f * multiplier),
                    prepared.textPaint.letterSpacing * prepared.textPaint.textSize,
                    0.001f,
                )
            }
        } finally {
            parent.removeAndDisposeAllChildren()
            parent.dispose()
            application.resources.updateConfiguration(originalConfiguration, application.resources.displayMetrics)
            DisplayMetricsHolder.setScreenDisplayMetrics(originalMetrics)
        }
    }

    @Test
    fun oneShotPlainBatchMeasureMatchesPreparedLayoutAcrossChatCorpusOnDevice() {
        val texts =
            arrayOf(
                "Message 1. The renderer should know the bubble height before the row mounts. Inline emphasis, quoted citations, and tabular figures still need exact native metrics.",
                "Message 2. Prepared text lets layout reuse stay width-bound instead of rebuilding typography. Worklet-driven lists need stable line counts, widths, and last-line geometry to avoid jank.",
                "Message 3. Glyph fields should mutate cells, not paragraphs, when the phenomenon is fixed-grid text. Prepared text performance should remain exact under changing widths.",
                "Message 4. Exact line breaks matter when high-quality paragraph optimization and hyphenation both participate in the result geometry.",
                "Message 5. Trailing whitespace should trim from visible width but never corrupt the line end contract.   ",
            )

        texts.forEach { text ->
            val measured =
                RNTextEngineBindings.measure(
                    text = text,
                    color = null,
                    fontFamily = null,
                    fontSize = 17.0,
                    fontWeight = "500",
                    fontStyle = null,
                    letterSpacing = 0.1,
                    lineHeight = 24.0,
                    allowFontScaling = false,
                    includeFontPadding = false,
                    tabularNumbers = false,
                    textBreakStrategy = "highQuality",
                    width = 260.0,
                    maxLines = 0,
                    ellipsizeMode = null,
                    anchorToCapHeight = false,
                )
            val handle =
                RNTextEngineBindings.prepare(
                    text = text,
                    color = null,
                    fontFamily = null,
                    fontSize = 17.0,
                    fontWeight = "500",
                    fontStyle = null,
                    letterSpacing = 0.1,
                    lineHeight = 24.0,
                    allowFontScaling = false,
                    includeFontPadding = false,
                    tabularNumbers = false,
                    textBreakStrategy = "highQuality",
                )

            try {
                val laidOut = RNTextEngineBindings.layout(handle, 260.0, 0, null, false)
                measured.indices.forEach { index ->
                    assertEquals("text=$text index=$index", laidOut[index], measured[index], 0.0001)
                }
            } finally {
                RNTextEngineBindings.release(handle)
            }
        }
    }

    @Test
    fun textViewCapAnchoredMountedBaselineMatchesMeasuredHeightOnDevice() {
        val manager = RNTextEngineTextViewManager()
        val sourceText = "EXACT ROW"
        val measured =
            RNTextEngineBindings.measure(
                text = sourceText,
                color = null,
                fontFamily = null,
                fontSize = 11.0,
                fontWeight = "800",
                fontStyle = null,
                letterSpacing = 0.9,
                lineHeight = Double.NaN,
                allowFontScaling = false,
                includeFontPadding = false,
                tabularNumbers = false,
                textBreakStrategy = null,
                width = 240.0,
                maxLines = 1,
                ellipsizeMode = null,
                anchorToCapHeight = true,
            )

        assertTrue("measured=${measured.contentToString()}", measured[1] > 0.0)

        val hostWidthPx = PixelUtil.toPixelFromDIP(measured[0].toFloat()).roundToInt()
        val hostHeightPx = PixelUtil.toPixelFromDIP(measured[1].toFloat()).roundToInt()
        val view = RNTextEngineTextViewManager.RNTextEngineTextView(application)

        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            manager.setAllowFontScaling(view, false)
            manager.setAnchorToCapHeight(view, true)
            manager.setFontSize(view, 11.0)
            manager.setFontWeight(view, "800")
            manager.setLetterSpacing(view, 0.9)
            manager.setText(view, sourceText)
            measureAndLayout(view, width = hostWidthPx, height = hostHeightPx)
        }

        val mountedLayout = requireNotNull(view.displayView.resolveLayout(hostWidthPx))
        val mountedBaseline = view.displayView.y + mountedLayout.getLineBaseline(mountedLayout.lineCount - 1)

        assertTrue("measured=${measured.contentToString()} baseline=$mountedBaseline hostHeightPx=$hostHeightPx", abs(mountedBaseline - hostHeightPx) <= 1)
        assertEquals(0, mountedLayout.getEllipsisCount(0))
        assertEquals(sourceText.length, mountedLayout.getLineVisibleEnd(0))
    }

    @Test
    fun textViewNativeTypographyUpdateReanchorsCapHeightWithoutExternalRelayoutOnDevice() {
        val manager = RNTextEngineTextViewManager()
        val view = RNTextEngineTextViewManager.RNTextEngineTextView(application)
        val hostWidthPx = PixelUtil.toPixelFromDIP(260f).roundToInt()
        val hostHeightPx = PixelUtil.toPixelFromDIP(120f).roundToInt()

        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            manager.setAnchorToCapHeight(view, true)
            manager.setAllowFontScaling(view, false)
            manager.setText(view, "EXACT ROW")
            manager.setFontWeight(view, "800")
            manager.setLetterSpacing(view, 0.9)
            manager.setFontSize(view, 16.0)
            manager.setLineHeight(view, 20.0)
            measureAndLayout(view, width = hostWidthPx, height = hostHeightPx)
        }

        val initialTop = effectiveTextOwnerTopInset(view.displayView)

        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            manager.setFontSize(view, 44.0)
            manager.setLineHeight(view, 48.0)
        }
        InstrumentationRegistry.getInstrumentation().waitForIdleSync()

        val expectedTop = view.displayView.resolveCapHeightInsets(hostWidthPx).top
        assertNotEquals(initialTop, expectedTop)
        assertEquals(expectedTop, effectiveTextOwnerTopInset(view.displayView), 0.001f)
        assertEquals(hostHeightPx, view.displayView.measuredHeight)
        assertEquals(expectedAnchoredContentHeight(hostHeightPx, view.displayView.resolveCapHeightInsets(hostWidthPx)), view.displayView.height)
    }

    @Test
    fun preparedTextHandleUpdateReanchorsCapHeightWithoutExternalRelayoutOnDevice() {
        val smallHandle =
            RNTextEngineBindings.prepare(
                text = "EXACT ROW",
                color = null,
                fontFamily = null,
                fontSize = 16.0,
                fontWeight = "800",
                fontStyle = null,
                letterSpacing = 0.9,
                lineHeight = 20.0,
                allowFontScaling = false,
                includeFontPadding = false,
                tabularNumbers = false,
                textBreakStrategy = null,
            )
        val largeHandle =
            RNTextEngineBindings.prepare(
                text = "EXACT ROW",
                color = null,
                fontFamily = null,
                fontSize = 44.0,
                fontWeight = "800",
                fontStyle = null,
                letterSpacing = 0.9,
                lineHeight = 48.0,
                allowFontScaling = false,
                includeFontPadding = false,
                tabularNumbers = false,
                textBreakStrategy = null,
            )
        val hostWidthPx = PixelUtil.toPixelFromDIP(260f).roundToInt()
        val hostHeightPx = PixelUtil.toPixelFromDIP(120f).roundToInt()
        val view = RNTextEnginePreparedTextViewManager.RNTextEnginePreparedTextView(application)

        try {
            InstrumentationRegistry.getInstrumentation().runOnMainSync {
                view.anchorToCapHeight = true
                view.setPreparedHandle(smallHandle)
                measureAndLayout(view, width = hostWidthPx, height = hostHeightPx)
            }

            val initialTop = effectiveTextOwnerTopInset(view.displayView)

            InstrumentationRegistry.getInstrumentation().runOnMainSync {
                view.setPreparedHandle(largeHandle)
            }
            InstrumentationRegistry.getInstrumentation().waitForIdleSync()

            val expectedTop = view.displayView.resolveCapHeightInsets(hostWidthPx).top
            assertNotEquals(initialTop, expectedTop)
            assertEquals(expectedTop, effectiveTextOwnerTopInset(view.displayView), 0.001f)
            assertEquals(hostHeightPx, view.displayView.measuredHeight)
            assertEquals(expectedAnchoredContentHeight(hostHeightPx, view.displayView.resolveCapHeightInsets(hostWidthPx)), view.displayView.height)
        } finally {
            RNTextEngineBindings.release(smallHandle)
            RNTextEngineBindings.release(largeHandle)
        }
    }

    @Test
    fun textViewMiddleEllipsisClearsWhenHostWidthExpandsOnDevice() {
        val manager = RNTextEngineTextViewManager()
        val sourceText = "0x3d3c7f1d1b4c88d6d9b0c8a5e4f2aa71"
        val intrinsicWidthDp =
            RNTextEngineBindings.measureWidth(
                text = sourceText,
                color = null,
                fontFamily = null,
                fontSize = 16.0,
                fontWeight = "700",
                fontStyle = null,
                letterSpacing = 0.2,
                lineHeight = 20.0,
                allowFontScaling = false,
                includeFontPadding = false,
                tabularNumbers = false,
                textBreakStrategy = null,
            )
        val wideWidthPx = PixelUtil.toPixelFromDIP((intrinsicWidthDp + 32.0).toFloat()).roundToInt()
        val view = RNTextEngineTextViewManager.RNTextEngineTextView(application)

        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            manager.setAllowFontScaling(view, false)
            manager.setFontSize(view, 16.0)
            manager.setFontWeight(view, "700")
            manager.setLetterSpacing(view, 0.2)
            manager.setLineHeight(view, 20.0)
            manager.setNumberOfLines(view, 1)
            manager.setEllipsizeMode(view, "middle")
            manager.setText(view, sourceText)
            measureAndLayout(view, width = wideWidthPx, height = 96)
        }

        val narrowWidthPx = findEllipsizedWidthPx(view, wideWidthPx)
        assertTrue("intrinsicWidthDp=$intrinsicWidthDp wideWidthPx=$wideWidthPx", narrowWidthPx > 0)

        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            measureAndLayout(view, width = wideWidthPx, height = 96)
        }

        val wideLayout = requireNotNull(view.displayView.resolveLayout(wideWidthPx))
        assertEquals("intrinsicWidthDp=$intrinsicWidthDp wideWidthPx=$wideWidthPx", 0, wideLayout.getEllipsisCount(0))
        assertEquals(sourceText.length, wideLayout.getLineVisibleEnd(0))
    }

    @Test
    fun textViewMiddleEllipsisDoesNotTruncateAtIntrinsicWidthOnDevice() {
        val manager = RNTextEngineTextViewManager()
        val sourceText = "Approximating"
        val intrinsicWidthDp =
            RNTextEngineBindings.measureWidth(
                text = sourceText,
                color = null,
                fontFamily = null,
                fontSize = 28.0,
                fontWeight = "800",
                fontStyle = null,
                letterSpacing = 0.1,
                lineHeight = 32.0,
                allowFontScaling = false,
                includeFontPadding = false,
                tabularNumbers = false,
                textBreakStrategy = null,
            )
        val intrinsicWidthPx = ceil(PixelUtil.toPixelFromDIP(intrinsicWidthDp.toFloat()).toDouble()).toInt()
        val view = RNTextEngineTextViewManager.RNTextEngineTextView(application)

        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            manager.setAllowFontScaling(view, false)
            manager.setFontSize(view, 28.0)
            manager.setFontWeight(view, "800")
            manager.setLetterSpacing(view, 0.1)
            manager.setLineHeight(view, 32.0)
            manager.setNumberOfLines(view, 1)
            manager.setEllipsizeMode(view, "middle")
            manager.setText(view, sourceText)
            measureAndLayout(view, width = intrinsicWidthPx, height = PixelUtil.toPixelFromDIP(48f).roundToInt())
        }

        val layout = requireNotNull(view.displayView.resolveLayout(intrinsicWidthPx))
        assertEquals("intrinsicWidthDp=$intrinsicWidthDp intrinsicWidthPx=$intrinsicWidthPx", 0, layout.getEllipsisCount(0))
        assertEquals(sourceText.length, layout.getLineVisibleEnd(0))
    }

    @Test
    fun preparedTextViewCapAnchoredMountedBaselineMatchesMeasuredHeightOnDevice() {
        val text = "Push this harder. A prepared message can be measured repeatedly without rebuilding the message itself."
        val handle =
            RNTextEngineBindings.prepare(
                text = text,
                color = null,
                fontFamily = "serif",
                fontSize = 17.0,
                fontWeight = null,
                fontStyle = null,
                letterSpacing = 0.0,
                lineHeight = 24.0,
                allowFontScaling = false,
                includeFontPadding = false,
                tabularNumbers = false,
                textBreakStrategy = null,
            )

        try {
            val measured = RNTextEngineBindings.layout(handle, 180.0, 0, null, true)
            assertTrue("measured=${measured.contentToString()}", measured[1] > 0.0)

            val hostWidthPx = PixelUtil.toPixelFromDIP(180f).roundToInt()
            val hostHeightPx = PixelUtil.toPixelFromDIP(measured[1].toFloat()).roundToInt()
            val view = RNTextEnginePreparedTextViewManager.RNTextEnginePreparedTextView(application)

            InstrumentationRegistry.getInstrumentation().runOnMainSync {
                view.anchorToCapHeight = true
                view.setPreparedHandle(handle)
                measureAndLayout(view, width = hostWidthPx, height = hostHeightPx)
            }

            val mountedLayout = requireNotNull(view.displayView.resolveLayout(hostWidthPx))
            val mountedBaseline = view.displayView.y + mountedLayout.getLineBaseline(mountedLayout.lineCount - 1)

            assertTrue("measured=${measured.contentToString()} baseline=$mountedBaseline hostHeightPx=$hostHeightPx", abs(mountedBaseline - hostHeightPx) <= 1)
        } finally {
            RNTextEngineBindings.release(handle)
        }
    }

    @Test
    fun preparedTextViewCapAnchoredPaddingUsesTheHostWidthOnDevice() {
        val text = "Push this harder. A prepared message can be measured repeatedly without rebuilding the message itself."
        val handle =
            RNTextEngineBindings.prepare(
                text = text,
                color = null,
                fontFamily = "serif",
                fontSize = 17.0,
                fontWeight = null,
                fontStyle = null,
                letterSpacing = 0.0,
                lineHeight = 24.0,
                allowFontScaling = false,
                includeFontPadding = false,
                tabularNumbers = false,
                textBreakStrategy = null,
            )

        try {
            val hostWidthPx = PixelUtil.toPixelFromDIP(240f).roundToInt()
            val hostHeightPx = PixelUtil.toPixelFromDIP(120f).roundToInt()
            val view = RNTextEnginePreparedTextViewManager.RNTextEnginePreparedTextView(application)

            InstrumentationRegistry.getInstrumentation().runOnMainSync {
                view.anchorToCapHeight = true
                view.setContentPadding(16, 16, 16, 16)
                view.setPreparedHandle(handle)
                measureAndLayout(view, width = hostWidthPx, height = hostHeightPx)
            }

            val insets = view.displayView.resolveCapHeightInsets(hostWidthPx)

            assertEquals(insets.top, effectiveTextOwnerTopInset(view.displayView), 0.001f)
            assertEquals(hostHeightPx, view.displayView.measuredHeight)
            assertEquals(expectedAnchoredContentHeight(hostHeightPx, insets), view.displayView.height)
        } finally {
            RNTextEngineBindings.release(handle)
        }
    }

    @Test
    fun preparedTextShrinkToFitWidthKeepsMountedLineBreaksOnDevice() {
        val text =
            "Push this harder. A prepared message can be measured repeatedly as the viewport changes width, font scale, or split-screen mode, without rebuilding the message itself. The UI stays simple. The substrate gets stronger."
        val handle =
            RNTextEngineBindings.prepare(
                text = text,
                color = null,
                fontFamily = null,
                fontSize = 17.0,
                fontWeight = null,
                fontStyle = null,
                letterSpacing = 0.1,
                lineHeight = 24.0,
                allowFontScaling = false,
                includeFontPadding = false,
                tabularNumbers = false,
                textBreakStrategy = null,
            )

        try {
            val view = RNTextEnginePreparedTextViewManager.RNTextEnginePreparedTextView(application)
            for (widthDp in listOf(180.0, 224.0, 280.0)) {
                val measured = RNTextEngineBindings.layout(handle, widthDp, 0, null, true)
                val hostWidthPx = ceil(PixelUtil.toPixelFromDIP(measured[0].toFloat()).toDouble()).toInt()
                val hostHeightPx = ceil(PixelUtil.toPixelFromDIP(measured[1].toFloat()).toDouble()).toInt()
                val actualWidthDp = hostWidthPx / application.resources.displayMetrics.density.toDouble()
                val expectedLines = unpackLines(RNTextEngineBindings.layoutLines(handle, actualWidthDp, 0, null, true))

                for (selectable in listOf(false, true)) {
                    InstrumentationRegistry.getInstrumentation().runOnMainSync {
                        view.anchorToCapHeight = true
                        view.setPreparedHandle(handle)
                        view.setSelectable(selectable)
                        measureAndLayout(view, width = hostWidthPx, height = hostHeightPx)
                    }

                    val layout = requireNotNull(
                        if (selectable) view.textContentView.layout else view.displayView.resolveLayout(hostWidthPx)
                    )
                    val context = "width=$widthDp selectable=$selectable"
                    assertEquals(context, expectedLines.size, layout.lineCount)
                    expectedLines.forEachIndexed { index, line ->
                        val expected = text.substring(line.start.toInt(), line.end.toInt()).trimEnd()
                        val actual = text.substring(layout.getLineStart(index), layout.getLineEnd(index)).trimEnd()
                        assertEquals("$context line=$index", expected, actual)
                    }
                }
            }
        } finally {
            RNTextEngineBindings.release(handle)
        }
    }

    @Test
    fun preparedTextShrinkToFitWidthKeepsMountedBaselineAndVisibleEndForTheChatMessageOnDevice() {
        val text =
            "Push this harder. A prepared message can be measured repeatedly as the viewport changes width, font scale, or split-screen mode, without rebuilding the message itself. The UI stays simple. The substrate gets stronger."
        val handle =
            RNTextEngineBindings.prepare(
                text = text,
                color = null,
                fontFamily = null,
                fontSize = 17.0,
                fontWeight = null,
                fontStyle = null,
                letterSpacing = 0.1,
                lineHeight = 24.0,
                allowFontScaling = false,
                includeFontPadding = false,
                tabularNumbers = false,
                textBreakStrategy = null,
            )

        try {
            val measured = RNTextEngineBindings.layout(handle, 180.0, 0, null, true)
            val hostWidthPx = ceil(PixelUtil.toPixelFromDIP(measured[0].toFloat()).toDouble()).toInt()
            val hostHeightPx = ceil(PixelUtil.toPixelFromDIP(measured[1].toFloat()).toDouble()).toInt()
            val view = RNTextEnginePreparedTextViewManager.RNTextEnginePreparedTextView(application)

            InstrumentationRegistry.getInstrumentation().runOnMainSync {
                view.anchorToCapHeight = true
                view.setPreparedHandle(handle)
                measureAndLayout(view, width = hostWidthPx, height = hostHeightPx)
            }

            val mountedLayout = requireNotNull(view.displayView.resolveLayout(hostWidthPx))
            val mountedBaseline = view.displayView.y + mountedLayout.getLineBaseline(mountedLayout.lineCount - 1)

            assertEquals("measured=${measured.contentToString()}", measured[2].toInt(), mountedLayout.lineCount)
            assertEquals("measured=${measured.contentToString()} baseline=$mountedBaseline hostHeightPx=$hostHeightPx", hostHeightPx.toFloat(), mountedBaseline, 1f)
            assertEquals(text.length, mountedLayout.getLineVisibleEnd(mountedLayout.lineCount - 1))
            assertEquals(0, mountedLayout.getEllipsisCount(mountedLayout.lineCount - 1))
        } finally {
            RNTextEngineBindings.release(handle)
        }
    }

    private fun assertNextLineMatchesLayoutLines(handle: Long, widthDp: Double, anchorToCapHeight: Boolean) {
        val lines = unpackLines(RNTextEngineBindings.layoutLines(handle, widthDp, 0, null, anchorToCapHeight))
        var startIndex = 0
        var previousBottom = 0.0
        val anchoredLineBottom = lines.firstOrNull()?.bottom ?: 0.0

        lines.forEach { expected ->
            val actual = requireNotNull(RNTextEngineBindings.layoutNextLine(handle, startIndex, widthDp, anchorToCapHeight))
            val expectedBottom = if (anchorToCapHeight) anchoredLineBottom else expected.bottom - previousBottom
            val context =
                "widthDp=$widthDp anchor=$anchorToCapHeight startIndex=$startIndex expected=$expected expectedBottom=$expectedBottom actual=${actual.contentToString()} lines=$lines"

            assertEquals(context, expected.start, actual[0], 0.0001)
            assertEquals(context, expected.end, actual[1], 0.0001)
            assertEquals(context, expected.width, actual[2], 0.0001)
            assertEquals(context, expectedBottom, actual[3], 0.0001)

            val nextStart = actual[1].toInt()
            if (nextStart <= startIndex) return
            previousBottom = expected.bottom
            startIndex = nextStart
        }
    }

    private fun unpackLines(packed: DoubleArray): List<InstrumentedPackedLine> {
        val lines = ArrayList<InstrumentedPackedLine>()
        var index = 4

        while (index + 3 < packed.size) {
            lines +=
                InstrumentedPackedLine(
                    bottom = packed[index + 3],
                    end = packed[index + 1],
                    start = packed[index],
                    width = packed[index + 2],
                )
            index += 4
        }

        return lines
    }

    private fun measureAndLayout(view: View, width: Int, height: Int) {
        val widthSpec = View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY)
        val heightSpec = View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY)
        view.measure(widthSpec, heightSpec)
        view.layout(0, 0, width, height)
    }

    private fun buildEllipsizedSingleLineLayout(
        prepared: RNTextEngineBindings.PreparedTextViewData,
        widthDp: Double,
    ): Layout {
        val widthPx = ceil(PixelUtil.toPixelFromDIP(widthDp.toFloat()).toDouble()).toInt()
        return buildStaticLayoutCompat(
            text = prepared.text,
            paint = TextPaint(prepared.textPaint),
            widthPx = widthPx,
            includeFontPadding = prepared.includeFontPadding,
            breakStrategy = Layout.BREAK_STRATEGY_HIGH_QUALITY,
            hyphenationFrequency = Layout.HYPHENATION_FREQUENCY_NORMAL,
            maxLines = 1,
            ellipsize = android.text.TextUtils.TruncateAt.MIDDLE,
        )
    }

    private fun findEllipsizedWidthPx(
        view: RNTextEngineTextViewManager.RNTextEngineTextView,
        wideWidthPx: Int,
    ): Int {
        var widthPx = wideWidthPx

        while (widthPx > 1) {
            widthPx = max(1, (widthPx * 0.75f).roundToInt())
            InstrumentationRegistry.getInstrumentation().runOnMainSync {
                measureAndLayout(view, width = widthPx, height = 96)
            }

            val layout = requireNotNull(view.displayView.resolveLayout(widthPx))
            if (layout.getEllipsisCount(0) > 0) return widthPx
        }

        return 0
    }

    private fun effectiveTextOwnerTopInset(view: View): Float {
        return -view.y
    }
}
