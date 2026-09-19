package com.rntextengine

import android.annotation.SuppressLint
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Path
import android.os.Build
import android.text.Layout
import android.text.StaticLayout
import android.text.Spanned
import android.text.TextPaint
import android.text.TextUtils
import android.text.style.LineHeightSpan
import android.text.style.MetricAffectingSpan
import android.widget.TextView
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.max

internal const val RN_TEXT_ENGINE_CAP_HEIGHT_EPSILON_PX = 0.01f

/** Enables fractional, unhinted glyph metrics for measurement and rendering. */
internal const val RN_TEXT_ENGINE_SHAPING_FLAGS = TextPaint.SUBPIXEL_TEXT_FLAG or TextPaint.LINEAR_TEXT_FLAG

private val capHeightPathThreadLocal = ThreadLocal<Path>()
private val capHeightBoundsThreadLocal = ThreadLocal<RectF>()

internal data class RNTextEngineCapHeightInsetsPx(
    val bottom: Float,
    val top: Float,
)

internal fun resolveCapHeightInsetsPx(
    layout: Layout?,
    text: CharSequence,
    defaultCapHeightPx: Float,
    uniformCapHeightPx: Float?,
): RNTextEngineCapHeightInsetsPx {
    if (layout == null || layout.lineCount == 0) return RNTextEngineCapHeightInsetsPx(bottom = 0f, top = 0f)

    val firstLineCapHeightPx =
        uniformCapHeightPx ?: resolveMaxCapHeightPx(text, layout.getLineStart(0), layout.getLineEnd(0), defaultCapHeightPx)
    val topInset = max(0f, layout.getLineBaseline(0) - firstLineCapHeightPx)
    val lastBaseline = layout.getLineBaseline(layout.lineCount - 1).toFloat()
    val bottomInset = max(0f, layout.height - lastBaseline)
    return RNTextEngineCapHeightInsetsPx(bottom = bottomInset, top = topInset)
}

internal fun resolveMaxCapHeightPx(text: CharSequence, start: Int, end: Int, defaultCapHeightPx: Float): Float {
    var maxCapHeightPx = defaultCapHeightPx

    if (text is Spanned && start < end) {
        text.getSpans(start, end, RNTextEngineTextPaintSpan::class.java).forEach { span ->
            maxCapHeightPx = max(maxCapHeightPx, span.resolveCapHeightPx())
        }
    }

    return maxCapHeightPx
}

internal fun resolveUniformCapHeightPx(text: CharSequence, defaultCapHeightPx: Float): Float? {
    if (text !is Spanned) return defaultCapHeightPx

    val spans = text.getSpans(0, text.length, RNTextEngineTextPaintSpan::class.java)
    if (spans.isEmpty()) return defaultCapHeightPx

    var uniformCapHeightPx = defaultCapHeightPx
    spans.forEach { span ->
        val spanCapHeightPx = span.resolveCapHeightPx()
        if (!isSameCapHeightPx(uniformCapHeightPx, spanCapHeightPx)) return null
    }

    return uniformCapHeightPx
}

internal fun roundMeasuredTextWidthPx(width: Float): Float {
    return if (Build.VERSION.SDK_INT > Build.VERSION_CODES.Q) ceil(width.toDouble()).toFloat() else width
}

@SuppressLint("ObsoleteSdkInt", "WrongConstant")
internal fun applyTextViewLineBreakConfig(textView: TextView, breakStrategy: Int, hyphenationFrequency: Int) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
    textView.breakStrategy = breakStrategy
    textView.hyphenationFrequency = hyphenationFrequency
}

@SuppressLint("ObsoleteSdkInt")
private fun resolveTextViewHyphenationFrequency(textView: TextView): Int {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        textView.hyphenationFrequency
    } else {
        Layout.HYPHENATION_FREQUENCY_NORMAL
    }
}

@SuppressLint("WrongConstant")
private fun StaticLayout.Builder.applyLineBreakConfig(breakStrategy: Int, hyphenationFrequency: Int): StaticLayout.Builder {
    setBreakStrategy(breakStrategy)
    setHyphenationFrequency(hyphenationFrequency)
    return this
}

@SuppressLint("WrongConstant")
@androidx.annotation.RequiresApi(Build.VERSION_CODES.O)
private fun StaticLayout.Builder.applyJustificationModeCompat(justificationMode: Int): StaticLayout.Builder {
    setJustificationMode(justificationMode)
    return this
}

