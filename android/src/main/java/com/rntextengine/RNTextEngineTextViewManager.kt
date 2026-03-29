package com.rntextengine

import android.graphics.Color
import android.os.Build
import android.text.Layout
import android.text.Spannable
import android.text.SpannableString
import android.text.TextPaint
import android.text.TextUtils
import android.text.style.LineHeightSpan
import android.text.style.MetricAffectingSpan
import android.util.TypedValue
import android.view.Gravity
import androidx.appcompat.widget.AppCompatTextView
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.PixelUtil
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.ViewProps
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.viewmanagers.RNTextEngineTextViewManagerDelegate
import com.facebook.react.viewmanagers.RNTextEngineTextViewManagerInterface
import com.facebook.react.views.text.ReactTypefaceUtils
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min

@ReactModule(name = RNTextEngineTextViewManager.REACT_CLASS)
internal class RNTextEngineTextViewManager :
    SimpleViewManager<RNTextEngineTextViewManager.RNTextEngineTextView>(),
    RNTextEngineTextViewManagerInterface<RNTextEngineTextViewManager.RNTextEngineTextView> {
    private val delegate: ViewManagerDelegate<RNTextEngineTextView> =
        RNTextEngineTextViewManagerDelegate<RNTextEngineTextView, RNTextEngineTextViewManager>(this)
    data class TextRunStyle(
        val color: String?,
        val fontFamily: String?,
        val fontSize: Double,
        val fontStyle: String?,
        val fontWeight: String?,
        val hasColor: Boolean,
        val hasFontFamily: Boolean,
        val hasFontSize: Boolean,
        val hasFontStyle: Boolean,
        val hasFontWeight: Boolean,
        val hasLetterSpacing: Boolean,
        val hasLineHeight: Boolean,
        val hasTabularNumbers: Boolean,
        val letterSpacing: Double,
        val lineHeight: Double,
        val tabularNumbers: Boolean,
    )

    data class TextRun(
        val end: Int,
        val start: Int,
        val style: TextRunStyle,
    )

    override fun getName(): String = REACT_CLASS

    override fun createViewInstance(reactContext: ThemedReactContext): RNTextEngineTextView {
        return RNTextEngineTextView(reactContext)
    }

    override fun getDelegate(): ViewManagerDelegate<RNTextEngineTextView> = delegate

    override fun onAfterUpdateTransaction(view: RNTextEngineTextView) {
        super.onAfterUpdateTransaction(view)
        view.flushTextDisplayIfNeeded()
    }

    @ReactProp(name = "text")
    override fun setText(view: RNTextEngineTextView, text: String?) {
        view.textValue = text ?: ""
        view.invalidateTextDisplay()
    }

    @ReactProp(name = "color", customType = "Color")
    override fun setColor(view: RNTextEngineTextView, color: Int?) {
        view.setTextColor(color ?: view.defaultTextColor)
        view.invalidateTextDisplay()
    }

    @ReactProp(name = "fontFamily")
    override fun setFontFamily(view: RNTextEngineTextView, fontFamily: String?) {
        view.fontFamily = fontFamily
        view.updateTypeface()
        view.invalidateTextDisplay()
    }

    @ReactProp(name = "fontSize", defaultFloat = 14f)
    override fun setFontSize(view: RNTextEngineTextView, fontSize: Double) {
        view.setTextSizePx(PixelUtil.toPixelFromDIP(fontSize.toFloat()))
        view.invalidateTextDisplay()
    }

    @ReactProp(name = "fontStyle")
    override fun setFontStyle(view: RNTextEngineTextView, fontStyle: String?) {
        view.fontStyle = fontStyle
        view.updateTypeface()
        view.invalidateTextDisplay()
    }

    @ReactProp(name = "fontWeight")
    override fun setFontWeight(view: RNTextEngineTextView, fontWeight: String?) {
        view.fontWeight = fontWeight
        view.updateTypeface()
        view.invalidateTextDisplay()
    }

    @ReactProp(name = "letterSpacing", defaultFloat = 0f)
    override fun setLetterSpacing(view: RNTextEngineTextView, letterSpacing: Double) {
        view.setLetterSpacingPx(PixelUtil.toPixelFromDIP(letterSpacing.toFloat()))
        view.invalidateTextDisplay()
    }

    @ReactProp(name = "lineHeight")
    override fun setLineHeight(view: RNTextEngineTextView, lineHeight: Double) {
        view.setLineHeightPx(
            if (lineHeight.isNaN()) {
                Float.NaN
            } else {
                PixelUtil.toPixelFromDIP(lineHeight.toFloat())
            },
        )
        view.invalidateTextDisplay()
    }

    @ReactProp(name = ViewProps.NUMBER_OF_LINES, defaultInt = 0)
    override fun setNumberOfLines(view: RNTextEngineTextView, numberOfLines: Int) {
        view.maxLines = if (numberOfLines > 0) numberOfLines else Int.MAX_VALUE
        view.setSingleLine(false)
    }

    @ReactProp(name = "selectable", defaultBoolean = false)
    override fun setSelectable(view: RNTextEngineTextView, selectable: Boolean) {
        view.setTextIsSelectable(selectable)
        view.isFocusable = selectable
        view.isFocusableInTouchMode = selectable
        view.isClickable = selectable
        view.isLongClickable = selectable
    }

    @ReactProp(name = "ellipsizeMode")
    override fun setEllipsizeMode(view: RNTextEngineTextView, ellipsizeMode: String?) {
        view.ellipsize = when (ellipsizeMode) {
            "head" -> TextUtils.TruncateAt.START
            "middle" -> TextUtils.TruncateAt.MIDDLE
            "tail" -> TextUtils.TruncateAt.END
            else -> null
        }
    }

    @ReactProp(name = "runs")
    fun setRuns(view: RNTextEngineTextView, runs: ReadableArray?) {
        view.runs = parseRuns(runs)
        view.invalidateTextDisplay()
    }

    @ReactProp(name = "runStarts")
    override fun setRunStarts(view: RNTextEngineTextView, runStarts: ReadableArray?) {
        view.runStarts = runStarts
        view.invalidateTextDisplay()
    }

    @ReactProp(name = "runEnds")
    override fun setRunEnds(view: RNTextEngineTextView, runEnds: ReadableArray?) {
        view.runEnds = runEnds
        view.invalidateTextDisplay()
    }

    @ReactProp(name = "runStyleMasks")
    override fun setRunStyleMasks(view: RNTextEngineTextView, runStyleMasks: ReadableArray?) {
        view.runStyleMasks = runStyleMasks
        view.invalidateTextDisplay()
    }

    @ReactProp(name = "runColors")
    override fun setRunColors(view: RNTextEngineTextView, runColors: ReadableArray?) {
        view.runColors = runColors
        view.invalidateTextDisplay()
    }

    @ReactProp(name = "runCount", defaultInt = 0)
    override fun setRunCount(view: RNTextEngineTextView, runCount: Int) {
        view.runCount = runCount
        view.invalidateTextDisplay()
    }

    @ReactProp(name = "runFontFamilies")
    override fun setRunFontFamilies(view: RNTextEngineTextView, runFontFamilies: ReadableArray?) {
        view.runFontFamilies = runFontFamilies
        view.invalidateTextDisplay()
    }

    @ReactProp(name = "runFontSizes")
    override fun setRunFontSizes(view: RNTextEngineTextView, runFontSizes: ReadableArray?) {
        view.runFontSizes = runFontSizes
        view.invalidateTextDisplay()
    }

    @ReactProp(name = "runFontWeights")
    override fun setRunFontWeights(view: RNTextEngineTextView, runFontWeights: ReadableArray?) {
        view.runFontWeights = runFontWeights
        view.invalidateTextDisplay()
    }

    @ReactProp(name = "runFontStyles")
    override fun setRunFontStyles(view: RNTextEngineTextView, runFontStyles: ReadableArray?) {
        view.runFontStyles = runFontStyles
        view.invalidateTextDisplay()
    }

    @ReactProp(name = "runLetterSpacings")
    override fun setRunLetterSpacings(view: RNTextEngineTextView, runLetterSpacings: ReadableArray?) {
        view.runLetterSpacings = runLetterSpacings
        view.invalidateTextDisplay()
    }

    @ReactProp(name = "runLineHeights")
    override fun setRunLineHeights(view: RNTextEngineTextView, runLineHeights: ReadableArray?) {
        view.runLineHeights = runLineHeights
        view.invalidateTextDisplay()
    }

    @ReactProp(name = "runTabularNumbers")
    override fun setRunTabularNumbers(view: RNTextEngineTextView, runTabularNumbers: ReadableArray?) {
        view.runTabularNumbers = runTabularNumbers
        view.invalidateTextDisplay()
    }

    @Suppress("WrongConstant")
    @ReactProp(name = ViewProps.TEXT_ALIGN)
    override fun setTextAlign(view: RNTextEngineTextView, textAlign: String?) {
        val horizontalGravity =
            when (textAlign) {
                null, "auto" -> Gravity.NO_GRAVITY
                "left" -> Gravity.LEFT
                "right" -> Gravity.RIGHT
                "center" -> Gravity.CENTER_HORIZONTAL
                "justify" -> Gravity.LEFT
                else -> Gravity.NO_GRAVITY
            }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            view.justificationMode =
                if (textAlign == "justify") Layout.JUSTIFICATION_MODE_INTER_WORD else Layout.JUSTIFICATION_MODE_NONE
        }

        val verticalGravity = view.gravity and Gravity.VERTICAL_GRAVITY_MASK
        view.gravity = horizontalGravity or verticalGravity
        view.invalidateTextDisplay()
    }

    internal class RNTextEngineTextView(context: ThemedReactContext) : AppCompatTextView(context) {
        var fontFamily: String? = null
        var fontStyle: String? = null
        var fontWeight: String? = null
        val defaultTextColor: Int = currentTextColor
        var runs: List<TextRun> = emptyList()
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
        private var textDisplayDirty = true
        private var lineHeightPx = Float.NaN

        init {
            includeFontPadding = false
            isFocusable = false
            isClickable = false
            setBackgroundColor(Color.TRANSPARENT)
            setLineSpacing(0f, 1f)
        }

        fun setTextSizePx(size: Float) {
            setTextSize(TypedValue.COMPLEX_UNIT_PX, size)
            updateLetterSpacing()
            updateLineHeightSpacing()
            updateTypeface()
        }

        fun setLetterSpacingPx(letterSpacingPx: Float) {
            val currentTextSize = textSize
            letterSpacing = if (currentTextSize > 0f) letterSpacingPx / currentTextSize else 0f
        }

        fun setLineHeightPx(value: Float) {
            lineHeightPx = value
            updateLineHeightSpacing()
        }

        fun updateTypeface() {
            val style = ReactTypefaceUtils.parseFontStyle(fontStyle)
            val weight = ReactTypefaceUtils.parseFontWeight(fontWeight)
            typeface =
                ReactTypefaceUtils.applyStyles(
                    typeface,
                    style,
                    weight,
                    fontFamily,
                    context.assets,
                )
        }

        private fun updateLetterSpacing() {
            val current = letterSpacing
            if (current.isNaN()) {
                letterSpacing = 0f
            }
        }

        private fun updateLineHeightSpacing() {
            if (lineHeightPx.isNaN()) {
                setLineSpacing(0f, 1f)
                return
            }

            val metrics = paint.fontMetricsInt
            val fontHeight = (-metrics.ascent + metrics.descent).toFloat()
            setLineSpacing(max(0f, lineHeightPx - fontHeight), 1f)
        }

        fun updateTextDisplay() {
            val resolvedRuns = resolveAnimatedRuns()
            val activeRuns = if (resolvedRuns.isNotEmpty()) resolvedRuns else runs

            if (activeRuns.isEmpty()) {
                includeFontPadding = false
                updateLineHeightSpacing()
                text = textValue
                return
            }

            includeFontPadding = false
            setLineSpacing(0f, 1f)

            val styledText = SpannableString(textValue)
            lineHeightPx.takeUnless(Float::isNaN)?.let { applyBaseLineHeightSpans(styledText, textValue.length, it, activeRuns) }

            activeRuns.forEach { run ->
                val runPaint = TextPaint(paint)
                applyRunStyle(runPaint, run.style)
                styledText.setSpan(
                    RNTextEngineTextPaintSpan(runPaint),
                    run.start,
                    run.end,
                    Spannable.SPAN_EXCLUSIVE_EXCLUSIVE,
                )

                if (run.style.hasLineHeight) {
                    styledText.setSpan(
                        RNTextEngineLineHeightSpan(PixelUtil.toPixelFromDIP(run.style.lineHeight.toFloat())),
                        run.start,
                        run.end,
                        Spannable.SPAN_EXCLUSIVE_EXCLUSIVE,
                    )
                }
            }

            text = styledText
        }

        fun flushTextDisplayIfNeeded() {
            if (!textDisplayDirty) return
            textDisplayDirty = false
            updateTextDisplay()
        }

        fun invalidateTextDisplay() {
            textDisplayDirty = true
        }

        private fun resolveAnimatedRuns(): List<TextRun> {
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

            val resolvedRuns = ArrayList<TextRun>(resolvedRunCount)
            var previousEnd = 0

            for (index in 0 until resolvedRunCount) {
                if (starts.isNull(index) || ends.isNull(index) || styleMasks.isNull(index)) continue

                val start = starts.getInt(index)
                val end = ends.getInt(index)
                val styleMask = styleMasks.getInt(index)
                if (styleMask == 0 || start < previousEnd || start < 0 || end <= start) continue

                val style =
                    TextRunStyle(
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

                resolvedRuns.add(TextRun(end = end, start = start, style = style))
                previousEnd = end
            }

            return resolvedRuns
        }

        private fun applyRunStyle(textPaint: TextPaint, style: TextRunStyle) {
            if (style.hasColor) {
                textPaint.color = resolveColor(style.color) ?: defaultTextColor
            }

            val resolvedFontFamily = if (style.hasFontFamily) style.fontFamily else this.fontFamily
            val resolvedFontStyle = if (style.hasFontStyle) style.fontStyle else this.fontStyle
            val resolvedFontWeight = if (style.hasFontWeight) style.fontWeight else this.fontWeight
            val fontSizePx =
                if (style.hasFontSize) PixelUtil.toPixelFromDIP(style.fontSize.toFloat()) else textSize

            textPaint.typeface =
                ReactTypefaceUtils.applyStyles(
                    textPaint.typeface,
                    ReactTypefaceUtils.parseFontStyle(resolvedFontStyle),
                    ReactTypefaceUtils.parseFontWeight(resolvedFontWeight),
                    resolvedFontFamily,
                    context.assets,
                )
            textPaint.textSize = fontSizePx

            if (style.hasLetterSpacing) {
                textPaint.letterSpacing =
                    if (fontSizePx > 0f) PixelUtil.toPixelFromDIP(style.letterSpacing.toFloat()) / fontSizePx else 0f
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP && style.hasTabularNumbers) {
                textPaint.fontFeatureSettings = if (style.tabularNumbers) "'tnum'" else null
            }
        }

        private fun resolveColor(value: String?): Int? {
            return RNTextEngineColorParser.parse(value)
        }

        private fun applyBaseLineHeightSpans(
            styledText: SpannableString,
            textLength: Int,
            baseLineHeightPx: Float,
            runs: List<TextRun>,
        ) {
            var cursor = 0

            runs.forEach { run ->
                if (run.style.hasLineHeight && cursor < run.start) {
                    styledText.setSpan(
                        RNTextEngineLineHeightSpan(baseLineHeightPx),
                        cursor,
                        run.start,
                        Spannable.SPAN_EXCLUSIVE_EXCLUSIVE,
                    )
                }

                if (run.style.hasLineHeight) {
                    cursor = run.end
                }
            }

            if (cursor < textLength) {
                styledText.setSpan(
                    RNTextEngineLineHeightSpan(baseLineHeightPx),
                    cursor,
                    textLength,
                    Spannable.SPAN_EXCLUSIVE_EXCLUSIVE,
                )
            }
        }
    }

    private fun parseRuns(runs: ReadableArray?): List<TextRun> {
        if (runs == null) return emptyList()

        val resolvedRuns = ArrayList<TextRun>(runs.size())
        var previousEnd = 0

        for (index in 0 until runs.size()) {
            val run = runs.getMap(index) ?: continue
            val start = if (run.hasKey("start") && !run.isNull("start")) run.getInt("start") else continue
            val end = if (run.hasKey("end") && !run.isNull("end")) run.getInt("end") else continue
            val styleMap = run.getMap("style") ?: continue
            if (start < previousEnd || start < 0 || end <= start) continue

            val style = parseRunStyle(styleMap)
            if (!hasAnyOverride(style)) continue

            resolvedRuns.add(TextRun(end = end, start = start, style = style))
            previousEnd = end
        }

        return resolvedRuns
    }

    private fun parseRunStyle(style: ReadableMap): TextRunStyle {
        return TextRunStyle(
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

    private fun hasAnyOverride(style: TextRunStyle): Boolean {
        return style.hasColor || style.hasFontFamily || style.hasFontSize || style.hasFontStyle || style.hasFontWeight || style.hasLetterSpacing || style.hasLineHeight || style.hasTabularNumbers
    }

    private class RNTextEngineTextPaintSpan(textPaint: TextPaint) : MetricAffectingSpan() {
        private val spanPaint = TextPaint(textPaint)

        override fun updateMeasureState(textPaint: TextPaint) {
            apply(textPaint)
        }

        override fun updateDrawState(textPaint: TextPaint) {
            apply(textPaint)
        }

        private fun apply(textPaint: TextPaint) {
            textPaint.typeface = spanPaint.typeface
            textPaint.textSize = spanPaint.textSize
            textPaint.letterSpacing = spanPaint.letterSpacing
            textPaint.color = spanPaint.color

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                textPaint.fontFeatureSettings = spanPaint.fontFeatureSettings
            }
        }
    }

    private class RNTextEngineLineHeightSpan(height: Float) : LineHeightSpan {
        private val lineHeight = ceil(height.toDouble()).toInt()

        override fun chooseHeight(text: CharSequence, start: Int, end: Int, spanstartv: Int, v: Int, fm: android.graphics.Paint.FontMetricsInt) {
            val leading = lineHeight - ((-fm.ascent) + fm.descent)
            fm.ascent -= ceil(leading / 2.0f).toInt()
            fm.descent += floor(leading / 2.0f).toInt()

            if (start == 0) {
                fm.top = fm.ascent
            }
            if (end == text.length) {
                fm.bottom = fm.descent
            }
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
    }
}
