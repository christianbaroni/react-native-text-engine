package com.rntextengine

import android.content.Context
import android.graphics.Color
import android.graphics.Paint
import android.os.Build
import android.text.Layout
import android.text.TextUtils
import android.view.Gravity
import android.view.View
import androidx.appcompat.widget.AppCompatTextView
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.common.mapbuffer.MapBuffer
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.PixelUtil
import com.facebook.react.uimanager.ReactStylesDiffMap
import com.facebook.react.uimanager.StateWrapper
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewGroupManager
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.ViewProps
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.uimanager.common.UIManagerType
import com.facebook.react.uimanager.common.ViewUtil
import com.facebook.react.viewmanagers.RNTextEngineTextViewManagerDelegate
import com.facebook.react.viewmanagers.RNTextEngineTextViewManagerInterface
import kotlin.math.min

@ReactModule(name = RNTextEngineTextViewManager.REACT_CLASS)
internal class RNTextEngineTextViewManager :
    ViewGroupManager<RNTextEngineTextViewManager.RNTextEngineTextView>(),
    RNTextEngineTextViewManagerInterface<RNTextEngineTextViewManager.RNTextEngineTextView> {
    private val delegate: ViewManagerDelegate<RNTextEngineTextView> =
        RNTextEngineTextViewManagerDelegate<RNTextEngineTextView, RNTextEngineTextViewManager>(this)

    override fun getName(): String = REACT_CLASS

    override fun createViewInstance(reactContext: ThemedReactContext): RNTextEngineTextView {
        return RNTextEngineTextView(reactContext)
    }

    override fun createShadowNodeInstance(): RNTextEngineTextShadowNode = RNTextEngineTextShadowNode()

    override fun getShadowNodeClass(): Class<RNTextEngineTextShadowNode> = RNTextEngineTextShadowNode::class.java

    override fun getDelegate(): ViewManagerDelegate<RNTextEngineTextView> = delegate

    override fun updateExtraData(root: RNTextEngineTextView, extraData: Any) {
        val payload = extraData as? RNTextEngineTextShadowNode.RNTextEngineResolvedTextPayload
        if (payload == null || !payload.hasNested) {
            root.applyResolvedNestedPayload(null)
            return
        }

        root.applyResolvedNestedPayload(payload)
    }

    override fun updateState(
        view: RNTextEngineTextView,
        props: ReactStylesDiffMap,
        stateWrapper: StateWrapper,
    ): Any? {
        val state = stateWrapper.stateDataMapBuffer ?: return RNTextEngineTextShadowNode.RNTextEngineResolvedTextPayload.EMPTY
        return parseResolvedPayload(state)
    }

    override fun setBackgroundColor(view: RNTextEngineTextView, backgroundColor: Int) {
        super.setBackgroundColor(view, backgroundColor)
        view.reapplyPaperOpacity()
    }

    override fun setOpacity(view: RNTextEngineTextView, opacity: Float) {
        view.setPaperOpacity(opacity)
    }

    override fun onAfterUpdateTransaction(view: RNTextEngineTextView) {
        super.onAfterUpdateTransaction(view)
        view.flushTextDisplayIfNeeded()
    }

    override fun needsCustomLayoutForChildren(): Boolean = true

    override fun addView(parent: RNTextEngineTextView, child: View, index: Int) {
        parent.addReactChild(child, index)
    }

    override fun getChildCount(parent: RNTextEngineTextView): Int = parent.reactChildCount()

    override fun getChildAt(parent: RNTextEngineTextView, index: Int): View {
        return parent.getReactChildAt(index)
            ?: throw IndexOutOfBoundsException("RNTextEngine: missing React child at index $index.")
    }

    override fun removeViewAt(parent: RNTextEngineTextView, index: Int) {
        parent.removeReactChildAt(index)
    }

    override fun onDropViewInstance(view: RNTextEngineTextView) {
        super.onDropViewInstance(view)
        view.clearReactChildren()
    }

    @ReactProp(name = "text")
    override fun setText(view: RNTextEngineTextView, text: String?) {
        view.setTextValue(text ?: "")
    }

    @ReactProp(name = "color", customType = "Color")
    override fun setColor(view: RNTextEngineTextView, color: Int?) {
        view.textContentView.setTextColor(color ?: view.textContentView.defaultTextColor)
        view.invalidateTextDisplay()
    }

    @ReactProp(name = "fontFamily")
    override fun setFontFamily(view: RNTextEngineTextView, fontFamily: String?) {
        view.textContentView.fontFamily = fontFamily
        view.invalidateTextDisplay()
    }

    @ReactProp(name = "fontSize", defaultFloat = 14f)
    override fun setFontSize(view: RNTextEngineTextView, fontSize: Double) {
        view.textContentView.setFontSizeValue(fontSize.toFloat())
        view.invalidateTextDisplay()
    }

    @ReactProp(name = "allowFontScaling", defaultBoolean = false)
    override fun setAllowFontScaling(view: RNTextEngineTextView, allowFontScaling: Boolean) {
        view.textContentView.setAllowFontScalingEnabled(allowFontScaling)
        view.invalidateTextDisplay()
    }

    @ReactProp(name = "fontStyle")
    override fun setFontStyle(view: RNTextEngineTextView, fontStyle: String?) {
        view.textContentView.fontStyle = fontStyle
        view.invalidateTextDisplay()
    }

    @ReactProp(name = "fontWeight")
    override fun setFontWeight(view: RNTextEngineTextView, fontWeight: String?) {
        view.textContentView.fontWeight = fontWeight
        view.invalidateTextDisplay()
    }

    @ReactProp(name = "letterSpacing", defaultFloat = 0f)
    override fun setLetterSpacing(view: RNTextEngineTextView, letterSpacing: Double) {
        view.textContentView.setLetterSpacingValue(letterSpacing.toFloat())
        view.invalidateTextDisplay()
    }

    @ReactProp(name = "rnteHasAllowFontScaling", defaultBoolean = false)
    override fun setRnteHasAllowFontScaling(view: RNTextEngineTextView, value: Boolean) = Unit

    @ReactProp(name = "rnteHasLetterSpacing", defaultBoolean = false)
    override fun setRnteHasLetterSpacing(view: RNTextEngineTextView, value: Boolean) = Unit

    @ReactProp(name = "lineHeight")
    override fun setLineHeight(view: RNTextEngineTextView, lineHeight: Double) {
        view.textContentView.setLineHeightValue(
            if (lineHeight.isNaN()) {
                Float.NaN
            } else {
                lineHeight.toFloat()
            },
        )
        view.invalidateTextDisplay()
    }

    @ReactProp(name = "tabularNumbers", defaultBoolean = false)
    override fun setTabularNumbers(view: RNTextEngineTextView, tabularNumbers: Boolean) {
        view.textContentView.setTabularNumbersEnabled(tabularNumbers)
        view.invalidateTextDisplay()
    }

    @ReactProp(name = "rnteHasTabularNumbers", defaultBoolean = false)
    override fun setRnteHasTabularNumbers(view: RNTextEngineTextView, value: Boolean) = Unit

    @ReactProp(name = "rnteIsVirtualTextSpan", defaultBoolean = false)
    override fun setRnteIsVirtualTextSpan(view: RNTextEngineTextView, value: Boolean) = Unit

    @ReactProp(name = "textDecorationLine")
    override fun setTextDecorationLine(view: RNTextEngineTextView, textDecorationLine: String?) {
        view.setTextDecorationLineValue(textDecorationLine)
    }

    @ReactProp(name = "textDecorationColor", customType = "Color")
    override fun setTextDecorationColor(view: RNTextEngineTextView, textDecorationColor: Int?) = Unit

    @ReactProp(name = "textDecorationStyle")
    override fun setTextDecorationStyle(view: RNTextEngineTextView, textDecorationStyle: String?) = Unit

    @ReactProp(name = ViewProps.NUMBER_OF_LINES, defaultInt = 0)
    override fun setNumberOfLines(view: RNTextEngineTextView, numberOfLines: Int) {
        view.setNumberOfLines(numberOfLines)
    }

    @ReactProp(name = "selectable", defaultBoolean = false)
    override fun setSelectable(view: RNTextEngineTextView, selectable: Boolean) {
        view.setSelectable(selectable)
    }

    @ReactProp(name = "anchorToCapHeight", defaultBoolean = false)
    override fun setAnchorToCapHeight(view: RNTextEngineTextView, anchorToCapHeight: Boolean) {
        view.anchorToCapHeight = anchorToCapHeight
    }

    @ReactProp(name = "ellipsizeMode")
    override fun setEllipsizeMode(view: RNTextEngineTextView, ellipsizeMode: String?) {
        view.setEllipsizeMode(ellipsizeMode)
    }

    @ReactProp(name = "runs")
    fun setRuns(view: RNTextEngineTextView, runs: ReadableArray?) {
        view.textContentView.runs = parseRuns(runs)
        view.invalidateTextDisplay()
    }

    @ReactProp(name = "runStarts")
    override fun setRunStarts(view: RNTextEngineTextView, runStarts: ReadableArray?) {
        view.textContentView.runStarts = runStarts
        view.invalidateTextDisplay()
    }

    @ReactProp(name = "runEnds")
    override fun setRunEnds(view: RNTextEngineTextView, runEnds: ReadableArray?) {
        view.textContentView.runEnds = runEnds
        view.invalidateTextDisplay()
    }

    @ReactProp(name = "runStyleMasks")
    override fun setRunStyleMasks(view: RNTextEngineTextView, runStyleMasks: ReadableArray?) {
        view.textContentView.runStyleMasks = runStyleMasks
        view.invalidateTextDisplay()
    }

    @ReactProp(name = "runColors")
    override fun setRunColors(view: RNTextEngineTextView, runColors: ReadableArray?) {
        view.textContentView.runColors = runColors
        view.invalidateTextDisplay()
    }

    @ReactProp(name = "runCount", defaultInt = 0)
    override fun setRunCount(view: RNTextEngineTextView, runCount: Int) {
        view.textContentView.runCount = runCount
        view.invalidateTextDisplay()
    }

    @ReactProp(name = "runFontFamilies")
    override fun setRunFontFamilies(view: RNTextEngineTextView, runFontFamilies: ReadableArray?) {
        view.textContentView.runFontFamilies = runFontFamilies
        view.invalidateTextDisplay()
    }

    @ReactProp(name = "runFontSizes")
    override fun setRunFontSizes(view: RNTextEngineTextView, runFontSizes: ReadableArray?) {
        view.textContentView.runFontSizes = runFontSizes
        view.invalidateTextDisplay()
    }

    @ReactProp(name = "runFontWeights")
    override fun setRunFontWeights(view: RNTextEngineTextView, runFontWeights: ReadableArray?) {
        view.textContentView.runFontWeights = runFontWeights
        view.invalidateTextDisplay()
    }

    @ReactProp(name = "runFontStyles")
    override fun setRunFontStyles(view: RNTextEngineTextView, runFontStyles: ReadableArray?) {
        view.textContentView.runFontStyles = runFontStyles
        view.invalidateTextDisplay()
    }

    @ReactProp(name = "runLetterSpacings")
    override fun setRunLetterSpacings(view: RNTextEngineTextView, runLetterSpacings: ReadableArray?) {
        view.textContentView.runLetterSpacings = runLetterSpacings
        view.invalidateTextDisplay()
    }

    @ReactProp(name = "runLineHeights")
    override fun setRunLineHeights(view: RNTextEngineTextView, runLineHeights: ReadableArray?) {
        view.textContentView.runLineHeights = runLineHeights
        view.invalidateTextDisplay()
    }

    @ReactProp(name = "runTabularNumbers")
    override fun setRunTabularNumbers(view: RNTextEngineTextView, runTabularNumbers: ReadableArray?) {
        view.textContentView.runTabularNumbers = runTabularNumbers
        view.invalidateTextDisplay()
    }

    @Suppress("WrongConstant")
    @ReactProp(name = ViewProps.TEXT_ALIGN)
    override fun setTextAlign(view: RNTextEngineTextView, textAlign: String?) {
        view.setTextAlignValue(textAlign)
    }

    @ReactProp(name = "textShadowColor", customType = "Color")
    override fun setTextShadowColor(view: RNTextEngineTextView, textShadowColor: Int?) {
        view.setTextShadowColorValue(textShadowColor)
    }

    @ReactProp(name = "textShadowOffset")
    override fun setTextShadowOffset(view: RNTextEngineTextView, textShadowOffset: ReadableMap?) {
        val widthPx =
            if (textShadowOffset?.hasKey("width") == true && !textShadowOffset.isNull("width")) {
                PixelUtil.toPixelFromDIP(textShadowOffset.getDouble("width").toFloat())
            } else {
                0f
            }
        val heightPx =
            if (textShadowOffset?.hasKey("height") == true && !textShadowOffset.isNull("height")) {
                PixelUtil.toPixelFromDIP(textShadowOffset.getDouble("height").toFloat())
            } else {
                0f
            }

        view.setTextShadowOffsetPx(widthPx, heightPx)
    }

    @ReactProp(name = "textShadowRadius", defaultFloat = 0f)
    override fun setTextShadowRadius(view: RNTextEngineTextView, textShadowRadius: Double) {
        view.setTextShadowRadiusPx(PixelUtil.toPixelFromDIP(textShadowRadius.toFloat()))
    }

    @ReactProp(name = "textTransform")
    override fun setTextTransform(view: RNTextEngineTextView, textTransform: String?) {
        view.textContentView.setTextTransformValue(textTransform)
        view.invalidateTextDisplay()
    }

    override fun setPadding(view: RNTextEngineTextView, left: Int, top: Int, right: Int, bottom: Int) {
        view.setContentPadding(left, top, right, bottom)
    }

    internal class RNTextEngineTextView(context: Context) : RNTextEngineCapAnchoredContainer(context) {
        private val attributedDisplayView = RNTextEngineAttributedTextDisplayView(context)
        val textContentView = RNTextEngineTextContentView(context)
        val displayView: RNTextEngineAttributedTextDisplayView
            get() = attributedDisplayView
        private var currentPreparedText: RNTextEngineBindings.PreparedTextViewData? = null
        private val reactChildren = ArrayList<View>()

        override val opacityTargetView: View
            get() = if (textContentView.parent === this) textContentView else attributedDisplayView

        override fun measureAnchoredContent(width: Int, height: Int) {
            val widthSpec = View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY)
            val heightSpec = View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY)
            attributedDisplayView.measure(widthSpec, heightSpec)
            if (textContentView.parent === this) {
                textContentView.measure(widthSpec, heightSpec)
            }
        }

        override fun prepareAnchoredContentForLayout() {
            flushTextDisplayIfNeeded()
        }

        override fun resolveCapHeightInsets(width: Int): RNTextEngineCapHeightInsetsPx {
            return attributedDisplayView.resolveCapHeightInsets(width)
        }

        override fun applyAnchoredContentFrame(left: Int, top: Int, right: Int, bottom: Int, translationY: Float) {
            attributedDisplayView.layout(left, top, right, bottom)
            attributedDisplayView.translationY = translationY
            if (textContentView.parent === this) {
                textContentView.layout(left, top, right, bottom)
                textContentView.translationY = translationY
            }
        }

        init {
            super.addView(
                attributedDisplayView,
                LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT),
            )
        }

        fun setTextValue(value: String) {
            if (textContentView.textValue == value) return
            textContentView.textValue = value
            invalidateTextDisplay()
            syncPaperLocalDataIfNeeded(value)
        }

        fun addReactChild(child: View, index: Int) {
            val insertionIndex = index.coerceIn(0, reactChildren.size)
            reactChildren.add(insertionIndex, child)
        }

        fun reactChildCount(): Int = reactChildren.size

        fun getReactChildAt(index: Int): View? = reactChildren.getOrNull(index)

        fun removeReactChildAt(index: Int) {
            if (index in 0 until reactChildren.size) {
                reactChildren.removeAt(index)
            }
        }

        fun clearReactChildren() {
            reactChildren.clear()
        }

        fun flushTextDisplayIfNeeded() {
            currentPreparedText = textContentView.flushPreparedTextIfNeeded(currentPreparedText)
            textContentView.setPreparedData(currentPreparedText)
            attributedDisplayView.setPreparedText(currentPreparedText)
        }

        fun invalidateTextDisplay() {
            textContentView.invalidateTextDisplay()
            requestCapAnchorLayout()
        }

        fun applyResolvedNestedPayload(payload: RNTextEngineTextShadowNode.RNTextEngineResolvedTextPayload?) {
            textContentView.setResolvedNestedPayload(payload)
            invalidateTextDisplay()
        }

        fun setNumberOfLines(numberOfLines: Int) {
            textContentView.maxLines = if (numberOfLines > 0) numberOfLines else Int.MAX_VALUE
            textContentView.setSingleLine(false)
            attributedDisplayView.numberOfLines = numberOfLines
            requestCapAnchorLayout()
        }

        fun setSelectable(value: Boolean) {
            flushTextDisplayIfNeeded()
            textContentView.setTextIsSelectable(value)
            textContentView.isFocusable = value
            textContentView.isFocusableInTouchMode = value
            textContentView.isClickable = value
            textContentView.isLongClickable = value
            syncInteractionTextView(value)
            reapplyPaperOpacity()
            requestCapAnchorLayout()
        }

        fun setEllipsizeMode(mode: String?) {
            textContentView.ellipsize =
                when (mode) {
                    "head" -> TextUtils.TruncateAt.START
                    "middle" -> TextUtils.TruncateAt.MIDDLE
                    "tail" -> TextUtils.TruncateAt.END
                    else -> null
                }
            attributedDisplayView.ellipsizeMode = mode
            requestCapAnchorLayout()
        }

        @Suppress("WrongConstant")
        fun setTextAlignValue(value: String?) {
            val horizontalGravity =
                when (value) {
                    null, "auto" -> Gravity.NO_GRAVITY
                    "left" -> Gravity.LEFT
                    "right" -> Gravity.RIGHT
                    "center" -> Gravity.CENTER_HORIZONTAL
                    "justify" -> Gravity.LEFT
                    else -> Gravity.NO_GRAVITY
                }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                textContentView.justificationMode =
                    if (value == "justify") Layout.JUSTIFICATION_MODE_INTER_WORD else Layout.JUSTIFICATION_MODE_NONE
            }

            val verticalGravity = textContentView.gravity and Gravity.VERTICAL_GRAVITY_MASK
            textContentView.gravity = horizontalGravity or verticalGravity
            attributedDisplayView.setTextAlignValue(value)
            requestCapAnchorLayout()
        }

        fun setTextDecorationLineValue(value: String?) {
            textContentView.setTextDecorationLineValue(value)
            attributedDisplayView.setTextDecorationLineValue(value)
        }

        fun setTextShadowColorValue(value: Int?) {
            textContentView.setTextShadowColorValue(value)
            attributedDisplayView.setTextShadowColorValue(value)
        }

        fun setTextShadowOffsetPx(widthPx: Float, heightPx: Float) {
            textContentView.setTextShadowOffsetPx(widthPx, heightPx)
            attributedDisplayView.setTextShadowOffsetPx(widthPx, heightPx)
        }

        fun setTextShadowRadiusPx(value: Float) {
            textContentView.setTextShadowRadiusPx(value)
            attributedDisplayView.setTextShadowRadiusPx(value)
        }

        fun setContentPadding(left: Int, top: Int, right: Int, bottom: Int) {
            textContentView.setPadding(left, top, right, bottom)
            attributedDisplayView.setPadding(left, top, right, bottom)
            requestCapAnchorLayout()
        }

        @Suppress("DEPRECATION")
        private fun syncPaperLocalDataIfNeeded(text: String) {
            if (id == View.NO_ID || ViewUtil.getUIManagerType(this) == UIManagerType.FABRIC) return
            (context as? ThemedReactContext)
                ?.getNativeModule(com.facebook.react.uimanager.UIManagerModule::class.java)
                ?.setViewLocalData(id, RNTextEngineTextLocalData(text))
        }

        private fun syncInteractionTextView(selectable: Boolean) {
            if (selectable) {
                if (textContentView.parent !== this) {
                    super.addView(
                        textContentView,
                        LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT),
                    )
                }
                textContentView.setPreparedData(currentPreparedText)
                attributedDisplayView.visibility = View.INVISIBLE
                return
            }

            if (textContentView.parent === this) {
                super.removeView(textContentView)
            }
            attributedDisplayView.visibility = View.VISIBLE
        }
    }

    internal class RNTextEngineTextContentView(context: Context) : AppCompatTextView(context) {
        var fontFamily: String? = null
        var fontStyle: String? = null
        var fontWeight: String? = null
        val defaultTextColor: Int = currentTextColor
        var runs: List<RNTextEngineTextRun> = emptyList()
        var runColors: ReadableArray? = null
        var runCount: Int = 0
        var runEnds: ReadableArray? = null
        var runFontFamilies: ReadableArray? = null
        var runFontSizes: ReadableArray? = null
        var runFontStyles: ReadableArray? = null
        var runFontWeights: ReadableArray? = null
        var runLetterSpacings: ReadableArray? = null
        var runLineHeights: ReadableArray? = null
        var runStarts: ReadableArray? = null
        var runStyleMasks: ReadableArray? = null
        var runTabularNumbers: ReadableArray? = null
        var textValue: String = ""
        private var baseCapHeightPx = 0f
        private var textDisplayDirty = true
        private var allowFontScaling = false
        private var fontSizeValue = 14f
        private var letterSpacingValue = 0f
        private var lineHeightValue = Float.NaN
        private var tabularNumbers = false
        private var textTransform: String? = null
        private var textDecorationLine: String? = null
        private var textShadowColor: Int? = null
        private var textShadowOffsetHeightPx = 0f
        private var textShadowOffsetWidthPx = 0f
        private var textShadowRadiusPx = 0f
        private var uniformCapHeightPx: Float? = 0f
        private var resolvedNestedPayload: RNTextEngineTextShadowNode.RNTextEngineResolvedTextPayload? = null

        init {
            includeFontPadding = false
            isFocusable = false
            isClickable = false
            setBackgroundColor(Color.TRANSPARENT)
            setLineSpacing(0f, 1f)
            applyTextViewLineBreakConfig(this, Layout.BREAK_STRATEGY_HIGH_QUALITY, Layout.HYPHENATION_FREQUENCY_NORMAL)
        }

        fun setFontSizeValue(value: Float) {
            if (fontSizeValue == value) return
            fontSizeValue = value
        }

        fun setAllowFontScalingEnabled(value: Boolean) {
            if (allowFontScaling == value) return
            allowFontScaling = value
        }

        fun setLetterSpacingValue(value: Float) {
            if (letterSpacingValue == value) return
            letterSpacingValue = value
        }

        fun setLineHeightValue(value: Float) {
            if (lineHeightValue == value) return
            lineHeightValue = value
        }

        fun setTextShadowColorValue(value: Int?) {
            textShadowColor = value
            updateTextShadow()
        }

        fun setTextShadowOffsetPx(widthPx: Float, heightPx: Float) {
            textShadowOffsetHeightPx = heightPx
            textShadowOffsetWidthPx = widthPx
            updateTextShadow()
        }

        fun setTextShadowRadiusPx(value: Float) {
            textShadowRadiusPx = value
            updateTextShadow()
        }

        fun setTabularNumbersEnabled(value: Boolean) {
            if (tabularNumbers == value) return
            tabularNumbers = value
        }

        fun setTextDecorationLineValue(value: String?) {
            if (textDecorationLine == value) return
            textDecorationLine = value
            updateTextDecorationFlags()
        }

        fun setTextTransformValue(value: String?) {
            if (textTransform == value) return
            textTransform = value
        }

        fun setResolvedNestedPayload(payload: RNTextEngineTextShadowNode.RNTextEngineResolvedTextPayload?) {
            val nextPayload = payload?.takeIf { it.hasNested }
            val currentPayload = resolvedNestedPayload?.takeIf { it.hasNested }
            if (
                currentPayload === nextPayload ||
                (currentPayload != null &&
                    nextPayload != null &&
                    currentPayload.hash == nextPayload.hash &&
                    currentPayload.text == nextPayload.text)
            ) {
                return
            }

            if (currentPayload == null && nextPayload == null) return

            resolvedNestedPayload = nextPayload
            invalidateTextDisplay()
        }

        private fun updateTextDecorationFlags() {
            var flags = paintFlags and Paint.UNDERLINE_TEXT_FLAG.inv() and Paint.STRIKE_THRU_TEXT_FLAG.inv()
            textDecorationLine?.split(" ")?.forEach { decoration ->
                when (decoration) {
                    "underline" -> flags = flags or Paint.UNDERLINE_TEXT_FLAG
                    "line-through" -> flags = flags or Paint.STRIKE_THRU_TEXT_FLAG
                }
            }
            paintFlags = flags
        }

        private fun updateTextShadow() {
            val resolvedColor = textShadowColor ?: Color.TRANSPARENT
            setShadowLayer(textShadowRadiusPx, textShadowOffsetWidthPx, textShadowOffsetHeightPx, resolvedColor)
        }

        fun setPreparedData(prepared: RNTextEngineBindings.PreparedTextViewData?) {
            val applied =
                applyPreparedTextViewData(
                    textView = this,
                    prepared = prepared,
                    defaultTextColor = defaultTextColor,
                )
            baseCapHeightPx = applied.baseCapHeightPx
            uniformCapHeightPx = applied.uniformCapHeightPx
            updateTextDecorationFlags()
            updateTextShadow()
        }

        private fun buildRunsFromResolvedPayload(
            payload: RNTextEngineTextShadowNode.RNTextEngineResolvedTextPayload
        ): List<RNTextEngineTextRun> {
            if (payload.runStarts.isEmpty() || payload.runEnds.isEmpty() || payload.runStyleMasks.isEmpty()) return emptyList()

            val runCount = minOf(payload.runStarts.size, payload.runEnds.size, payload.runStyleMasks.size)
            val resolvedRuns = ArrayList<RNTextEngineTextRun>(runCount)
            var previousEnd = 0

            for (index in 0 until runCount) {
                val start = payload.runStarts[index]
                val end = payload.runEnds[index]
                val styleMask = payload.runStyleMasks[index]
                if (styleMask == 0 || start < previousEnd || start < 0 || end <= start) continue

                val style =
                    RNTextEngineTextRunStyle(
                        color = payload.runColors.getOrNull(index),
                        fontFamily = payload.runFontFamilies.getOrNull(index),
                        fontSize = payload.runFontSizes.getOrNull(index) ?: 0.0,
                        fontStyle = payload.runFontStyles.getOrNull(index),
                        fontWeight = payload.runFontWeights.getOrNull(index),
                        hasColor = styleMask and RUN_STYLE_HAS_COLOR != 0,
                        hasFontFamily = styleMask and RUN_STYLE_HAS_FONT_FAMILY != 0,
                        hasFontSize = styleMask and RUN_STYLE_HAS_FONT_SIZE != 0,
                        hasFontStyle = styleMask and RUN_STYLE_HAS_FONT_STYLE != 0,
                        hasFontWeight = styleMask and RUN_STYLE_HAS_FONT_WEIGHT != 0,
                        hasLetterSpacing = styleMask and RUN_STYLE_HAS_LETTER_SPACING != 0,
                        hasLineHeight = styleMask and RUN_STYLE_HAS_LINE_HEIGHT != 0,
                        hasTabularNumbers = styleMask and RUN_STYLE_HAS_TABULAR_NUMBERS != 0,
                        letterSpacing = payload.runLetterSpacings.getOrNull(index) ?: 0.0,
                        lineHeight = payload.runLineHeights.getOrNull(index) ?: 0.0,
                        tabularNumbers = payload.runTabularNumbers.getOrNull(index) ?: false,
                    )

                resolvedRuns.add(RNTextEngineTextRun(end = end, start = start, style = style))
                previousEnd = end
            }

            return resolvedRuns
        }

        private fun buildDisplayData(): RNTextEngineBindings.PreparedTextViewData {
            val nestedPayload = resolvedNestedPayload
            return if (nestedPayload != null) {
                RNTextEngineBindings.buildTextViewDisplayData(
                    text = nestedPayload.text,
                    textTransform = null,
                    color = currentTextColor,
                    fontFamily = fontFamily,
                    fontSize = resolvePreparedTypographyValue(fontSizeValue),
                    fontWeight = fontWeight,
                    fontStyle = fontStyle,
                    letterSpacing = resolvePreparedTypographyValue(letterSpacingValue),
                    lineHeight = resolvePreparedLineHeightValue(),
                    allowFontScaling = false,
                    tabularNumbers = tabularNumbers,
                    textBreakStrategy = null,
                    runs = buildRunsFromResolvedPayload(nestedPayload),
                )
            } else {
                val animatedRuns = resolveAnimatedRuns()
                val activeRuns = if (animatedRuns.isNotEmpty()) animatedRuns else runs
                RNTextEngineBindings.buildTextViewDisplayData(
                    text = textValue,
                    textTransform = textTransform,
                    color = currentTextColor,
                    fontFamily = fontFamily,
                    fontSize = fontSizeValue.toDouble(),
                    fontWeight = fontWeight,
                    fontStyle = fontStyle,
                    letterSpacing = letterSpacingValue.toDouble(),
                    lineHeight = if (lineHeightValue.isNaN()) Double.NaN else lineHeightValue.toDouble(),
                    allowFontScaling = allowFontScaling,
                    tabularNumbers = tabularNumbers,
                    textBreakStrategy = null,
                    runs = activeRuns,
                )
            }
        }

        private fun resolvePreparedLineHeightValue(): Double {
            return if (lineHeightValue.isNaN()) {
                Double.NaN
            } else {
                resolvePreparedTypographyValue(lineHeightValue)
            }
        }

        private fun resolvePreparedTypographyValue(value: Float): Double {
            return if (allowFontScaling) {
                value * RNTextEngineBindings.currentFontScaleMultiplier()
            } else {
                value.toDouble()
            }
        }

        fun flushPreparedTextIfNeeded(currentPreparedText: RNTextEngineBindings.PreparedTextViewData?): RNTextEngineBindings.PreparedTextViewData? {
            if (!textDisplayDirty) return currentPreparedText
            textDisplayDirty = false
            return buildDisplayData()
        }

        fun invalidateTextDisplay() {
            textDisplayDirty = true
        }

        fun resolveCapHeightInsets(width: Int): RNTextEngineCapHeightInsetsPx {
            return resolveCapHeightInsetsPx(
                layout = buildLayoutForTextView(this, width),
                text = text ?: "",
                defaultCapHeightPx = baseCapHeightPx,
                uniformCapHeightPx = uniformCapHeightPx,
            )
        }

        fun resolveLayout(width: Int): Layout? = buildLayoutForTextView(this, width)

        private fun resolveAnimatedRuns(): List<RNTextEngineTextRun> {
            val starts = runStarts ?: return emptyList()
            val ends = runEnds ?: return emptyList()
            val styleMasks = runStyleMasks ?: return emptyList()
            val resolvedRunCount =
                if (runCount > 0) {
                    min(runCount, minOf(starts.size(), ends.size(), styleMasks.size()))
                } else {
                    minOf(starts.size(), ends.size(), styleMasks.size())
                }
            if (resolvedRunCount == 0) return emptyList()

            val resolvedRuns = ArrayList<RNTextEngineTextRun>(resolvedRunCount)
            var previousEnd = 0

            for (index in 0 until resolvedRunCount) {
                if (starts.isNull(index) || ends.isNull(index) || styleMasks.isNull(index)) continue

                val start = starts.getInt(index)
                val end = ends.getInt(index)
                val styleMask = styleMasks.getInt(index)
                if (styleMask == 0 || start < previousEnd || start < 0 || end <= start) continue

                val style =
                    RNTextEngineTextRunStyle(
                        color = if (styleMask and RUN_STYLE_HAS_COLOR != 0 && index < (runColors?.size() ?: 0)) runColors?.getString(index) else null,
                        fontFamily = if (styleMask and RUN_STYLE_HAS_FONT_FAMILY != 0 && index < (runFontFamilies?.size() ?: 0)) runFontFamilies?.getString(index) else null,
                        fontSize = if (styleMask and RUN_STYLE_HAS_FONT_SIZE != 0 && index < (runFontSizes?.size() ?: 0)) runFontSizes?.getDouble(index) ?: 0.0 else 0.0,
                        fontStyle = if (styleMask and RUN_STYLE_HAS_FONT_STYLE != 0 && index < (runFontStyles?.size() ?: 0)) runFontStyles?.getString(index) else null,
                        fontWeight = if (styleMask and RUN_STYLE_HAS_FONT_WEIGHT != 0 && index < (runFontWeights?.size() ?: 0)) runFontWeights?.getString(index) else null,
                        hasColor = styleMask and RUN_STYLE_HAS_COLOR != 0,
                        hasFontFamily = styleMask and RUN_STYLE_HAS_FONT_FAMILY != 0,
                        hasFontSize = styleMask and RUN_STYLE_HAS_FONT_SIZE != 0,
                        hasFontStyle = styleMask and RUN_STYLE_HAS_FONT_STYLE != 0,
                        hasFontWeight = styleMask and RUN_STYLE_HAS_FONT_WEIGHT != 0,
                        hasLetterSpacing = styleMask and RUN_STYLE_HAS_LETTER_SPACING != 0,
                        hasLineHeight = styleMask and RUN_STYLE_HAS_LINE_HEIGHT != 0,
                        hasTabularNumbers = styleMask and RUN_STYLE_HAS_TABULAR_NUMBERS != 0,
                        letterSpacing = if (styleMask and RUN_STYLE_HAS_LETTER_SPACING != 0 && index < (runLetterSpacings?.size() ?: 0)) runLetterSpacings?.getDouble(index) ?: 0.0 else 0.0,
                        lineHeight = if (styleMask and RUN_STYLE_HAS_LINE_HEIGHT != 0 && index < (runLineHeights?.size() ?: 0)) runLineHeights?.getDouble(index) ?: 0.0 else 0.0,
                        tabularNumbers = styleMask and RUN_STYLE_HAS_TABULAR_NUMBERS != 0 && index < (runTabularNumbers?.size() ?: 0) && (runTabularNumbers?.getBoolean(index) ?: false),
                    )

                resolvedRuns.add(RNTextEngineTextRun(end = end, start = start, style = style))
                previousEnd = end
            }

            return resolvedRuns
        }
    }

    private fun parseRuns(runs: ReadableArray?): List<RNTextEngineTextRun> {
        if (runs == null) return emptyList()

        val resolvedRuns = ArrayList<RNTextEngineTextRun>(runs.size())
        var previousEnd = 0

        for (index in 0 until runs.size()) {
            val run = runs.getMap(index) ?: continue
            val start = if (run.hasKey("start") && !run.isNull("start")) run.getInt("start") else continue
            val end = if (run.hasKey("end") && !run.isNull("end")) run.getInt("end") else continue
            val styleMap = run.getMap("style") ?: continue
            if (start < previousEnd || start < 0 || end <= start) continue

            val style = parseRunStyle(styleMap)
            if (!hasAnyOverride(style)) continue

            resolvedRuns.add(RNTextEngineTextRun(end = end, start = start, style = style))
            previousEnd = end
        }

        return resolvedRuns
    }

    private fun parseRunStyle(style: ReadableMap): RNTextEngineTextRunStyle {
        return RNTextEngineTextRunStyle(
            color = style.getString("color"),
            fontFamily = style.getString("fontFamily"),
            fontSize = if (style.hasKey("fontSize") && !style.isNull("fontSize")) style.getDouble("fontSize") else 0.0,
            fontStyle = style.getString("fontStyle"),
            fontWeight = style.getString("fontWeight"),
            hasColor = style.hasKey("color") && !style.isNull("color"),
            hasFontFamily = style.hasKey("fontFamily") && !style.isNull("fontFamily"),
            hasFontSize = style.hasKey("fontSize") && !style.isNull("fontSize"),
            hasFontStyle = style.hasKey("fontStyle") && !style.isNull("fontStyle"),
            hasFontWeight = style.hasKey("fontWeight") && !style.isNull("fontWeight"),
            hasLetterSpacing = style.hasKey("letterSpacing") && !style.isNull("letterSpacing"),
            hasLineHeight = style.hasKey("lineHeight") && !style.isNull("lineHeight"),
            hasTabularNumbers = style.hasKey("tabularNumbers") && !style.isNull("tabularNumbers"),
            letterSpacing = if (style.hasKey("letterSpacing") && !style.isNull("letterSpacing")) style.getDouble("letterSpacing") else 0.0,
            lineHeight = if (style.hasKey("lineHeight") && !style.isNull("lineHeight")) style.getDouble("lineHeight") else 0.0,
            tabularNumbers = style.hasKey("tabularNumbers") && !style.isNull("tabularNumbers") && style.getBoolean("tabularNumbers"),
        )
    }

    private fun hasAnyOverride(style: RNTextEngineTextRunStyle): Boolean {
        return style.hasColor || style.hasFontFamily || style.hasFontSize || style.hasFontStyle || style.hasFontWeight || style.hasLetterSpacing || style.hasLineHeight || style.hasTabularNumbers
    }

    private fun parseResolvedPayload(state: MapBuffer): RNTextEngineTextShadowNode.RNTextEngineResolvedTextPayload {
        val hasNested = state.contains(STATE_HAS_NESTED_KEY) && state.getBoolean(STATE_HAS_NESTED_KEY)
        if (!hasNested) return RNTextEngineTextShadowNode.RNTextEngineResolvedTextPayload.EMPTY

        return RNTextEngineTextShadowNode.RNTextEngineResolvedTextPayload(
            hasNested = true,
            hash = if (state.contains(STATE_HASH_KEY)) state.getLong(STATE_HASH_KEY) else 0L,
            text = if (state.contains(STATE_TEXT_KEY)) state.getString(STATE_TEXT_KEY) else "",
            runStarts = parseIntArray(state, STATE_RUN_STARTS_KEY),
            runEnds = parseIntArray(state, STATE_RUN_ENDS_KEY),
            runStyleMasks = parseIntArray(state, STATE_RUN_STYLE_MASKS_KEY),
            runColors = parseNullableStringArray(state, STATE_RUN_COLORS_KEY),
            runFontFamilies = parseNullableStringArray(state, STATE_RUN_FONT_FAMILIES_KEY),
            runFontSizes = parseDoubleArray(state, STATE_RUN_FONT_SIZES_KEY),
            runFontWeights = parseNullableStringArray(state, STATE_RUN_FONT_WEIGHTS_KEY),
            runFontStyles = parseNullableStringArray(state, STATE_RUN_FONT_STYLES_KEY),
            runLetterSpacings = parseDoubleArray(state, STATE_RUN_LETTER_SPACINGS_KEY),
            runLineHeights = parseDoubleArray(state, STATE_RUN_LINE_HEIGHTS_KEY),
            runTabularNumbers = parseBooleanArray(state, STATE_RUN_TABULAR_NUMBERS_KEY),
        )
    }

    private fun parseIntArray(state: MapBuffer, key: Int): IntArray {
        if (!state.contains(key)) return IntArray(0)
        val map = state.getMapBuffer(key)
        val count = if (map.contains(STATE_ARRAY_LENGTH_KEY)) map.getInt(STATE_ARRAY_LENGTH_KEY).coerceAtLeast(0) else 0
        return IntArray(count) { index ->
            val valueKey = index + 1
            if (map.contains(valueKey)) map.getInt(valueKey) else 0
        }
    }

    private fun parseDoubleArray(state: MapBuffer, key: Int): DoubleArray {
        if (!state.contains(key)) return DoubleArray(0)
        val map = state.getMapBuffer(key)
        val count = if (map.contains(STATE_ARRAY_LENGTH_KEY)) map.getInt(STATE_ARRAY_LENGTH_KEY).coerceAtLeast(0) else 0
        return DoubleArray(count) { index ->
            val valueKey = index + 1
            if (map.contains(valueKey)) map.getDouble(valueKey) else 0.0
        }
    }

    private fun parseBooleanArray(state: MapBuffer, key: Int): BooleanArray {
        if (!state.contains(key)) return BooleanArray(0)
        val map = state.getMapBuffer(key)
        val count = if (map.contains(STATE_ARRAY_LENGTH_KEY)) map.getInt(STATE_ARRAY_LENGTH_KEY).coerceAtLeast(0) else 0
        return BooleanArray(count) { index ->
            val valueKey = index + 1
            map.contains(valueKey) && map.getBoolean(valueKey)
        }
    }

    private fun parseNullableStringArray(state: MapBuffer, key: Int): Array<String?> {
        if (!state.contains(key)) return emptyArray()
        val map = state.getMapBuffer(key)
        val count = if (map.contains(STATE_ARRAY_LENGTH_KEY)) map.getInt(STATE_ARRAY_LENGTH_KEY).coerceAtLeast(0) else 0
        return Array(count) { index ->
            val valueKey = index + 1
            if (!map.contains(valueKey)) return@Array null
            val value = map.getString(valueKey)
            if (value.isEmpty()) null else value
        }
    }

    companion object {
        const val REACT_CLASS = "RNTextEngineTextView"
        private const val RUN_STYLE_HAS_COLOR = 1 shl 0
        private const val RUN_STYLE_HAS_FONT_FAMILY = 1 shl 1
        private const val RUN_STYLE_HAS_FONT_SIZE = 1 shl 2
        private const val RUN_STYLE_HAS_FONT_STYLE = 1 shl 3
        private const val RUN_STYLE_HAS_FONT_WEIGHT = 1 shl 4
        private const val RUN_STYLE_HAS_LETTER_SPACING = 1 shl 5
        private const val RUN_STYLE_HAS_LINE_HEIGHT = 1 shl 6
        private const val RUN_STYLE_HAS_TABULAR_NUMBERS = 1 shl 7

        private const val STATE_HAS_NESTED_KEY = 1
        private const val STATE_HASH_KEY = 2
        private const val STATE_TEXT_KEY = 3
        private const val STATE_RUN_STARTS_KEY = 4
        private const val STATE_RUN_ENDS_KEY = 5
        private const val STATE_RUN_STYLE_MASKS_KEY = 6
        private const val STATE_RUN_COLORS_KEY = 7
        private const val STATE_RUN_FONT_FAMILIES_KEY = 8
        private const val STATE_RUN_FONT_SIZES_KEY = 9
        private const val STATE_RUN_FONT_WEIGHTS_KEY = 10
        private const val STATE_RUN_FONT_STYLES_KEY = 11
        private const val STATE_RUN_LETTER_SPACINGS_KEY = 12
        private const val STATE_RUN_LINE_HEIGHTS_KEY = 13
        private const val STATE_RUN_TABULAR_NUMBERS_KEY = 14
        private const val STATE_ARRAY_LENGTH_KEY = 0
    }
}