@SuppressLint("ObsoleteSdkInt")
internal fun buildStaticLayoutCompat(
    text: CharSequence,
    paint: TextPaint,
    widthPx: Int,
    includeFontPadding: Boolean,
    breakStrategy: Int,
    hyphenationFrequency: Int,
    maxLines: Int,
    ellipsize: TextUtils.TruncateAt?,
    start: Int = 0,
    end: Int = text.length,
    alignment: Layout.Alignment = Layout.Alignment.ALIGN_NORMAL,
    justificationMode: Int = 0,
    lineSpacingAdd: Float = 0f,
    lineSpacingMultiplier: Float = 1f,
): Layout {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        val builder =
            StaticLayout.Builder.obtain(text, start, end, paint, max(1, widthPx))
            .setAlignment(alignment)
            .applyLineBreakConfig(breakStrategy, hyphenationFrequency)
            .setIncludePad(includeFontPadding)
            .setLineSpacing(lineSpacingAdd, lineSpacingMultiplier)
            .setMaxLines(maxLines)
            .setEllipsize(ellipsize)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            builder.applyJustificationModeCompat(justificationMode)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            builder.setUseLineSpacingFromFallbacks(true)
        }
        builder.build()
    } else {
        @Suppress("DEPRECATION")
        StaticLayout(
            text,
            start,
            end,
            paint,
            max(1, widthPx),
            Layout.Alignment.ALIGN_NORMAL,
            lineSpacingMultiplier,
            lineSpacingAdd,
            includeFontPadding,
            ellipsize,
            max(1, widthPx),
        )
    }
}

internal fun buildLayoutForTextView(textView: TextView, width: Int): Layout? {
    val text = textView.text ?: return null
    val textWidthPx = max(1, width - textView.compoundPaddingLeft - textView.compoundPaddingRight)
    textView.layout?.takeIf { !textView.isLayoutRequested && it.text === text && it.width == textWidthPx }?.let { return it }
    val maxLines = if (textView.maxLines > 0) textView.maxLines else Int.MAX_VALUE
    return buildStaticLayoutCompat(
        text = text,
        paint = TextPaint(textView.paint),
        widthPx = textWidthPx,
        includeFontPadding = textView.includeFontPadding,
        breakStrategy = textView.breakStrategy,
        hyphenationFrequency = resolveTextViewHyphenationFrequency(textView),
        maxLines = maxLines,
        ellipsize = if (maxLines == Int.MAX_VALUE) null else textView.ellipsize,
        lineSpacingAdd = textView.lineSpacingExtra,
        lineSpacingMultiplier = textView.lineSpacingMultiplier,
    )
}

internal fun measureCapHeightPx(textPaint: TextPaint): Float {
    val path =
        capHeightPathThreadLocal.get()
            ?: Path().also { capHeightPathThreadLocal.set(it) }
    val bounds =
        capHeightBoundsThreadLocal.get()
            ?: RectF().also { capHeightBoundsThreadLocal.set(it) }

    path.reset()
    bounds.setEmpty()
    textPaint.getTextPath("H", 0, 1, 0f, 0f, path)
    if (!path.isEmpty) {
        path.computeBounds(bounds, true)
        val measuredCapHeight = -bounds.top
        if (measuredCapHeight > 0f) return measuredCapHeight
    }

    val rect = Rect()
    textPaint.getTextBounds("H", 0, 1, rect)
    val measuredCapHeight = -rect.top.toFloat()
    if (measuredCapHeight > 0f) return measuredCapHeight
    return max(0f, -textPaint.fontMetrics.ascent)
}

internal fun isSameCapHeightPx(left: Float, right: Float): Boolean {
    return abs(left - right) <= RN_TEXT_ENGINE_CAP_HEIGHT_EPSILON_PX
}

internal class RNTextEngineTextPaintSpan(textPaint: TextPaint, resolvedCapHeightPx: Float? = null) : MetricAffectingSpan() {
    private val spanPaint = TextPaint(textPaint)
    private var capHeightPx = resolvedCapHeightPx ?: Float.NaN

    override fun updateMeasureState(textPaint: TextPaint) {
        apply(textPaint)
    }

    override fun updateDrawState(textPaint: TextPaint) {
        apply(textPaint)
    }

    fun resolveCapHeightPx(): Float {
        if (capHeightPx.isNaN()) {
            capHeightPx = measureCapHeightPx(spanPaint)
        }
        return capHeightPx
    }

    private fun apply(textPaint: TextPaint) {
        textPaint.typeface = spanPaint.typeface
        textPaint.textSize = spanPaint.textSize
        textPaint.letterSpacing = spanPaint.letterSpacing
        textPaint.color = spanPaint.color
        textPaint.fontFeatureSettings = spanPaint.fontFeatureSettings
    }
}

internal class RNTextEngineLineHeightSpan(height: Float) : LineHeightSpan {
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
