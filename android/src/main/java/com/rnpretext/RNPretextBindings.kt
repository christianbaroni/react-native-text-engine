package com.rnpretext

import android.graphics.Color
import android.graphics.Typeface
import android.os.Build
import android.text.Layout
import android.text.SpannableString
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils
import android.text.style.LineHeightSpan
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.common.assets.ReactFontManager
import com.facebook.react.uimanager.DisplayMetricsHolder
import com.facebook.react.uimanager.PixelUtil
import com.facebook.react.views.text.ReactTypefaceUtils.parseFontWeight
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min

internal object RNPretextBindings {
    private val nextHandle = AtomicLong(1)
    private val preparedTexts = ConcurrentHashMap<Long, PreparedTextData>()
    private lateinit var reactContext: ReactApplicationContext

    private data class ResolvedTextStyle(
        val fallbackLineHeight: Double,
        val includeFontPadding: Boolean,
        val lineHeightPx: Float?,
        val textBreakStrategy: Int,
        val textColor: Int?,
        val textPaint: TextPaint,
    )

    private data class PreparedTextData(
        val style: ResolvedTextStyle,
        val text: String,
        val textWithLineHeight: CharSequence,
    )

    internal data class PreparedTextViewData(
        val includeFontPadding: Boolean,
        val text: CharSequence,
        val textColor: Int?,
        val textPaint: TextPaint,
    )

    @JvmStatic
    fun initialize(context: ReactApplicationContext) {
        reactContext = context
    }

    @JvmStatic
    fun cleanup() {
        preparedTexts.clear()
        nextHandle.set(1)
    }

    @JvmStatic
    fun prepare(
        text: String,
        color: String?,
        fontFamily: String?,
        fontSize: Double,
        fontWeight: String?,
        fontStyle: String?,
        letterSpacing: Double,
        lineHeight: Double,
        allowFontScaling: Boolean,
        includeFontPadding: Boolean,
        tabularNumbers: Boolean,
        textBreakStrategy: String?,
    ): Long {
        val style = resolveTextStyle(
            color = color,
            fontFamily = fontFamily,
            fontSize = fontSize,
            fontWeight = fontWeight,
            fontStyle = fontStyle,
            letterSpacing = letterSpacing,
            lineHeight = lineHeight,
            allowFontScaling = allowFontScaling,
            includeFontPadding = includeFontPadding,
            tabularNumbers = tabularNumbers,
            textBreakStrategy = textBreakStrategy,
        )
        val handle = nextHandle.getAndIncrement()
        preparedTexts[handle] = buildPreparedText(text, style)
        return handle
    }

    @JvmStatic
    fun prepareBatch(
        texts: Array<String>,
        color: String?,
        fontFamily: String?,
        fontSize: Double,
        fontWeight: String?,
        fontStyle: String?,
        letterSpacing: Double,
        lineHeight: Double,
        allowFontScaling: Boolean,
        includeFontPadding: Boolean,
        tabularNumbers: Boolean,
        textBreakStrategy: String?,
    ): LongArray {
        val style = resolveTextStyle(
            color = color,
            fontFamily = fontFamily,
            fontSize = fontSize,
            fontWeight = fontWeight,
            fontStyle = fontStyle,
            letterSpacing = letterSpacing,
            lineHeight = lineHeight,
            allowFontScaling = allowFontScaling,
            includeFontPadding = includeFontPadding,
            tabularNumbers = tabularNumbers,
            textBreakStrategy = textBreakStrategy,
        )

        return LongArray(texts.size) { index ->
            val handle = nextHandle.getAndIncrement()
            preparedTexts[handle] = buildPreparedText(texts[index], style)
            handle
        }
    }

    @JvmStatic
    fun release(handle: Long) {
        preparedTexts.remove(handle)
    }

    @JvmStatic
    fun releaseMany(handles: LongArray) {
        handles.forEach(preparedTexts::remove)
    }

    @JvmStatic
    fun measureWidth(
        text: String,
        color: String?,
        fontFamily: String?,
        fontSize: Double,
        fontWeight: String?,
        fontStyle: String?,
        letterSpacing: Double,
        lineHeight: Double,
        allowFontScaling: Boolean,
        includeFontPadding: Boolean,
        tabularNumbers: Boolean,
        textBreakStrategy: String?,
    ): Double {
        val style = resolveTextStyle(
            color = color,
            fontFamily = fontFamily,
            fontSize = fontSize,
            fontWeight = fontWeight,
            fontStyle = fontStyle,
            letterSpacing = letterSpacing,
            lineHeight = lineHeight,
            allowFontScaling = allowFontScaling,
            includeFontPadding = includeFontPadding,
            tabularNumbers = tabularNumbers,
            textBreakStrategy = textBreakStrategy,
        )
        val prepared = buildPreparedText(text, style)
        return Layout.getDesiredWidth(prepared.textWithLineHeight, prepared.style.textPaint).toDouble().toDp()
    }

