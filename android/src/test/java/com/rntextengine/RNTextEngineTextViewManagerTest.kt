package com.rntextengine

import android.app.Activity
import android.app.Application
import android.graphics.Color
import android.os.Looper
import android.text.Spanned
import android.text.TextPaint
import android.view.View
import android.widget.FrameLayout
import androidx.appcompat.widget.AppCompatTextView
import androidx.test.core.app.ApplicationProvider
import com.facebook.react.bridge.JavaOnlyMap
import com.facebook.react.bridge.JavaOnlyArray
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
import com.facebook.react.uimanager.ViewGroupManager
import com.facebook.react.turbomodule.core.interfaces.CallInvokerHolder
import com.facebook.yoga.YogaMeasureMode
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.roundToInt
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Ignore
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

private class TextViewManagerTestReactContext(application: Application) : ReactApplicationContext(application) {
    override fun <T : JavaScriptModule> getJSModule(jsInterface: Class<T>): T {
        throw UnsupportedOperationException("JS modules are not used in RNTextEngineTextViewManager tests.")
    }

    override fun <T : NativeModule> hasNativeModule(nativeModuleInterface: Class<T>): Boolean = false

    override fun getNativeModules(): MutableCollection<NativeModule> = mutableListOf()

    override fun <T : NativeModule> getNativeModule(nativeModuleInterface: Class<T>): T? = null

    override fun getNativeModule(moduleName: String): NativeModule? = null

