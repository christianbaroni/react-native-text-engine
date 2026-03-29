package com.rnpretext

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
import com.facebook.react.bridge.ColorPropConverter
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.uimanager.PixelUtil
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewProps
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.views.text.ReactTypefaceUtils
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.max

internal class RNPretextTextViewManager : SimpleViewManager<RNPretextTextViewManager.RNPretextTextView>() {
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
        val letterSpacing: Double,
        val lineHeight: Double,
    )

    data class TextRun(
        val end: Int,
        val start: Int,
        val style: TextRunStyle,
    )

    override fun getName(): String = REACT_CLASS

    override fun createViewInstance(reactContext: ThemedReactContext): RNPretextTextView {
        return RNPretextTextView(reactContext)
    }

    @ReactProp(name = "text")
    fun setText(view: RNPretextTextView, text: String?) {
        view.textValue = text ?: ""
        view.updateTextDisplay()
    }

    @ReactProp(name = "color", customType = "Color")
    fun setColor(view: RNPretextTextView, color: Any?) {
        val resolved = ColorPropConverter.getColor(color, view.context)
        view.setTextColor(resolved ?: view.defaultTextColor)
        view.updateTextDisplay()
    }

    @ReactProp(name = "fontFamily")
    fun setFontFamily(view: RNPretextTextView, fontFamily: String?) {
        view.fontFamily = fontFamily
        view.updateTypeface()
        view.updateTextDisplay()
    }

    @ReactProp(name = "fontSize", defaultFloat = 14f)
    fun setFontSize(view: RNPretextTextView, fontSize: Float) {
        view.setTextSizePx(PixelUtil.toPixelFromDIP(fontSize))
        view.updateTextDisplay()
    }

    @ReactProp(name = "fontStyle")
    fun setFontStyle(view: RNPretextTextView, fontStyle: String?) {
        view.fontStyle = fontStyle
        view.updateTypeface()
        view.updateTextDisplay()
    }

    @ReactProp(name = "fontWeight")
    fun setFontWeight(view: RNPretextTextView, fontWeight: String?) {
        view.fontWeight = fontWeight
        view.updateTypeface()
        view.updateTextDisplay()
    }

    @ReactProp(name = "letterSpacing", defaultFloat = 0f)
    fun setLetterSpacing(view: RNPretextTextView, letterSpacing: Float) {
        view.setLetterSpacingPx(PixelUtil.toPixelFromDIP(letterSpacing))
        view.updateTextDisplay()
    }

    @ReactProp(name = "lineHeight")
    fun setLineHeight(view: RNPretextTextView, lineHeight: Float) {
        view.setLineHeightPx(
            if (lineHeight.isNaN()) {
                Float.NaN
            } else {
                PixelUtil.toPixelFromDIP(lineHeight)
            },
        )
        view.updateTextDisplay()
    }

    @ReactProp(name = ViewProps.NUMBER_OF_LINES, defaultInt = 0)
    fun setNumberOfLines(view: RNPretextTextView, numberOfLines: Int) {
        view.maxLines = if (numberOfLines > 0) numberOfLines else Int.MAX_VALUE
        view.setSingleLine(false)
    }

    @ReactProp(name = "selectable", defaultBoolean = false)
    fun setSelectable(view: RNPretextTextView, selectable: Boolean) {
        view.setTextIsSelectable(selectable)
        view.isFocusable = selectable
        view.isFocusableInTouchMode = selectable
        view.isClickable = selectable
        view.isLongClickable = selectable
    }

    @ReactProp(name = "ellipsizeMode")
    fun setEllipsizeMode(view: RNPretextTextView, ellipsizeMode: String?) {
        view.ellipsize = when (ellipsizeMode) {
            "head" -> TextUtils.TruncateAt.START
            "middle" -> TextUtils.TruncateAt.MIDDLE
            "tail" -> TextUtils.TruncateAt.END
            else -> null
        }
    }

    @ReactProp(name = "runs")
    fun setRuns(view: RNPretextTextView, runs: ReadableArray?) {
        view.runs = parseRuns(runs)
        view.updateTextDisplay()
    }

    @Suppress("WrongConstant")
    @ReactProp(name = ViewProps.TEXT_ALIGN)
    fun setTextAlign(view: RNPretextTextView, textAlign: String?) {
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
        view.updateTextDisplay()
    }

    internal class RNPretextTextView(context: ThemedReactContext) : AppCompatTextView(context) {
        var fontFamily: String? = null
        var fontStyle: String? = null
        var fontWeight: String? = null
        val defaultTextColor: Int = currentTextColor
        var runs: List<TextRun> = emptyList()
        var textValue: String = ""
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
            if (runs.isEmpty()) {
                includeFontPadding = false
                updateLineHeightSpacing()
                text = textValue
                return
            }

            includeFontPadding = false
            setLineSpacing(0f, 1f)

            val styledText = SpannableString(textValue)
            lineHeightPx.takeUnless(Float::isNaN)?.let { applyBaseLineHeightSpans(styledText, textValue.length, it, runs) }

            runs.forEach { run ->
                val runPaint = TextPaint(paint)
                applyRunStyle(runPaint, run.style)
                styledText.setSpan(
                    RNPretextTextPaintSpan(runPaint),
                    run.start,
                    run.end,
                    Spannable.SPAN_EXCLUSIVE_EXCLUSIVE,
                )

                if (run.style.hasLineHeight) {
                    styledText.setSpan(
                        RNPretextLineHeightSpan(PixelUtil.toPixelFromDIP(run.style.lineHeight.toFloat())),
                        run.start,
                        run.end,
                        Spannable.SPAN_EXCLUSIVE_EXCLUSIVE,
                    )
                }
            }

            text = styledText
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
        }

        private fun resolveColor(value: String?): Int? {
            if (value.isNullOrBlank()) return null
            return runCatching { Color.parseColor(value) }.getOrNull()
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
                        RNPretextLineHeightSpan(baseLineHeightPx),
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
                    RNPretextLineHeightSpan(baseLineHeightPx),
                    cursor,
                    textLength,
                    Spannable.SPAN_EXCLUSIVE_EXCLUSIVE,
                )
            }
        }
    }

    companion object {
        const val REACT_CLASS = "RNPretextTextView"
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
            letterSpacing = if (style.hasKey("letterSpacing") && !style.isNull("letterSpacing")) style.getDouble("letterSpacing") else 0.0,
            lineHeight = if (style.hasKey("lineHeight") && !style.isNull("lineHeight")) style.getDouble("lineHeight") else 0.0,
        )
    }

    private fun hasAnyOverride(style: TextRunStyle): Boolean {
        return style.hasColor || style.hasFontFamily || style.hasFontSize || style.hasFontStyle || style.hasFontWeight || style.hasLetterSpacing || style.hasLineHeight
    }

    private class RNPretextTextPaintSpan(textPaint: TextPaint) : MetricAffectingSpan() {
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
        }
    }

    private class RNPretextLineHeightSpan(height: Float) : LineHeightSpan {
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
}