    @JvmStatic
    fun measure(
        text: String,
        color: String?,
        fontFamily: String?,
        fontSize: Double,
        fontWeight: String?,
        fontStyle: String?,
        letterSpacing: Double,
        lineHeight: Double,
        allowFontScaling: Boolean,
        includeFontPadding: Boolean,
        tabularNumbers: Boolean,
        textBreakStrategy: String?,
        width: Double,
        maxLines: Int,
        ellipsizeMode: String?,
    ): DoubleArray {
        val style = resolveTextStyle(
            color = color,
            fontFamily = fontFamily,
            fontSize = fontSize,
            fontWeight = fontWeight,
            fontStyle = fontStyle,
            letterSpacing = letterSpacing,
            lineHeight = lineHeight,
            allowFontScaling = allowFontScaling,
            includeFontPadding = includeFontPadding,
            tabularNumbers = tabularNumbers,
            textBreakStrategy = textBreakStrategy,
        )
        val prepared = buildPreparedText(text, style)
        return packLayout(buildLayout(prepared, width, maxLines, ellipsizeMode, includeLines = false))
    }

    @JvmStatic
    fun measureBatch(
        texts: Array<String>,
        color: String?,
        fontFamily: String?,
        fontSize: Double,
        fontWeight: String?,
        fontStyle: String?,
        letterSpacing: Double,
        lineHeight: Double,
        allowFontScaling: Boolean,
        includeFontPadding: Boolean,
        tabularNumbers: Boolean,
        textBreakStrategy: String?,
        width: Double,
        maxLines: Int,
        ellipsizeMode: String?,
    ): DoubleArray {
        val style = resolveTextStyle(
            color = color,
            fontFamily = fontFamily,
            fontSize = fontSize,
            fontWeight = fontWeight,
            fontStyle = fontStyle,
            letterSpacing = letterSpacing,
            lineHeight = lineHeight,
            allowFontScaling = allowFontScaling,
            includeFontPadding = includeFontPadding,
            tabularNumbers = tabularNumbers,
            textBreakStrategy = textBreakStrategy,
        )
        val packed = DoubleArray(texts.size * PACKED_LAYOUT_SIZE)
        texts.forEachIndexed { index, text ->
            packLayoutInto(
                packed,
                index * PACKED_LAYOUT_SIZE,
                buildLayout(buildPreparedText(text, style), width, maxLines, ellipsizeMode, includeLines = false),
            )
        }
        return packed
    }

    @JvmStatic
    fun layout(handle: Long, width: Double, maxLines: Int, ellipsizeMode: String?): DoubleArray {
        val prepared = requirePrepared(handle)
        return packLayout(buildLayout(prepared, width, maxLines, ellipsizeMode, includeLines = false))
    }

    @JvmStatic
    fun layoutBatch(handles: LongArray, width: Double, maxLines: Int, ellipsizeMode: String?): DoubleArray {
        val packed = DoubleArray(handles.size * PACKED_LAYOUT_SIZE)
        handles.forEachIndexed { index, handle ->
            packLayoutInto(
                packed,
                index * PACKED_LAYOUT_SIZE,
                buildLayout(requirePrepared(handle), width, maxLines, ellipsizeMode, includeLines = false),
            )
        }
        return packed
    }

    @JvmStatic
    fun layoutLines(handle: Long, width: Double, maxLines: Int, ellipsizeMode: String?): DoubleArray {
        val prepared = requirePrepared(handle)
        return packLayoutWithLines(buildLayout(prepared, width, maxLines, ellipsizeMode, includeLines = true))
    }

    @JvmStatic
    fun layoutNextLine(handle: Long, start: Int, width: Double): DoubleArray? {
        val prepared = requirePrepared(handle)
        if (start < 0 || start >= prepared.text.length) return null

        val nextPrepared = prepared.copy(
            text = prepared.text.substring(start),
            textWithLineHeight = prepared.textWithLineHeight.subSequence(start, prepared.text.length),
        )

        val layout = buildLayout(
            prepared = nextPrepared,
            width = width,
            maxLines = 1,
            ellipsizeMode = null,
            includeLines = true,
            baseOffset = start,
        )

        val line = layout.lines.firstOrNull() ?: return null
        return doubleArrayOf(line.start, line.end, line.width, line.bottom)
    }

