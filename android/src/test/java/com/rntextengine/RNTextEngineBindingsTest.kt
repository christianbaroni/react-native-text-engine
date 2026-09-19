package com.rntextengine

import android.app.Application
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Build
import android.text.BoringLayout
import android.text.Layout
import android.text.Spanned
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils
import androidx.test.core.app.ApplicationProvider
import com.facebook.react.bridge.Callback
import com.facebook.react.bridge.CatalystInstance
import com.facebook.react.bridge.JavaScriptContextHolder
import com.facebook.react.bridge.JavaScriptModule
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.RuntimeExecutor
import com.facebook.react.bridge.UIManager
import com.facebook.react.uimanager.DisplayMetricsHolder
import com.facebook.react.uimanager.PixelUtil
import com.facebook.react.turbomodule.core.interfaces.CallInvokerHolder
import kotlin.math.ceil
import kotlin.math.max
import org.junit.After
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.assertThrows
import org.junit.Before
import org.junit.Ignore
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.RobolectricTestRunner

private data class PackedLine(
    val bottom: Double,
    val end: Double,
    val start: Double,
    val width: Double,
)

private class TestReactApplicationContext(application: Application) : ReactApplicationContext(application) {
    override fun <T : JavaScriptModule> getJSModule(jsInterface: Class<T>): T {
        throw UnsupportedOperationException("JS modules are not used in RNTextEngineBindings tests.")
    }

    override fun <T : NativeModule> hasNativeModule(nativeModuleInterface: Class<T>): Boolean = false

    override fun getNativeModules(): MutableCollection<NativeModule> = mutableListOf()

    override fun <T : NativeModule> getNativeModule(nativeModuleInterface: Class<T>): T? = null

    override fun getNativeModule(moduleName: String): NativeModule? = null

    override fun getCatalystInstance(): CatalystInstance {
        throw UnsupportedOperationException("CatalystInstance is not used in RNTextEngineBindings tests.")
    }

    override fun hasActiveCatalystInstance(): Boolean = false

    override fun hasActiveReactInstance(): Boolean = false

    override fun hasCatalystInstance(): Boolean = false

    override fun hasReactInstance(): Boolean = false

    override fun destroy() = Unit

    override fun handleException(e: Exception) {
        throw e
    }

    override fun isBridgeless(): Boolean = false

    override fun getJavaScriptContextHolder(): JavaScriptContextHolder? = null

    override fun getRuntimeExecutor(): RuntimeExecutor? = null

    override fun getJSCallInvokerHolder(): CallInvokerHolder? = null

    override fun getFabricUIManager(): UIManager? = null

    override fun getSourceURL(): String? = null

