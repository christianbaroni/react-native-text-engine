package com.rntextengine

import android.app.Application
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.text.Layout
import android.text.TextPaint
import android.util.DisplayMetrics
import android.view.View
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.facebook.react.bridge.JavaOnlyArray
import com.facebook.react.soloader.OpenSourceMergedSoMapping
import com.facebook.react.uimanager.DisplayMetricsHolder
import com.facebook.react.uimanager.PixelUtil
import com.facebook.react.uimanager.ReactStylesDiffMap
import com.facebook.react.bridge.JavaOnlyMap
import com.facebook.yoga.YogaMeasureOutput
import com.facebook.soloader.SoLoader
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.roundToInt
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertSame
import org.junit.Assert.assertNotSame
import org.junit.Assert.assertNull
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

private fun expectedAnchoredContentHeight(hostHeight: Int, insets: RNTextEngineCapHeightInsetsPx): Int {
    return hostHeight + kotlin.math.floor(insets.top.toDouble()).toInt() + ceil(insets.bottom.toDouble()).toInt()
}

class RNTextEngineAccessibilityTestActivity : android.app.Activity()

@RunWith(AndroidJUnit4::class)
class RNTextEngineBindingsInstrumentedTest {
    private lateinit var application: Application

    @Before
    fun setUp() {
        application = ApplicationProvider.getApplicationContext()
        SoLoader.init(application, OpenSourceMergedSoMapping)
        DisplayMetricsHolder.initDisplayMetricsIfNotInitialized(application)
        RNTextEngineBindings.initialize(InstrumentedReactContext(application))
        RNTextEngineBindings.cleanup()
    }

    @After
    fun tearDown() {
        RNTextEngineBindings.cleanup()
    }