    private fun resolveTextStyle(
        color: String?,
        fontFamily: String?,
        fontSize: Double,
        fontWeight: String?,
        fontStyle: String?,
        letterSpacing: Double,
        lineHeight: Double,
        allowFontScaling: Boolean,
        includeFontPadding: Boolean,
        tabularNumbers: Boolean,
        textBreakStrategy: String?,
    ): ResolvedTextStyle {
        val textPaint = TextPaint(TextPaint.ANTI_ALIAS_FLAG)
        val effectiveFontSize = scale(fontSize, allowFontScaling, defaultValue = 14.0)
        textPaint.textSize = effectiveFontSize

        val resolvedColor = resolveTextColor(color)
        if (resolvedColor != null) {
            textPaint.color = resolvedColor
        }

        val typeface = resolveTypeface(fontFamily, fontWeight, fontStyle)
        textPaint.typeface = typeface

        if (!letterSpacing.isNaN() && effectiveFontSize > 0f) {
            textPaint.letterSpacing = scale(letterSpacing, allowFontScaling, defaultValue = 0.0) / effectiveFontSize
        }

        if (tabularNumbers && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            textPaint.fontFeatureSettings = "'tnum'"
        }

        val fallbackLineHeight = if (lineHeight.isNaN()) {
            ((-textPaint.fontMetricsInt.ascent) + textPaint.fontMetricsInt.descent).toDouble().toDp()
        } else {
            scale(lineHeight, allowFontScaling, defaultValue = lineHeight).toDouble().toDp()
        }

        return ResolvedTextStyle(
            fallbackLineHeight = fallbackLineHeight,
            includeFontPadding = includeFontPadding,
            lineHeightPx = if (lineHeight.isNaN()) null else scale(lineHeight, allowFontScaling, defaultValue = lineHeight),
            textBreakStrategy = resolveTextBreakStrategy(textBreakStrategy),
            textColor = resolvedColor,
            textPaint = textPaint,
        )
    }

    private fun buildPreparedText(text: String, style: ResolvedTextStyle): PreparedTextData {
        val textWithLineHeight =
            if (style.lineHeightPx == null || text.isEmpty()) {
                text
            } else {
                SpannableString(text).apply {
                    setSpan(
                        RNPretextLineHeightSpan(style.lineHeightPx),
                        0,
                        text.length,
                        SpannableString.SPAN_INCLUSIVE_INCLUSIVE,
                    )
                }
            }

        return PreparedTextData(
            style = style,
            text = text,
            textWithLineHeight = textWithLineHeight,
        )
    }

    private data class LineInfo(
        val bottom: Double,
        val end: Double,
        val start: Double,
        val width: Double,
    )

    private data class LayoutInfo(
        val height: Double,
        val lastLineWidth: Double,
        val lineCount: Double,
        val lines: List<LineInfo>,
        val width: Double,
    )

    private fun buildLayout(
        prepared: PreparedTextData,
        width: Double,
        maxLines: Int,
        ellipsizeMode: String?,
        includeLines: Boolean,
        baseOffset: Int = 0,
    ): LayoutInfo {
        if (prepared.text.isEmpty()) {
            return LayoutInfo(
                height = prepared.style.fallbackLineHeight,
                lastLineWidth = 0.0,
                lineCount = 0.0,
                lines = emptyList(),
                width = 0.0,
            )
        }

        val density = currentDensity()
        val layoutWidth = max(0.0, width) * density
        val textWidthPx = max(1, ceil(layoutWidth).toInt())
        val charSequence = prepared.textWithLineHeight
        val paint = TextPaint(prepared.style.textPaint)
        val effectiveMaxLines = if (maxLines > 0) maxLines else Int.MAX_VALUE
        val ellipsize = resolveEllipsize(ellipsizeMode, effectiveMaxLines)

        val layout = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            StaticLayout.Builder.obtain(charSequence, 0, charSequence.length, paint, textWidthPx)
                .setAlignment(Layout.Alignment.ALIGN_NORMAL)
                .setBreakStrategy(prepared.style.textBreakStrategy)
                .setHyphenationFrequency(Layout.HYPHENATION_FREQUENCY_NORMAL)
                .setIncludePad(prepared.style.includeFontPadding)
                .setMaxLines(effectiveMaxLines)
                .setEllipsize(ellipsize)
                .build()
        } else {
            @Suppress("DEPRECATION")
            StaticLayout(
                charSequence,
                paint,
                textWidthPx,
                Layout.Alignment.ALIGN_NORMAL,
                1f,
                0f,
                prepared.style.includeFontPadding,
            )
        }

        val actualLineCount = min(layout.lineCount, effectiveMaxLines)
        var widestLine = 0.0
        var lastLineWidth = 0.0
        val lines = if (includeLines) ArrayList<LineInfo>(actualLineCount) else emptyList<LineInfo>()