    override fun registerSegment(segmentId: Int, path: String, callback: Callback) = Unit
}

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class RNTextEngineBindingsTest {
    private lateinit var application: Application

    @Before
    fun setUp() {
        application = ApplicationProvider.getApplicationContext()
        DisplayMetricsHolder.initDisplayMetrics(application)
        RNTextEngineBindings.initialize(TestReactApplicationContext(application))
        RNTextEngineBindings.cleanup()
    }

    @After
    fun tearDown() {
        RNTextEngineBindings.cleanup()
    }

    @Test
    fun preparedBatchLayoutMatchesSingleLayoutAndReleaseClearsViewData() {
        val singleAlpha =
            RNTextEngineBindings.prepare(
                text = "Alpha beta gamma",
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
        val singleBeta =
            RNTextEngineBindings.prepare(
                text = "Delta epsilon zeta",
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
        val batch =
            RNTextEngineBindings.prepareBatch(
                texts = arrayOf("Alpha beta gamma", "Delta epsilon zeta"),
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

        val batchLayout = RNTextEngineBindings.layoutBatch(batch, 120.0, 0, null, false)
        val singleLayout =
            RNTextEngineBindings.layout(singleAlpha, 120.0, 0, null, false) +
                RNTextEngineBindings.layout(singleBeta, 120.0, 0, null, false)

        assertArrayEquals(singleLayout, batchLayout, 0.0001)
        assertEquals("Alpha beta gamma", RNTextEngineBindings.resolvePreparedTextViewData(singleAlpha)?.text?.toString())
        assertNotNull(RNTextEngineBindings.resolvePreparedTextViewData(singleBeta))

        RNTextEngineBindings.releaseMany(batch)
        RNTextEngineBindings.release(singleAlpha)
        RNTextEngineBindings.release(singleBeta)

        assertNull(RNTextEngineBindings.resolvePreparedTextViewData(singleAlpha))
        assertNull(RNTextEngineBindings.resolvePreparedTextViewData(singleBeta))
    }

    @Test
    fun measureMatchesPreparedLayoutAndReleaseInvalidatesTheHandle() {
        val handle =
            RNTextEngineBindings.prepare(
                text = "Prepared layout should match one-shot measurement.",
                color = null,
                fontFamily = null,
                fontSize = 17.0,
                fontWeight = "500",
                fontStyle = null,
                letterSpacing = 0.2,
                lineHeight = 24.0,
                allowFontScaling = false,
                includeFontPadding = false,
                tabularNumbers = false,
                textBreakStrategy = "highQuality",
            )

        val measured =
            RNTextEngineBindings.measure(
                text = "Prepared layout should match one-shot measurement.",
                color = null,
                fontFamily = null,
                fontSize = 17.0,
                fontWeight = "500",
                fontStyle = null,
                letterSpacing = 0.2,
                lineHeight = 24.0,
                allowFontScaling = false,
                includeFontPadding = false,
                tabularNumbers = false,
                textBreakStrategy = "highQuality",
                width = 180.0,
                maxLines = 0,
                ellipsizeMode = null,
                anchorToCapHeight = false,
            )
        val laidOut = RNTextEngineBindings.layout(handle, 180.0, 0, null, false)

        assertArrayEquals(measured, laidOut, 0.0001)

        RNTextEngineBindings.release(handle)

        val error = assertThrows(IllegalStateException::class.java) {
            RNTextEngineBindings.layout(handle, 180.0, 0, null, false)
        }
        assertTrue(error.message?.contains("invalid prepared text handle") == true)
    }

    @Test
    @Config(qualifiers = "xhdpi")
    fun intrinsicWidthMatchesReactTextMeasurement() {
        val handle =
            RNTextEngineBindings.prepare(
                text = "Buy Ethereum",
                color = null,
                fontFamily = null,
                fontSize = 17.0,
                fontWeight = "700",
                fontStyle = null,
                letterSpacing = 0.6,
                lineHeight = 22.0,
                allowFontScaling = false,
                includeFontPadding = false,
                tabularNumbers = false,
                textBreakStrategy = null,
            )
        val prepared = requireNotNull(RNTextEngineBindings.resolvePreparedTextViewData(handle))
        val expectedWidthDp = measureReactTextWidth(prepared.text, prepared.textPaint, prepared.includeFontPadding)
        val measuredWidthDp = RNTextEngineBindings.measurePreparedWidth(handle)

        assertEquals(expectedWidthDp, measuredWidthDp, 0.0001)

        RNTextEngineBindings.release(handle)
    }

    @Test
    fun sharedTextViewDisplayDataKeepsTypographyInSyncWithPreparedTextViewOwner() {
        val direct =
            RNTextEngineBindings.buildTextViewDisplayData(
                text = "exact row",
                textTransform = "uppercase",
                color = null,
                fontFamily = null,
                fontSize = 20.0,
                fontWeight = "800",
                fontStyle = null,
                letterSpacing = 1.5,
                lineHeight = 24.0,
                allowFontScaling = true,
                tabularNumbers = true,
                textBreakStrategy = null,
            )
        val handle =
            RNTextEngineBindings.prepareTextView(
                text = "exact row",
                textTransform = "uppercase",
                color = null,
                fontFamily = null,
                fontSize = 20.0,
                fontWeight = "800",
                fontStyle = null,
                letterSpacing = 1.5,
                lineHeight = 24.0,
                allowFontScaling = true,
                includeFontPadding = false,
                tabularNumbers = true,
                textBreakStrategy = null,
            )
        val prepared = requireNotNull(RNTextEngineBindings.resolvePreparedTextViewData(handle))

        assertEquals(prepared.text.toString(), direct.text.toString())
        assertEquals(prepared.textPaint.textSize, direct.textPaint.textSize, 0.0001f)
        assertEquals(prepared.textPaint.letterSpacing, direct.textPaint.letterSpacing, 0.0001f)
        assertEquals(prepared.textPaint.fontFeatureSettings, direct.textPaint.fontFeatureSettings)
        assertEquals(prepared.textColor, direct.textColor)
        assertEquals(prepared.includeFontPadding, direct.includeFontPadding)
        assertEquals(prepared.baseCapHeightPx, direct.baseCapHeightPx, 0.0001f)
        assertEquals(prepared.uniformCapHeightPx, direct.uniformCapHeightPx)

        RNTextEngineBindings.release(handle)
    }

    @Test
    fun plainPreparedTextViewDataKeepsTheExactPreparedMountedTextPath() {
        val handle =
            RNTextEngineBindings.prepareTextView(
                text = "exact row",
                textTransform = "uppercase",
                color = null,
                fontFamily = null,
                fontSize = 20.0,
                fontWeight = "800",
                fontStyle = null,
                letterSpacing = 1.5,
                lineHeight = 24.0,
                allowFontScaling = false,
                includeFontPadding = false,
                tabularNumbers = false,
                textBreakStrategy = null,
            )
        val prepared = requireNotNull(RNTextEngineBindings.resolvePreparedTextViewData(handle))

        assertEquals(RNTextEngineBindings.TextMountMode.SPANNABLE, prepared.mountMode)
        assertTrue(prepared.text is Spanned)
        assertEquals("EXACT ROW", prepared.text.toString())
        assertEquals(null, prepared.lineHeightPx)

        RNTextEngineBindings.release(handle)
    }

    @Test
    fun plainTextViewDisplayDataKeepsTheNativeMountedTextPath() {
        val direct =
            RNTextEngineBindings.buildTextViewDisplayData(
                text = "exact row",
                textTransform = "uppercase",
                color = null,
                fontFamily = null,
                fontSize = 20.0,
                fontWeight = "800",
                fontStyle = null,
                letterSpacing = 1.5,
                lineHeight = 24.0,
                allowFontScaling = false,
                tabularNumbers = false,
                textBreakStrategy = null,
            )

        assertEquals(RNTextEngineBindings.TextMountMode.NATIVE, direct.mountMode)
        assertFalse(direct.text is Spanned)
        assertEquals("EXACT ROW", direct.text.toString())
        assertEquals(PixelUtil.toPixelFromDIP(24f), direct.lineHeightPx ?: Float.NaN, 0.0001f)
    }

    @Test
    fun inlineRunPreparedTextViewDataKeepsTheStyledMountedTextPath() {
        val handle =
            RNTextEngineBindings.prepareTextViewWithRuns(
                text = "Alpha beta",
                textTransform = null,
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
                runStarts = intArrayOf(6),
                runEnds = intArrayOf(10),
                runStyleMasks = intArrayOf(1 shl 2),
                runColors = arrayOfNulls(1),
                runFontFamilies = arrayOfNulls(1),
                runFontSizes = doubleArrayOf(24.0),
                runFontWeights = arrayOfNulls(1),
                runFontStyles = arrayOfNulls(1),
                runLetterSpacings = doubleArrayOf(0.0),
                runLineHeights = doubleArrayOf(0.0),
                runTabularNumbers = booleanArrayOf(false),
            )
        val prepared = requireNotNull(RNTextEngineBindings.resolvePreparedTextViewData(handle))

        assertEquals(RNTextEngineBindings.TextMountMode.SPANNABLE, prepared.mountMode)
        assertTrue(prepared.text is Spanned)

        RNTextEngineBindings.release(handle)
    }

    @Test
    fun layoutWidthMatchesReactTextMeasurement() {
        val handle =
            RNTextEngineBindings.prepare(
                text = "0x3d...8cB0",
                color = null,
                fontFamily = null,
                fontSize = 20.0,
                fontWeight = "800",
                fontStyle = null,
                letterSpacing = 0.6,
                lineHeight = 24.0,
                allowFontScaling = false,
                includeFontPadding = false,
                tabularNumbers = false,
                textBreakStrategy = null,
            )
        val prepared = requireNotNull(RNTextEngineBindings.resolvePreparedTextViewData(handle))
        val widthDp = measureReactTextWidth(prepared.text, prepared.textPaint, prepared.includeFontPadding)
        val expectedWidthDp = measureReactTextLayoutWidth(prepared.text, prepared.textPaint, prepared.includeFontPadding, widthDp)
        val measuredWidthDp = RNTextEngineBindings.layout(handle, widthDp, 0, null, false)[0]

        assertEquals(expectedWidthDp, measuredWidthDp, 0.0001)

        RNTextEngineBindings.release(handle)
    }

    @Test
    @Ignore("Ellipsize behavior is verified on-device; Robolectric does not faithfully apply Android's single-line ellipsis contract here.")
    fun ellipsizedSingleLineLayoutKeepsTheAssignedWidth() {
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
        val prepared = requireNotNull(RNTextEngineBindings.resolvePreparedTextViewData(handle))
        val intrinsicWidthDp = measureReactTextWidth(prepared.text, prepared.textPaint, prepared.includeFontPadding)
        var widthDp = max(1.0, intrinsicWidthDp * 0.5)
        var layout = buildEllipsizedSingleLineLayout(prepared, widthDp)

        while (layout.getEllipsisCount(0) == 0 && widthDp > 1.0) {
            widthDp = max(1.0, widthDp * 0.75)
            layout = buildEllipsizedSingleLineLayout(prepared, widthDp)
        }

        assertTrue("intrinsicWidthDp=$intrinsicWidthDp constrainedWidthDp=$widthDp", layout.getEllipsisCount(0) > 0)
        assertEquals(widthDp, RNTextEngineBindings.layout(handle, widthDp, 1, "middle", false)[0], 0.0001)

        RNTextEngineBindings.release(handle)
    }

    @Test
    fun prepareTextViewWithRunsRemapsSpansAfterTextExpansion() {
        val handle =
            RNTextEngineBindings.prepareTextViewWithRuns(
                text = "ßb",
                textTransform = "uppercase",
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
                runStarts = intArrayOf(1),
                runEnds = intArrayOf(2),
                runStyleMasks = intArrayOf(1 shl 2),
                runColors = arrayOfNulls(1),
                runFontFamilies = arrayOfNulls(1),
                runFontSizes = doubleArrayOf(40.0),
                runFontWeights = arrayOfNulls(1),
                runFontStyles = arrayOfNulls(1),
                runLetterSpacings = doubleArrayOf(0.0),
                runLineHeights = doubleArrayOf(0.0),
                runTabularNumbers = booleanArrayOf(false),
            )

        val prepared = RNTextEngineBindings.resolvePreparedTextViewData(handle)
        assertNotNull(prepared)
        assertEquals("SSB", prepared?.text?.toString())

        val text = prepared?.text as android.text.Spanned
        val spans = text.getSpans(0, text.length, RNTextEngineTextPaintSpan::class.java)
        assertEquals(1, spans.size)
        assertEquals(2, text.getSpanStart(spans[0]))
        assertEquals(3, text.getSpanEnd(spans[0]))

        RNTextEngineBindings.release(handle)
    }

    @Test
    fun anchorToCapHeightTrimsOnlyTheOuterTopAndBottomEdges() {
        val handle =
            RNTextEngineBindings.prepare(
                text = "First line\nSecond line\nThird line",
                color = null,
                fontFamily = "serif",
                fontSize = 17.0,
                fontWeight = null,
                fontStyle = null,
                letterSpacing = Double.NaN,
                lineHeight = 24.0,
                allowFontScaling = false,
                includeFontPadding = false,
                tabularNumbers = false,
                textBreakStrategy = null,
            )

        val unanchored = RNTextEngineBindings.layoutLines(handle, 240.0, 0, null, false)
        val anchored = RNTextEngineBindings.layoutLines(handle, 240.0, 0, null, true)
        val unanchoredLines = unpackLines(unanchored)
        val anchoredLines = unpackLines(anchored)

        assertEquals(unanchoredLines.size, anchoredLines.size)
        assertTrue(anchored[1] > 0.0)
        assertTrue(anchored[1] < unanchored[1])
        assertEquals(24.0, anchoredLines[1].bottom - anchoredLines[0].bottom, 0.0001)
    }

    @Test
    fun layoutWidthIsStableForThePreparedChatShrinkToFitMessage() {
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
            val constrained = RNTextEngineBindings.layout(handle, 180.0, 0, null, true)
            val shrinkToFit = RNTextEngineBindings.layout(handle, constrained[0], 0, null, true)

            assertEquals(constrained.contentToString(), constrained[2], shrinkToFit[2], 0.0001)
            assertEquals(constrained.contentToString(), constrained[1], shrinkToFit[1], 0.0001)
            assertEquals(constrained.contentToString(), constrained[0], shrinkToFit[0], 0.0001)
        } finally {
            RNTextEngineBindings.release(handle)
        }
    }

    @Test
    @Ignore("Production layoutNextLine contract is validated by instrumented Android tests; Robolectric does not faithfully model the real text primitives used here.")
    fun layoutLinesAndNextLineStayAlignedForResolvedLineStarts() {
        val handle =
            RNTextEngineBindings.prepare(
                text = "First line\nSecond line\nThird line",
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

        val packedLines = RNTextEngineBindings.layoutLines(handle, 240.0, 0, null, false)
        val lines = unpackLines(packedLines)

        val firstLine = RNTextEngineBindings.layoutNextLine(handle, 0, 240.0, false)
        val secondLine = RNTextEngineBindings.layoutNextLine(handle, lines[1].start.toInt(), 240.0, false)

        assertTrue("Packed lines: ${packedLines.contentToString()}", lines.size == 3)

        val resolvedFirstLine = requireNotNull(firstLine)
        val resolvedSecondLine = requireNotNull(secondLine)

        assertEquals(lines[0].start, resolvedFirstLine[0], 0.0001)
        assertEquals(lines[0].end, resolvedFirstLine[1], 0.0001)
        assertEquals(lines[1].start, resolvedSecondLine[0], 0.0001)
        assertEquals(lines[1].end, resolvedSecondLine[1], 0.0001)
        assertTrue(resolvedFirstLine[2] > 0.0)
        assertTrue(resolvedSecondLine[2] > 0.0)
        assertTrue(resolvedFirstLine[3] > 0.0)
        assertTrue(resolvedSecondLine[3] > 0.0)
    }

    @Test
    @Ignore("Production layoutNextLine contract is validated by instrumented Android tests; Robolectric does not faithfully model the real text primitives used here.")
    fun layoutLinesAndNextLineStayAlignedWhenTrailingWhitespaceIsTrimmed() {
        val spacedHandle =
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
        val spacedLines = RNTextEngineBindings.layoutLines(spacedHandle, 240.0, 0, null, false)
        val nextLine = requireNotNull(RNTextEngineBindings.layoutNextLine(spacedHandle, 0, 240.0, false))

        val lines = unpackLines(spacedLines)

        assertEquals(1, lines.size)
        assertEquals(5.0, lines[0].end, 0.0001)
        assertEquals(5.0, nextLine[1], 0.0001)
        assertEquals("spacedLines=${spacedLines.contentToString()} nextLine=${nextLine.contentToString()}", lines[0].width, nextLine[2], 0.0001)
        assertEquals("spacedLines=${spacedLines.contentToString()} nextLine=${nextLine.contentToString()}", lines[0].bottom, nextLine[3], 0.0001)
        assertEquals(lines[0].width, spacedLines[0], 0.0001)
        assertEquals(lines[0].width, spacedLines[3], 0.0001)
    }

    @Test
    @Ignore("Production layoutNextLine contract is validated by instrumented Android tests; Robolectric does not faithfully model the real text primitives used here.")
    fun layoutNextLineReturnsTheFirstVisibleLineNotTheWholeRemainingParagraphSet() {
        val text =
            "The measure is the length of a line of text -- the distance the eye travels before returning to the left edge." +
                "\n\n" +
                "Second paragraph begins here."
        val width = 240.0

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

        val lines = unpackLines(RNTextEngineBindings.layoutLines(handle, width, 0, null, false))
        val nextLine = requireNotNull(RNTextEngineBindings.layoutNextLine(handle, 0, width, false))
        val firstParagraphEnd = text.indexOf("\n\n").toDouble()

        assertTrue(lines.size > 1)
        assertEquals(lines[0].start, nextLine[0], 0.0001)
        assertEquals(lines[0].end, nextLine[1], 0.0001)
        assertTrue("lines=$lines nextLine=${nextLine.contentToString()} firstParagraphEnd=$firstParagraphEnd", nextLine[1] <= firstParagraphEnd)
        assertTrue(nextLine[1] < text.length.toDouble())
    }

    @Test
    @Ignore("Production layoutNextLine contract is validated by instrumented Android tests; Robolectric does not faithfully model the real text primitives used here.")
    fun layoutNextLineMatchesStaticLayoutForPlainPreparedTextAcrossWidths() {
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
            val prepared = requireNotNull(RNTextEngineBindings.resolvePreparedTextViewData(handle))

            try {
                widths.forEach { width ->
                    assertNextLineMatchesReference(prepared, handle, width, anchorToCapHeight = false)
                    assertNextLineMatchesReference(prepared, handle, width, anchorToCapHeight = true)
                }
            } finally {
                RNTextEngineBindings.release(handle)
            }
        }
    }

    @Test
    fun prepareWithRunsRejectsInvalidInlineRunPayloads() {
        val emptyStyleError =
            assertThrows(IllegalArgumentException::class.java) {
                RNTextEngineBindings.prepareWithRuns(
                    text = "inline",
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
                    runStarts = intArrayOf(0),
                    runEnds = intArrayOf(3),
                    runStyleMasks = intArrayOf(0),
                    runColors = arrayOfNulls(1),
                    runFontFamilies = arrayOfNulls(1),
                    runFontSizes = doubleArrayOf(0.0),
                    runFontWeights = arrayOfNulls(1),
                    runFontStyles = arrayOfNulls(1),
                    runLetterSpacings = doubleArrayOf(0.0),
                    runLineHeights = doubleArrayOf(0.0),
                    runTabularNumbers = booleanArrayOf(false),
                )
            }
        val unsortedError =
            assertThrows(IllegalArgumentException::class.java) {
                RNTextEngineBindings.prepareWithRuns(
                    text = "inline",
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
                    runStarts = intArrayOf(3, 1),
                    runEnds = intArrayOf(5, 2),
                    runStyleMasks = intArrayOf(1, 1),
                    runColors = arrayOf("#fff", "#fff"),
                    runFontFamilies = arrayOfNulls(2),
                    runFontSizes = doubleArrayOf(0.0, 0.0),
                    runFontWeights = arrayOfNulls(2),
                    runFontStyles = arrayOfNulls(2),
                    runLetterSpacings = doubleArrayOf(0.0, 0.0),
                    runLineHeights = doubleArrayOf(0.0, 0.0),
                    runTabularNumbers = booleanArrayOf(false, false),
                )
            }

        assertTrue(emptyStyleError.message?.contains("override at least one inline style field") == true)
        assertTrue(unsortedError.message?.contains("sorted and non-overlapping") == true)
    }

    @Test
    fun glyphFieldIndicesAndBuffersValidateTheirContract() {
        val handle =
            RNTextEngineBindings.createGlyphField(
                columns = 3,
                rows = 2,
                fontFamily = null,
                fontSize = 14.0,
                glyphPalette = ".#*",
                letterSpacing = 0.0,
                lineHeight = 16.0,
                textAlign = "center",
                variantColors = arrayOf("#ffffff"),
                variantFontWeights = arrayOfNulls(1),
                variantFontStyles = arrayOfNulls(1),
            )

        RNTextEngineBindings.updateGlyphFieldIndices(
            handle,
            glyphIndices = byteArrayOf(0, 1, 2, 2, 1, 0),
            variantIndices = byteArrayOf(0, 0, 0, 0, 0, 0),
        )

        val glyphBuffer = java.nio.ByteBuffer.allocateDirect(6).apply {
            put(byteArrayOf(2, 1, 0, 0, 1, 2))
        }
        val variantBuffer = java.nio.ByteBuffer.allocateDirect(6).apply {
            put(byteArrayOf(0, 0, 0, 0, 0, 0))
        }

        RNTextEngineBindings.attachGlyphFieldBuffers(handle, glyphBuffer, variantBuffer)
        RNTextEngineBindings.commitGlyphFieldBuffers(handle)

        val error =
            assertThrows(IllegalArgumentException::class.java) {
                RNTextEngineBindings.updateGlyphFieldIndices(
                    handle,
                    glyphIndices = byteArrayOf(3, 0, 0, 0, 0, 0),
                    variantIndices = byteArrayOf(0, 0, 0, 0, 0, 0),
                )
            }

        assertTrue(error.message?.contains("glyph index exceeded the configured glyphPalette length") == true)

        RNTextEngineBindings.releaseGlyphField(handle)
    }

    @Test
    fun oneShotPlainBatchMeasureMatchesPreparedLayoutAcrossChatCorpus() {
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
                assertArrayEquals("text=$text", measured, laidOut, 0.0001)
            } finally {
                RNTextEngineBindings.release(handle)
            }
        }
    }

    @Test
    fun glyphFieldIndicesUpdatedWithoutViewsStillDrawOnFirstRender() {
        val handle =
            RNTextEngineBindings.createGlyphField(
                columns = 3,
                rows = 2,
                fontFamily = null,
                fontSize = 14.0,
                glyphPalette = ".#*",
                letterSpacing = 0.0,
                lineHeight = 16.0,
                textAlign = "center",
                variantColors = arrayOf("#ffffffff"),
                variantFontWeights = arrayOfNulls(1),
                variantFontStyles = arrayOfNulls(1),
            )

        try {
            RNTextEngineBindings.updateGlyphFieldIndices(
                handle,
                glyphIndices = byteArrayOf(0, 1, 2, 2, 1, 0),
                variantIndices = byteArrayOf(0, 0, 0, 0, 0, 0),
            )

            val glyphField = resolveGlyphFieldHandleState(handle)
            assertTrue(resolveGlyphFieldRenderedRows(glyphField).isEmpty())

            val bitmap = Bitmap.createBitmap(80, 40, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            RNTextEngineBindings.drawGlyphField(handle, canvas, bitmap.width.toFloat(), bitmap.height.toFloat())

            assertEquals(2, resolveGlyphFieldRenderedRows(glyphField).size)
        } finally {
            RNTextEngineBindings.releaseGlyphField(handle)
        }
    }

    @Test
    fun glyphFieldStringUpdatedWithoutViewsStillDrawOnFirstRender() {
        val handle =
            RNTextEngineBindings.createGlyphField(
                columns = 3,
                rows = 2,
                fontFamily = null,
                fontSize = 14.0,
                glyphPalette = ".#*",
                letterSpacing = 0.0,
                lineHeight = 16.0,
                textAlign = "center",
                variantColors = arrayOf("#ffffffff"),
                variantFontWeights = arrayOfNulls(1),
                variantFontStyles = arrayOfNulls(1),
            )

        try {
            RNTextEngineBindings.updateGlyphField(
                handle,
                glyphs = ".#**#.",
                variantIndices = byteArrayOf(0, 0, 0, 0, 0, 0),
            )

            val glyphField = resolveGlyphFieldHandleState(handle)
            assertTrue(resolveGlyphFieldRenderedRows(glyphField).isEmpty())

            val bitmap = Bitmap.createBitmap(80, 40, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            RNTextEngineBindings.drawGlyphField(handle, canvas, bitmap.width.toFloat(), bitmap.height.toFloat())

            assertEquals(2, resolveGlyphFieldRenderedRows(glyphField).size)
        } finally {
            RNTextEngineBindings.releaseGlyphField(handle)
        }
    }

    private fun resolveGlyphFieldHandleState(handle: Long): Any {
        val glyphFieldsField = RNTextEngineBindings::class.java.getDeclaredField("glyphFields").apply { isAccessible = true }
        val glyphFields = glyphFieldsField.get(RNTextEngineBindings) as Map<*, *>
        return requireNotNull(glyphFields[handle])
    }

    private fun resolveGlyphFieldRenderedRows(glyphField: Any): List<*> {
        val renderedRowsField = glyphField.javaClass.getDeclaredField("renderedRows").apply { isAccessible = true }
        return renderedRowsField.get(glyphField) as List<*>
    }

    private fun unpackLines(packed: DoubleArray): List<PackedLine> {
        val lines = ArrayList<PackedLine>()
        var index = 4

        while (index + 3 < packed.size) {
            lines +=
                PackedLine(
                    start = packed[index],
                    end = packed[index + 1],
                    width = packed[index + 2],
                    bottom = packed[index + 3],
                )
            index += 4
        }

        return lines
    }

    private fun assertNextLineMatchesReference(
        prepared: RNTextEngineBindings.PreparedTextViewData,
        handle: Long,
        widthDp: Double,
        anchorToCapHeight: Boolean,
    ) {
        var start = 0

        while (true) {
            val actual = RNTextEngineBindings.layoutNextLine(handle, start, widthDp, anchorToCapHeight)
            val expected = resolveReferenceNextLine(prepared, start, widthDp, anchorToCapHeight)

            if (expected == null) {
                assertNull(actual)
                return
            }

            val resolved = requireNotNull(actual)
            val context =
                "text=${prepared.text} widthDp=$widthDp anchor=$anchorToCapHeight start=$start expected=$expected actual=${resolved.contentToString()}"
            assertEquals(context, expected.start, resolved[0], 0.0001)
            assertEquals(context, expected.end, resolved[1], 0.0001)
            assertEquals(context, expected.width, resolved[2], 0.0001)
            assertEquals(context, expected.bottom, resolved[3], 0.0001)

            val nextStart = resolved[1].toInt()
            if (nextStart <= start) return
            start = nextStart
        }
    }

    private fun resolveReferenceNextLine(
        prepared: RNTextEngineBindings.PreparedTextViewData,
        start: Int,
        widthDp: Double,
        anchorToCapHeight: Boolean,
    ): PackedLine? {
        val text = prepared.text
        if (start < 0 || start >= text.length) return null

        val widthPx = max(1, ceil(PixelUtil.toPixelFromDIP(widthDp.toFloat()).toDouble()).toInt())
        val paint = TextPaint(prepared.textPaint)
        val layout =
            StaticLayout.Builder.obtain(text, start, text.length, paint, widthPx)
                .setAlignment(Layout.Alignment.ALIGN_NORMAL)
                .setIncludePad(prepared.includeFontPadding)
                .setBreakStrategy(Layout.BREAK_STRATEGY_HIGH_QUALITY)
                .setHyphenationFrequency(Layout.HYPHENATION_FREQUENCY_NORMAL)
                .setMaxLines(1)
                .apply {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        setUseLineSpacingFromFallbacks(true)
                    }
                }
                .build()
        if (layout.lineCount == 0) return null

        val lineStart = layout.getLineStart(0).toDouble()
        val lineEnd = trimVisibleEnd(text, lineStart.toInt(), layout.getLineVisibleEnd(0)).toDouble()
        val lineBottom =
            if (anchorToCapHeight) {
                measureCapHeightPx(paint).toDouble() / application.resources.displayMetrics.density
            } else {
                layout.getLineBottom(0).toDouble() / application.resources.displayMetrics.density
            }

        return PackedLine(
            bottom = lineBottom,
            end = lineEnd,
            start = lineStart,
            width = resolveReferencePlainTextWidthPx(paint, text.toString(), lineStart.toInt(), lineEnd.toInt()).toDouble() /
                application.resources.displayMetrics.density,
        )
    }

    private fun trimVisibleEnd(text: CharSequence, start: Int, end: Int): Int {
        var visibleEnd = end

        while (visibleEnd > start && text[visibleEnd - 1].isWhitespace()) {
            visibleEnd -= 1
        }

        return visibleEnd
    }

    private fun resolveReferencePlainTextWidthPx(paint: TextPaint, text: String, start: Int, end: Int): Float {
        if (end <= start) return 0f
        val measuredWidth = paint.getRunAdvance(text, start, end, start, end, false, end)
        return if (Build.VERSION.SDK_INT > Build.VERSION_CODES.Q) {
            ceil(measuredWidth.toDouble()).toFloat()
        } else {
            measuredWidth
        }
    }

    private fun measureReactTextLayoutWidth(
        text: CharSequence,
        paint: TextPaint,
        includeFontPadding: Boolean,
        widthDp: Double,
    ): Double {
        val widthPx = PixelUtil.toPixelFromDIP(widthDp.toFloat())
        val layout =
            StaticLayout.Builder.obtain(text, 0, text.length, TextPaint(paint), ceil(widthPx.toDouble()).toInt())
                .setAlignment(Layout.Alignment.ALIGN_NORMAL)
                .setLineSpacing(0f, 1f)
                .setIncludePad(includeFontPadding)
                .setBreakStrategy(Layout.BREAK_STRATEGY_HIGH_QUALITY)
                .setHyphenationFrequency(Layout.HYPHENATION_FREQUENCY_NORMAL)
                .apply {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        setUseLineSpacingFromFallbacks(true)
                    }
                }
                .build()

        return resolveReactMeasuredWidthPx(layout, text).toDouble() / application.resources.displayMetrics.density
    }

    private fun measureReactTextWidth(
        text: CharSequence,
        paint: TextPaint,
        includeFontPadding: Boolean,
    ): Double {
        val resolvedPaint = TextPaint(paint)
        val boring = BoringLayout.isBoring(text, resolvedPaint)
        val layout =
            if (boring != null) {
                BoringLayout.make(
                    text,
                    resolvedPaint,
                    max(boring.width, 0),
                    Layout.Alignment.ALIGN_NORMAL,
                    1f,
                    0f,
                    boring,
                    includeFontPadding,
                )
            } else {
                StaticLayout.Builder.obtain(
                    text,
                    0,
                    text.length,
                    resolvedPaint,
                    max(1, ceil(Layout.getDesiredWidth(text, resolvedPaint).toDouble()).toInt()),
                )
                    .setAlignment(Layout.Alignment.ALIGN_NORMAL)
                    .setLineSpacing(0f, 1f)
                    .setIncludePad(includeFontPadding)
                    .setBreakStrategy(Layout.BREAK_STRATEGY_HIGH_QUALITY)
                    .setHyphenationFrequency(Layout.HYPHENATION_FREQUENCY_NORMAL)
                    .apply {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            setUseLineSpacingFromFallbacks(true)
                        }
                    }
                    .build()
            }

        return resolveReactMeasuredWidthPx(layout, text).toDouble() / application.resources.displayMetrics.density
    }

    private fun resolveReactMeasuredWidthPx(layout: Layout, text: CharSequence): Float {
        var widthPx = 0f

        for (lineIndex in 0 until layout.lineCount) {
            val lineEnd = layout.getLineEnd(lineIndex)
            val endsWithNewLine = text.isNotEmpty() && lineEnd > 0 && text[lineEnd - 1] == '\n'
            val lineWidth = if (endsWithNewLine) layout.getLineMax(lineIndex) else layout.getLineWidth(lineIndex)
            widthPx = max(widthPx, if (Build.VERSION.SDK_INT > Build.VERSION_CODES.Q) ceil(lineWidth.toDouble()).toFloat() else lineWidth)
        }

        return widthPx
    }

    private fun buildEllipsizedSingleLineLayout(
        prepared: RNTextEngineBindings.PreparedTextViewData,
        widthDp: Double,
    ): StaticLayout {
        val widthPx = ceil(PixelUtil.toPixelFromDIP(widthDp.toFloat()).toDouble()).toInt()
        return StaticLayout.Builder.obtain(prepared.text, 0, prepared.text.length, TextPaint(prepared.textPaint), widthPx)
            .setAlignment(Layout.Alignment.ALIGN_NORMAL)
            .setLineSpacing(0f, 1f)
            .setIncludePad(prepared.includeFontPadding)
            .setBreakStrategy(Layout.BREAK_STRATEGY_HIGH_QUALITY)
            .setHyphenationFrequency(Layout.HYPHENATION_FREQUENCY_NORMAL)
            .setMaxLines(1)
            .setEllipsize(TextUtils.TruncateAt.MIDDLE)
            .apply {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    setUseLineSpacingFromFallbacks(true)
                }
            }
            .build()
    }
}
