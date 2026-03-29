package com.rnpretext

import android.graphics.Canvas
import android.graphics.Typeface
import android.os.Build
import android.text.Layout
import android.text.Spannable
import android.text.SpannableString
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils
import android.text.style.LineHeightSpan
import android.text.style.MetricAffectingSpan
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.common.assets.ReactFontManager
import com.facebook.react.uimanager.DisplayMetricsHolder
import com.facebook.react.uimanager.PixelUtil
import com.facebook.react.views.text.ReactTypefaceUtils.parseFontWeight
import java.lang.ref.WeakReference
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.atomic.AtomicLong
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min

internal object RNPretextBindings {
    private val nextHandle = AtomicLong(1)
    private val nextGlyphFieldHandle = AtomicLong(1)
    private val preparedTexts = ConcurrentHashMap<Long, PreparedTextData>()
    private val glyphFields = ConcurrentHashMap<Long, GlyphFieldData>()
    private lateinit var reactContext: ReactApplicationContext

    private data class ResolvedTextStyle(
        val fallbackLineHeight: Double,
        val includeFontPadding: Boolean,
        val lineHeightPx: Float?,
        val textBreakStrategy: Int,
        val textColor: Int?,
        val textPaint: TextPaint,
    )

    private data class TextMeasureRunStyle(
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

    private data class TextMeasureRun(
        val end: Int,
        val start: Int,
        val style: TextMeasureRunStyle,
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

    internal data class GlyphFieldVariantData(
        val textPaint: TextPaint,
        val widthCache: MutableMap<Int, Float> = HashMap(),
        val yOffset: Float,
    )

    private data class GlyphFieldData(
        val columns: Int,
        val lineHeightPx: Float,
        val rows: Int,
        val textAlign: String?,
        val variants: List<GlyphFieldVariantData>,
        val views: CopyOnWriteArrayList<WeakReference<android.view.View>> = CopyOnWriteArrayList(),
        @Volatile var glyphs: String = "",
        @Volatile var variantIndices: ByteArray = ByteArray(0),
    )

    @JvmStatic
    fun initialize(context: ReactApplicationContext) {
        reactContext = context
    }

    @JvmStatic
    fun cleanup() {
        preparedTexts.clear()
        glyphFields.clear()
        nextHandle.set(1)
        nextGlyphFieldHandle.set(1)
    }

    @JvmStatic
    fun createGlyphField(
        columns: Int,
        rows: Int,
        fontFamily: String?,
        fontSize: Double,
        letterSpacing: Double,
        lineHeight: Double,
        textAlign: String?,
        variantColors: Array<String>,
        variantFontWeights: Array<String?>,
        variantFontStyles: Array<String?>,
    ): Long {
        require(columns > 0 && rows > 0) { "RNPretext: glyph field columns and rows must be positive." }
        require(fontSize > 0 && lineHeight > 0) { "RNPretext: glyph field fontSize and lineHeight must be positive." }
        require(variantColors.isNotEmpty() && variantColors.size <= 255) {
            "RNPretext: glyph field variants must contain between 1 and 255 entries."
        }
        require(variantColors.size == variantFontWeights.size && variantColors.size == variantFontStyles.size) {
            "RNPretext: glyph field variant arrays must stay aligned."
        }

        val variants =
            List(variantColors.size) { index ->
                val style =
                    resolveTextStyle(
                        color = variantColors[index],
                        fontFamily = fontFamily,
                        fontSize = fontSize,
                        fontWeight = variantFontWeights[index],
                        fontStyle = variantFontStyles[index],
                        letterSpacing = letterSpacing,
                        lineHeight = lineHeight,
                        allowFontScaling = false,
                        includeFontPadding = false,
                        tabularNumbers = false,
                        textBreakStrategy = null,
                    )
                val metrics = style.textPaint.fontMetrics
                GlyphFieldVariantData(
                    textPaint = style.textPaint,
                    yOffset = ((style.lineHeightPx ?: 0f) - (metrics.descent - metrics.ascent)) * 0.5f - metrics.ascent,
                )
            }

        val handle = nextGlyphFieldHandle.getAndIncrement()
        glyphFields[handle] =
            GlyphFieldData(
                columns = columns,
                lineHeightPx = PixelUtil.toPixelFromDIP(lineHeight.toFloat()),
                rows = rows,
                textAlign = textAlign,
                variants = variants,
            )
        return handle
    }

    @JvmStatic
    fun updateGlyphField(handle: Long, glyphs: String, variantIndices: ByteArray) {
        val field = glyphFields[handle] ?: error("RNPretext: attempted to use an invalid glyph field handle.")
        val cellCount = field.columns * field.rows
        require(glyphs.length == cellCount) { "RNPretext: glyph field glyphs length must match columns * rows." }
        require(variantIndices.size == cellCount) { "RNPretext: glyph field variantIndices length must match columns * rows." }
        variantIndices.forEach { variantIndex ->
            require((variantIndex.toInt() and 0xFF) < field.variants.size) {
                "RNPretext: glyph field variant index exceeded the configured variant count."
            }
        }

        field.glyphs = glyphs
        field.variantIndices = variantIndices.copyOf()
        invalidateGlyphFieldViews(field)
    }

    @JvmStatic
    fun releaseGlyphField(handle: Long) {
        glyphFields.remove(handle)
    }

    internal fun registerGlyphFieldView(handle: Long, view: android.view.View) {
        if (handle <= 0L) return
        glyphFields[handle]?.views?.add(WeakReference(view))
    }

    internal fun unregisterGlyphFieldView(handle: Long, view: android.view.View) {
        if (handle <= 0L) return
        glyphFields[handle]?.views?.removeAll { reference ->
            val candidate = reference.get()
            candidate == null || candidate === view
        }
    }

    internal fun drawGlyphField(handle: Long, canvas: Canvas, width: Float, height: Float) {
        val field = glyphFields[handle] ?: return
        if (field.glyphs.isEmpty() || field.variantIndices.isEmpty()) return

        val topInset = max(0f, (height - field.rows * field.lineHeightPx) * 0.5f)
        for (row in 0 until field.rows) {
            val rowWidth = glyphFieldRowWidth(field, row)
            var x =
                when (field.textAlign) {
                    "right" -> width - rowWidth
                    "center" -> (width - rowWidth) * 0.5f
                    else -> 0f
                }
            val rowStart = row * field.columns

            for (column in 0 until field.columns) {
                val cellIndex = rowStart + column
                val glyph = field.glyphs[cellIndex].toString()
                val variant = field.variants[field.variantIndices[cellIndex].toInt() and 0xFF]
                val glyphWidth = measureGlyphWidth(variant, glyph)
                val baseline = topInset + row * field.lineHeightPx + variant.yOffset
                canvas.drawText(glyph, x, baseline, variant.textPaint)
                x += glyphWidth
            }
        }
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
    fun prepareWithRuns(
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
        runStarts: IntArray,
        runEnds: IntArray,
        runStyleMasks: IntArray,
        runColors: Array<String?>,
        runFontFamilies: Array<String?>,
        runFontSizes: DoubleArray,
        runFontWeights: Array<String?>,
        runFontStyles: Array<String?>,
        runLetterSpacings: DoubleArray,
        runLineHeights: DoubleArray,
        runTabularNumbers: BooleanArray,
    ): Long {
        val baseStyle = resolveTextStyle(
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
        val runs =
            buildRuns(
                textLength = text.length,
                runStarts = runStarts,
                runEnds = runEnds,
                runStyleMasks = runStyleMasks,
                runColors = runColors,
                runFontFamilies = runFontFamilies,
                runFontSizes = runFontSizes,
                runFontWeights = runFontWeights,
                runFontStyles = runFontStyles,
                runLetterSpacings = runLetterSpacings,
                runLineHeights = runLineHeights,
                runTabularNumbers = runTabularNumbers,
            )

        val handle = nextHandle.getAndIncrement()
        preparedTexts[handle] =
            buildPreparedText(text, baseStyle, runs) { runStyle ->
                resolveTextStyle(
                    color = if (runStyle.hasColor) runStyle.color else color,
                    fontFamily = if (runStyle.hasFontFamily) runStyle.fontFamily else fontFamily,
                    fontSize = if (runStyle.hasFontSize) runStyle.fontSize else fontSize,
                    fontWeight = if (runStyle.hasFontWeight) runStyle.fontWeight else fontWeight,
                    fontStyle = if (runStyle.hasFontStyle) runStyle.fontStyle else fontStyle,
                    letterSpacing = if (runStyle.hasLetterSpacing) runStyle.letterSpacing else letterSpacing,
                    lineHeight = if (runStyle.hasLineHeight) runStyle.lineHeight else lineHeight,
                    allowFontScaling = allowFontScaling,
                    includeFontPadding = includeFontPadding,
                    tabularNumbers = if (runStyle.hasTabularNumbers) runStyle.tabularNumbers else tabularNumbers,
                    textBreakStrategy = textBreakStrategy,
                )
            }
        return handle
    }

    @JvmStatic
    fun prepareBatchWithRuns(
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
        runCounts: IntArray,
        runStarts: IntArray,
        runEnds: IntArray,
        runStyleMasks: IntArray,
        runColors: Array<String?>,
        runFontFamilies: Array<String?>,
        runFontSizes: DoubleArray,
        runFontWeights: Array<String?>,
        runFontStyles: Array<String?>,
        runLetterSpacings: DoubleArray,
        runLineHeights: DoubleArray,
        runTabularNumbers: BooleanArray,
    ): LongArray {
        val baseStyle = resolveTextStyle(
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
        val runsByText =
            buildRunsByText(
                texts = texts,
                runCounts = runCounts,
                runStarts = runStarts,
                runEnds = runEnds,
                runStyleMasks = runStyleMasks,
                runColors = runColors,
                runFontFamilies = runFontFamilies,
                runFontSizes = runFontSizes,
                runFontWeights = runFontWeights,
                runFontStyles = runFontStyles,
                runLetterSpacings = runLetterSpacings,
                runLineHeights = runLineHeights,
                runTabularNumbers = runTabularNumbers,
            )

        return LongArray(texts.size) { index ->
            val handle = nextHandle.getAndIncrement()
            preparedTexts[handle] =
                buildPreparedText(texts[index], baseStyle, runsByText[index]) { runStyle ->
                    resolveTextStyle(
                        color = if (runStyle.hasColor) runStyle.color else color,
                        fontFamily = if (runStyle.hasFontFamily) runStyle.fontFamily else fontFamily,
                        fontSize = if (runStyle.hasFontSize) runStyle.fontSize else fontSize,
                        fontWeight = if (runStyle.hasFontWeight) runStyle.fontWeight else fontWeight,
                        fontStyle = if (runStyle.hasFontStyle) runStyle.fontStyle else fontStyle,
                        letterSpacing = if (runStyle.hasLetterSpacing) runStyle.letterSpacing else letterSpacing,
                        lineHeight = if (runStyle.hasLineHeight) runStyle.lineHeight else lineHeight,
                        allowFontScaling = allowFontScaling,
                        includeFontPadding = includeFontPadding,
                        tabularNumbers = if (runStyle.hasTabularNumbers) runStyle.tabularNumbers else tabularNumbers,
                        textBreakStrategy = textBreakStrategy,
                    )
                }
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
    fun measureWidthWithRuns(
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
        runStarts: IntArray,
        runEnds: IntArray,
        runStyleMasks: IntArray,
        runColors: Array<String?>,
        runFontFamilies: Array<String?>,
        runFontSizes: DoubleArray,
        runFontWeights: Array<String?>,
        runFontStyles: Array<String?>,
        runLetterSpacings: DoubleArray,
        runLineHeights: DoubleArray,
        runTabularNumbers: BooleanArray,
    ): Double {
        val baseStyle = resolveTextStyle(
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
        val runs =
            buildRuns(
                textLength = text.length,
                runStarts = runStarts,
                runEnds = runEnds,
                runStyleMasks = runStyleMasks,
                runColors = runColors,
                runFontFamilies = runFontFamilies,
                runFontSizes = runFontSizes,
                runFontWeights = runFontWeights,
                runFontStyles = runFontStyles,
                runLetterSpacings = runLetterSpacings,
                runLineHeights = runLineHeights,
                runTabularNumbers = runTabularNumbers,
            )
        val prepared =
            buildPreparedText(text, baseStyle, runs) { runStyle ->
                resolveTextStyle(
                    color = if (runStyle.hasColor) runStyle.color else color,
                    fontFamily = if (runStyle.hasFontFamily) runStyle.fontFamily else fontFamily,
                    fontSize = if (runStyle.hasFontSize) runStyle.fontSize else fontSize,
                    fontWeight = if (runStyle.hasFontWeight) runStyle.fontWeight else fontWeight,
                    fontStyle = if (runStyle.hasFontStyle) runStyle.fontStyle else fontStyle,
                    letterSpacing = if (runStyle.hasLetterSpacing) runStyle.letterSpacing else letterSpacing,
                    lineHeight = if (runStyle.hasLineHeight) runStyle.lineHeight else lineHeight,
                    allowFontScaling = allowFontScaling,
                    includeFontPadding = includeFontPadding,
                    tabularNumbers = if (runStyle.hasTabularNumbers) runStyle.tabularNumbers else tabularNumbers,
                    textBreakStrategy = textBreakStrategy,
                )
            }
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
    fun measureWithRuns(
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
        runStarts: IntArray,
        runEnds: IntArray,
        runStyleMasks: IntArray,
        runColors: Array<String?>,
        runFontFamilies: Array<String?>,
        runFontSizes: DoubleArray,
        runFontWeights: Array<String?>,
        runFontStyles: Array<String?>,
        runLetterSpacings: DoubleArray,
        runLineHeights: DoubleArray,
        runTabularNumbers: BooleanArray,
    ): DoubleArray {
        val baseStyle = resolveTextStyle(
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
        val runs =
            buildRuns(
                textLength = text.length,
                runStarts = runStarts,
                runEnds = runEnds,
                runStyleMasks = runStyleMasks,
                runColors = runColors,
                runFontFamilies = runFontFamilies,
                runFontSizes = runFontSizes,
                runFontWeights = runFontWeights,
                runFontStyles = runFontStyles,
                runLetterSpacings = runLetterSpacings,
                runLineHeights = runLineHeights,
                runTabularNumbers = runTabularNumbers,
            )
        val prepared =
            buildPreparedText(text, baseStyle, runs) { runStyle ->
                resolveTextStyle(
                    color = if (runStyle.hasColor) runStyle.color else color,
                    fontFamily = if (runStyle.hasFontFamily) runStyle.fontFamily else fontFamily,
                    fontSize = if (runStyle.hasFontSize) runStyle.fontSize else fontSize,
                    fontWeight = if (runStyle.hasFontWeight) runStyle.fontWeight else fontWeight,
                    fontStyle = if (runStyle.hasFontStyle) runStyle.fontStyle else fontStyle,
                    letterSpacing = if (runStyle.hasLetterSpacing) runStyle.letterSpacing else letterSpacing,
                    lineHeight = if (runStyle.hasLineHeight) runStyle.lineHeight else lineHeight,
                    allowFontScaling = allowFontScaling,
                    includeFontPadding = includeFontPadding,
                    tabularNumbers = if (runStyle.hasTabularNumbers) runStyle.tabularNumbers else tabularNumbers,
                    textBreakStrategy = textBreakStrategy,
                )
            }
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
    fun measureBatchWithRuns(
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
        runCounts: IntArray,
        runStarts: IntArray,
        runEnds: IntArray,
        runStyleMasks: IntArray,
        runColors: Array<String?>,
        runFontFamilies: Array<String?>,
        runFontSizes: DoubleArray,
        runFontWeights: Array<String?>,
        runFontStyles: Array<String?>,
        runLetterSpacings: DoubleArray,
        runLineHeights: DoubleArray,
        runTabularNumbers: BooleanArray,
    ): DoubleArray {
        val baseStyle = resolveTextStyle(
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
        val runsByText =
            buildRunsByText(
                texts = texts,
                runCounts = runCounts,
                runStarts = runStarts,
                runEnds = runEnds,
                runStyleMasks = runStyleMasks,
                runColors = runColors,
                runFontFamilies = runFontFamilies,
                runFontSizes = runFontSizes,
                runFontWeights = runFontWeights,
                runFontStyles = runFontStyles,
                runLetterSpacings = runLetterSpacings,
                runLineHeights = runLineHeights,
                runTabularNumbers = runTabularNumbers,
            )
        val packed = DoubleArray(texts.size * PACKED_LAYOUT_SIZE)
        texts.forEachIndexed { index, text ->
            packLayoutInto(
                packed,
                index * PACKED_LAYOUT_SIZE,
                buildLayout(
                    buildPreparedText(text, baseStyle, runsByText[index]) { runStyle ->
                        resolveTextStyle(
                            color = if (runStyle.hasColor) runStyle.color else color,
                            fontFamily = if (runStyle.hasFontFamily) runStyle.fontFamily else fontFamily,
                            fontSize = if (runStyle.hasFontSize) runStyle.fontSize else fontSize,
                            fontWeight = if (runStyle.hasFontWeight) runStyle.fontWeight else fontWeight,
                            fontStyle = if (runStyle.hasFontStyle) runStyle.fontStyle else fontStyle,
                            letterSpacing = if (runStyle.hasLetterSpacing) runStyle.letterSpacing else letterSpacing,
                            lineHeight = if (runStyle.hasLineHeight) runStyle.lineHeight else lineHeight,
                            allowFontScaling = allowFontScaling,
                            includeFontPadding = includeFontPadding,
                            tabularNumbers = if (runStyle.hasTabularNumbers) runStyle.tabularNumbers else tabularNumbers,
                            textBreakStrategy = textBreakStrategy,
                        )
                    },
                    width,
                    maxLines,
                    ellipsizeMode,
                    includeLines = false,
                ),
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

    private fun invalidateGlyphFieldViews(field: GlyphFieldData) {
        field.views.removeAll { reference ->
            val view = reference.get()
            if (view == null) {
                true
            } else {
                view.postInvalidateOnAnimation()
                false
            }
        }
    }

    private fun measureGlyphWidth(variant: GlyphFieldVariantData, glyph: String): Float {
        val codePoint = glyph.firstOrNull()?.code ?: 0
        return variant.widthCache.getOrPut(codePoint) {
            variant.textPaint.measureText(glyph)
        }
    }

    private fun glyphFieldRowWidth(field: GlyphFieldData, row: Int): Float {
        var width = 0f
        val rowStart = row * field.columns
        for (column in 0 until field.columns) {
            val cellIndex = rowStart + column
            val glyph = field.glyphs[cellIndex].toString()
            val variant = field.variants[field.variantIndices[cellIndex].toInt() and 0xFF]
            width += measureGlyphWidth(variant, glyph)
        }
        return width
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
                        Spannable.SPAN_INCLUSIVE_INCLUSIVE,
                    )
                }
            }

        return PreparedTextData(
            style = style,
            text = text,
            textWithLineHeight = textWithLineHeight,
        )
    }

    private fun buildPreparedText(
        text: String,
        style: ResolvedTextStyle,
        runs: List<TextMeasureRun>,
        resolveRunStyle: (TextMeasureRunStyle) -> ResolvedTextStyle,
    ): PreparedTextData {
        val textWithLineHeight =
            if (text.isEmpty()) {
                text
            } else {
                buildStyledText(text, style, runs, resolveRunStyle)
            }

        return PreparedTextData(
            style = style,
            text = text,
            textWithLineHeight = textWithLineHeight,
        )
    }

    private fun buildStyledText(
        text: String,
        baseStyle: ResolvedTextStyle,
        runs: List<TextMeasureRun>,
        resolveRunStyle: (TextMeasureRunStyle) -> ResolvedTextStyle,
    ): CharSequence {
        val styledText = SpannableString(text)

        if (baseStyle.lineHeightPx != null) {
            applyBaseLineHeightSpans(styledText, text.length, baseStyle.lineHeightPx, runs)
        }

        runs.forEach { run ->
            val runStyle = resolveRunStyle(run.style)
            styledText.setSpan(
                RNPretextTextPaintSpan(runStyle.textPaint),
                run.start,
                run.end,
                Spannable.SPAN_EXCLUSIVE_EXCLUSIVE,
            )

            runStyle.lineHeightPx?.let { lineHeightPx ->
                styledText.setSpan(
                    RNPretextLineHeightSpan(lineHeightPx),
                    run.start,
                    run.end,
                    Spannable.SPAN_EXCLUSIVE_EXCLUSIVE,
                )
            }
        }

        return styledText
    }

    private fun applyBaseLineHeightSpans(
        styledText: SpannableString,
        textLength: Int,
        lineHeightPx: Float,
        runs: List<TextMeasureRun>,
    ) {
        var cursor = 0

        runs.forEach { run ->
            if (run.style.hasLineHeight && cursor < run.start) {
                styledText.setSpan(
                    RNPretextLineHeightSpan(lineHeightPx),
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
                RNPretextLineHeightSpan(lineHeightPx),
                cursor,
                textLength,
                Spannable.SPAN_EXCLUSIVE_EXCLUSIVE,
            )
        }
    }

    private fun buildRuns(
        textLength: Int,
        runStarts: IntArray,
        runEnds: IntArray,
        runStyleMasks: IntArray,
        runColors: Array<String?>,
        runFontFamilies: Array<String?>,
        runFontSizes: DoubleArray,
        runFontWeights: Array<String?>,
        runFontStyles: Array<String?>,
        runLetterSpacings: DoubleArray,
        runLineHeights: DoubleArray,
        runTabularNumbers: BooleanArray,
    ): List<TextMeasureRun> {
        requireAlignedRunArrays(
            runStarts.size,
            runEnds.size,
            runStyleMasks.size,
            runColors.size,
            runFontFamilies.size,
            runFontSizes.size,
            runFontWeights.size,
            runFontStyles.size,
            runLetterSpacings.size,
            runLineHeights.size,
            runTabularNumbers.size,
        )

        return buildRuns(
            textLength = textLength,
            runOffset = 0,
            runCount = runStarts.size,
            runStarts = runStarts,
            runEnds = runEnds,
            runStyleMasks = runStyleMasks,
            runColors = runColors,
            runFontFamilies = runFontFamilies,
            runFontSizes = runFontSizes,
            runFontWeights = runFontWeights,
            runFontStyles = runFontStyles,
            runLetterSpacings = runLetterSpacings,
            runLineHeights = runLineHeights,
            runTabularNumbers = runTabularNumbers,
        )
    }

    private fun buildRuns(
        textLength: Int,
        runOffset: Int,
        runCount: Int,
        runStarts: IntArray,
        runEnds: IntArray,
        runStyleMasks: IntArray,
        runColors: Array<String?>,
        runFontFamilies: Array<String?>,
        runFontSizes: DoubleArray,
        runFontWeights: Array<String?>,
        runFontStyles: Array<String?>,
        runLetterSpacings: DoubleArray,
        runLineHeights: DoubleArray,
        runTabularNumbers: BooleanArray,
    ): List<TextMeasureRun> {
        val runs = ArrayList<TextMeasureRun>(runCount)
        var previousEnd = 0

        for (relativeIndex in 0 until runCount) {
            val index = runOffset + relativeIndex
            val start = runStarts[index]
            val end = runEnds[index]
            val styleMask = runStyleMasks[index]

            require(styleMask != 0) { "RNPretext: each text run must override at least one inline style field." }
            require(start >= 0 && end <= textLength && end > start) {
                "RNPretext: text runs must stay within the source text and have positive length."
            }
            require(start >= previousEnd) { "RNPretext: text runs must be sorted and non-overlapping." }

            runs.add(
                TextMeasureRun(
                    end = end,
                    start = start,
                    style =
                        TextMeasureRunStyle(
                            color = runColors[index],
                            fontFamily = runFontFamilies[index],
                            fontSize = runFontSizes[index],
                            fontStyle = runFontStyles[index],
                            fontWeight = runFontWeights[index],
                            hasColor = styleMask and RUN_STYLE_HAS_COLOR != 0,
                            hasFontFamily = styleMask and RUN_STYLE_HAS_FONT_FAMILY != 0,
                            hasFontSize = styleMask and RUN_STYLE_HAS_FONT_SIZE != 0,
                            hasFontStyle = styleMask and RUN_STYLE_HAS_FONT_STYLE != 0,
                            hasFontWeight = styleMask and RUN_STYLE_HAS_FONT_WEIGHT != 0,
                            hasLetterSpacing = styleMask and RUN_STYLE_HAS_LETTER_SPACING != 0,
                            hasLineHeight = styleMask and RUN_STYLE_HAS_LINE_HEIGHT != 0,
                            hasTabularNumbers = styleMask and RUN_STYLE_HAS_TABULAR_NUMBERS != 0,
                            letterSpacing = runLetterSpacings[index],
                            lineHeight = runLineHeights[index],
                            tabularNumbers = runTabularNumbers[index],
                        ),
                ),
            )
            previousEnd = end
        }

        return runs
    }

    private fun buildRunsByText(
        texts: Array<String>,
        runCounts: IntArray,
        runStarts: IntArray,
        runEnds: IntArray,
        runStyleMasks: IntArray,
        runColors: Array<String?>,
        runFontFamilies: Array<String?>,
        runFontSizes: DoubleArray,
        runFontWeights: Array<String?>,
        runFontStyles: Array<String?>,
        runLetterSpacings: DoubleArray,
        runLineHeights: DoubleArray,
        runTabularNumbers: BooleanArray,
    ): List<List<TextMeasureRun>> {
        require(runCounts.size == texts.size) { "RNPretext: batch text runs must align with the batch text input length." }
        val totalRunCount = runCounts.sum()
        requireAlignedRunArrays(
            totalRunCount,
            runEnds.size,
            runStyleMasks.size,
            runColors.size,
            runFontFamilies.size,
            runFontSizes.size,
            runFontWeights.size,
            runFontStyles.size,
            runLetterSpacings.size,
            runLineHeights.size,
            runTabularNumbers.size,
        )

        val runsByText = ArrayList<List<TextMeasureRun>>(texts.size)
        var runOffset = 0

        texts.forEachIndexed { index, text ->
            val runCount = runCounts[index]
            runsByText.add(
                buildRuns(
                    textLength = text.length,
                    runOffset = runOffset,
                    runCount = runCount,
                    runStarts = runStarts,
                    runEnds = runEnds,
                    runStyleMasks = runStyleMasks,
                    runColors = runColors,
                    runFontFamilies = runFontFamilies,
                    runFontSizes = runFontSizes,
                    runFontWeights = runFontWeights,
                    runFontStyles = runFontStyles,
                    runLetterSpacings = runLetterSpacings,
                    runLineHeights = runLineHeights,
                    runTabularNumbers = runTabularNumbers,
                ),
            )
            runOffset += runCount
        }

        return runsByText
    }

    private fun requireAlignedRunArrays(expectedSize: Int, vararg actualSizes: Int) {
        actualSizes.forEach { actualSize ->
            require(actualSize == expectedSize) { "RNPretext: run payload arrays must stay aligned." }
        }
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
        return RNPretextColorParser.parse(value)
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

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                textPaint.fontFeatureSettings = spanPaint.fontFeatureSettings
            }
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

    private const val PACKED_LAYOUT_SIZE = 4
    private const val PACKED_LINE_SIZE = 4
    private const val RUN_STYLE_HAS_COLOR = 1 shl 0
    private const val RUN_STYLE_HAS_FONT_FAMILY = 1 shl 1
    private const val RUN_STYLE_HAS_FONT_SIZE = 1 shl 2
    private const val RUN_STYLE_HAS_FONT_STYLE = 1 shl 3
    private const val RUN_STYLE_HAS_FONT_WEIGHT = 1 shl 4
    private const val RUN_STYLE_HAS_LETTER_SPACING = 1 shl 5
    private const val RUN_STYLE_HAS_LINE_HEIGHT = 1 shl 6
    private const val RUN_STYLE_HAS_TABULAR_NUMBERS = 1 shl 7
}