    override fun getCatalystInstance(): CatalystInstance {
        throw UnsupportedOperationException("CatalystInstance is not used in RNTextEngineTextViewManager tests.")
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

private fun expectedAnchoredContentHeight(hostHeight: Int, insets: RNTextEngineCapHeightInsetsPx): Int {
    return hostHeight + floor(insets.top.toDouble()).toInt() + ceil(insets.bottom.toDouble()).toInt()
}

private fun referencePlainTextWidthPx(text: CharSequence, paint: TextPaint): Float {
    if (text.isEmpty()) return 0f
    return roundMeasuredTextWidthPx(paint.getRunAdvance(text, 0, text.length, 0, text.length, false, text.length))
}

private fun effectiveAnchoredTopInset(view: View): Float {
    return -view.y
}

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class RNTextEngineTextViewManagerTest {
    companion object {
        private const val PACKED_LAYOUT_SIZE = 4
        private const val PACKED_LINE_SIZE = 4
        private const val PACKED_LINE_BOTTOM_INDEX = 3
    }

    private lateinit var application: Application

    @Before
    fun setUp() {
        application = ApplicationProvider.getApplicationContext()
        DisplayMetricsHolder.initDisplayMetricsIfNotInitialized(application)
        RNTextEngineBindings.initialize(TextViewManagerTestReactContext(application))
        RNTextEngineBindings.cleanup()
    }

    @After
    fun tearDown() {
        RNTextEngineBindings.cleanup()
    }

    @Test
    fun textViewAnchorToCapHeightOffsetsTheMountedDisplayOwner() {
        val text = "Cap anchored text"
        val view = RNTextEngineTextViewManager.RNTextEngineTextView(application)
        view.anchorToCapHeight = true
        view.textContentView.textValue = text
        view.textContentView.fontFamily = "serif"
        view.textContentView.setFontSizeValue(48f)
        view.textContentView.setLineHeightValue(56f)
        view.invalidateTextDisplay()
        view.flushTextDisplayIfNeeded()

        val insets = view.displayView.resolveCapHeightInsets(240)
        val viewHeight = 80

        measureAndLayout(view, width = 240, height = viewHeight)
        shadowOf(Looper.getMainLooper()).idle()

        assertEquals(insets.top, effectiveAnchoredTopInset(view.displayView), 0.001f)
        assertEquals(viewHeight, view.displayView.measuredHeight)
        assertEquals(expectedAnchoredContentHeight(viewHeight, insets), view.displayView.height)
    }

    @Test
    fun preparedTextViewAnchorToCapHeightOffsetsTheMountedDisplayOwner() {
        val text = "Cap anchored prepared text"
        val handle =
            RNTextEngineBindings.prepare(
                text = text,
                color = null,
                fontFamily = "serif",
                fontSize = 40.0,
                fontWeight = null,
                fontStyle = null,
                letterSpacing = Double.NaN,
                lineHeight = 48.0,
                allowFontScaling = false,
                includeFontPadding = false,
                tabularNumbers = false,
                textBreakStrategy = null,
            )
        val view = RNTextEnginePreparedTextViewManager.RNTextEnginePreparedTextView(application)
        view.anchorToCapHeight = true
        view.setPreparedHandle(handle)

        val insets = view.displayView.resolveCapHeightInsets(240)
        val viewHeight = 80

        measureAndLayout(view, width = 240, height = viewHeight)
        shadowOf(Looper.getMainLooper()).idle()

        assertEquals(insets.top, effectiveAnchoredTopInset(view.displayView), 0.001f)
        assertEquals(viewHeight, view.displayView.measuredHeight)
        assertEquals(expectedAnchoredContentHeight(viewHeight, insets), view.displayView.height)
    }

    @Test
    fun preparedTextViewAttachedHandleUpdateReanchorsImmediatelyWithoutParentRelayout() {
        val handle =
            RNTextEngineBindings.prepare(
                text = "Push this harder. A prepared message can be measured repeatedly without rebuilding the message itself.",
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
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        val root = FrameLayout(activity)
        val view = RNTextEnginePreparedTextViewManager.RNTextEnginePreparedTextView(activity)
        val hostWidth = 240
        val hostHeight = 120

        view.anchorToCapHeight = true
        root.addView(view, FrameLayout.LayoutParams(hostWidth, hostHeight))
        activity.setContentView(root)
        measureAndLayout(root, width = hostWidth, height = hostHeight)
        shadowOf(Looper.getMainLooper()).idle()

        assertTrue(view.isAttachedToWindow)
        assertEquals(0f, effectiveAnchoredTopInset(view.displayView), 0.001f)

        view.setPreparedHandle(handle)
        shadowOf(Looper.getMainLooper()).idle()

        val insets = view.displayView.resolveCapHeightInsets(hostWidth)

        assertEquals(insets.top, effectiveAnchoredTopInset(view.displayView), 0.001f)
        assertEquals(hostHeight, view.displayView.measuredHeight)
        assertEquals(expectedAnchoredContentHeight(hostHeight, insets), view.displayView.height)

        RNTextEngineBindings.release(handle)
    }

    @Test
    fun textViewAnchorToCapHeightUsesHostWidthWhenPaddingIsPresent() {
        val manager = RNTextEngineTextViewManager()
        val view = RNTextEngineTextViewManager.RNTextEngineTextView(application)
        val hostWidth = 240
        val hostHeight = 120

        manager.setAnchorToCapHeight(view, true)
        manager.setAllowFontScaling(view, false)
        manager.setFontFamily(view, "serif")
        manager.setFontSize(view, 17.0)
        manager.setLineHeight(view, 24.0)
        manager.setPadding(view, 16, 16, 16, 16)
        manager.setText(
            view,
            "Push this harder. A prepared message can be measured repeatedly without rebuilding the message itself.",
        )
        view.flushTextDisplayIfNeeded()

        measureAndLayout(view, width = hostWidth, height = hostHeight)
        shadowOf(Looper.getMainLooper()).idle()

        val insets = view.displayView.resolveCapHeightInsets(hostWidth)

        assertEquals(insets.top, effectiveAnchoredTopInset(view.displayView), 0.001f)
        assertEquals(hostHeight, view.displayView.measuredHeight)
        assertEquals(expectedAnchoredContentHeight(hostHeight, insets), view.displayView.height)
    }

    @Test
    fun preparedTextViewAnchorToCapHeightUsesHostWidthWhenPaddingIsPresent() {
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
        val view = RNTextEnginePreparedTextViewManager.RNTextEnginePreparedTextView(application)
        val hostWidth = 240
        val hostHeight = 120

        view.anchorToCapHeight = true
        view.setContentPadding(16, 16, 16, 16)
        view.setPreparedHandle(handle)

        measureAndLayout(view, width = hostWidth, height = hostHeight)
        shadowOf(Looper.getMainLooper()).idle()

        val insets = view.displayView.resolveCapHeightInsets(hostWidth)

        assertEquals(insets.top, effectiveAnchoredTopInset(view.displayView), 0.001f)
        assertEquals(hostHeight, view.displayView.measuredHeight)
        assertEquals(expectedAnchoredContentHeight(hostHeight, insets), view.displayView.height)

        RNTextEngineBindings.release(handle)
    }

    @Test
    @Ignore("Mounted cap-height baseline alignment is validated by instrumented Android tests; Robolectric does not model anchored text measurement faithfully here.")
    fun textViewCapAnchoredMountedBaselineMatchesMeasuredHeight() {
        val manager = RNTextEngineTextViewManager()
        val sourceText = "Exact row"
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
        val view = RNTextEngineTextViewManager.RNTextEngineTextView(application)

        manager.setAllowFontScaling(view, false)
        manager.setAnchorToCapHeight(view, true)
        manager.setFontSize(view, 11.0)
        manager.setFontWeight(view, "800")
        manager.setLetterSpacing(view, 0.9)
        manager.setTextTransform(view, "uppercase")
        manager.setText(view, sourceText)

        val hostWidthPx = PixelUtil.toPixelFromDIP(measured[0].toFloat()).roundToInt()
        val hostHeightPx = PixelUtil.toPixelFromDIP(measured[1].toFloat()).roundToInt()

        measureAndLayout(view, width = hostWidthPx, height = hostHeightPx)

        val mountedLayout = requireNotNull(view.displayView.resolveLayout(hostWidthPx))
        val mountedBottom = view.displayView.y + mountedLayout.getLineBottom(mountedLayout.lineCount - 1)

        assertTrue("measured=${measured.contentToString()} bottom=$mountedBottom hostHeightPx=$hostHeightPx", abs(mountedBottom - hostHeightPx) <= 1)
        assertEquals(0, mountedLayout.getEllipsisCount(0))
        assertEquals("EXACT ROW".length, mountedLayout.getLineVisibleEnd(0))
    }

    @Test
    @Ignore("Mounted cap-height baseline alignment is validated by instrumented Android tests; Robolectric does not model anchored text measurement faithfully here.")
    fun preparedTextViewCapAnchoredMountedBaselineMatchesMeasuredHeight() {
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
        val measured = RNTextEngineBindings.layout(handle, 180.0, 0, null, true)
        val view = RNTextEnginePreparedTextViewManager.RNTextEnginePreparedTextView(application)
        view.anchorToCapHeight = true
        view.setPreparedHandle(handle)

        val hostWidthPx = PixelUtil.toPixelFromDIP(180f).roundToInt()
        val hostHeightPx = PixelUtil.toPixelFromDIP(measured[1].toFloat()).roundToInt()

        measureAndLayout(view, width = hostWidthPx, height = hostHeightPx)

        val mountedLayout = requireNotNull(view.displayView.resolveLayout(hostWidthPx))
        val mountedBottom = view.displayView.y + mountedLayout.getLineBottom(mountedLayout.lineCount - 1)

        assertTrue("measured=${measured.contentToString()} bottom=$mountedBottom hostHeightPx=$hostHeightPx", abs(mountedBottom - hostHeightPx) <= 1)
        RNTextEngineBindings.release(handle)
    }

    @Test
    fun anchoredPaperOpacityTargetsTheMountedDisplayOwner() {
        val manager = RNTextEngineTextViewManager()
        val view = RNTextEngineTextViewManager.RNTextEngineTextView(application)
        view.anchorToCapHeight = true

        manager.setOpacity(view, 0.5f)

        assertEquals(1f, view.alpha, 0.001f)
        assertEquals(0.5f, view.displayView.alpha, 0.001f)
    }

    @Test
    fun nonAnchoredPaperOpacityStillTargetsTheHostView() {
        val manager = RNTextEngineTextViewManager()
        val view = RNTextEngineTextViewManager.RNTextEngineTextView(application)
        view.anchorToCapHeight = false

        manager.setOpacity(view, 0.5f)

        assertEquals(0.5f, view.alpha, 0.001f)
        assertEquals(1f, view.displayView.alpha, 0.001f)
    }

    @Test
    fun layoutLinesAnchorToCapHeightPreservesInterlineSpacing() {
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

        val packed = RNTextEngineBindings.layoutLines(handle, 240.0, 0, null, true)
        val lineCount = packed[2].toInt()
        assertTrue(packed.contentToString(), lineCount >= 2)
        val firstBottom = packed[PACKED_LAYOUT_SIZE + PACKED_LINE_BOTTOM_INDEX]
        val secondBottom = packed[PACKED_LAYOUT_SIZE + PACKED_LINE_SIZE + PACKED_LINE_BOTTOM_INDEX]
        assertEquals(24.0, secondBottom - firstBottom, 0.001)
    }

    @Test
    fun preparedAutoSizeTextShortCircuitsExactConstraints() {
        val measurement =
            measurePreparedAutoSizeText(
                handle = 0,
                widthPx = 180f,
                widthMode = YogaMeasureMode.EXACTLY,
                heightPx = 42f,
                heightMode = YogaMeasureMode.EXACTLY,
                numberOfLines = 0,
                ellipsizeMode = null,
                anchorToCapHeight = false,
            )

        assertEquals(180f, measurement.widthPx, 0.001f)
        assertEquals(42f, measurement.heightPx, 0.001f)
    }

    @Test
    fun preparedAutoSizeTextMeasuresIntrinsicWidthWithoutWrapping() {
        val text = "Intrinsic measurement text"
        val handle =
            RNTextEngineBindings.prepare(
                text = text,
                color = null,
                fontFamily = null,
                fontSize = 20.0,
                fontWeight = null,
                fontStyle = null,
                letterSpacing = 0.0,
                lineHeight = 24.0,
                allowFontScaling = false,
                includeFontPadding = false,
                tabularNumbers = false,
                textBreakStrategy = null,
            )
        val measurement =
            measurePreparedAutoSizeText(
                handle = handle,
                widthPx = 0f,
                widthMode = YogaMeasureMode.UNDEFINED,
                heightPx = 0f,
                heightMode = YogaMeasureMode.UNDEFINED,
                numberOfLines = 0,
                ellipsizeMode = null,
                anchorToCapHeight = false,
            )
        val expectedWidthPx = PixelUtil.toPixelFromDIP(RNTextEngineBindings.measurePreparedWidth(handle).toFloat())
        val expectedHeightPx = PixelUtil.toPixelFromDIP(RNTextEngineBindings.layout(handle, RNTextEngineBindings.measurePreparedWidth(handle), 0, null, false)[1].toFloat())
        RNTextEngineBindings.release(handle)

        assertEquals(expectedWidthPx, measurement.widthPx, 0.001f)
        assertEquals(expectedHeightPx, measurement.heightPx, 0.001f)
    }

    @Test
    fun preparedAutoSizeTextWrapsToAtMostWidth() {
        val text = "Wrapped measurement text should occupy more than one line at genuinely narrow widths across fallback fonts."
        val handle =
            RNTextEngineBindings.prepare(
                text = text,
                color = null,
                fontFamily = null,
                fontSize = 18.0,
                fontWeight = null,
                fontStyle = null,
                letterSpacing = 0.0,
                lineHeight = 22.0,
                allowFontScaling = false,
                includeFontPadding = false,
                tabularNumbers = false,
                textBreakStrategy = null,
            )
        val intrinsic = measurePreparedAutoSizeText(handle, 0f, YogaMeasureMode.UNDEFINED, 0f, YogaMeasureMode.UNDEFINED, 0, null, false)
        val constrainedWidthDp = 60.0
        val constrainedWidthPx = PixelUtil.toPixelFromDIP(constrainedWidthDp.toFloat())
        val wrapped = measurePreparedAutoSizeText(handle, constrainedWidthPx, YogaMeasureMode.AT_MOST, 0f, YogaMeasureMode.UNDEFINED, 0, null, false)
        val expectedWrapped = RNTextEngineBindings.layout(handle, constrainedWidthDp, 0, null, false)
        RNTextEngineBindings.release(handle)

        assertTrue(wrapped.widthPx <= constrainedWidthPx + 0.001f)
        assertEquals(PixelUtil.toPixelFromDIP(expectedWrapped[1].toFloat()), wrapped.heightPx, 0.001f)
    }

    @Test
    fun preparedAutoSizeTextRespectsNumberOfLines() {
        val text = "One two three four five six seven eight nine ten."
        val handle =
            RNTextEngineBindings.prepare(
                text = text,
                color = null,
                fontFamily = null,
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
        val intrinsic = measurePreparedAutoSizeText(handle, 0f, YogaMeasureMode.UNDEFINED, 0f, YogaMeasureMode.UNDEFINED, 0, null, false)
        val constrainedWidthPx = intrinsic.widthPx * 0.4f
        val singleLine = measurePreparedAutoSizeText(handle, constrainedWidthPx, YogaMeasureMode.AT_MOST, 0f, YogaMeasureMode.UNDEFINED, 1, "tail", false)
        RNTextEngineBindings.release(handle)

        val expectedLineHeightPx = PixelUtil.toPixelFromDIP(24f)
        assertEquals(expectedLineHeightPx, singleLine.heightPx, 0.001f)
    }

    @Test
    fun preparedAutoSizeTextDoesNotPrematurelyShrinkAtMostSingleLineEllipsis() {
        val text = "Approximating"
        val handle =
            RNTextEngineBindings.prepare(
                text = text,
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
        val prepared = requireNotNull(RNTextEngineBindings.resolvePreparedTextViewData(handle))
        val intrinsicWidthPx = referencePlainTextWidthPx(prepared.text, TextPaint(prepared.textPaint))
        val measurement =
            measurePreparedAutoSizeText(
                handle = handle,
                widthPx = intrinsicWidthPx,
                widthMode = YogaMeasureMode.AT_MOST,
                heightPx = 0f,
                heightMode = YogaMeasureMode.UNDEFINED,
                numberOfLines = 1,
                ellipsizeMode = "middle",
                anchorToCapHeight = false,
            )
        RNTextEngineBindings.release(handle)

        assertEquals(intrinsicWidthPx, measurement.widthPx, 0.001f)
    }

    @Test
    fun preparedAutoSizeTextKeepsTrackedUppercaseWidthAtMostSingleLineEllipsis() {
        val handle =
            RNTextEngineBindings.prepareTextView(
                text = "exact row",
                textTransform = "uppercase",
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
            )
        val prepared = requireNotNull(RNTextEngineBindings.resolvePreparedTextViewData(handle))
        val intrinsicWidthPx = referencePlainTextWidthPx(prepared.text, TextPaint(prepared.textPaint))
        val measurement =
            measurePreparedAutoSizeText(
                handle = handle,
                widthPx = intrinsicWidthPx,
                widthMode = YogaMeasureMode.AT_MOST,
                heightPx = 0f,
                heightMode = YogaMeasureMode.UNDEFINED,
                numberOfLines = 1,
                ellipsizeMode = "middle",
                anchorToCapHeight = true,
            )
        RNTextEngineBindings.release(handle)

        assertEquals(intrinsicWidthPx, measurement.widthPx, 0.001f)
    }

    @Test
    fun mountedPlainPreparedTextKeepsTheExactPreparedOwnerPath() {
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
        val textView = AppCompatTextView(application)

        applyPreparedTextViewData(textView, prepared, textView.currentTextColor)

        assertEquals(RNTextEngineBindings.TextMountMode.SPANNABLE, prepared.mountMode)
        assertTrue(textView.text is Spanned)
        assertEquals("EXACT ROW", textView.text.toString())
        assertEquals(0f, textView.lineSpacingExtra, 0.0001f)

        RNTextEngineBindings.release(handle)
    }

    @Test
    fun mountedInlinePreparedTextKeepsTheStyledOwnerPath() {
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
        val textView = AppCompatTextView(application)

        applyPreparedTextViewData(textView, prepared, textView.currentTextColor)

        assertTrue(textView.text is Spanned)
        assertEquals(0f, textView.lineSpacingExtra, 0.0001f)

        RNTextEngineBindings.release(handle)
    }

    @Test
    fun preparedAutoSizeTextMeasuresInlineRunOverrides() {
        val text = "MMMMMMMM"
        val runHandle =
            RNTextEngineBindings.prepareWithRuns(
                text = text,
                color = null,
                fontFamily = null,
                fontSize = 16.0,
                fontWeight = null,
                fontStyle = null,
                letterSpacing = 0.0,
                lineHeight = 20.0,
                allowFontScaling = false,
                includeFontPadding = false,
                tabularNumbers = false,
                textBreakStrategy = null,
                runStarts = intArrayOf(0),
                runEnds = intArrayOf(text.length),
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
        val runMeasurement = measurePreparedAutoSizeText(runHandle, 0f, YogaMeasureMode.UNDEFINED, 0f, YogaMeasureMode.UNDEFINED, 0, null, false)
        val expectedRunWidthPx = PixelUtil.toPixelFromDIP(RNTextEngineBindings.measurePreparedWidth(runHandle).toFloat())
        RNTextEngineBindings.release(runHandle)

        assertEquals(expectedRunWidthPx, runMeasurement.widthPx, 0.001f)
    }

    @Test
    fun textTransformUpdatesMountedTextContent() {
        val manager = RNTextEngineTextViewManager()
        val view = RNTextEngineTextViewManager.RNTextEngineTextView(application)

        manager.setText(view, "gas")
        manager.setTextTransform(view, "uppercase")
        view.flushTextDisplayIfNeeded()
        assertEquals("GAS", view.textContentView.text.toString())

        manager.setTextTransform(view, "capitalize")
        manager.setText(view, "hold to swap")
        view.invalidateTextDisplay()
        view.flushTextDisplayIfNeeded()
        assertEquals("Hold To Swap", view.textContentView.text.toString())

        manager.setTextTransform(view, "none")
        manager.setText(view, "Hold To Swap")
        view.invalidateTextDisplay()
        view.flushTextDisplayIfNeeded()
        assertEquals("Hold To Swap", view.textContentView.text.toString())
    }

    @Test
    fun textViewPaddingInsetsTheMountedDisplayOwner() {
        val manager = RNTextEngineTextViewManager()
        val view = RNTextEngineTextViewManager.RNTextEngineTextView(application)

        manager.setPadding(view, 10, 6, 8, 4)
        measureAndLayout(view, width = 200, height = 50)

        assertEquals(10, view.displayView.paddingLeft)
        assertEquals(6, view.displayView.paddingTop)
        assertEquals(8, view.displayView.paddingRight)
        assertEquals(4, view.displayView.paddingBottom)
        assertEquals(0, view.displayView.left)
        assertEquals(0, view.displayView.top)
        assertEquals(200, view.displayView.right)
        assertEquals(50, view.displayView.bottom)
    }

    @Test
    fun collapsingCapAnchoredHostClearsTheMountedDisplayOwnerBounds() {
        val view = RNTextEngineTextViewManager.RNTextEngineTextView(application)
        view.anchorToCapHeight = true
        view.textContentView.textValue = "Animated text"
        view.textContentView.setFontSizeValue(36f)
        view.textContentView.setLineHeightValue(42f)
        view.invalidateTextDisplay()
        view.flushTextDisplayIfNeeded()

        measureAndLayout(view, width = 220, height = 60)
        assertTrue(view.displayView.bottom > 0)

        measureAndLayout(view, width = 0, height = 0)

        assertEquals(0, view.displayView.left)
        assertEquals(0, view.displayView.top)
        assertEquals(0, view.displayView.right)
        assertEquals(0, view.displayView.bottom)
    }

    @Test
    fun mountedHostKeepsItsPrivateDisplayOwnerOutOfPublicChildEnumeration() {
        val view = RNTextEngineTextViewManager.RNTextEngineTextView(application)

        assertEquals(view, view.displayView.parent)
        assertEquals(null, view.textContentView.parent)
        assertEquals(0, view.childCount)
        assertEquals(null, view.getChildAt(0))
        assertEquals(-1, view.indexOfChild(view.displayView))

        repeat(2) {
            view.setSelectable(true)
            assertEquals(view, view.textContentView.parent)
            assertEquals(0, view.childCount)
            assertEquals(null, view.getChildAt(0))
            assertEquals(-1, view.indexOfChild(view.textContentView))

            view.setSelectable(false)
            assertEquals(null, view.textContentView.parent)
            assertEquals(view, view.displayView.parent)
            assertEquals(View.VISIBLE, view.displayView.visibility)
            assertEquals(0, view.childCount)
        }
    }

    @Test
    fun preparedHostRemovesItsPrivateSelectableChild() {
        val view = RNTextEnginePreparedTextViewManager.RNTextEnginePreparedTextView(application)

        repeat(2) {
            view.setSelectable(true)
            assertEquals(view, view.textContentView.parent)
            assertEquals(0, view.childCount)
            assertEquals(null, view.getChildAt(0))
            assertEquals(-1, view.indexOfChild(view.textContentView))

            view.setSelectable(false)
            assertEquals(null, view.textContentView.parent)
            assertEquals(view, view.displayView.parent)
            assertEquals(View.VISIBLE, view.displayView.visibility)
            assertEquals(0, view.childCount)
        }
    }

    @Test
    fun mountedRunArrayPropsIgnoreOutOfTextRangesDuringFabricPropUpdates() {
        val manager = RNTextEngineTextViewManager()
        val view = RNTextEngineTextViewManager.RNTextEngineTextView(application)

        manager.setText(view, "Hello world")
        manager.setRunStarts(view, JavaOnlyArray.of(6))
        manager.setRunEnds(view, JavaOnlyArray.of(11))
        manager.setRunStyleMasks(view, JavaOnlyArray.of(1 shl 4))
        manager.setRunFontWeights(view, JavaOnlyArray.of("700"))
        measureAndLayout(view, width = 200, height = 50)

        manager.setText(view, "short")
        measureAndLayout(view, width = 200, height = 50)
        assertEquals("short", view.textContentView.text.toString())
        val staleText = view.textContentView.text as? Spanned
        assertEquals(0, staleText?.getSpans(0, staleText.length, RNTextEngineTextPaintSpan::class.java)?.size ?: 0)

        manager.setRunStarts(view, JavaOnlyArray.of(0))
        manager.setRunEnds(view, JavaOnlyArray.of(5))
        measureAndLayout(view, width = 200, height = 50)
        val updatedText = view.textContentView.text as Spanned
        assertEquals(1, updatedText.getSpans(0, updatedText.length, RNTextEngineTextPaintSpan::class.java).size)
    }

    @Test
    fun emptyRunArrayPropsOverrideLegacyRunsUntilTheArrayPropsAreRemoved() {
        val manager = RNTextEngineTextViewManager()
        val view = RNTextEngineTextViewManager.RNTextEngineTextView(application)
        manager.setText(view, "Hello")
        manager.setRuns(view, JavaOnlyArray.of(JavaOnlyMap.of("start", 0, "end", 5, "style", JavaOnlyMap.of("fontWeight", "700"))))
        measureAndLayout(view, width = 200, height = 50)
        val originalText = view.textContentView.text as Spanned
        assertEquals(1, originalText.getSpans(0, originalText.length, RNTextEngineTextPaintSpan::class.java).size)

        manager.setRunEnds(view, JavaOnlyArray.of(5))
        measureAndLayout(view, width = 200, height = 50)
        val partialText = view.textContentView.text as? Spanned
        assertEquals(0, partialText?.getSpans(0, partialText.length, RNTextEngineTextPaintSpan::class.java)?.size ?: 0)

        manager.setRunStarts(view, JavaOnlyArray())
        manager.setRunEnds(view, JavaOnlyArray())
        manager.setRunStyleMasks(view, JavaOnlyArray())
        measureAndLayout(view, width = 200, height = 50)
        val clearedText = view.textContentView.text as? Spanned
        assertEquals(0, clearedText?.getSpans(0, clearedText.length, RNTextEngineTextPaintSpan::class.java)?.size ?: 0)

        manager.setRunStarts(view, null)
        manager.setRunEnds(view, null)
        manager.setRunStyleMasks(view, null)
        measureAndLayout(view, width = 200, height = 50)
        val restoredText = view.textContentView.text as Spanned
        assertEquals(1, restoredText.getSpans(0, restoredText.length, RNTextEngineTextPaintSpan::class.java).size)
    }

    @Test
    fun nestedPayloadDiscardsRunsOutsideItsText() {
        val manager = RNTextEngineTextViewManager()
        val view = RNTextEngineTextViewManager.RNTextEngineTextView(application)
        val payload = RNTextEngineTextShadowNode.RNTextEngineResolvedTextPayload.EMPTY.copy(
            hasNested = true,
            hash = 1L,
            text = "short",
            runStarts = intArrayOf(6),
            runEnds = intArrayOf(11),
            runStyleMasks = intArrayOf(1 shl 4),
            runFontWeights = arrayOf("700"),
        )

        manager.updateExtraData(view, payload)
        measureAndLayout(view, width = 200, height = 50)

        assertEquals("short", view.textContentView.text.toString())
        val text = view.textContentView.text as? Spanned
        assertEquals(0, text?.getSpans(0, text.length, RNTextEngineTextPaintSpan::class.java)?.size ?: 0)
    }

    @Test
    fun paperManagerKeepsReactChildrenVirtualWhileTheMountedHostStaysLeafLike() {
        val manager = RNTextEngineTextViewManager()
        val view = RNTextEngineTextViewManager.RNTextEngineTextView(application)
        val firstChild = View(application)
        val secondChild = View(application)

        assertTrue(ViewGroupManager::class.java.isAssignableFrom(manager.javaClass))
        assertTrue(manager.needsCustomLayoutForChildren())

        manager.addView(view, firstChild, 0)
        manager.addView(view, secondChild, 1)

        assertEquals(2, manager.getChildCount(view))
        assertEquals(firstChild, manager.getChildAt(view, 0))
        assertEquals(secondChild, manager.getChildAt(view, 1))
        assertEquals(0, view.childCount)
        assertEquals(null, view.getChildAt(0))
        assertEquals(null, firstChild.parent)
        assertEquals(null, secondChild.parent)

        manager.removeViewAt(view, 0)

        assertEquals(1, manager.getChildCount(view))
        assertEquals(secondChild, manager.getChildAt(view, 0))
        assertEquals(0, view.childCount)
        assertEquals(null, view.getChildAt(0))
    }

    @Test
    fun layoutFlushesNestedPayloadAppliedAfterPaperTransaction() {
        val manager = RNTextEngineTextViewManager()
        val view = RNTextEngineTextViewManager.RNTextEngineTextView(application)
        val payload =
            RNTextEngineTextShadowNode.RNTextEngineResolvedTextPayload(
                hasNested = true,
                hash = 1L,
                text = "nested text",
                runStarts = IntArray(0),
                runEnds = IntArray(0),
                runStyleMasks = IntArray(0),
                runColors = emptyArray(),
                runFontFamilies = emptyArray(),
                runFontSizes = DoubleArray(0),
                runFontWeights = emptyArray(),
                runFontStyles = emptyArray(),
                runLetterSpacings = DoubleArray(0),
                runLineHeights = DoubleArray(0),
                runTabularNumbers = BooleanArray(0),
            )

        manager.setText(view, "")
        view.flushTextDisplayIfNeeded()
        assertEquals("", view.textContentView.text.toString())

        manager.updateExtraData(view, payload)
        assertEquals("", view.textContentView.text.toString())

        measureAndLayout(view, width = 200, height = 50)

        assertEquals("nested text", view.textContentView.text.toString())
    }

    @Test
    fun equivalentNestedPayloadDoesNotRedirtyMountedText() {
        val manager = RNTextEngineTextViewManager()
        val view = RNTextEngineTextViewManager.RNTextEngineTextView(application)
        val dirtyField =
            view.textContentView.javaClass.getDeclaredField("textDisplayDirty").apply {
                isAccessible = true
            }
        val firstPayload =
            RNTextEngineTextShadowNode.RNTextEngineResolvedTextPayload(
                hasNested = true,
                hash = 99L,
                text = "nested text",
                runStarts = intArrayOf(0),
                runEnds = intArrayOf(6),
                runStyleMasks = intArrayOf(1),
                runColors = arrayOf("#ff0000"),
                runFontFamilies = emptyArray(),
                runFontSizes = DoubleArray(0),
                runFontWeights = emptyArray(),
                runFontStyles = emptyArray(),
                runLetterSpacings = DoubleArray(0),
                runLineHeights = DoubleArray(0),
                runTabularNumbers = BooleanArray(0),
            )
        val equivalentPayload =
            RNTextEngineTextShadowNode.RNTextEngineResolvedTextPayload(
                hasNested = true,
                hash = 99L,
                text = "nested text",
                runStarts = intArrayOf(0),
                runEnds = intArrayOf(6),
                runStyleMasks = intArrayOf(1),
                runColors = arrayOf("#ff0000"),
                runFontFamilies = emptyArray(),
                runFontSizes = DoubleArray(0),
                runFontWeights = emptyArray(),
                runFontStyles = emptyArray(),
                runLetterSpacings = DoubleArray(0),
                runLineHeights = DoubleArray(0),
                runTabularNumbers = BooleanArray(0),
            )

        manager.updateExtraData(view, firstPayload)
        measureAndLayout(view, width = 200, height = 50)
        assertFalse(dirtyField.getBoolean(view.textContentView))

        manager.updateExtraData(view, equivalentPayload)

        assertFalse(dirtyField.getBoolean(view.textContentView))
    }

    @Test
    fun nestedPayloadIgnoresMismatchedRunArrays() {
        val manager = RNTextEngineTextViewManager()
        val view = RNTextEngineTextViewManager.RNTextEngineTextView(application)
        val payload =
            RNTextEngineTextShadowNode.RNTextEngineResolvedTextPayload(
                hasNested = true,
                hash = 7L,
                text = "nested text",
                runStarts = intArrayOf(0),
                runEnds = IntArray(0),
                runStyleMasks = intArrayOf(1),
                runColors = arrayOf("#ff0000"),
                runFontFamilies = emptyArray(),
                runFontSizes = DoubleArray(0),
                runFontWeights = emptyArray(),
                runFontStyles = emptyArray(),
                runLetterSpacings = DoubleArray(0),
                runLineHeights = DoubleArray(0),
                runTabularNumbers = BooleanArray(0),
            )

        manager.updateExtraData(view, payload)
        measureAndLayout(view, width = 200, height = 50)

        assertEquals("nested text", view.textContentView.text.toString())
    }

    @Test
    fun shadowPropsUpdateMountedTextPaint() {
        val manager = RNTextEngineTextViewManager()
        val view = RNTextEngineTextViewManager.RNTextEngineTextView(application)
        val offset = JavaOnlyMap.of("width", 2.0, "height", 3.0)

        manager.setTextShadowColor(view, Color.RED)
        manager.setTextShadowOffset(view, offset)
        manager.setTextShadowRadius(view, 4.0)

        assertEquals(Color.RED, view.textContentView.shadowColor)
        assertEquals(PixelUtil.toPixelFromDIP(2f), view.textContentView.shadowDx, 0.001f)
        assertEquals(PixelUtil.toPixelFromDIP(3f), view.textContentView.shadowDy, 0.001f)
        assertEquals(PixelUtil.toPixelFromDIP(4f), view.textContentView.shadowRadius, 0.001f)
    }

    @Test
    fun textDecorationLineTogglesUnderlineAndStrikethrough() {
        val manager = RNTextEngineTextViewManager()
        val view = RNTextEngineTextViewManager.RNTextEngineTextView(application)

        manager.setTextDecorationLine(view, "underline line-through")

        assertTrue(view.textContentView.paintFlags and android.graphics.Paint.UNDERLINE_TEXT_FLAG != 0)
        assertTrue(view.textContentView.paintFlags and android.graphics.Paint.STRIKE_THRU_TEXT_FLAG != 0)

        manager.setTextDecorationLine(view, null)

        assertTrue(view.textContentView.paintFlags and android.graphics.Paint.UNDERLINE_TEXT_FLAG == 0)
        assertTrue(view.textContentView.paintFlags and android.graphics.Paint.STRIKE_THRU_TEXT_FLAG == 0)
    }

    @Test
    fun tabularNumbersUpdateMountedFontFeatures() {
        val manager = RNTextEngineTextViewManager()
        val view = RNTextEngineTextViewManager.RNTextEngineTextView(application)

        manager.setTabularNumbers(view, true)
        view.flushTextDisplayIfNeeded()
        assertEquals("'tnum'", view.textContentView.fontFeatureSettings)

        manager.setTabularNumbers(view, false)
        view.flushTextDisplayIfNeeded()
        assertEquals(null, view.textContentView.fontFeatureSettings)
    }

    @Test
    @Ignore("Mounted AppCompatTextView typography is validated on device and through shared bindings-data tests; Robolectric reports 0px textSize here.")
    fun allowFontScalingResolvesMountedTypographyFromRawValues() {
        val manager = RNTextEngineTextViewManager()
        val view = RNTextEngineTextViewManager.RNTextEngineTextView(application)

        manager.setText(view, "Scale me")
        manager.setFontSize(view, 20.0)
        manager.setLetterSpacing(view, 1.5)
        manager.setLineHeight(view, 24.0)
        manager.setAllowFontScaling(view, false)
        view.flushTextDisplayIfNeeded()
        shadowOf(Looper.getMainLooper()).idle()

        assertEquals(PixelUtil.toPixelFromDIP(20f), view.textContentView.textSize, 0.001f)

        manager.setAllowFontScaling(view, true)
        view.flushTextDisplayIfNeeded()
        shadowOf(Looper.getMainLooper()).idle()

        assertEquals(PixelUtil.toPixelFromSP(20f), view.textContentView.textSize, 0.001f)
    }

    @Test
    fun nestedLetterSpacingCanExplicitlyResetToZero() {
        val parent =
            RNTextEngineResolvedStyleSnapshot(
                allowFontScaling = true,
                colorString = null,
                fontFamily = null,
                fontSize = 14.0,
                fontStyle = null,
                fontWeight = null,
                letterSpacing = 2.0,
                lineHeight = 0.0,
                tabularNumbers = false,
            )

        val resolved =
            resolveTextViewNodeStyle(
                parent = parent,
                input =
                    RNTextEngineNodeStyleInput(
                        hasAllowFontScaling = false,
                        allowFontScaling = true,
                        colorString = null,
                        fontFamily = null,
                        fontSize = 0.0,
                        fontStyle = null,
                        fontWeight = null,
                        hasLetterSpacing = true,
                        letterSpacing = 0.0,
                        lineHeight = 0.0,
                        hasTabularNumbers = false,
                        tabularNumbers = false,
                    ),
            )

        assertEquals(0.0, resolved.letterSpacing, 0.0)
    }

    @Test
    fun nestedTabularNumbersCanExplicitlyResetToFalse() {
        val parent =
            RNTextEngineResolvedStyleSnapshot(
                allowFontScaling = true,
                colorString = null,
                fontFamily = null,
                fontSize = 14.0,
                fontStyle = null,
                fontWeight = null,
                letterSpacing = 0.0,
                lineHeight = 0.0,
                tabularNumbers = true,
            )

        val resolved =
            resolveTextViewNodeStyle(
                parent = parent,
                input =
                    RNTextEngineNodeStyleInput(
                        hasAllowFontScaling = false,
                        allowFontScaling = true,
                        colorString = null,
                        fontFamily = null,
                        fontSize = 0.0,
                        fontStyle = null,
                        fontWeight = null,
                        hasLetterSpacing = false,
                        letterSpacing = 0.0,
                        lineHeight = 0.0,
                        hasTabularNumbers = true,
                        tabularNumbers = false,
                    ),
            )

        assertFalse(resolved.tabularNumbers)
    }

    @Test
    fun nestedAllowFontScalingCanExplicitlyResetToFalse() {
        val parent =
            RNTextEngineResolvedStyleSnapshot(
                allowFontScaling = true,
                colorString = null,
                fontFamily = null,
                fontSize = 14.0,
                fontStyle = null,
                fontWeight = null,
                letterSpacing = 0.0,
                lineHeight = 0.0,
                tabularNumbers = false,
            )

        val resolved =
            resolveTextViewNodeStyle(
                parent = parent,
                input =
                    RNTextEngineNodeStyleInput(
                        hasAllowFontScaling = true,
                        allowFontScaling = false,
                        colorString = null,
                        fontFamily = null,
                        fontSize = 0.0,
                        fontStyle = null,
                        fontWeight = null,
                        hasLetterSpacing = false,
                        letterSpacing = 0.0,
                        lineHeight = 0.0,
                        hasTabularNumbers = false,
                        tabularNumbers = false,
                    ),
            )

        assertFalse(resolved.allowFontScaling)
    }

    @Test
    fun invalidNestedChildThrowsInsteadOfSilentlyDropping() {
        try {
            validateTextViewChildren(
                children = listOf("valid", 42),
                isTextViewChild = { child -> child == "valid" },
                describeChild = { child -> child?.toString() ?: "null" },
            )
            fail("Expected invalid nested child to throw.")
        } catch (error: IllegalStateException) {
            assertTrue(error.message?.contains("must resolve to TextView nodes") == true)
            assertTrue(error.message?.contains("42") == true)
        }
    }

    @Test
    fun validateTextViewChildrenReturnsTrueWhenAllChildrenAreValid() {
        val hasNested =
            validateTextViewChildren(
                children = listOf("alpha", "beta"),
                isTextViewChild = { child -> child is String },
                describeChild = { child -> child?.toString() ?: "null" },
            )

        assertTrue(hasNested)
    }

    private fun measureAndLayout(view: View, width: Int, height: Int) {
        val widthSpec = View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY)
        val heightSpec = View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY)
        view.measure(widthSpec, heightSpec)
        view.layout(0, 0, width, height)
    }
}