        for (index in 0 until actualLineCount) {
            val lineWidth = layout.getLineMax(index).toDouble() / density
            widestLine = max(widestLine, lineWidth)
            lastLineWidth = lineWidth

            if (includeLines) {
                (lines as ArrayList).add(
                    LineInfo(
                        bottom = layout.getLineBottom(index).toDouble() / density,
                        end = (baseOffset + layout.getLineVisibleEnd(index)).toDouble(),
                        start = (baseOffset + layout.getLineStart(index)).toDouble(),
                        width = lineWidth,
                    ),
                )
            }
        }

        return LayoutInfo(
            height = layout.height.toDouble() / density,
            lastLineWidth = lastLineWidth,
            lineCount = actualLineCount.toDouble(),
            lines = lines,
            width = widestLine,
        )
    }

    private fun packLayout(layout: LayoutInfo): DoubleArray {
        val packed = DoubleArray(PACKED_LAYOUT_SIZE)
        packLayoutInto(packed, 0, layout)
        return packed
    }

    private fun packLayoutInto(target: DoubleArray, offset: Int, layout: LayoutInfo) {
        target[offset] = layout.width
        target[offset + 1] = layout.height
        target[offset + 2] = layout.lineCount
        target[offset + 3] = layout.lastLineWidth
    }

    private fun packLayoutWithLines(layout: LayoutInfo): DoubleArray {
        val packed = DoubleArray(PACKED_LAYOUT_SIZE + layout.lines.size * PACKED_LINE_SIZE)
        packed[0] = layout.width
        packed[1] = layout.height
        packed[2] = layout.lineCount
        packed[3] = layout.lastLineWidth

        layout.lines.forEachIndexed { index, line ->
            val offset = PACKED_LAYOUT_SIZE + index * PACKED_LINE_SIZE
            packed[offset] = line.start
            packed[offset + 1] = line.end
            packed[offset + 2] = line.width
            packed[offset + 3] = line.bottom
        }

        return packed
    }

    private fun requirePrepared(handle: Long): PreparedTextData {
        return preparedTexts[handle] ?: error("RNPretext: attempted to use an invalid prepared text handle.")
    }

    @JvmStatic
    internal fun resolvePreparedTextViewData(handle: Long): PreparedTextViewData? {
        val prepared = preparedTexts[handle] ?: return null
        return PreparedTextViewData(
            includeFontPadding = prepared.style.includeFontPadding,
            text = SpannableString.valueOf(prepared.textWithLineHeight),
            textColor = prepared.style.textColor,
            textPaint = TextPaint(prepared.style.textPaint),
        )
    }

    private fun resolveTypeface(fontFamily: String?, fontWeight: String?, fontStyle: String?): Typeface {
        val style = resolveTypefaceStyle(fontWeight, fontStyle)
        if (fontFamily == null) {
            return Typeface.defaultFromStyle(style)
        }

        return ReactFontManager.getInstance().getTypeface(fontFamily, style, reactContext.assets)
            ?: Typeface.defaultFromStyle(style)
    }

    private fun resolveTypefaceStyle(fontWeight: String?, fontStyle: String?): Int {
        var style = if (fontStyle == "italic") Typeface.ITALIC else Typeface.NORMAL
        val weight = fontWeight ?: return style
        if (parseFontWeight(weight) >= 500) {
            style = style or Typeface.BOLD
        }
        return style
    }

    private fun resolveTextBreakStrategy(value: String?): Int {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return 0
        return when (value) {
            "balanced" -> Layout.BREAK_STRATEGY_BALANCED
            "simple" -> Layout.BREAK_STRATEGY_SIMPLE
            else -> Layout.BREAK_STRATEGY_HIGH_QUALITY
        }
    }

    private fun resolveTextColor(value: String?): Int? {
        if (value.isNullOrBlank()) return null
        return runCatching { Color.parseColor(value) }.getOrNull()
    }

    private fun resolveEllipsize(mode: String?, maxLines: Int): TextUtils.TruncateAt? {
        if (maxLines <= 0 || maxLines == Int.MAX_VALUE) return null
        return when (mode) {
            "clip" -> null
            "head" -> TextUtils.TruncateAt.START
            "middle" -> TextUtils.TruncateAt.MIDDLE
            else -> TextUtils.TruncateAt.END
        }
    }

    private fun scale(value: Double, allowFontScaling: Boolean, defaultValue: Double): Float {
        val measure = if (value.isNaN()) defaultValue else value
        return if (allowFontScaling) PixelUtil.toPixelFromSP(measure.toFloat()) else PixelUtil.toPixelFromDIP(measure.toFloat())
    }

    private fun currentDensity(): Double {
        return DisplayMetricsHolder.getWindowDisplayMetrics().density.toDouble()
    }

    private fun Double.toDp(): Double {
        return this / currentDensity()
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

    private const val PACKED_LAYOUT_SIZE = 4
    private const val PACKED_LINE_SIZE = 4
}