    @Test
    fun paragraphAccessibilityUsesResolvedTextAndPreservesSelectionActions() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val automation = instrumentation.uiAutomation
        val originalServiceFlags = automation.serviceInfo.flags
        automation.serviceInfo = automation.serviceInfo.apply {
            flags = flags and android.accessibilityservice.AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS.inv()
        }
        val activity = instrumentation.startActivitySync(android.content.Intent(
            instrumentation.targetContext, RNTextEngineAccessibilityTestActivity::class.java,
        ).addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK))
        val manager = RNTextEngineTextViewManager()
        lateinit var view: RNTextEngineTextViewManager.RNTextEngineTextView
        try {
            instrumentation.runOnMainSync {
                view = RNTextEngineTextViewManager.RNTextEngineTextView(activity)
                activity.setContentView(view)
                manager.updateProperties(view, ReactStylesDiffMap(JavaOnlyMap.of(
                    "text", "Straße ", "textTransform", "uppercase", "accessible", true, "testID", "paragraph",
                )))
                val paragraphNode = RNTextEngineTextShadowNode().apply {
                    measureText = "Straße "
                    measureTextTransform = "uppercase"
                }
                val child = RNTextEngineTextShadowNode().apply {
                    measureRnteIsVirtualTextSpan = true
                    measureText = "שלום"
                }
                paragraphNode.addChildAt(child, 0)
                val resolvePayload = RNTextEngineTextShadowNode::class.java.getDeclaredMethod("resolvePayload")
                resolvePayload.isAccessible = true
                manager.updateExtraData(view, resolvePayload.invoke(paragraphNode))
                measureAndLayout(view, 320, 160)
                assertTrue(view.isFocusable)
                assertEquals("STRASSE שלום", view.createAccessibilityNodeInfo().text.toString())
                for (selectable in listOf(true, false, true)) {
                    manager.updateProperties(view, ReactStylesDiffMap(JavaOnlyMap.of(
                        "selectable", selectable, "accessibilityLabel", "Spoken label", "accessibilityRole", "button",
                        "accessibilityHint", "Paragraph hint",
                    )))
                    measureAndLayout(view, 320, 160)
                    val info = view.createAccessibilityNodeInfo()
                    assertEquals("Spoken label", info.contentDescription)
                    assertEquals("android.widget.Button", info.className)
                    assertEquals("Paragraph hint", info.tooltipText)
                    assertEquals("STRASSE שלום", info.text.toString())
                    if (selectable) {
                        val action = android.view.accessibility.AccessibilityNodeInfo.ACTION_SET_SELECTION
                        assertTrue(info.actions and action != 0)
                        val arguments = android.os.Bundle().apply {
                            putInt(android.view.accessibility.AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_START_INT, 1)
                            putInt(android.view.accessibility.AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_END_INT, 4)
                        }
                        assertTrue(view.performAccessibilityAction(action, arguments))
                        assertEquals(1, view.selectionView?.selectionStart)
                        assertEquals(4, view.selectionView?.selectionEnd)
                        arguments.putInt(android.view.accessibility.AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_START_INT, 2)
                        arguments.putInt(android.view.accessibility.AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_END_INT, 2)
                        assertTrue(view.performAccessibilityAction(action, arguments))
                        assertEquals(2, view.selectionView?.selectionStart)
                        assertEquals(2, view.createAccessibilityNodeInfo().textSelectionStart)
                        arguments.putInt(android.view.accessibility.AccessibilityNodeInfo.ACTION_ARGUMENT_MOVEMENT_GRANULARITY_INT,
                            android.view.accessibility.AccessibilityNodeInfo.MOVEMENT_GRANULARITY_CHARACTER)
                        assertTrue(view.performAccessibilityAction(
                            android.view.accessibility.AccessibilityNodeInfo.ACTION_NEXT_AT_MOVEMENT_GRANULARITY, arguments))
                        assertEquals(3, view.selectionView?.selectionEnd)
                    }
                    manager.updateProperties(view, ReactStylesDiffMap(JavaOnlyMap.of("accessibilityLabel", null)))
                    assertTrue(view.createAccessibilityNodeInfo().contentDescription.isNullOrEmpty())
                }
            }
            instrumentation.waitForIdleSync()
            fun paragraphs(node: android.view.accessibility.AccessibilityNodeInfo): List<android.view.accessibility.AccessibilityNodeInfo> =
                (if (node.text?.toString() == "STRASSE שלום") listOf(node) else emptyList()) +
                    (0 until node.childCount).flatMap { index -> node.getChild(index)?.let(::paragraphs).orEmpty() }
            val exposedParagraphs = paragraphs(automation.rootInActiveWindow)
            assertEquals(1, exposedParagraphs.size)
            val paragraph = exposedParagraphs.single()
            assertEquals("android.widget.Button", paragraph.className)
            val locationKey = android.view.accessibility.AccessibilityNodeInfo.EXTRA_DATA_TEXT_CHARACTER_LOCATION_KEY
            assertTrue(paragraph.availableExtraData.contains(locationKey))
            val locationArguments = android.os.Bundle().apply {
                putInt(android.view.accessibility.AccessibilityNodeInfo.EXTRA_DATA_TEXT_CHARACTER_LOCATION_ARG_START_INDEX, 2)
                putInt(android.view.accessibility.AccessibilityNodeInfo.EXTRA_DATA_TEXT_CHARACTER_LOCATION_ARG_LENGTH, 2)
            }
            assertTrue(paragraph.refreshWithExtraData(locationKey, locationArguments))
            val locations = requireNotNull(paragraph.extras.getParcelableArray(locationKey))
            assertEquals(2, locations.size)
            assertTrue(locations.all { it is android.graphics.RectF && !it.isEmpty })
            val movement = android.os.Bundle().apply {
                putInt(android.view.accessibility.AccessibilityNodeInfo.ACTION_ARGUMENT_MOVEMENT_GRANULARITY_INT,
                    android.view.accessibility.AccessibilityNodeInfo.MOVEMENT_GRANULARITY_CHARACTER)
            }
            val event = automation.executeAndWaitForEvent({
                assertTrue(paragraph.performAction(
                    android.view.accessibility.AccessibilityNodeInfo.ACTION_NEXT_AT_MOVEMENT_GRANULARITY, movement))
            }, { it.eventType == android.view.accessibility.AccessibilityEvent.TYPE_VIEW_TEXT_TRAVERSED_AT_MOVEMENT_GRANULARITY }, 5000)
            assertEquals("paragraph", event.source?.viewIdResourceName)
            instrumentation.runOnMainSync {
                manager.updateProperties(view, ReactStylesDiffMap(JavaOnlyMap.of("accessible", false)))
            }
            instrumentation.waitForIdleSync()
            assertTrue(paragraph.refresh())
            assertTrue(!paragraph.isFocusable)
            instrumentation.runOnMainSync {
                manager.updateProperties(view, ReactStylesDiffMap(JavaOnlyMap.of("importantForAccessibility", "no-hide-descendants")))
            }
            instrumentation.waitForIdleSync()
            assertTrue(paragraphs(automation.rootInActiveWindow).isEmpty())
        } finally {
            instrumentation.runOnMainSync { activity.finish() }
            automation.serviceInfo = automation.serviceInfo.apply { flags = originalServiceFlags }
        }
    }

    @Test
    fun preparedParagraphAccessibilityTracksHandleReplacementAndExplicitProps() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val activity = instrumentation.startActivitySync(android.content.Intent(
            instrumentation.targetContext, RNTextEngineAccessibilityTestActivity::class.java,
        ).addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK))
        try {
            instrumentation.runOnMainSync {
                val manager = RNTextEnginePreparedTextViewManager()
                val view = RNTextEnginePreparedTextViewManager.RNTextEnginePreparedTextView(activity)
                activity.setContentView(view)
                manager.updateProperties(view, ReactStylesDiffMap(JavaOnlyMap.of("accessible", true, "selectable", true)))
                for (text in listOf("First paragraph", "Replacement שלום")) {
                    val handle = RNTextEngineBindings.prepareTextView(text, null, null, null, 17.0,
                        null, null, 0.0, Double.NaN, false, false, false, null)
                    manager.setHandle(view, handle.toDouble())
                    measureAndLayout(view, 320, 160)
                    assertEquals(text, view.createAccessibilityNodeInfo().text.toString())
                    assertEquals(text, view.selectionView?.text.toString())
                    RNTextEngineBindings.release(handle)
                }
                manager.updateProperties(view, ReactStylesDiffMap(JavaOnlyMap.of("accessibilityValue", JavaOnlyMap.of("text", "Value"),
                    "accessibilityLabel", "Alias")))
                assertEquals("Alias, Value", view.createAccessibilityNodeInfo().contentDescription)
                manager.updateProperties(view, ReactStylesDiffMap(JavaOnlyMap.of("accessibilityLabel", null)))
                assertEquals("Value", view.createAccessibilityNodeInfo().contentDescription)
                manager.updateProperties(view, ReactStylesDiffMap(JavaOnlyMap.of("accessible", false)))
                assertTrue(!view.isFocusable)
                manager.updateProperties(view, ReactStylesDiffMap(JavaOnlyMap.of("importantForAccessibility", "no-hide-descendants")))
                assertEquals(View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS, view.importantForAccessibility)
                manager.setHandle(view, 0.0)
                assertNull(view.createAccessibilityNodeInfo().text)
            }
        } finally { instrumentation.runOnMainSync { activity.finish() } }
    }

    @Test
    fun inlineDrawingStylesPreserveNativeShaping() {
        fun prepare(text: String, starts: IntArray, ends: IntArray, masks: IntArray, height: Double): Long {
            val count = starts.size
            return RNTextEngineBindings.prepareTextViewWithRuns(
                text, null, "#000000", null, 17.0, null, null, 0.0, height, false, false, false, null,
                starts, ends, masks, Array(count) { if (it % 2 == 0) "#ff0000" else "#0000ff" },
                arrayOfNulls(count), DoubleArray(count) { 34.0 }, Array(count) { "700" }, arrayOfNulls(count),
                DoubleArray(count), DoubleArray(count) { 28.0 }, BooleanArray(count),
            )
        }

        fun assertGeometry(label: String, expected: Layout, actual: Layout) {
            assertEquals(label, expected.height, actual.height)
            assertEquals(label, expected.lineCount, actual.lineCount)
            for (line in 0 until expected.lineCount) {
                assertEquals(label, expected.getLineStart(line), actual.getLineStart(line))
                assertEquals(label, expected.getLineEnd(line), actual.getLineEnd(line))
                assertEquals(label, expected.getLineTop(line), actual.getLineTop(line))
                assertEquals(label, expected.getLineBottom(line), actual.getLineBottom(line))
                assertEquals(label, expected.getLineBaseline(line), actual.getLineBaseline(line))
                assertEquals(label, expected.getLineLeft(line), actual.getLineLeft(line), 0f)
                assertEquals(label, expected.getLineRight(line), actual.getLineRight(line), 0f)
                assertEquals(label, expected.getLineWidth(line), actual.getLineWidth(line), 0f)
                assertEquals(label, expected.getEllipsisStart(line), actual.getEllipsisStart(line))
                assertEquals(label, expected.getEllipsisCount(line), actual.getEllipsisCount(line))
            }
            for (offset in 0..expected.text.length) {
                assertEquals(label, expected.getPrimaryHorizontal(offset), actual.getPrimaryHorizontal(offset), 0f)
            }
        }

        val fixtures = listOf(
            "Words, punctuation." to (0 to 5),
            "office affine" to (2 to 3),
            "السلام عليكم" to (1 to 3),
            "क्षत्रिय हिन्दी" to (1 to 2),
            "a\u0301e\u0308 combining" to (0 to 1),
            "👩‍👩‍👧‍👦 emoji" to (0 to 2),
            "English العربية हिन्दी 🙂" to (8 to 11),
        )
        val runMasks = listOf(
            intArrayOf(1, 1, 1),
            intArrayOf(1, 1 or (1 shl 2), 1 shl 6),
            intArrayOf(1 shl 6, 1 shl 6, 1 shl 6),
            intArrayOf(1 or (1 shl 2), 1 shl 2, 1 or (1 shl 4)),
        )
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            for ((chunk, range) in fixtures) for (masks in runMasks) for (height in listOf(Double.NaN, 25.0)) {
                val text = "$chunk $chunk $chunk"
                val starts = intArrayOf(range.first, chunk.length + 1, chunk.length * 2 + 2)
                val ends = intArrayOf(range.second, chunk.length * 2 + 1, text.length)
                val handle = prepare(text, starts, ends, masks, height)
                val label = "$chunk masks=${masks.contentToString()} height=$height"
                try {
                    val prepared = requireNotNull(RNTextEngineBindings.preparedText(handle))
                    val actualText = prepared.displayText() as android.text.Spanned
                    if (masks.all { it and ((1 shl 2) or (1 shl 4)) == 0 }) {
                        assertEquals(prepared.capHeights.base, requireNotNull(prepared.capHeights.uniform), 0f)
                    }
                    val reference = android.text.SpannableString(text)
                    // Isolate character shaping from the independently tested line-height projection.
                    actualText.getSpans(0, text.length, android.text.style.LineHeightSpan::class.java).forEach {
                        reference.setSpan(it, actualText.getSpanStart(it), actualText.getSpanEnd(it), actualText.getSpanFlags(it))
                    }
                    for (index in starts.indices) {
                        fun span(value: Any) = reference.setSpan(value, starts[index], ends[index], android.text.Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                        if (masks[index] and (1 shl 2) != 0) span(android.text.style.RelativeSizeSpan(2f))
                        if (masks[index] and (1 shl 4) != 0) span(android.text.style.StyleSpan(android.graphics.Typeface.BOLD))
                        if (masks[index] and 1 != 0) span(android.text.style.ForegroundColorSpan(if (index % 2 == 0) Color.RED else Color.BLUE))
                    }
                    for (width in listOf(105, 240, 640)) for (maxLines in listOf(Int.MAX_VALUE, 2)) {
                        fun layout(input: CharSequence) = buildStaticLayoutCompat(
                            input, TextPaint(prepared.style.textPaint), width, false,
                            Layout.BREAK_STRATEGY_HIGH_QUALITY, Layout.HYPHENATION_FREQUENCY_NORMAL, maxLines,
                            if (maxLines == 2) android.text.TextUtils.TruncateAt.END else null,
                        )
                        val actual = layout(actualText)
                        val expected = layout(reference)
                        assertGeometry("$label width=$width maxLines=$maxLines", expected, actual)
                        fun render(layout: Layout) = Bitmap.createBitmap(width, max(1, layout.height), Bitmap.Config.ARGB_8888).also {
                            layout.draw(Canvas(it))
                        }
                        val actualBitmap = render(actual)
                        val expectedBitmap = render(expected)
                        assertTrue("$label width=$width maxLines=$maxLines pixels", actualBitmap.sameAs(expectedBitmap))
                        actualBitmap.recycle()
                        expectedBitmap.recycle()
                    }
                    for (anchor in listOf(false, true)) {
                        val view = RNTextEnginePreparedTextViewManager.RNTextEnginePreparedTextView(application).apply {
                            setPreparedHandle(handle)
                            anchorToCapHeight = anchor
                            measureAndLayout(this, 240, 1600)
                        }
                        fun renderView() = Bitmap.createBitmap(240, 1600, Bitmap.Config.ARGB_8888).also { view.draw(Canvas(it)) }
                        val display = renderView()
                        view.setSelectable(true)
                        view.finishUpdates()
                        measureAndLayout(view, 240, 1600)
                        val selection = renderView()
                        assertTrue("$label anchor=$anchor selection", display.sameAs(selection))
                        display.recycle()
                        selection.recycle()
                    }
                } finally {
                    RNTextEngineBindings.release(handle)
                }
            }
        }
    }

    @Test
    fun inlineSpansKeepExplicitTypographyOverridesAndColorInheritance() {
        val masks = intArrayOf(1, 1, 1 shl 6, 1 shl 5, 1 shl 7, 1 shl 2, 1 or (1 shl 4), 1 shl 1, 1 shl 3)
        val count = masks.size
        val handle = RNTextEngineBindings.prepareTextViewWithRuns(
            "a b c d e f g h i", null, "#ff00ff", null, 17.0, null, null, 2.0, 25.0, false, false, true, null,
            IntArray(count) { it * 2 }, IntArray(count) { it * 2 + 1 }, masks,
            Array(count) { if (it == 1) "invalid" else "#0000ff" }, arrayOfNulls(count), DoubleArray(count) { 17.0 },
            Array(count) { "700" }, arrayOfNulls(count), DoubleArray(count), DoubleArray(count) { Double.NaN }, BooleanArray(count),
        )
        try {
            val prepared = requireNotNull(RNTextEngineBindings.preparedText(handle))
            val text = prepared.displayText() as android.text.Spanned
            assertTrue(prepared.hasInlineStyleRuns)
            assertEquals(6, text.getSpans(0, text.length, RNTextEngineTextPaintSpan::class.java).size)
            assertEquals(2, text.getSpans(0, text.length, android.text.style.ForegroundColorSpan::class.java).size)
            assertTrue(text.getSpans(4, 5, android.text.style.CharacterStyle::class.java).isEmpty())
            assertTrue(text.getSpans(4, 5, android.text.style.LineHeightSpan::class.java).isEmpty())
            for (index in masks.indices) {
                val spans = text.getSpans(index * 2, index * 2 + 1, android.text.style.CharacterStyle::class.java)
                if (index == 2) continue
                assertEquals(1, spans.size)
                val paint = TextPaint(prepared.style.textPaint).apply { color = Color.RED }
                spans.single().updateDrawState(paint)
                assertEquals(when (index) { 1 -> TextPaint().color; 0, 6 -> Color.BLUE; else -> Color.RED }, paint.color)
                assertEquals(if (index == 3) 0f else prepared.style.textPaint.letterSpacing, paint.letterSpacing, 0f)
                assertEquals(if (index == 4) null else "'tnum'", paint.fontFeatureSettings)
            }
        } finally {
            RNTextEngineBindings.release(handle)
        }
    }

    @Test
    fun rootFallbackHeightAndExplicitNaturalRunHeightRemainDistinct() {
        val density = PixelUtil.getDisplayMetricDensity()
        for (lineHeight in listOf(Double.NaN, 0.0, 25.0)) {
            val handle = RNTextEngineBindings.prepareTextView(
                "", null, null, null, 17.0, null, null, 0.0, lineHeight, false, false, false, null,
            )
            try {
                val prepared = requireNotNull(RNTextEngineBindings.preparedText(handle))
                val metrics = prepared.style.textPaint.fontMetricsInt
                val expected = if (lineHeight.isNaN()) (metrics.descent - metrics.ascent) / density.toDouble()
                    else ceil(PixelUtil.toPixelFromDIP(lineHeight)) / density.toDouble()
                assertEquals(expected, RNTextEngineBindings.layout(handle, 180.0, 0, null, false)[1], 0.000001)
            } finally {
                RNTextEngineBindings.release(handle)
            }
        }
        val run = RNTextEngineTextRunStyle(
            color = null, fontFamily = null, fontSize = 23.0, fontStyle = null, fontWeight = null,
            hasColor = false, hasFontFamily = false, hasFontSize = true, hasFontStyle = false,
            hasFontWeight = false, hasLetterSpacing = false, hasLineHeight = true, hasTabularNumbers = false,
            letterSpacing = 0.0, lineHeight = Double.NaN, tabularNumbers = false,
        )
        val prepared = RNTextEngineBindings.prepareTextViewContent(
            "Natural run", null, null, null, 17.0, null, null, 0.0, 25.0, false,
            tabularNumbers = false, textBreakStrategy = null,
            runs = listOf(RNTextEngineTextRun(start = 0, end = 11, style = run)),
        )
        val styled = prepared.textWithLineHeight as android.text.Spanned
        assertTrue(styled.getSpans(0, styled.length, RNTextEngineLineHeightSpan::class.java).isEmpty())
        val paint = TextPaint(prepared.style.textPaint)
        styled.getSpans(0, styled.length, RNTextEngineTextPaintSpan::class.java).single().updateMeasureState(paint)
        assertEquals(PixelUtil.toPixelFromDIP(23.0), paint.textSize, 0f)
        assertEquals(ceil(PixelUtil.toPixelFromDIP(25.0).toDouble()) / density, prepared.style.fallbackLineHeight, 0.000001)
    }

    @Test
    fun initializationPreservesContentUntilItsEnvironmentChanges() {
        val context = InstrumentedReactContext(application)
        RNTextEngineBindings.initialize(context)
        fun prepare(previous: RNTextEngineBindings.PreparedText? = null) = RNTextEngineBindings.prepareTextViewContent(
            "initial", "uppercase", null, null, 18.0, null, null, 0.0, Double.NaN, true,
            tabularNumbers = false, textBreakStrategy = null, prepared = previous, retainSource = true,
        )
        val locale = java.util.Locale.getDefault()
        try {
            java.util.Locale.setDefault(java.util.Locale.US)
            val original = prepare()
            RNTextEngineBindings.initialize(context)
            assertSame(original, prepare(original))

            java.util.Locale.setDefault(java.util.Locale.forLanguageTag("tr-TR"))
            RNTextEngineBindings.initialize(context)
            val localized = prepare(original)
            assertNotSame(original, localized)
            assertEquals("İNİTİAL", localized.text)

            val replacement = InstrumentedReactContext(application)
            RNTextEngineBindings.initialize(replacement)
            val replaced = prepare(localized)
            assertNotSame(localized, replaced)
            RNTextEngineBindings.initialize(replacement)
            assertSame(replaced, prepare(replaced))

            RNTextEngineBindings.cleanup()
            RNTextEngineBindings.initialize(replacement)
            assertNotSame(replaced, prepare(replaced))
        } finally {
            java.util.Locale.setDefault(locale)
        }
    }

    @Test
    fun fabricMeasurementsBoundPhysicalWidthHistory() {
        val text = "Widths change while the same prepared paragraph survives across revisions."
        fun prepare(version: Long) = RNTextEngineBindings.prepareTextView(
            text, null, null, null, 17.0, null, null, 0.0, Double.NaN, false, false, false, null,
            environmentVersion = version,
        )
        val handle = prepare(RNTextEngineBindings.textEnvironmentVersion())
        val reference = prepare(0)
        try {
            for (index in 0 until 4096) {
                val width = 80.0 + index * 0.25
                val maxLines = index % 3
                val anchored = index % 2 == 0
                val expected = RNTextEngineBindings.layout(reference, width, maxLines, "tail", anchored)
                val packed = RNTextEngineBindings.measureTextView(handle, width, maxLines, 3, anchored)
                assertEquals(expected[0].toFloat(), Float.fromBits((packed ushr 32).toInt()))
                assertEquals(expected[1].toFloat(), Float.fromBits(packed.toInt()))
            }
            val registry = RNTextEngineBindings::class.java.getDeclaredField("preparedTexts").apply { isAccessible = true }
                .get(RNTextEngineBindings) as Map<*, *>
            val prepared = requireNotNull(registry[handle])
            val layouts = prepared.javaClass.getDeclaredField("layoutsByKey").apply { isAccessible = true }
            val history = layouts.get(prepared) as android.util.LongSparseArray<*>
            assertTrue("Private preparation retained historical widths", history.size() <= 8)
            val density = PixelUtil.getDisplayMetricDensity()
            val pixelWidth = ceil(180.0 * density)
            val width = (pixelWidth - 0.75) / density
            RNTextEngineBindings.measureTextView(handle, width, 0, 3, false)
            val entries = List(history.size()) { history.valueAt(it) }
            RNTextEngineBindings.measureTextView(handle, (pixelWidth - 0.25) / density, 0, 3, false)
            assertEquals("Subpixel widths must share physical layout results", entries.size, history.size())
            entries.forEachIndexed { index, value -> assertSame(value, history.valueAt(index)) }
        } finally {
            RNTextEngineBindings.release(handle)
            RNTextEngineBindings.release(reference)
        }
    }

    @Test
    fun fabricOverflowPreservesOtherPhysicalWidths() {
        val handle = RNTextEngineBindings.prepareTextView(
            "A stable paragraph keeps useful measurements when one new width arrives.",
            null, null, null, 17.0, null, null, 0.0, Double.NaN, false, false, false, null,
            environmentVersion = RNTextEngineBindings.textEnvironmentVersion(),
        )
        try {
            val density = PixelUtil.getDisplayMetricDensity()
            fun measure(pixelWidth: Int, fraction: Double) =
                RNTextEngineBindings.measureTextView(handle, (pixelWidth - fraction) / density, 0, 3, false)
            val expected = (400 until 408).associateWith { measure(it, 0.75) }
            val registry = RNTextEngineBindings::class.java.getDeclaredField("preparedTexts").apply { isAccessible = true }
                .get(RNTextEngineBindings) as Map<*, *>
            val prepared = requireNotNull(registry[handle])
            val history = prepared.javaClass.getDeclaredField("layoutsByKey").apply { isAccessible = true }
                .get(prepared) as android.util.LongSparseArray<*>
            val entries = (0 until history.size()).associate { history.keyAt(it) to history.valueAt(it) }
            measure(408, 0.75)
            assertEquals(8, history.size())
            val survivors = entries.filter { (key, value) -> history[key] === value }
            assertEquals("One new width must evict only one result", 7, survivors.size)
            for ((key, value) in survivors) {
                val pixelWidth = (key ushr 32).toInt()
                assertEquals(expected.getValue(pixelWidth), measure(pixelWidth, 0.25))
                assertSame("Fractional widths must reuse surviving physical results", value, history[key])
            }
        } finally {
            RNTextEngineBindings.release(handle)
        }
    }

    @Test
    fun fabricPreparedStatePreservesUiOverridesAcrossCommits() {
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            fun prepare(text: String, fontSize: Double) = RNTextEngineBindings.prepareTextView(
                text, null, null, null, fontSize, null, null, 0.0, Double.NaN, false, false, false, null,
                environmentVersion = RNTextEngineBindings.textEnvironmentVersion(),
            )
            fun draw(view: View) {
                val bitmap = Bitmap.createBitmap(320, 160, Bitmap.Config.ARGB_8888)
                try { view.draw(Canvas(bitmap)) } finally { bitmap.recycle() }
            }
            val manager = RNTextEngineTextViewManager()
            val view = RNTextEngineTextViewManager.RNTextEngineTextView(application).apply { id = 2 }
            val text = "Measured \u0000text 😀"
            manager.setText(view, text)
            manager.setFontSize(view, 18.0)
            val handle = prepare(text, 18.0)
            val prepared = requireNotNull(RNTextEngineBindings.preparedText(handle))
            manager.updateExtraData(view, prepared)
            measureAndLayout(view, 320, 160)
            val first = requireNotNull(view.displayView.resolveLayout(320))
            assertSame(prepared.displayText(), first.text)
            assertEquals(view.defaultTextColor, first.paint.color)
            manager.updateProperties(view, ReactStylesDiffMap(JavaOnlyMap.of("color", Color.BLUE)))
            assertSame(first, view.displayView.resolveLayout(320))
            assertEquals(Color.BLUE, first.paint.color)
            RNTextEngineBindings.release(handle)
            manager.updateProperties(view, ReactStylesDiffMap(JavaOnlyMap.of("selectable", true)))
            assertEquals(text, view.selectionView?.text.toString())

            manager.updateProperties(view, ReactStylesDiffMap(JavaOnlyMap.of(
                "text", "Animated input", "fontSize", 42.0,
            )))
            draw(view)
            assertEquals("Animated input", view.selectionView?.text.toString())
            assertEquals(PixelUtil.toPixelFromDIP(42f), view.selectionView!!.textSize, 0f)
            val animatedLayout = view.displayView.resolveLayout(320)
            val selectedText = view.selectionView!!.text as android.text.Spannable
            android.text.Selection.setSelection(selectedText, 2, 7)
            manager.updateExtraData(view, prepared)
            assertSame(animatedLayout, view.displayView.resolveLayout(320))
            assertSame(selectedText, view.selectionView!!.text)
            assertEquals(2, view.selectionView!!.selectionStart)
            assertEquals(7, view.selectionView!!.selectionEnd)
            val equivalentHandle = prepare("Animated input", 42.0)
            manager.updateExtraData(view, requireNotNull(RNTextEngineBindings.preparedText(equivalentHandle)))
            RNTextEngineBindings.release(equivalentHandle)
            assertSame(animatedLayout, view.displayView.resolveLayout(320))
            assertSame(selectedText, view.selectionView!!.text)
            assertEquals(2, view.selectionView!!.selectionStart)
            assertEquals(7, view.selectionView!!.selectionEnd)
            assertEquals("Animated input", view.selectionView?.text.toString())
            assertEquals(PixelUtil.toPixelFromDIP(42f), view.selectionView!!.textSize, 0f)

            manager.updateProperties(view, ReactStylesDiffMap(JavaOnlyMap.of(
                "text", "Committed text", "fontSize", 24.0,
            )))
            val nextHandle = prepare("Committed text", 24.0)
            val next = requireNotNull(RNTextEngineBindings.preparedText(nextHandle))
            manager.updateExtraData(view, next)
            RNTextEngineBindings.release(nextHandle)
            assertSame(next.displayText(), view.displayView.resolveLayout(320)?.text)
            assertEquals(next.text, view.selectionView?.text.toString())
            assertEquals(next.style.textPaint.textSize, view.selectionView!!.textSize, 0f)
            assertEquals(Color.BLUE, view.selectionView?.currentTextColor)

            manager.updateProperties(view, ReactStylesDiffMap(JavaOnlyMap.of("text", "")))
            val emptyHandle = prepare("", 24.0)
            manager.updateExtraData(view, requireNotNull(RNTextEngineBindings.preparedText(emptyHandle)))
            RNTextEngineBindings.release(emptyHandle)
            assertEquals("", view.selectionView?.text.toString())
            manager.setSelectable(view, false)
            assertEquals("", view.displayView.resolveLayout(320)?.text.toString())
        }
    }

    @Test
    @Suppress("DEPRECATION")
    fun uiOnlyUpdatesReadmitPreparedTextAfterEnvironmentChanges() {
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            val configuration = Configuration(application.resources.configuration)
            val metrics = DisplayMetricsHolder.getScreenDisplayMetrics()
            val locale = java.util.Locale.getDefault()
            val manager = RNTextEngineTextViewManager()
            val failures = ArrayList<String>()
            val bitmap = Bitmap.createBitmap(360, 240, Bitmap.Config.ARGB_8888)
            try {
                for (fabric in listOf(false, true)) {
                    for (paintOnly in listOf(false, true)) {
                        fun fontScale(value: Float) {
                            application.resources.updateConfiguration(Configuration(configuration).apply { fontScale = value },
                                application.resources.displayMetrics)
                            DisplayMetricsHolder.setScreenDisplayMetrics(application.resources.displayMetrics)
                        }
                        fontScale(1f)
                        java.util.Locale.setDefault(java.util.Locale.US)
                        val view = RNTextEngineTextViewManager.RNTextEngineTextView(application).apply {
                            if (fabric) id = 2
                        }
                        manager.updateProperties(view, ReactStylesDiffMap(JavaOnlyMap.of(
                            "text", "initial i", "textTransform", "uppercase", "fontSize", 18.0, "allowFontScaling", true,
                        )))
                        if (fabric) {
                            val handle = RNTextEngineBindings.prepareTextView("initial i", "uppercase", null, null,
                                18.0, null, null, 0.0, Double.NaN, true, false, false, null,
                                environmentVersion = RNTextEngineBindings.textEnvironmentVersion())
                            manager.updateExtraData(view, requireNotNull(RNTextEngineBindings.preparedText(handle)))
                            RNTextEngineBindings.release(handle)
                        }
                        measureAndLayout(view, 360, 240)
                        fontScale(1.5f)
                        manager.updateProperties(view, ReactStylesDiffMap(
                            if (paintOnly) JavaOnlyMap.of("color", Color.BLUE) else JavaOnlyMap.of("fontSize", 18.0)))
                        view.draw(Canvas(bitmap))
                        val label = "fabric=$fabric paintOnly=$paintOnly"
                        val paint = requireNotNull(view.displayView.resolveLayout(360)).paint
                        if (paint.textSize != PixelUtil.toPixelFromSP(18f)) failures += "$label: UI font scale remained stale"
                        java.util.Locale.setDefault(java.util.Locale.forLanguageTag("tr-TR"))
                        manager.updateProperties(view, ReactStylesDiffMap(
                            if (paintOnly) JavaOnlyMap.of("color", Color.RED) else JavaOnlyMap.of("textTransform", "uppercase")))
                        view.draw(Canvas(bitmap))
                        if (view.displayView.resolveLayout(360)?.text.toString() != "initial i".uppercase(java.util.Locale.getDefault())) {
                            failures += "$label: UI case transformation remained stale"
                        }
                    }
                }
                assertTrue(failures.joinToString(), failures.isEmpty())
            } finally {
                bitmap.recycle()
                java.util.Locale.setDefault(locale)
                application.resources.updateConfiguration(configuration, application.resources.displayMetrics)
                DisplayMetricsHolder.setScreenDisplayMetrics(metrics)
            }
        }
    }

    @Test
    fun selectionIsLazyAndUsesPreparedContentAcrossUpdates() {
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            val manager = RNTextEngineTextViewManager()
            val view = RNTextEngineTextViewManager.RNTextEngineTextView(application)
            manager.setText(view, "First mounted text")
            manager.setFontSize(view, 17.0)
            manager.setColor(view, Color.BLUE)
            view.finishUpdates()
            assertEquals(null, view.selectionView)
            assertEquals(null, view.displayView.resolveLayout(320))
            view.setSelectable(false)
            measureAndLayout(view, 320, 160)
            val firstLayout = requireNotNull(view.displayView.resolveLayout(320))
            view.finishUpdates()
            view.applyResolvedNestedPayload(null)
            assertSame(firstLayout, view.displayView.resolveLayout(320))
            assertEquals(null, view.selectionView)

            view.setSelectable(true)
            view.finishUpdates()
            val selection = requireNotNull(view.selectionView)
            assertEquals("First mounted text", selection.text.toString())
            assertEquals(Color.BLUE, selection.currentTextColor)
            val selectedText = selection.text
            view.finishUpdates()
            assertSame("Unchanged preparation must not reset selection text", selectedText, selection.text)
            view.setSelectable(false)
            assertEquals(null, selection.parent)
            assertEquals(false, selection.isTextSelectable)

            manager.setText(view, "Second text has the latest style")
            manager.setColor(view, Color.RED)
            manager.setFontSize(view, 23.0)
            manager.setLineHeight(view, 29.5)
            manager.setNumberOfLines(view, 2)
            manager.setTextAlign(view, "center")
            manager.setTextDecorationLine(view, "underline line-through")
            manager.setTextShadowColor(view, Color.BLUE)
            manager.setTextShadowRadius(view, 2.0)
            manager.setTextShadowOffset(view, JavaOnlyMap.of("width", 2.0, "height", 3.0))
            manager.setPadding(view, 7, 5, 11, 3)
            view.finishUpdates()
            assertEquals("Disabled selection must retain no obsolete text", "", selection.text.toString())
            view.setSelectable(true)
            view.finishUpdates()
            assertSame(selection, view.selectionView)
            assertEquals("Second text has the latest style", selection.text.toString())
            assertEquals(Color.RED, selection.currentTextColor)
            assertEquals(2, selection.maxLines)
            assertEquals(android.text.TextUtils.TruncateAt.END, selection.ellipsize)
            assertEquals(7, selection.paddingLeft)
            assertEquals(5, selection.paddingTop)
            assertEquals(11, selection.paddingRight)
            assertEquals(3, selection.paddingBottom)
            assertEquals(Color.BLUE, selection.shadowColor)
            assertEquals(PixelUtil.toPixelFromDIP(2f), selection.shadowRadius, 0.001f)
            assertEquals(PixelUtil.toPixelFromDIP(2f), selection.shadowDx, 0.001f)
            assertEquals(PixelUtil.toPixelFromDIP(3f), selection.shadowDy, 0.001f)
            assertTrue(selection.paintFlags and android.graphics.Paint.UNDERLINE_TEXT_FLAG != 0)
            assertTrue(selection.paintFlags and android.graphics.Paint.STRIKE_THRU_TEXT_FLAG != 0)
        }
    }

    @Test
    fun defaultTextColorMatchesTheInitialNativeWidgetState() {
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            val testContext = InstrumentationRegistry.getInstrumentation().context
            for (themeName in listOf("RNTETextTheme", "RNTEDirectTextTheme", "RNTEDisabledTextTheme", "RNTESingleLineTextTheme", "RNTEInputTextTheme", "RNTEDigitsTextTheme")) {
                val themeId = testContext.resources.getIdentifier(themeName, "style", testContext.packageName)
                assertNotEquals(0, themeId)
                val context = androidx.appcompat.view.ContextThemeWrapper(testContext, themeId)
                val reference = androidx.appcompat.widget.AppCompatTextView(context)
                val view = RNTextEngineTextViewManager.RNTextEngineTextView(context)
                assertEquals(themeName, reference.currentTextColor, view.defaultTextColor)
                assertEquals(null, view.selectionView)
            }
        }
    }

    @Test
    fun selectionDrawingStyleUpdatesMatchFreshRendering() {
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            val manager = RNTextEngineTextViewManager()
            fun createView() = RNTextEngineTextViewManager.RNTextEngineTextView(application).apply {
                manager.setText(this, "Selected text with a shadow near its edge")
                manager.setFontSize(this, 17.0)
                manager.setColor(this, Color.BLACK)
                setSelectable(true)
                measureAndLayout(this, 360, 160)
            }
            fun render(view: View) = Bitmap.createBitmap(360, 160, Bitmap.Config.ARGB_8888).also {
                view.draw(Canvas(it))
            }
            val updates = listOf<(RNTextEngineTextViewManager.RNTextEngineTextView) -> Unit>(
                { it.setTextDecorationLineValue("underline line-through") },
                { it.setTextShadowColorValue(Color.RED) },
                { it.setTextShadowOffsetPx(-3f, -2f) },
                { it.setTextShadowRadiusPx(4f) },
                { it.setTextDecorationLineValue(null) },
                { it.setTextShadowColorValue(null) },
            )
            val view = createView()
            updates.forEachIndexed { index, update ->
                update(view)
                view.finishUpdates()
                val fresh = createView()
                updates.take(index + 1).forEach { it(fresh) }
                fresh.finishUpdates()
                val actual = render(view)
                val expected = render(fresh)
                assertTrue("Selected style update $index changed pixels", actual.sameAs(expected))
                val pixels = IntArray(actual.width * actual.height)
                actual.getPixels(pixels, 0, actual.width, 0, 0, actual.width, actual.height)
                assertTrue(pixels.any { it != Color.TRANSPARENT })
                actual.recycle()
                expected.recycle()
            }
        }
    }

    @Test
    fun explicitTextAlignmentUsesPhysicalEdgesAcrossSelectionChanges() {
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            val manager = RNTextEngineTextViewManager()
            val view = RNTextEngineTextViewManager.RNTextEngineTextView(application)
            manager.setFontSize(view, 14.0)
            manager.setColor(view, Color.BLACK)
            manager.setPadding(view, 17, 9, 23, 11)
            val bitmap = Bitmap.createBitmap(420, 240, Bitmap.Config.ARGB_8888)
            val pixels = IntArray(bitmap.width * bitmap.height)
            val fixtures = listOf(
                "שלום" to listOf(-1),
                "مرحبا" to listOf(-1),
                "Hello" to listOf(1),
                "שלום abc" to listOf(-1),
                "abc שלום" to listOf(1),
                "שלום\nHello" to listOf(-1, 1),
                "Hello\nمرحبا" to listOf(1, -1),
            )
            try {
                for (direction in listOf(View.LAYOUT_DIRECTION_LTR, View.LAYOUT_DIRECTION_RTL)) {
                    view.layoutDirection = direction
                    for ((text, paragraphDirections) in fixtures) {
                        manager.setText(view, text)
                        for (alignment in listOf("left", "right", "center", null, "auto", "justify")) {
                            manager.setTextAlign(view, alignment)
                            for (selectable in listOf(true, false, true)) {
                                view.setSelectable(selectable)
                                measureAndLayout(view, bitmap.width, bitmap.height)
                                val layout = if (selectable) requireNotNull(view.selectionView?.layout)
                                    else requireNotNull(view.displayView.resolveLayout(bitmap.width))
                                val case = "$text align=$alignment direction=$direction selectable=$selectable"
                                assertEquals(case, paragraphDirections.size, layout.lineCount)
                                assertEquals(case, bitmap.width - 17 - 23, layout.width)
                                bitmap.eraseColor(Color.TRANSPARENT)
                                view.draw(Canvas(bitmap))
                                bitmap.getPixels(pixels, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)
                                for ((line, paragraphDirection) in paragraphDirections.withIndex()) {
                                    assertEquals(case, paragraphDirection, layout.getParagraphDirection(line))
                                    val left = layout.getLineLeft(line)
                                    val right = layout.getLineRight(line)
                                    when (alignment) {
                                        "left" -> assertEquals(case, 0f, left, 0.01f)
                                        "right" -> assertEquals(case, layout.width.toFloat(), right, 0.01f)
                                        "center" -> assertEquals(case, layout.width.toFloat(), left + right, 1f)
                                        else -> if (paragraphDirection == 1) assertEquals(case, 0f, left, 0.01f)
                                            else assertEquals(case, layout.width.toFloat(), right, 0.01f)
                                    }
                                    var inkLeft = bitmap.width
                                    var inkRight = -1
                                    for (y in 9 + layout.getLineTop(line) until 9 + layout.getLineBottom(line)) {
                                        for (x in 0 until bitmap.width) {
                                            if (Color.alpha(pixels[y * bitmap.width + x]) != 0) {
                                                inkLeft = minOf(inkLeft, x)
                                                inkRight = maxOf(inkRight, x)
                                            }
                                        }
                                    }
                                    assertTrue("$case line=$line drew no text", inkRight >= inkLeft)
                                    assertTrue("$case line=$line ink starts at $inkLeft before ${17 + left}", inkLeft >= 17 + left - 2)
                                    assertTrue("$case line=$line ink ends at $inkRight after ${17 + right}", inkRight <= 17 + right + 2)
                                }
                            }
                        }
                    }
                }
            } finally {
                bitmap.recycle()
            }
        }
    }

    @Test
    fun drawingOriginsPreservePhysicalEdgesAndRtlOverflow() {
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            val manager = RNTextEngineTextViewManager()
            val view = RNTextEngineTextViewManager.RNTextEngineTextView(application)
            manager.setFontSize(view, 24.0)
            manager.setLineHeight(view, 16.25)
            manager.setColor(view, Color.BLACK)
            val actual = Bitmap.createBitmap(480, 1000, Bitmap.Config.ARGB_8888)
            val expected = Bitmap.createBitmap(480, 1000, Bitmap.Config.ARGB_8888)
            var sawRtlOverflow = false
            try {
                for (text in listOf("שָׁ", "مرحبا abc\nLatin שלום", "שָׁ\t🙂\nLatin\tمرحبا", "Words wrapping across multiple lines for truncation")) {
                    manager.setText(view, text)
                    for (alignment in listOf(null, "auto", "justify", "left", "right", "center")) {
                        manager.setTextAlign(view, alignment)
                        for ((maxLines, ellipsize) in listOf(0 to "clip", 2 to "tail", 1 to "middle")) {
                            view.setNumberOfLines(maxLines)
                            view.setEllipsizeMode(ellipsize)
                            for (padding in listOf(3, 17)) {
                                manager.setPadding(view, padding, 7, padding + 2, 9)
                                for (contentWidth in listOf(0, 1, 31, 240)) {
                                    val width = contentWidth + 2 * padding + 2
                                    measureAndLayout(view, width, actual.height)
                                    val layout = requireNotNull(view.displayView.resolveLayout(width))
                                    var minLeft = 0f
                                    var maxRight = 0f
                                    for (line in 0 until layout.lineCount) {
                                        minLeft = minOf(minLeft, layout.getLineLeft(line))
                                        maxRight = maxOf(maxRight, layout.getLineRight(line))
                                    }
                                    sawRtlOverflow = sawRtlOverflow || minLeft < 0f
                                    val origin = when (alignment) {
                                        "center" -> 0f
                                        "right" -> -ceil(max(0f, maxRight - contentWidth).toDouble()).toFloat()
                                        else -> ceil(max(0f, -minLeft).toDouble()).toFloat()
                                    }
                                    if (alignment == "left") assertEquals(0f, origin, 0f)
                                    if (alignment == "right" && contentWidth == 0) assertEquals(-1f, origin, 0f)
                                    actual.eraseColor(Color.TRANSPARENT)
                                    expected.eraseColor(Color.TRANSPARENT)
                                    view.displayView.draw(Canvas(actual))
                                    val canvas = Canvas(expected)
                                    canvas.translate(padding + origin, 7f)
                                    layout.draw(canvas)
                                    assertTrue("text=$text align=$alignment width=$contentWidth padding=$padding lines=$maxLines mode=$ellipsize",
                                        actual.sameAs(expected))
                                }
                            }
                        }
                    }
                }
                assertTrue("The fixtures must exercise negative RTL extents", sawRtlOverflow)
            } finally {
                actual.recycle()
                expected.recycle()
            }
        }
    }

    @Test
    fun emptyBackgroundsPreserveTransparencyAndRequestedColors() {
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            val testContext = InstrumentationRegistry.getInstrumentation().context
            val themeId = testContext.resources.getIdentifier("RNTETextTheme", "style", testContext.packageName)
            assertNotEquals(0, themeId)
            val context = androidx.appcompat.view.ContextThemeWrapper(testContext, themeId)
            assertTrue("The widget theme must supply a background", androidx.appcompat.widget.AppCompatTextView(context).background != null)
            val manager = RNTextEngineTextViewManager()
            val actual = RNTextEngineTextViewManager.RNTextEngineTextView(context)
            val reference = RNTextEngineTextViewManager.RNTextEngineTextView(context)
            reference.setBackgroundColor(Color.TRANSPARENT)
            reference.displayView.setBackgroundColor(Color.TRANSPARENT)
            assertNull(actual.background)
            assertNull(actual.displayView.background)
            for (view in listOf(actual, reference)) {
                android.widget.FrameLayout(application).addView(view)
                manager.setText(view, "Background and overflow: Ag pq 🙂")
                manager.setFontSize(view, 24.0)
                manager.setLineHeight(view, 32.0)
                manager.setColor(view, Color.BLACK)
                manager.setPadding(view, 5, 3, 7, 2)
            }
            fun render(view: View) = Bitmap.createBitmap(360, 180, Bitmap.Config.ARGB_8888).also {
                val host = view.parent as View
                measureAndLayout(host, 360, 180)
                host.draw(Canvas(it))
            }
            for (anchored in listOf(false, true, false)) {
                for (selectable in listOf(false, true, false)) {
                    for (color in listOf(null, Color.GREEN, Color.argb(128, 255, 0, 0), Color.BLUE, Color.TRANSPARENT, null)) {
                        for (opacity in listOf(1f, 0.4f)) {
                            for (view in listOf(actual, reference)) {
                                view.anchorToCapHeight = anchored
                                view.setSelectable(selectable)
                                if (color == null) {
                                    view.background = if (view === reference) android.graphics.drawable.ColorDrawable(Color.TRANSPARENT) else null
                                    view.reapplyPaperOpacity()
                                } else {
                                    manager.setBackgroundColor(view, color)
                                }
                                manager.setOpacity(view, opacity)
                                measureAndLayout(view, 360, 180)
                            }
                            reference.selectionView?.setBackgroundColor(Color.TRANSPARENT)
                            actual.selectionView?.let { assertNull(it.background) }
                            val actualBitmap = render(actual)
                            val case = "anchor=$anchored selectable=$selectable color=$color opacity=$opacity"
                            val expectedCorner = if (color == null) Color.TRANSPARENT else
                                Color.argb((opacity * Color.alpha(color)).roundToInt(), Color.red(color), Color.green(color), Color.blue(color))
                            assertEquals(case, expectedCorner, actualBitmap.getPixel(359, 179))
                            if (color == null || color == Color.TRANSPARENT) {
                                val expectedBitmap = render(reference)
                                assertTrue(case, actualBitmap.sameAs(expectedBitmap))
                                expectedBitmap.recycle()
                            }
                            actualBitmap.recycle()
                        }
                    }
                }
            }
        }
    }

    @Test
    fun selectionPreservesPreparedGeometryUnderWidgetThemes() {
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            fun render(view: View) = Bitmap.createBitmap(360, 640, Bitmap.Config.ARGB_8888).also {
                view.draw(Canvas(it))
            }
            val testContext = InstrumentationRegistry.getInstrumentation().context
            for (themeName in listOf("RNTETextTheme", "RNTEDirectTextTheme")) {
                val themeId = testContext.resources.getIdentifier(themeName, "style", testContext.packageName)
                assertNotEquals(0, themeId)
                val context = androidx.appcompat.view.ContextThemeWrapper(testContext, themeId)
                val referenceColor = androidx.appcompat.widget.AppCompatTextView(context).currentTextColor
                val manager = RNTextEngineTextViewManager()
                val view = RNTextEngineTextViewManager.RNTextEngineTextView(context)
                assertEquals(referenceColor, view.defaultTextColor)
                manager.setText(view, "Mixed case text wraps onto several lines under either interaction mode.")
                manager.setFontSize(view, 17.0)
                manager.setLineHeight(view, 24.5)
                manager.setColor(view, Color.MAGENTA)
                manager.setColor(view, null)
                manager.setPadding(view, 5, 3, 7, 2)
                measureAndLayout(view, 360, 640)
                assertEquals(referenceColor, requireNotNull(view.displayView.resolveLayout(360)).paint.color)
                for (text in listOf("Mixed case text wraps onto several lines under either interaction mode.", "אבג דהו זחט יכל מנס עפצ קרש תאב גדה וזח טיכ למנ סעפ צקר שתא", "Hello 🙂 日本語 বাংলা mixed fallback fonts")) {
                    manager.setText(view, text)
                    for (alignment in listOf(null, "left", "right", "center")) {
                        manager.setTextAlign(view, alignment)
                        for (anchored in listOf(false, true)) {
                            view.anchorToCapHeight = anchored
                            view.setSelectable(false)
                            measureAndLayout(view, 360, 640)
                            val displayLayout = requireNotNull(view.displayView.resolveLayout(360))
                            val displayed = render(view)
                            view.setSelectable(true)
                            view.finishUpdates()
                            val selected = requireNotNull(view.selectionView)
                            val selectedLayout = requireNotNull(selected.layout)
                            val case = "$themeName $alignment anchored=$anchored text=$text"
                            assertEquals(case, text, selected.text.toString())
                            assertEquals(case, referenceColor, selected.currentTextColor)
                            assertEquals(case, Int.MAX_VALUE, selected.maxLines)
                            assertEquals(case, displayLayout.lineCount, selectedLayout.lineCount)
                            assertEquals(case, view.displayView.y, selected.y, 0.001f)
                            val selectedBitmap = render(view)
                            assertTrue("$case changed pixels", displayed.sameAs(selectedBitmap))
                            displayed.recycle()
                            selectedBitmap.recycle()
                            for (line in 0 until displayLayout.lineCount) {
                                assertEquals(case, displayLayout.getLineStart(line), selectedLayout.getLineStart(line))
                                assertEquals(case, displayLayout.getLineEnd(line), selectedLayout.getLineEnd(line))
                                assertEquals(case, displayLayout.getLineBaseline(line), selectedLayout.getLineBaseline(line))
                                assertEquals(case, displayLayout.getLineLeft(line), selectedLayout.getLineLeft(line), 0.01f)
                            }
                        }
                    }
                }
                val handle = RNTextEngineBindings.prepare(
                    text = "Prepared color", color = null, fontFamily = null, fontSize = 17.0,
                    fontWeight = null, fontStyle = null, letterSpacing = 0.0, lineHeight = Double.NaN,
                    allowFontScaling = false, includeFontPadding = false, tabularNumbers = false,
                    textBreakStrategy = null,
                )
                try {
                    val preparedView = RNTextEnginePreparedTextViewManager.RNTextEnginePreparedTextView(context)
                    preparedView.setPreparedHandle(handle)
                    measureAndLayout(preparedView, 360, 160)
                    val color = requireNotNull(preparedView.displayView.resolveLayout(360)).paint.color
                    preparedView.setSelectable(true)
                    preparedView.finishUpdates()
                    assertEquals(color, requireNotNull(preparedView.selectionView).currentTextColor)
                } finally {
                    RNTextEngineBindings.release(handle)
                }
            }
        }
    }

    @Test
    fun mountedViewsSharePreparedTextWithoutSharingMutableDrawingState() {
        val handle = RNTextEngineBindings.prepareTextViewWithRuns(
            text = "Root inherited explicit",
            textTransform = null,
            color = "#000000",
            fontFamily = null,
            fontSize = 17.0,
            fontWeight = null,
            fontStyle = null,
            letterSpacing = 0.0,
            lineHeight = 25.0,
            allowFontScaling = false,
            includeFontPadding = false,
            tabularNumbers = false,
            textBreakStrategy = null,
            runStarts = intArrayOf(5, 15),
            runEnds = intArrayOf(14, 23),
            runStyleMasks = intArrayOf(1 shl 2, 1),
            runColors = arrayOf(null, "#0000ff"),
            runFontFamilies = arrayOfNulls(2),
            runFontSizes = doubleArrayOf(20.0, 0.0),
            runFontWeights = arrayOfNulls(2),
            runFontStyles = arrayOfNulls(2),
            runLetterSpacings = doubleArrayOf(0.0, 0.0),
            runLineHeights = doubleArrayOf(0.0, 0.0),
            runTabularNumbers = booleanArrayOf(false, false),
        )
        repeat(32) { index ->
            RNTextEngineBindings.layout(handle, 80.0 + index, 0, null, false)
        }
        val prepared = requireNotNull(RNTextEngineBindings.preparedText(handle))
        assertSame(prepared, RNTextEngineBindings.preparedText(handle))
        val text = prepared.displayText() as android.text.Spanned
        assertTrue("Canonical spans must be immutable", text !is android.text.Spannable)
        val inherited = text.getSpans(5, 14, RNTextEngineTextPaintSpan::class.java).single()
        val explicit = text.getSpans(15, 23, android.text.style.CharacterStyle::class.java).single()
        val paint = TextPaint(prepared.style.textPaint).apply { color = Color.RED }
        inherited.updateDrawState(paint)
        assertEquals(Color.RED, paint.color)
        assertTrue(text.getSpans(15, 23, android.text.style.MetricAffectingSpan::class.java).isEmpty())
        explicit.updateDrawState(paint)
        assertEquals(Color.BLUE, paint.color)
        assertSame(prepared.capHeights, prepared.capHeights)

        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            fun createView() = RNTextEnginePreparedTextViewManager.RNTextEnginePreparedTextView(application).apply {
                setPreparedHandle(handle)
                measureAndLayout(this, 360, 200)
            }
            fun render(view: View) = Bitmap.createBitmap(360, 200, Bitmap.Config.ARGB_8888).also {
                view.draw(Canvas(it))
            }
            val first = createView()
            val second = createView()
            val before = render(second)
            RNTextEngineBindings.release(handle)
            assertEquals(null, RNTextEngineBindings.preparedText(handle))
            first.setTextDecorationLineValue("underline line-through")
            first.setTextShadowColorValue(Color.RED)
            first.setTextShadowRadiusPx(2f)
            first.setSelectable(true)
            first.finishUpdates()
            val selectedText = requireNotNull(first.selectionView).text as android.text.Spannable
            selectedText.setSpan(android.text.style.ForegroundColorSpan(Color.MAGENTA), 0, selectedText.length, 0)
            val after = render(second)
            assertTrue("Another view mutated shared prepared content", before.sameAs(after))
            assertEquals("Root inherited explicit", requireNotNull(second.displayView.resolveLayout(360)).text.toString())
            assertSame(explicit, text.getSpans(0, text.length, android.text.style.ForegroundColorSpan::class.java).single())
            before.recycle()
            after.recycle()
        }
    }

    @Test
    fun relativeLayoutsMatchPhysicalAlignmentOnlyForUniformDirection() {
        for ((text, physicalAlignment) in listOf(
            "Hello\nWorld" to "left",
            "שלום\nمرحبا" to "right",
            "Hello\nשלום" to null,
            "שלום\nHello" to null,
        )) {
            val layout = buildStaticLayoutCompat(
                text = text,
                paint = TextPaint().apply { textSize = 32f },
                widthPx = 360,
                includeFontPadding = false,
                breakStrategy = Layout.BREAK_STRATEGY_HIGH_QUALITY,
                hyphenationFrequency = Layout.HYPHENATION_FREQUENCY_NORMAL,
                maxLines = Int.MAX_VALUE,
                ellipsize = null,
            )
            assertEquals(2, layout.lineCount)
            assertTrue(layout.matchesAlignment(Layout.Alignment.ALIGN_NORMAL))
            for (alignment in listOf("left", "right", "center")) {
                assertEquals("$text align=$alignment", alignment == physicalAlignment,
                    layout.matchesAlignment(resolveLayoutAlignment(alignment)))
            }
        }
    }

    @Test
    fun measuredLayoutsTransferExclusivelyAndMatchFreshDrawing() {
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            val text = "Shared layout 😀 বাংলা 日本語 wraps through a measured paragraph. ".repeat(3)
            val density = PixelUtil.getDisplayMetricDensity()
            fun pending(prepared: RNTextEngineBindings.PreparedText): Layout? {
                val field = prepared.javaClass.getDeclaredField("measuredLayout").apply { isAccessible = true }
                val slot = field.get(prepared) ?: return null
                return slot.javaClass.getDeclaredField("layout").apply { isAccessible = true }.get(slot) as Layout
            }
            for (styled in listOf(false, true)) {
                for (lineHeight in doubleArrayOf(Double.NaN, 12.0, 24.0, 24.5)) {
                    for (anchor in listOf(false, true)) {
                        for (maxLines in intArrayOf(0, 2)) {
                            for (align in listOf(null, "left", "center", "right", "justify")) {
                                fun prepare(forMount: Boolean): Long = if (!styled) {
                                    RNTextEngineBindings.prepareTextView(text, null, null, null, 17.0, null, null,
                                        0.0, lineHeight, false, false, false, null, environmentVersion = if (forMount) RNTextEngineBindings.textEnvironmentVersion() else 0)
                                } else {
                                    RNTextEngineBindings.prepareTextViewWithRuns(text, null, null, null, 17.0, null, null,
                                        0.0, lineHeight, false, false, false, null,
                                        intArrayOf(0), intArrayOf(6), intArrayOf((1 shl 2) or 1),
                                        arrayOf("#ff0000"), arrayOf(null), doubleArrayOf(23.0), arrayOf(null), arrayOf(null),
                                        doubleArrayOf(0.0), doubleArrayOf(0.0), booleanArrayOf(false), environmentVersion = if (forMount) RNTextEngineBindings.textEnvironmentVersion() else 0)
                                }
                                val handle = prepare(true)
                                val referenceHandle = prepare(false)
                                try {
                                    val width = 360
                                    val contentWidth = width - 3 - 7
                                    val widthDp = contentWidth.toDouble() / density
                                    val expected = RNTextEngineBindings.layout(referenceHandle, widthDp, maxLines, "tail", anchor)
                                    val actual = RNTextEngineBindings.layout(handle, widthDp, maxLines, "tail", anchor)
                                    org.junit.Assert.assertArrayEquals(expected, actual, 0.0001)
                                    val prepared = requireNotNull(RNTextEngineBindings.preparedText(handle))
                                    val measured = pending(prepared)
                                    val eligible = align == null || align == "left"
                                    if (eligible) assertTrue(measured != null)
                                    fun view(content: RNTextEngineBindings.PreparedText) =
                                        RNTextEngineAttributedTextDisplayView(application).apply {
                                            setPreparedText(content)
                                            numberOfLines = maxLines
                                            ellipsizeMode = "tail"
                                            setTextAlignValue(align)
                                            setTextColorValue(Color.BLUE)
                                            setTextDecorationLineValue("underline line-through")
                                            setTextShadowColorValue(Color.RED)
                                            setTextShadowOffsetPx(1f, 2f)
                                            setTextShadowRadiusPx(1f)
                                            setPadding(3, 5, 7, 9)
                                            measureAndLayout(this, width, 1000)
                                            if (anchor) capHeightTopInsetPx = resolveCapHeightInsets(width).top
                                        }
                                    val transferred = view(prepared)
                                    val fresh = view(requireNotNull(RNTextEngineBindings.preparedText(referenceHandle)))
                                    val firstLayout = requireNotNull(transferred.resolveLayout(width))
                                    if (eligible) assertSame("Transfer height=$lineHeight anchor=$anchor lines=$maxLines align=$align measuredWidth=${measured?.width}", measured, firstLayout)
                                    else if (measured != null) assertTrue(measured !== firstLayout)
                                    assertEquals(null, pending(prepared))
                                    RNTextEngineBindings.layout(handle, widthDp - 10, maxLines, "tail", anchor)
                                    val nextLayout = pending(prepared)
                                    assertTrue(nextLayout !== firstLayout)
                                    RNTextEngineBindings.layout(handle, widthDp, maxLines, "tail", anchor)
                                    assertSame("A scalar cache hit must not rebuild or replace the pending layout", nextLayout, pending(prepared))
                                    val second = view(prepared)
                                    val secondLayout = requireNotNull(second.resolveLayout(width))
                                    assertEquals(null, pending(prepared))
                                    assertTrue(firstLayout !== secondLayout)
                                    assertTrue(firstLayout.paint !== secondLayout.paint)
                                    fun render(view: View) = Bitmap.createBitmap(width, 1000, Bitmap.Config.ARGB_8888).also {
                                        view.draw(Canvas(it))
                                    }
                                    val before = render(transferred)
                                    val reference = render(fresh)
                                    assertTrue("Transferred layout differs: height=$lineHeight anchor=$anchor lines=$maxLines align=$align",
                                        before.sameAs(reference))
                                    RNTextEngineBindings.release(handle)
                                    second.setTextColorValue(Color.GREEN)
                                    val after = render(transferred)
                                    assertTrue(before.sameAs(after))
                                    before.recycle()
                                    reference.recycle()
                                    after.recycle()
                                } finally {
                                    RNTextEngineBindings.release(handle)
                                    RNTextEngineBindings.release(referenceHandle)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @Test
    fun drawStyleUpdatesReuseLayoutAndMatchFreshRendering() {
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            val prepared = RNTextEngineBindings.prepareTextViewContent(
                text = "Visible text wraps across several lines.",
                textTransform = null,
                color = Color.BLACK,
                fontFamily = null,
                fontSize = 17.0,
                fontWeight = null,
                fontStyle = null,
                letterSpacing = 0.0,
                lineHeight = 24.0,
                allowFontScaling = false,
                tabularNumbers = false,
                textBreakStrategy = "highQuality",
            )
            fun createView() = RNTextEngineAttributedTextDisplayView(application).apply {
                setPreparedText(prepared)
                layout(0, 0, 320, 240)
            }
            fun render(view: View) = Bitmap.createBitmap(320, 240, Bitmap.Config.ARGB_8888).also {
                view.draw(Canvas(it))
            }
            val view = createView()
            val layout = requireNotNull(view.resolveLayout(320))
            val updates = listOf<(RNTextEngineAttributedTextDisplayView) -> Unit>(
                { it.setTextDecorationLineValue("underline line-through") },
                { it.setTextShadowColorValue(Color.RED) },
                { it.setTextShadowOffsetPx(2f, 3f) },
                { it.setTextShadowRadiusPx(2f) },
                { it.setTextDecorationLineValue(null) },
                { it.setTextShadowColorValue(null) },
            )
            updates.forEachIndexed { index, update ->
                update(view)
                assertSame("Draw-only update $index rebuilt text layout", layout, view.resolveLayout(320))
                assertEquals(0, prepared.style.textPaint.flags and (android.graphics.Paint.UNDERLINE_TEXT_FLAG or android.graphics.Paint.STRIKE_THRU_TEXT_FLAG))
                val reference = createView()
                updates.take(index + 1).forEach { it(reference) }
                val actual = render(view)
                val expected = render(reference)
                assertTrue("Draw-only update $index changed rendering", actual.sameAs(expected))
                val pixels = IntArray(actual.width * actual.height)
                actual.getPixels(pixels, 0, actual.width, 0, 0, actual.width, actual.height)
                assertTrue("Text drawing must not be blank", pixels.any { it != Color.TRANSPARENT })
                actual.recycle()
                expected.recycle()
            }
            view.numberOfLines = 1
            assertNotSame("Line limits must invalidate layout", layout, view.resolveLayout(320))
        }
    }

    @Test
    fun measurementMatchesRenderedLineHeightsAndFallbackFonts() {
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            val texts = listOf("OK 1", "日本語の短い文章", "বাংলা ভাষা", "Hello 🙂 world", "Ag\n", "Ag\n\n", "\n", "\n\n", "\nAg", "Ag\nAg\nAg")
            for (text in texts) for (lineHeight in listOf(Double.NaN, 8.0, 16.25, 32.0)) for (includeFontPadding in listOf(false, true)) {
                val handle = RNTextEngineBindings.prepare(
                    text, null, null, 16.0, null, null, 0.0, lineHeight,
                    false, includeFontPadding, false, null,
                )
                try {
                    val prepared = requireNotNull(RNTextEngineBindings.preparedText(handle))
                    for (width in listOf(80.0, 160.0)) {
                        for (maxLines in listOf(0, 1, 2)) for (ellipsize in listOf("tail", "clip")) {
                            val view = RNTextEngineAttributedTextDisplayView(application).apply {
                                setPreparedText(prepared)
                                numberOfLines = maxLines
                                ellipsizeMode = ellipsize
                            }
                            val widthPx = PixelUtil.toPixelFromDIP(width.toFloat()).roundToInt()
                            val layout = requireNotNull(view.resolveLayout(widthPx))
                            val lineCount = if (maxLines > 0) minOf(layout.lineCount, maxLines) else layout.lineCount
                            val lastLine = lineCount - 1
                            for (anchor in listOf(false, true)) {
                                val expectedPx = if (anchor) {
                                    layout.getLineBaseline(lastLine) - view.resolveCapHeightInsets(widthPx).top
                                } else {
                                    layout.getLineBottom(lastLine).toFloat()
                                }
                                val expected = PixelUtil.toDIPFromPixel(expectedPx).toDouble()
                                val measured = RNTextEngineBindings.measure(
                                    text, null, null, 16.0, null, null, 0.0, lineHeight,
                                    false, includeFontPadding, false, null, width, maxLines, ellipsize, anchor,
                                )
                                val batch = RNTextEngineBindings.measureBatch(
                                    arrayOf("prefix", text), null, null, 16.0, null, null, 0.0, lineHeight,
                                    false, includeFontPadding, false, null, width, maxLines, ellipsize, anchor,
                                ).copyOfRange(4, 8)
                                val cached = RNTextEngineBindings.layout(handle, width, maxLines, ellipsize, anchor)
                                val lines = RNTextEngineBindings.layoutLines(handle, width, maxLines, ellipsize, anchor)
                                val tolerance = PixelUtil.toDIPFromPixel(1f).toDouble()
                                for (result in listOf(measured, batch, cached, lines)) {
                                    assertEquals("text=$text lineHeight=$lineHeight width=$width maxLines=$maxLines mode=$ellipsize padding=$includeFontPadding anchor=$anchor", expected, result[1], tolerance)
                                    assertEquals(lineCount.toDouble(), result[2], 0.0)
                                }
                            }
                        }
                    }
                } finally {
                    RNTextEngineBindings.release(handle)
                }
            }
        }
    }

    @Test
    fun explicitLineHeightControlsPlainTextLineBoxes() {
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            val manager = RNTextEngineTextViewManager()
            val view = RNTextEngineTextViewManager.RNTextEngineTextView(application)
            manager.setFontSize(view, 32.0)
            for (text in listOf("Ag\nAg\nAg", "বাংলা\n日本語\n🙂")) {
                manager.setText(view, text)
                for (lineHeight in listOf(16.0, 16.25, 32.0, 48.0)) {
                    manager.setLineHeight(view, lineHeight)
                    val lineHeightPx = ceil(PixelUtil.toPixelFromDIP(lineHeight.toFloat()).toDouble()).toInt()
                    for (anchor in listOf(false, true)) {
                        view.anchorToCapHeight = anchor
                        for (selectable in listOf(false, true, false)) {
                            view.setSelectable(selectable)
                            manager.setRuns(view, null)
                            measureAndLayout(view, 600, 600)
                            val layout = if (selectable) requireNotNull(view.selectionView?.layout)
                                else requireNotNull(view.displayView.resolveLayout(600))
                            val case = "$text height=$lineHeight anchor=$anchor selectable=$selectable"
                            assertEquals(case, 3, layout.lineCount)
                            assertEquals(case, lineHeightPx * layout.lineCount, layout.height)
                            for (line in 0 until layout.lineCount) {
                                assertEquals(case, lineHeightPx * line, layout.getLineTop(line))
                                assertEquals(case, lineHeightPx * (line + 1), layout.getLineBottom(line))
                            }
                            manager.setRuns(view, JavaOnlyArray.of(JavaOnlyMap.of(
                                "start", 0, "end", text.length, "style", JavaOnlyMap.of("color", "#0000ff"),
                            )))
                            measureAndLayout(view, 600, 600)
                            val styled = if (selectable) requireNotNull(view.selectionView?.layout)
                                else requireNotNull(view.displayView.resolveLayout(600))
                            assertEquals(case, layout.lineCount, styled.lineCount)
                            for (line in 0 until layout.lineCount) {
                                assertEquals(case, layout.getLineTop(line), styled.getLineTop(line))
                                assertEquals(case, layout.getLineBottom(line), styled.getLineBottom(line))
                                assertEquals(case, layout.getLineBaseline(line), styled.getLineBaseline(line))
                            }
                        }
                    }
                }
            }
        }
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
            val prepared = requireNotNull(RNTextEngineBindings.preparedText(handle))
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
    fun nestedTextKeepsNaturalLineHeight() {
        for (mixed in listOf(false, true)) {
            val parent = RNTextEngineTextShadowNode().apply { measureText = "A"; measureFontSize = 17.0 }
            val child = RNTextEngineTextShadowNode().apply {
                measureText = "B"
                measureRnteIsVirtualTextSpan = true
                if (mixed) measureFontSize = 23.0
            }
            parent.addChildAt(child, 0)
            try {
                val content = requireNotNull(RNTextEngineBindings.preparedText(resolvePreparedHandle(parent)))
                assertEquals(null, content.style.lineHeightPx)
                val geometry = RNTextEngineBindings.layout(resolvePreparedHandle(parent), 240.0, 0, null, false)
                assertTrue("Natural nested text must have positive height", geometry[1] > 0)
            } finally {
                parent.removeAndDisposeAllChildren()
                parent.dispose()
            }
        }
    }

    @Test
    @Suppress("DEPRECATION")
    fun nestedTextUsesTheSameFontScalingAsFlatText() {
        val originalConfiguration = Configuration(application.resources.configuration)
        val originalMetrics = DisplayMetrics().apply { setTo(DisplayMetricsHolder.getScreenDisplayMetrics()) }
        try {
            for (fontScale in floatArrayOf(1f, 1.5f, 2f)) {
                application.resources.updateConfiguration(
                    Configuration(originalConfiguration).apply { this.fontScale = fontScale },
                    application.resources.displayMetrics,
                )
                DisplayMetricsHolder.setScreenDisplayMetrics(application.resources.displayMetrics)
                for (allowFontScaling in booleanArrayOf(true, false)) {
                    val parent = RNTextEngineTextShadowNode()
                    val flat = RNTextEngineTextShadowNode()
                    val child = RNTextEngineTextShadowNode()
                    try {
                        for (node in listOf(parent, flat)) {
                            node.measureRnteHasAllowFontScaling = true
                            node.measureAllowFontScaling = allowFontScaling
                            node.measureFontSize = 18.0
                            node.measureLineHeight = 40.0
                            node.measureRnteHasLetterSpacing = true
                            node.measureLetterSpacing = 2.0
                        }
                        parent.measureText = "Parent "
                        child.measureRnteIsVirtualTextSpan = true
                        child.measureText = "child"
                        parent.addChildAt(child, 0)
                        flat.measureText = "Parent child"
                        val flatHandle = resolvePreparedHandle(flat)
                        val nestedHandle = resolvePreparedHandle(parent)
                        val flatText = requireNotNull(RNTextEngineBindings.preparedText(flatHandle))
                        val nestedText = requireNotNull(RNTextEngineBindings.preparedText(nestedHandle))
                        val label = "fontScale=$fontScale allowFontScaling=$allowFontScaling"
                        assertEquals(label, flatText.style.textPaint.textSize, nestedText.style.textPaint.textSize, 0.001f)
                        assertEquals(label, flatText.style.lineHeightPx!!, nestedText.style.lineHeightPx!!, 0.001f)
                        assertEquals(label, flatText.style.textPaint.letterSpacing, nestedText.style.textPaint.letterSpacing, 0.001f)
                        for (width in doubleArrayOf(60.0, 240.0)) {
                            val expected = RNTextEngineBindings.layout(flatHandle, width, 0, null, false)
                            val actual = RNTextEngineBindings.layout(nestedHandle, width, 0, null, false)
                            org.junit.Assert.assertArrayEquals(label, expected, actual, 0.001)
                        }
                        val payloadMethod = RNTextEngineTextShadowNode::class.java.getDeclaredMethod("resolvePayload")
                        payloadMethod.isAccessible = true
                        val payload = payloadMethod.invoke(parent) as RNTextEngineTextShadowNode.RNTextEngineResolvedTextPayload
                        InstrumentationRegistry.getInstrumentation().runOnMainSync {
                            val manager = RNTextEngineTextViewManager()
                            val flatView = RNTextEngineTextViewManager.RNTextEngineTextView(application)
                            val nestedView = RNTextEngineTextViewManager.RNTextEngineTextView(application)
                            for (view in listOf(flatView, nestedView)) {
                                manager.setText(view, "Parent child")
                                manager.setFontSize(view, 18.0)
                                manager.setLineHeight(view, 40.0)
                                manager.setLetterSpacing(view, 2.0)
                                manager.setAllowFontScaling(view, allowFontScaling)
                            }
                            manager.updateExtraData(nestedView, payload)
                            for (width in intArrayOf(160, 640)) {
                                measureAndLayout(flatView, width, 1000)
                                measureAndLayout(nestedView, width, 1000)
                                val expected = requireNotNull(flatView.displayView.resolveLayout(width))
                                val actual = requireNotNull(nestedView.displayView.resolveLayout(width))
                                assertEquals(label, flatText.style.textPaint.textSize, actual.paint.textSize, 0.001f)
                                assertEquals(label, expected.paint.letterSpacing, actual.paint.letterSpacing, 0.001f)
                                assertEquals(label, expected.lineCount, actual.lineCount)
                                assertEquals(label, expected.height, actual.height)
                            }
                        }
                    } finally {
                        parent.removeAndDisposeAllChildren()
                        parent.dispose()
                        flat.dispose()
                    }
                }
            }
        } finally {
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
            manager.updateProperties(view, ReactStylesDiffMap(JavaOnlyMap.of("fontSize", 44.0, "lineHeight", 48.0)))
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
                RNTextEnginePreparedTextViewManager().updateProperties(
                    view, ReactStylesDiffMap(JavaOnlyMap.of("handle", largeHandle.toDouble())),
                )
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
                        if (selectable) requireNotNull(view.selectionView).layout else view.displayView.resolveLayout(hostWidthPx)
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
        prepared: RNTextEngineBindings.PreparedText,
        widthDp: Double,
    ): Layout {
        val widthPx = ceil(PixelUtil.toPixelFromDIP(widthDp.toFloat()).toDouble()).toInt()
        return buildStaticLayoutCompat(
            text = prepared.displayText(),
            paint = TextPaint(prepared.style.textPaint),
            widthPx = widthPx,
            includeFontPadding = prepared.style.includeFontPadding,
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
