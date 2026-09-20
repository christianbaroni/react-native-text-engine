package com.rntextengine

import android.graphics.Canvas
import android.graphics.text.LineBreaker
import android.graphics.text.MeasuredText
import android.graphics.Typeface
import android.os.Build
import android.text.BoringLayout
import android.text.Layout
import android.text.Spannable
import android.text.SpannableString
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils
import android.util.LongSparseArray
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.common.assets.ReactFontManager
import com.facebook.react.uimanager.PixelUtil
import com.facebook.react.views.text.ReactTypefaceUtils.parseFontWeight
import java.lang.ref.WeakReference
import java.nio.ByteBuffer
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.atomic.AtomicLong
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min

internal object RNTextEngineBindings {
    private val nextHandle = AtomicLong(1)
    private val nextGlyphFieldHandle = AtomicLong(1)
    private val preparedTexts = ConcurrentHashMap<Long, PreparedTextData>()
    private val glyphFields = ConcurrentHashMap<Long, GlyphFieldData>()
    private lateinit var reactContext: ReactApplicationContext
    private val highQualityLineBreaker by lazy { buildLineBreaker(Layout.BREAK_STRATEGY_HIGH_QUALITY) }
    private val simpleLineBreaker by lazy { buildLineBreaker(Layout.BREAK_STRATEGY_SIMPLE) }
    private val balancedLineBreaker by lazy { buildLineBreaker(Layout.BREAK_STRATEGY_BALANCED) }
    private val lineBreakerConstraints = ThreadLocal<LineBreaker.ParagraphConstraints>()
    private val lineBreakerScratchBuffers = ThreadLocal<LineBreakerScratchBuffers>()

    private data class ResolvedTextStyle(
        val fallbackLineHeight: Double,
        val includeFontPadding: Boolean,
        val lineHeightPx: Float?,
        val textBreakStrategy: Int,
        val textColor: Int?,
        val textPaint: TextPaint,
    )

    private data class TextStyleConfig(
        val allowFontScaling: Boolean,
        val color: String?,
        val fontFamily: String?,
        val fontSize: Double,
        val fontStyle: String?,
        val fontWeight: String?,
        val includeFontPadding: Boolean,
        val letterSpacing: Double,
        val lineHeight: Double,
        val tabularNumbers: Boolean,
        val textBreakStrategy: String?,
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
        val hasInlineStyleRuns: Boolean,
        @Volatile var cachedLayoutText: CharSequence? = null,
        @Volatile var layoutQueryOwner: LayoutQueryOwner? = null,
        @Volatile var plainNextLineOwner: PlainNextLineOwner? = null,
        val style: ResolvedTextStyle,
        val text: String,
        val textWithLineHeight: CharSequence,
        val uniformCapHeightPx: Float?,
    )

    private class LayoutQueryOwner {
        val layoutsByKey = LongSparseArray<LayoutInfo>()
    }

    private data class PlainLineInfo(
        val end: Int,
        val widthPx: Float,
    )

    private class PlainNextLineOwner {
        val linesByKey = LongSparseArray<PlainLineInfo>()
        @Volatile var capHeightPx = Float.NaN
        @Volatile var measurementChars: CharArray? = null
    }

    private class LineBreakerScratchBuffers(
        var lengths: IntArray = IntArray(8),
        var buffers: Array<CharArray?> = arrayOfNulls(8),
        var size: Int = 0,
    ) {
        fun resolve(length: Int): CharArray {
            for (index in 0 until size) {
                if (lengths[index] == length) return requireNotNull(buffers[index])
            }

            if (size == lengths.size) {
                lengths = lengths.copyOf(size * 2)
                buffers = buffers.copyOf(size * 2)
            }

            return CharArray(length).also { buffer ->
                lengths[size] = length
                buffers[size] = buffer
                size += 1
            }
        }
    }

    internal enum class TextMountMode {
        NATIVE,
        SPANNABLE,
    }

    internal data class PreparedTextViewData(
        val baseCapHeightPx: Float,
        val includeFontPadding: Boolean,
        val lineHeightPx: Float?,
        val mountMode: TextMountMode,
        val text: CharSequence,
        val textPaint: TextPaint,
        val uniformCapHeightPx: Float?,
    )

    internal data class GlyphFieldVariantData(
        val paletteWidths: FloatArray? = null,
        val textPaint: TextPaint,
        val widthCache: MutableMap<Int, Float> = HashMap(),
        val yOffset: Float,
    )

    private data class GlyphFieldRunData(
        val text: String,
        val variant: GlyphFieldVariantData,
        val variantIndex: Int,
        val width: Float,
    )

    private data class GlyphFieldRowData(
        val runs: List<GlyphFieldRunData>,
        val width: Float,
    )

    private data class GlyphFieldData(
        val columns: Int,
        @Volatile var currentGlyphs: String? = null,
        @Volatile var currentGlyphIndices: ByteArray? = null,
        @Volatile var currentVariantIndices: ByteArray? = null,
        @Volatile var glyphIndexBuffer: ByteBuffer? = null,
        val glyphPaletteChars: CharArray?,
        val glyphPalette: String?,
        val lineHeightPx: Float,
        val rows: Int,
        val textAlign: String?,
        @Volatile var variantIndexBuffer: ByteBuffer? = null,
        val variants: List<GlyphFieldVariantData>,
        val views: CopyOnWriteArrayList<WeakReference<android.view.View>> = CopyOnWriteArrayList(),
        @Volatile var renderedRows: List<GlyphFieldRowData> = emptyList(),
    )

    private val defaultTextPaintColor = TextPaint(TextPaint.ANTI_ALIAS_FLAG).color

    @JvmStatic
    fun initialize(context: ReactApplicationContext) {
        reactContext = context
    }

    @JvmStatic
    fun cleanup() {
        preparedTexts.clear()
        glyphFields.clear()
    }

    @JvmStatic
    fun createGlyphField(
        columns: Int,
        rows: Int,
        fontFamily: String?,
        fontSize: Double,
        glyphPalette: String?,
        letterSpacing: Double,
        lineHeight: Double,
        textAlign: String?,
        variantColors: Array<String>,
        variantFontWeights: Array<String?>,
        variantFontStyles: Array<String?>,
    ): Long {
        require(columns > 0 && rows > 0) { "RNTextEngine: glyph field columns and rows must be positive." }
        require(fontSize > 0 && lineHeight > 0) { "RNTextEngine: glyph field fontSize and lineHeight must be positive." }
        require(variantColors.isNotEmpty() && variantColors.size <= 255) {
            "RNTextEngine: glyph field variants must contain between 1 and 255 entries."
        }
        require(glyphPalette == null || (glyphPalette.isNotEmpty() && glyphPalette.length <= 256)) {
            "RNTextEngine: glyph field glyphPalette must contain between 1 and 256 UTF-16 code units."
        }
        require(variantColors.size == variantFontWeights.size && variantColors.size == variantFontStyles.size) {
            "RNTextEngine: glyph field variant arrays must stay aligned."
        }
        val glyphPaletteChars = glyphPalette?.toCharArray()

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
                    paletteWidths =
                        glyphPaletteChars?.let { chars ->
                            FloatArray(chars.size) { glyphIndex ->
                                style.textPaint.measureText(chars[glyphIndex].toString())
                            }
                        },
                    textPaint = style.textPaint,
                    yOffset = ((style.lineHeightPx ?: 0f) - (metrics.descent - metrics.ascent)) * 0.5f - metrics.ascent,
                )
            }

        val handle = nextGlyphFieldHandle.getAndIncrement()
        glyphFields[handle] =
            GlyphFieldData(
                columns = columns,
                glyphPaletteChars = glyphPaletteChars,
                glyphPalette = glyphPalette,
                lineHeightPx = PixelUtil.toPixelFromDIP(lineHeight.toFloat()),
                rows = rows,
                textAlign = textAlign,
                variants = variants,
            )
        return handle
    }

    @JvmStatic
    fun getGlyphFieldCellCount(handle: Long): Int {
        val field = glyphFields[handle] ?: error("RNTextEngine: attempted to use an invalid glyph field handle.")
        return field.columns * field.rows
    }

    @JvmStatic
    fun updateGlyphField(handle: Long, glyphs: String, variantIndices: ByteArray) {
        val field = glyphFields[handle] ?: error("RNTextEngine: attempted to use an invalid glyph field handle.")
        val cellCount = field.columns * field.rows
        require(glyphs.length == cellCount) { "RNTextEngine: glyph field glyphs length must match columns * rows." }
        require(variantIndices.size == cellCount) { "RNTextEngine: glyph field variantIndices length must match columns * rows." }
        variantIndices.forEach { variantIndex ->
            require((variantIndex.toInt() and 0xFF) < field.variants.size) {
                "RNTextEngine: glyph field variant index exceeded the configured variant count."
            }
        }
        if (field.views.isEmpty()) {
            field.currentGlyphs = glyphs
            field.currentGlyphIndices = null
            field.currentVariantIndices = variantIndices.copyOf()
            field.renderedRows = emptyList()
            return
        }

        val nextRows = buildGlyphFieldRows(field, glyphs, variantIndices)
        field.currentGlyphs = null
        field.currentGlyphIndices = null
        field.currentVariantIndices = null
        val dirtyRanges = buildGlyphFieldDirtyRanges(field.renderedRows, nextRows, field.rows)
        field.renderedRows = nextRows
        invalidateGlyphFieldViews(field, dirtyRanges)
    }

    @JvmStatic
    fun updateGlyphFieldIndices(handle: Long, glyphIndices: ByteArray, variantIndices: ByteArray) {
        val field = glyphFields[handle] ?: error("RNTextEngine: attempted to use an invalid glyph field handle.")
        val glyphPalette = field.glyphPalette ?: error("RNTextEngine: updateGlyphFieldIndices() requires glyphPalette on the glyph field config.")
        val cellCount = field.columns * field.rows
        require(glyphIndices.size == cellCount) { "RNTextEngine: glyph field glyphIndices length must match columns * rows." }
        require(variantIndices.size == cellCount) { "RNTextEngine: glyph field variantIndices length must match columns * rows." }
        val changedRows = resolveGlyphFieldChangedRows(field, glyphPalette, glyphIndices, variantIndices)
        if (!changedRows.any { it }) return
        field.currentGlyphs = null
        if (field.views.isEmpty()) {
            field.renderedRows = emptyList()
            return
        }

        val nextRows = rebuildChangedGlyphFieldRows(field, glyphPalette, changedRows)
        field.renderedRows = nextRows
        val dirtyRanges = buildGlyphFieldDirtyRanges(changedRows)
        invalidateGlyphFieldViews(field, dirtyRanges)
    }

    @JvmStatic
    fun attachGlyphFieldBuffers(handle: Long, glyphIndices: ByteBuffer, variantIndices: ByteBuffer) {
        val field = glyphFields[handle] ?: error("RNTextEngine: attempted to use an invalid glyph field handle.")
        val cellCount = field.columns * field.rows
        require(glyphIndices.capacity() == cellCount && variantIndices.capacity() == cellCount) {
            "RNTextEngine: glyph field buffers must match columns * rows."
        }
        field.glyphIndexBuffer = glyphIndices
        field.variantIndexBuffer = variantIndices
    }

    @JvmStatic
    fun commitGlyphFieldBuffers(handle: Long) {
        val field = glyphFields[handle] ?: error("RNTextEngine: attempted to use an invalid glyph field handle.")
        val glyphPalette = field.glyphPalette ?: error("RNTextEngine: commitGlyphFieldBuffers() requires glyphPalette on the glyph field config.")
        val glyphIndices = field.glyphIndexBuffer ?: error("RNTextEngine: attempted to use glyph field buffers before creating them.")
        val variantIndices = field.variantIndexBuffer ?: error("RNTextEngine: attempted to use glyph field buffers before creating them.")
        val cellCount = field.columns * field.rows
        require(glyphIndices.capacity() == cellCount && variantIndices.capacity() == cellCount) {
            "RNTextEngine: glyph field buffers must match columns * rows."
        }
        val changedRows = resolveGlyphFieldChangedRows(field, glyphPalette, glyphIndices, variantIndices)
        if (!changedRows.any { it }) return
        field.currentGlyphs = null
        if (field.views.isEmpty()) {
            field.renderedRows = emptyList()
            return
        }

        val nextRows = rebuildChangedGlyphFieldRows(field, glyphPalette, changedRows)
        field.renderedRows = nextRows
        val dirtyRanges = buildGlyphFieldDirtyRanges(changedRows)
        invalidateGlyphFieldViews(field, dirtyRanges)
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
        val rows = resolveGlyphFieldRenderedRows(field)
        if (rows.isEmpty()) return

        val topInset = max(0f, (height - field.rows * field.lineHeightPx) * 0.5f)
        val clipBounds = canvas.clipBounds
        val startRow = max(0, floor((clipBounds.top - topInset) / field.lineHeightPx).toInt())
        val endRow = min(field.rows, ceil((clipBounds.bottom - topInset) / field.lineHeightPx).toInt())

        for (row in startRow until endRow) {
            val rowData = rows.getOrNull(row) ?: continue
            var x =
                when (field.textAlign) {
                    "right" -> width - rowData.width
                    "center" -> (width - rowData.width) * 0.5f
                    else -> 0f
                }

            for (run in rowData.runs) {
                val baseline = topInset + row * field.lineHeightPx + run.variant.yOffset
                canvas.drawText(run.text, x, baseline, run.variant.textPaint)
                x += run.width
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
    fun prepareTextView(
        text: String,
        textTransform: String?,
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
        preparedTexts[handle] = buildPreparedTextForTextView(text, textTransform, style)
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
        val baseConfig =
            TextStyleConfig(
                allowFontScaling = allowFontScaling,
                color = color,
                fontFamily = fontFamily,
                fontSize = fontSize,
                fontStyle = fontStyle,
                fontWeight = fontWeight,
                includeFontPadding = includeFontPadding,
                letterSpacing = letterSpacing,
                lineHeight = lineHeight,
                tabularNumbers = tabularNumbers,
                textBreakStrategy = textBreakStrategy,
            )
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
            buildPreparedText(text, baseStyle, runs) { runStyle -> resolveRunTextStyle(baseStyle, baseConfig, runStyle) }
        return handle
    }

    @JvmStatic
    fun prepareTextViewWithRuns(
        text: String,
        textTransform: String?,
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
        val baseConfig =
            TextStyleConfig(
                allowFontScaling = allowFontScaling,
                color = color,
                fontFamily = fontFamily,
                fontSize = fontSize,
                fontStyle = fontStyle,
                fontWeight = fontWeight,
                includeFontPadding = includeFontPadding,
                letterSpacing = letterSpacing,
                lineHeight = lineHeight,
                tabularNumbers = tabularNumbers,
                textBreakStrategy = textBreakStrategy,
            )
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
            buildPreparedTextForTextView(text, textTransform, baseStyle, runs) { runStyle ->
                resolveRunTextStyle(baseStyle, baseConfig, runStyle)
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
        val baseConfig =
            TextStyleConfig(
                allowFontScaling = allowFontScaling,
                color = color,
                fontFamily = fontFamily,
                fontSize = fontSize,
                fontStyle = fontStyle,
                fontWeight = fontWeight,
                includeFontPadding = includeFontPadding,
                letterSpacing = letterSpacing,
                lineHeight = lineHeight,
                tabularNumbers = tabularNumbers,
                textBreakStrategy = textBreakStrategy,
            )
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
                    resolveRunTextStyle(baseStyle, baseConfig, runStyle)
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
        handles.forEach { handle ->
            preparedTexts.remove(handle)
        }
    }

    @JvmStatic
    fun measurePreparedWidth(handle: Long): Double {
        return measureIntrinsicWidth(requirePrepared(handle))
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
        return measureIntrinsicWidth(prepared)
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
        val baseConfig =
            TextStyleConfig(
                allowFontScaling = allowFontScaling,
                color = color,
                fontFamily = fontFamily,
                fontSize = fontSize,
                fontStyle = fontStyle,
                fontWeight = fontWeight,
                includeFontPadding = includeFontPadding,
                letterSpacing = letterSpacing,
                lineHeight = lineHeight,
                tabularNumbers = tabularNumbers,
                textBreakStrategy = textBreakStrategy,
            )
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
            buildPreparedText(text, baseStyle, runs) { runStyle -> resolveRunTextStyle(baseStyle, baseConfig, runStyle) }
        return measureIntrinsicWidth(prepared)
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
        anchorToCapHeight: Boolean,
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
        val context = resolveOneShotPlainLayoutContext(style, width, maxLines, ellipsizeMode, anchorToCapHeight)
        return packLayout(buildOneShotPlainLayout(text, style, context, anchorToCapHeight, includeLines = false))
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
        anchorToCapHeight: Boolean,
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
        val baseConfig =
            TextStyleConfig(
                allowFontScaling = allowFontScaling,
                color = color,
                fontFamily = fontFamily,
                fontSize = fontSize,
                fontStyle = fontStyle,
                fontWeight = fontWeight,
                includeFontPadding = includeFontPadding,
                letterSpacing = letterSpacing,
                lineHeight = lineHeight,
                tabularNumbers = tabularNumbers,
                textBreakStrategy = textBreakStrategy,
            )
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
            buildPreparedText(text, baseStyle, runs) { runStyle -> resolveRunTextStyle(baseStyle, baseConfig, runStyle) }
        val ellipsize = resolveEllipsize(ellipsizeMode, maxLines)
        return packLayout(buildLayout(prepared, width, maxLines, ellipsize, anchorToCapHeight, includeLines = false))
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
        anchorToCapHeight: Boolean,
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
        val context = resolveOneShotPlainLayoutContext(style, width, maxLines, ellipsizeMode, anchorToCapHeight)
        val sharedPaint = TextPaint(style.textPaint)
        for (index in texts.indices) {
            packLayoutInto(
                packed,
                index * PACKED_LAYOUT_SIZE,
                buildOneShotPlainLayout(texts[index], style, context, anchorToCapHeight, includeLines = false, reusablePaint = sharedPaint),
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
        anchorToCapHeight: Boolean,
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
        val baseConfig =
            TextStyleConfig(
                allowFontScaling = allowFontScaling,
                color = color,
                fontFamily = fontFamily,
                fontSize = fontSize,
                fontStyle = fontStyle,
                fontWeight = fontWeight,
                includeFontPadding = includeFontPadding,
                letterSpacing = letterSpacing,
                lineHeight = lineHeight,
                tabularNumbers = tabularNumbers,
                textBreakStrategy = textBreakStrategy,
            )
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
        val ellipsize = resolveEllipsize(ellipsizeMode, maxLines)
        val packed = DoubleArray(texts.size * PACKED_LAYOUT_SIZE)
        texts.forEachIndexed { index, text ->
            packLayoutInto(
                packed,
                index * PACKED_LAYOUT_SIZE,
                buildLayout(
                    buildPreparedText(text, baseStyle, runsByText[index]) { runStyle -> resolveRunTextStyle(baseStyle, baseConfig, runStyle) },
                    width,
                    maxLines,
                    ellipsize,
                    anchorToCapHeight,
                    includeLines = false,
                ),
            )
        }
        return packed
    }

    @JvmStatic
    fun measureTextView(handle: Long, width: Double, maxLines: Int, ellipsizeMode: Int, anchorToCapHeight: Boolean): Long {
        val ellipsize = resolveEllipsize(ellipsizeMode, maxLines)
        val layout = buildLayout(requirePrepared(handle), width, maxLines, ellipsize, anchorToCapHeight, includeLines = false)
        val widthBits = layout.width.toFloat().toRawBits().toLong()
        // Sign-extending a negative height would overwrite the packed width.
        val heightBits = layout.height.toFloat().toRawBits().toLong() and 0xFFFFFFFFL
        return (widthBits shl 32) or heightBits
    }

    @JvmStatic
    fun layout(handle: Long, width: Double, maxLines: Int, ellipsizeMode: String?, anchorToCapHeight: Boolean): DoubleArray {
        val prepared = requirePrepared(handle)
        val ellipsize = resolveEllipsize(ellipsizeMode, maxLines)
        return packLayout(buildLayout(prepared, width, maxLines, ellipsize, anchorToCapHeight, includeLines = false))
    }

    @JvmStatic
    fun layoutBatch(handles: LongArray, width: Double, maxLines: Int, ellipsizeMode: String?, anchorToCapHeight: Boolean): DoubleArray {
        val ellipsize = resolveEllipsize(ellipsizeMode, maxLines)
        val packed = DoubleArray(handles.size * PACKED_LAYOUT_SIZE)
        handles.forEachIndexed { index, handle ->
            packLayoutInto(
                packed,
                index * PACKED_LAYOUT_SIZE,
                buildLayout(requirePrepared(handle), width, maxLines, ellipsize, anchorToCapHeight, includeLines = false),
            )
        }
        return packed
    }

    @JvmStatic
    fun layoutLines(handle: Long, width: Double, maxLines: Int, ellipsizeMode: String?, anchorToCapHeight: Boolean): DoubleArray {
        val prepared = requirePrepared(handle)
        val ellipsize = resolveEllipsize(ellipsizeMode, maxLines)
        return packLayoutWithLines(buildLayout(prepared, width, maxLines, ellipsize, anchorToCapHeight, includeLines = true))
    }

    @JvmStatic
    fun layoutNextLine(handle: Long, start: Int, width: Double, anchorToCapHeight: Boolean): DoubleArray? {
        val prepared = requirePrepared(handle)
        val queryStart = resolveNextLineStart(prepared.text, start)
        if (queryStart < 0) return null
        resolvePlainNextLine(prepared, queryStart, width, anchorToCapHeight)?.let { return it }

        val text: CharSequence = if (prepared.hasInlineStyleRuns) prepared.textWithLineHeight else prepared.text
        if (queryStart >= text.length) return null

        val density = currentDensity()
        val layoutWidth = max(0.0, width) * density
        val textWidthPx = max(1, ceil(layoutWidth).toInt())
        val paint = if (prepared.hasInlineStyleRuns) TextPaint(prepared.style.textPaint) else prepared.style.textPaint
        val layoutEnd = resolveNextLineContextEnd(text, paint, queryStart, textWidthPx)
        val layout =
            buildStaticLayout(
                text = text,
                paint = paint,
                widthPx = textWidthPx,
                style = prepared.style,
                maxLines = 1,
                ellipsizeMode = "clip",
                start = queryStart,
                end = layoutEnd,
            )
        if (layout.lineCount == 0) return null

        val capHeightTopInsetPx =
            if (anchorToCapHeight) {
                val defaultCapHeightPx = measureCapHeightPx(paint)
                resolveCapHeightInsetsPx(
                    layout = layout,
                    text = text,
                    defaultCapHeightPx = defaultCapHeightPx,
                    uniformCapHeightPx = prepared.uniformCapHeightPx ?: resolveUniformCapHeightPx(text, defaultCapHeightPx),
                ).top
            } else {
                0f
            }

        val lineStart = layout.getLineStart(0)
        val lineEnd = trimVisibleEnd(text, lineStart, layout.getLineVisibleEnd(0))
        val lineWidth =
            if (prepared.hasInlineStyleRuns) {
                resolveMeasuredLineWidthPx(layout, text, 0).toDouble() / density
            } else {
                resolvePlainTextLineWidthPx(paint, prepared.text, lineStart, lineEnd).toDouble() / density
            }
        val lineBottom =
            if (anchorToCapHeight) {
                (layout.getLineBaseline(0) - capHeightTopInsetPx).toDouble() / density
            } else if (!prepared.hasInlineStyleRuns && prepared.style.lineHeightPx != null) {
                prepared.style.lineHeightPx.toDouble() / density
            } else {
                layout.getLineBottom(0).toDouble() / density
            }

        return doubleArrayOf(lineStart.toDouble(), lineEnd.toDouble(), lineWidth, lineBottom)
    }

    private fun resolvePlainNextLine(
        prepared: PreparedTextData,
        start: Int,
        width: Double,
        anchorToCapHeight: Boolean,
    ): DoubleArray? {
        if (prepared.hasInlineStyleRuns || prepared.style.includeFontPadding) return null
        if (start < 0 || start >= prepared.text.length) return null

        val density = currentDensity()
        val widthPx = max(1, ceil(max(0.0, width) * density).toInt())
        val nextLineOwner = resolvePlainNextLineOwner(prepared)
        val cacheKey = resolvePlainNextLineKey(widthPx, start)
        val cachedLine = synchronized(nextLineOwner) { nextLineOwner.linesByKey[cacheKey] } ?: run {
            val measurementChars = resolvePlainMeasurementChars(nextLineOwner, prepared.text)
            val paint = prepared.style.textPaint
            val contextEnd = resolveLineBreakerContextEnd(prepared.text, measurementChars, paint, start, widthPx)
            val lineRangeChars = resolveLineBreakerMeasurementChars(measurementChars, start, contextEnd)
            val measuredText = buildMeasuredText(lineRangeChars, paint)
            val result = resolveLineBreaker(prepared.style.textBreakStrategy).computeLineBreaks(measuredText, resolveLineBreakerConstraints(widthPx), 0)
            if (result.lineCount == 0) return null
            val lineEnd = trimVisibleEnd(prepared.text, start, min(prepared.text.length, start + result.getLineBreakOffset(0)))

            PlainLineInfo(
                end = lineEnd,
                widthPx = resolvePlainTextLineWidthPx(paint, measurementChars, start, lineEnd),
            ).also { line ->
                synchronized(nextLineOwner) {
                    nextLineOwner.linesByKey.put(cacheKey, line)
                }
            }
        }
        val lineBottomPx =
            if (anchorToCapHeight) {
                resolvePlainCapHeightPx(nextLineOwner, prepared.style.textPaint)
            } else {
                prepared.style.lineHeightPx ?: (prepared.style.fallbackLineHeight * density).toFloat()
            }

        return doubleArrayOf(
            start.toDouble(),
            cachedLine.end.toDouble(),
            cachedLine.widthPx.toDouble() / density,
            lineBottomPx.toDouble() / density,
        )
    }

    private fun resolvePlainNextLineOwner(prepared: PreparedTextData): PlainNextLineOwner {
        prepared.plainNextLineOwner?.let { return it }
        return synchronized(prepared) {
            prepared.plainNextLineOwner ?: PlainNextLineOwner().also { prepared.plainNextLineOwner = it }
        }
    }

    private fun resolvePlainNextLineKey(widthPx: Int, start: Int): Long {
        return (widthPx.toLong() shl 32) or (start.toLong() and 0xFFFFFFFFL)
    }

    private fun resolvePlainMeasurementChars(nextLineOwner: PlainNextLineOwner, text: String): CharArray {
        nextLineOwner.measurementChars?.let { return it }
        return synchronized(nextLineOwner) {
            nextLineOwner.measurementChars ?: text.toCharArray().also { nextLineOwner.measurementChars = it }
        }
    }

    private fun resolveLineBreaker(breakStrategy: Int): LineBreaker {
        return when (breakStrategy) {
            Layout.BREAK_STRATEGY_SIMPLE -> simpleLineBreaker
            Layout.BREAK_STRATEGY_BALANCED -> balancedLineBreaker
            else -> highQualityLineBreaker
        }
    }

    private fun buildLineBreaker(breakStrategy: Int): LineBreaker {
        return LineBreaker.Builder()
            .setBreakStrategy(breakStrategy)
            .setHyphenationFrequency(LineBreaker.HYPHENATION_FREQUENCY_NORMAL)
            .build()
    }

    private fun resolveLineBreakerConstraints(widthPx: Int): LineBreaker.ParagraphConstraints {
        val constraints =
            lineBreakerConstraints.get()
                ?: LineBreaker.ParagraphConstraints().also { lineBreakerConstraints.set(it) }
        constraints.setWidth(widthPx.toFloat())
        return constraints
    }

    private fun buildMeasuredText(text: CharArray, paint: TextPaint): MeasuredText {
        val measuredTextBuilder = MeasuredText.Builder(text).setComputeLayout(false)
        if (Build.VERSION.SDK_INT >= 33) {
            measuredTextBuilder.setComputeHyphenation(MeasuredText.Builder.HYPHENATION_MODE_FAST)
        } else {
            @Suppress("DEPRECATION")
            measuredTextBuilder.setComputeHyphenation(true)
        }

        return measuredTextBuilder
            .appendStyleRun(paint, text.size, false)
            .build()
    }

    private fun resolveLineBreakerContextEnd(
        text: String,
        measurementChars: CharArray,
        paint: TextPaint,
        start: Int,
        widthPx: Int,
    ): Int {
        val hardBreakIndex = text.indexOf('\n', start).let { if (it == -1) text.length else it + 1 }
        val measuredCount = paint.breakText(measurementChars, start, measurementChars.size - start, widthPx.toFloat(), null).coerceAtLeast(1)
        var end = min(hardBreakIndex, start + measuredCount)
        var remainingBoundaries = 3

        while (end < hardBreakIndex) {
            val previous = text[end - 1]
            if (previous == '\n' || previous == '\r' || previous == '.' || previous == '!' || previous == '?') break
            if (!previous.isWhitespace() && text[end].isWhitespace()) {
                remainingBoundaries -= 1
                while (end < hardBreakIndex && text[end].isWhitespace()) {
                    end += 1
                }
                if (remainingBoundaries <= 0 || end >= hardBreakIndex) break
                continue
            }
            end += 1
        }

        return end
    }

    private fun resolveLineBreakerMeasurementChars(source: CharArray, start: Int, end: Int): CharArray {
        val length = max(0, end - start)
        val scratchBuffers =
            lineBreakerScratchBuffers.get()
                ?: LineBreakerScratchBuffers().also { lineBreakerScratchBuffers.set(it) }
        val target = scratchBuffers.resolve(length)
        System.arraycopy(source, start, target, 0, length)
        return target
    }

    private fun resolveLineBreakerMeasurementChars(text: String): CharArray {
        val scratchBuffers =
            lineBreakerScratchBuffers.get()
                ?: LineBreakerScratchBuffers().also { lineBreakerScratchBuffers.set(it) }
        val target = scratchBuffers.resolve(text.length)
        text.toCharArray(target, 0, 0, text.length)
        return target
    }

    private fun resolvePlainCapHeightPx(nextLineOwner: PlainNextLineOwner, textPaint: TextPaint): Float {
        val cached = nextLineOwner.capHeightPx
        if (!cached.isNaN()) return cached

        return synchronized(nextLineOwner) {
            val measured = nextLineOwner.capHeightPx
            if (!measured.isNaN()) {
                measured
            } else {
                measureCapHeightPx(textPaint).also { nextLineOwner.capHeightPx = it }
            }
        }
    }

    private fun resolveNextLineStart(text: String, start: Int): Int {
        if (start < 0 || start >= text.length) return -1

        var lineStart = start
        while (lineStart < text.length) {
            val char = text[lineStart]
            if (char == '\n' || char == '\r') {
                lineStart += 1
                continue
            }

            val followsExplicitBreak = lineStart > 0 && (text[lineStart - 1] == '\n' || text[lineStart - 1] == '\r')
            if (!followsExplicitBreak && lineStart > start && char.isWhitespace()) {
                lineStart += 1
                continue
            }

            if (!followsExplicitBreak && lineStart == start && char.isWhitespace() && start > 0) {
                lineStart += 1
                continue
            }

            break
        }

        return if (lineStart >= text.length) -1 else lineStart
    }

    private fun resolveNextLineContextEnd(
        text: CharSequence,
        paint: TextPaint,
        start: Int,
        widthPx: Int,
    ): Int {
        if (start >= text.length) return text.length

        val measuredCount = paint.breakText(text, start, text.length, true, widthPx.toFloat(), null).coerceAtLeast(1)
        var end = min(text.length, start + measuredCount)

        while (end < text.length) {
            val char = text[end - 1]
            if (char == '\n' || char == '\r' || char == '.' || char == '!' || char == '?') break
            end += 1
        }

        while (end < text.length && text[end].isWhitespace()) {
            end += 1
        }

        return end
    }

    private fun resolvePlainTextLineWidthPx(paint: TextPaint, text: String, start: Int, end: Int): Float {
        if (end <= start) return 0f
        val measuredWidth = paint.getRunAdvance(text, start, end, start, end, false, end)
        return roundMeasuredTextWidthPx(measuredWidth)
    }

    private fun resolvePlainTextLineWidthPx(paint: TextPaint, text: CharArray, start: Int, end: Int): Float {
        if (end <= start) return 0f
        val measuredWidth = paint.getRunAdvance(text, start, end, start, end, false, end)
        return roundMeasuredTextWidthPx(measuredWidth)
    }

    private fun buildGlyphFieldRows(field: GlyphFieldData, glyphs: String, variantIndices: ByteArray): List<GlyphFieldRowData> {
        val rows = ArrayList<GlyphFieldRowData>(field.rows)

        repeat(field.rows) { row ->
            val runs = ArrayList<GlyphFieldRunData>()
            val rowStart = row * field.columns
            var rowWidth = 0f
            var runText = StringBuilder(field.columns)
            var runVariantIndex = -1
            var runVariant: GlyphFieldVariantData? = null
            var runWidth = 0f

            fun flushRun() {
                val variant = runVariant ?: return
                if (runText.isEmpty()) return

                runs +=
                    GlyphFieldRunData(
                        text = runText.toString(),
                        variant = variant,
                        variantIndex = runVariantIndex,
                        width = runWidth,
                    )
                rowWidth += runWidth
                runText = StringBuilder(field.columns)
                runVariantIndex = -1
                runVariant = null
                runWidth = 0f
            }

            repeat(field.columns) { column ->
                val cellIndex = rowStart + column
                val glyph = glyphs[cellIndex]
                val variantIndex = variantIndices[cellIndex].toInt() and 0xFF
                val variant = field.variants[variantIndex]

                if (runVariantIndex != variantIndex) {
                    flushRun()
                    runVariantIndex = variantIndex
                    runVariant = variant
                }

                runText.append(glyph)
                runWidth += measureGlyphWidth(variant, glyph)
            }

            flushRun()
            rows += GlyphFieldRowData(runs = runs, width = rowWidth)
        }

        return rows
    }

    private fun buildGlyphFieldRowsFromIndices(
        field: GlyphFieldData,
        glyphPalette: String,
        glyphIndices: ByteArray,
        variantIndices: ByteArray,
    ): List<GlyphFieldRowData> {
        val rows = ArrayList<GlyphFieldRowData>(field.rows)

        repeat(field.rows) { row ->
            val runs = ArrayList<GlyphFieldRunData>()
            val rowStart = row * field.columns
            var rowWidth = 0f
            var runText = StringBuilder(field.columns)
            var runVariantIndex = -1
            var runVariant: GlyphFieldVariantData? = null
            var runWidth = 0f

            fun flushRun() {
                val variant = runVariant ?: return
                if (runText.isEmpty()) return

                runs +=
                    GlyphFieldRunData(
                        text = runText.toString(),
                        variant = variant,
                        variantIndex = runVariantIndex,
                        width = runWidth,
                    )
                rowWidth += runWidth
                runText = StringBuilder(field.columns)
                runVariantIndex = -1
                runVariant = null
                runWidth = 0f
            }

            repeat(field.columns) { column ->
                val cellIndex = rowStart + column
                val glyphIndex = glyphIndices[cellIndex].toInt() and 0xFF
                val glyph = glyphPalette[glyphIndex]
                val variantIndex = variantIndices[cellIndex].toInt() and 0xFF
                val variant = field.variants[variantIndex]

                if (runVariantIndex != variantIndex) {
                    flushRun()
                    runVariantIndex = variantIndex
                    runVariant = variant
                }

                runText.append(glyph)
                runWidth += measureGlyphWidth(variant, glyph)
            }

            flushRun()
            rows += GlyphFieldRowData(runs = runs, width = rowWidth)
        }

        return rows
    }

    private fun buildGlyphFieldRowFromIndices(
        field: GlyphFieldData,
        glyphPalette: String,
        glyphIndices: ByteArray,
        variantIndices: ByteArray,
        row: Int,
    ): GlyphFieldRowData {
        val runs = ArrayList<GlyphFieldRunData>()
        val rowStart = row * field.columns
        var rowWidth = 0f
        var runText = StringBuilder(field.columns)
        var runVariantIndex = -1
        var runVariant: GlyphFieldVariantData? = null
        var runWidth = 0f

        fun flushRun() {
            val variant = runVariant ?: return
            if (runText.isEmpty()) return

            runs +=
                GlyphFieldRunData(
                    text = runText.toString(),
                    variant = variant,
                    variantIndex = runVariantIndex,
                    width = runWidth,
                )
            rowWidth += runWidth
            runText = StringBuilder(field.columns)
            runVariantIndex = -1
            runVariant = null
            runWidth = 0f
        }

        repeat(field.columns) { column ->
            val cellIndex = rowStart + column
            val glyphIndex = glyphIndices[cellIndex].toInt() and 0xFF
            val glyph = field.glyphPaletteChars?.get(glyphIndex) ?: glyphPalette[glyphIndex]
            val variantIndex = variantIndices[cellIndex].toInt() and 0xFF
            val variant = field.variants[variantIndex]

            if (runVariantIndex != variantIndex) {
                flushRun()
                runVariantIndex = variantIndex
                runVariant = variant
            }

            runText.append(glyph)
            runWidth += variant.paletteWidths?.get(glyphIndex) ?: measureGlyphWidth(variant, glyph)
        }

        flushRun()
        return GlyphFieldRowData(runs = runs, width = rowWidth)
    }

    private fun buildGlyphFieldRowsFromBuffers(
        field: GlyphFieldData,
        glyphPalette: String,
        glyphIndices: ByteBuffer,
        variantIndices: ByteBuffer,
    ): List<GlyphFieldRowData> {
        val rows = ArrayList<GlyphFieldRowData>(field.rows)

        repeat(field.rows) { row ->
            val runs = ArrayList<GlyphFieldRunData>()
            val rowStart = row * field.columns
            var rowWidth = 0f
            var runText = StringBuilder(field.columns)
            var runVariantIndex = -1
            var runVariant: GlyphFieldVariantData? = null
            var runWidth = 0f

            fun flushRun() {
                val variant = runVariant ?: return
                if (runText.isEmpty()) return

                runs +=
                    GlyphFieldRunData(
                        text = runText.toString(),
                        variant = variant,
                        variantIndex = runVariantIndex,
                        width = runWidth,
                    )
                rowWidth += runWidth
                runText = StringBuilder(field.columns)
                runVariantIndex = -1
                runVariant = null
                runWidth = 0f
            }

            repeat(field.columns) { column ->
                val cellIndex = rowStart + column
                val glyphIndex = glyphIndices.get(cellIndex).toInt() and 0xFF
                val glyph = glyphPalette[glyphIndex]
                val variantIndex = variantIndices.get(cellIndex).toInt() and 0xFF
                val variant = field.variants[variantIndex]

                if (runVariantIndex != variantIndex) {
                    flushRun()
                    runVariantIndex = variantIndex
                    runVariant = variant
                }

                runText.append(glyph)
                runWidth += measureGlyphWidth(variant, glyph)
            }

            flushRun()
            rows += GlyphFieldRowData(runs = runs, width = rowWidth)
        }

        return rows
    }

    private fun rebuildChangedGlyphFieldRows(
        field: GlyphFieldData,
        glyphPalette: String,
        changedRows: BooleanArray,
    ): List<GlyphFieldRowData> {
        val glyphIndices = requireNotNull(field.currentGlyphIndices)
        val variantIndices = requireNotNull(field.currentVariantIndices)
        val nextRows =
            if (field.renderedRows.size == field.rows) {
                ArrayList(field.renderedRows)
            } else {
                MutableList(field.rows) { GlyphFieldRowData(runs = emptyList(), width = 0f) }
            }

        repeat(field.rows) { row ->
            if (changedRows[row]) {
                nextRows[row] = resolveGlyphFieldRow(field, glyphPalette, glyphIndices, variantIndices, row)
            }
        }

        return nextRows
    }

    private fun resolveGlyphFieldRow(
        field: GlyphFieldData,
        glyphPalette: String,
        glyphIndices: ByteArray,
        variantIndices: ByteArray,
        row: Int,
    ): GlyphFieldRowData = buildGlyphFieldRowFromIndices(field, glyphPalette, glyphIndices, variantIndices, row)

    private fun resolveGlyphFieldChangedRows(
        field: GlyphFieldData,
        glyphPalette: String,
        glyphIndices: ByteArray,
        variantIndices: ByteArray,
    ): BooleanArray {
        val cellCount = field.columns * field.rows
        val currentGlyphIndices = field.currentGlyphIndices ?: ByteArray(cellCount).also { field.currentGlyphIndices = it }
        val currentVariantIndices = field.currentVariantIndices ?: ByteArray(cellCount).also { field.currentVariantIndices = it }
        val changedRows = BooleanArray(field.rows)
        val hasExistingRows = field.renderedRows.size == field.rows

        repeat(field.rows) { row ->
            val rowStart = row * field.columns
            var changed = !hasExistingRows

            repeat(field.columns) { column ->
                val index = rowStart + column
                val nextGlyphIndex = glyphIndices[index]
                val nextVariantIndex = variantIndices[index]
                if (currentGlyphIndices[index] != nextGlyphIndex || currentVariantIndices[index] != nextVariantIndex) {
                    val glyphIndex = nextGlyphIndex.toInt() and 0xFF
                    require(glyphIndex < glyphPalette.length) {
                        "RNTextEngine: glyph field glyph index exceeded the configured glyphPalette length."
                    }
                    val variantIndex = nextVariantIndex.toInt() and 0xFF
                    require(variantIndex < field.variants.size) {
                        "RNTextEngine: glyph field variant index exceeded the configured variant count."
                    }
                    changed = true
                    currentGlyphIndices[index] = nextGlyphIndex
                    currentVariantIndices[index] = nextVariantIndex
                }
            }

            changedRows[row] = changed
        }

        return changedRows
    }

    private fun resolveGlyphFieldChangedRows(
        field: GlyphFieldData,
        glyphPalette: String,
        glyphIndices: ByteBuffer,
        variantIndices: ByteBuffer,
    ): BooleanArray {
        val cellCount = field.columns * field.rows
        val currentGlyphIndices = field.currentGlyphIndices ?: ByteArray(cellCount).also { field.currentGlyphIndices = it }
        val currentVariantIndices = field.currentVariantIndices ?: ByteArray(cellCount).also { field.currentVariantIndices = it }
        val changedRows = BooleanArray(field.rows)
        val hasExistingRows = field.renderedRows.size == field.rows

        repeat(field.rows) { row ->
            val rowStart = row * field.columns
            var changed = !hasExistingRows

            repeat(field.columns) { column ->
                val index = rowStart + column
                val nextGlyphIndex = glyphIndices.get(index)
                val nextVariantIndex = variantIndices.get(index)
                if (currentGlyphIndices[index] != nextGlyphIndex || currentVariantIndices[index] != nextVariantIndex) {
                    val glyphIndex = nextGlyphIndex.toInt() and 0xFF
                    require(glyphIndex < glyphPalette.length) {
                        "RNTextEngine: glyph field glyph index exceeded the configured glyphPalette length."
                    }
                    val variantIndex = nextVariantIndex.toInt() and 0xFF
                    require(variantIndex < field.variants.size) {
                        "RNTextEngine: glyph field variant index exceeded the configured variant count."
                    }
                    changed = true
                    currentGlyphIndices[index] = nextGlyphIndex
                    currentVariantIndices[index] = nextVariantIndex
                }
            }

            changedRows[row] = changed
        }

        return changedRows
    }

    private fun buildGlyphFieldDirtyRanges(changedRows: BooleanArray): List<IntRange> {
        val dirtyRanges = ArrayList<IntRange>()
        var rangeStart = -1

        repeat(changedRows.size) { row ->
            if (changedRows[row] && rangeStart == -1) {
                rangeStart = row
                return@repeat
            }

            if (!changedRows[row] && rangeStart != -1) {
                dirtyRanges += rangeStart until row
                rangeStart = -1
            }
        }

        if (rangeStart != -1) {
            dirtyRanges += rangeStart until changedRows.size
        }

        return dirtyRanges
    }

    private fun buildGlyphFieldDirtyRanges(
        previousRows: List<GlyphFieldRowData>,
        nextRows: List<GlyphFieldRowData>,
        rowCount: Int,
    ): List<IntRange> {
        val changedRows = BooleanArray(rowCount) { row -> previousRows.getOrNull(row) != nextRows.getOrNull(row) }
        return buildGlyphFieldDirtyRanges(changedRows)
    }

    private fun invalidateGlyphFieldViews(field: GlyphFieldData, dirtyRanges: List<IntRange>) {
        if (dirtyRanges.isEmpty()) return

        field.views.removeAll { reference ->
            val view = reference.get()
            if (view == null) {
                true
            } else {
                val shouldInvalidateWholeView =
                    dirtyRanges.size == 1 && dirtyRanges.first().first == 0 && dirtyRanges.first().last + 1 >= field.rows

                if (shouldInvalidateWholeView || view.height <= 0 || view.width <= 0) {
                    view.postInvalidateOnAnimation()
                } else {
                    val topInset = max(0f, (view.height - field.rows * field.lineHeightPx) * 0.5f)
                    dirtyRanges.forEach { rows ->
                        val top = floor(topInset + rows.first * field.lineHeightPx).toInt().coerceAtLeast(0)
                        val bottom = ceil(topInset + (rows.last + 1) * field.lineHeightPx).toInt().coerceAtMost(view.height)
                        view.postInvalidateOnAnimation(0, top, view.width, bottom)
                    }
                }
                false
            }
        }
    }

    private fun measureGlyphWidth(variant: GlyphFieldVariantData, glyph: Char): Float {
        val codePoint = glyph.code
        return variant.widthCache.getOrPut(codePoint) {
            variant.textPaint.measureText(glyph.toString())
        }
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
        val textPaint = TextPaint(TextPaint.ANTI_ALIAS_FLAG or RN_TEXT_ENGINE_SHAPING_FLAGS)
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

        if (tabularNumbers) {
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

    private fun resolveRunTextStyle(
        baseStyle: ResolvedTextStyle,
        baseConfig: TextStyleConfig,
        runStyle: TextMeasureRunStyle,
    ): ResolvedTextStyle {
        val color = if (runStyle.hasColor) runStyle.color else baseConfig.color
        val fontFamily = if (runStyle.hasFontFamily) runStyle.fontFamily else baseConfig.fontFamily
        val fontSize = if (runStyle.hasFontSize) runStyle.fontSize else baseConfig.fontSize
        val fontWeight = if (runStyle.hasFontWeight) runStyle.fontWeight else baseConfig.fontWeight
        val fontStyle = if (runStyle.hasFontStyle) runStyle.fontStyle else baseConfig.fontStyle
        val letterSpacing = if (runStyle.hasLetterSpacing) runStyle.letterSpacing else baseConfig.letterSpacing
        val lineHeight = if (runStyle.hasLineHeight) runStyle.lineHeight else baseConfig.lineHeight
        val tabularNumbers = if (runStyle.hasTabularNumbers) runStyle.tabularNumbers else baseConfig.tabularNumbers

        val textPaint = TextPaint(baseStyle.textPaint)
        val resolvedTextColor = if (runStyle.hasColor) resolveTextColor(color) else baseStyle.textColor
        if (runStyle.hasColor) {
            textPaint.color = resolvedTextColor ?: defaultTextPaintColor
        }

        val shouldResolveTypeface = runStyle.hasFontFamily || runStyle.hasFontWeight || runStyle.hasFontStyle
        if (shouldResolveTypeface) {
            textPaint.typeface = resolveTypeface(fontFamily, fontWeight, fontStyle)
        }

        val shouldResolveFontSize = runStyle.hasFontSize
        if (shouldResolveFontSize) {
            textPaint.textSize = scale(fontSize, baseConfig.allowFontScaling, defaultValue = 14.0)
        }

        if (runStyle.hasFontSize || runStyle.hasLetterSpacing) {
            val effectiveFontSize = textPaint.textSize
            textPaint.letterSpacing =
                if (!letterSpacing.isNaN() && effectiveFontSize > 0f) {
                    scale(letterSpacing, baseConfig.allowFontScaling, defaultValue = 0.0) / effectiveFontSize
                } else {
                    0f
                }
        }

        if (runStyle.hasTabularNumbers) {
            textPaint.fontFeatureSettings = if (tabularNumbers) "'tnum'" else null
        }

        val lineHeightPx =
            if (runStyle.hasLineHeight) {
                if (lineHeight.isNaN()) null else scale(lineHeight, baseConfig.allowFontScaling, defaultValue = lineHeight)
            } else {
                baseStyle.lineHeightPx
            }
        val fallbackLineHeight =
            if (!lineHeight.isNaN() && runStyle.hasLineHeight) {
                scale(lineHeight, baseConfig.allowFontScaling, defaultValue = lineHeight).toDouble().toDp()
            } else if (lineHeight.isNaN() && (runStyle.hasLineHeight || shouldResolveTypeface || shouldResolveFontSize)) {
                ((-textPaint.fontMetricsInt.ascent) + textPaint.fontMetricsInt.descent).toDouble().toDp()
            } else {
                baseStyle.fallbackLineHeight
            }

        return ResolvedTextStyle(
            fallbackLineHeight = fallbackLineHeight,
            includeFontPadding = baseStyle.includeFontPadding,
            lineHeightPx = lineHeightPx,
            textBreakStrategy = baseStyle.textBreakStrategy,
            textColor = resolvedTextColor,
            textPaint = textPaint,
        )
    }

    private fun buildPreparedText(text: String, style: ResolvedTextStyle): PreparedTextData {
        return PreparedTextData(
            cachedLayoutText = null,
            hasInlineStyleRuns = false,
            plainNextLineOwner = null,
            style = style,
            text = text,
            textWithLineHeight = text,
            uniformCapHeightPx = null,
        )
    }

    private fun buildPreparedTextForTextView(
        text: String,
        textTransform: String?,
        style: ResolvedTextStyle,
    ): PreparedTextData {
        return buildPreparedText(applyTextTransform(text, textTransform), style)
    }

    private fun buildPreparedText(
        text: String,
        style: ResolvedTextStyle,
        runs: List<TextMeasureRun>,
        resolveRunStyle: (TextMeasureRunStyle) -> ResolvedTextStyle,
    ): PreparedTextData {
        val styledText =
            if (text.isEmpty()) {
                StyledTextData(text = text, uniformCapHeightPx = null)
            } else {
                buildStyledText(text, style, runs, resolveRunStyle)
            }

        return PreparedTextData(
            cachedLayoutText = styledText.text,
            hasInlineStyleRuns = runs.isNotEmpty(),
            plainNextLineOwner = null,
            style = style,
            text = text,
            textWithLineHeight = styledText.text,
            uniformCapHeightPx = styledText.uniformCapHeightPx,
        )
    }

    private fun buildPreparedTextForTextView(
        text: String,
        textTransform: String?,
        style: ResolvedTextStyle,
        runs: List<TextMeasureRun>,
        resolveRunStyle: (TextMeasureRunStyle) -> ResolvedTextStyle,
    ): PreparedTextData {
        if (runs.isEmpty()) return buildPreparedTextForTextView(text, textTransform, style)

        val boundaries = ArrayList<Int>(runs.size * 2)
        runs.forEach { run ->
            boundaries.add(run.start)
            boundaries.add(run.end)
        }
        val transformed = transformText(text, textTransform, boundaries)
        val transformedRuns =
            runs.map { run ->
                run.copy(
                    start = transformed.offsetsByOriginal[run.start] ?: run.start,
                    end = transformed.offsetsByOriginal[run.end] ?: run.end,
                )
            }

        return buildPreparedText(transformed.text, style, transformedRuns, resolveRunStyle)
    }

    private fun resolvePreparedLayoutText(prepared: PreparedTextData): CharSequence {
        if (prepared.hasInlineStyleRuns) return prepared.textWithLineHeight
        if (prepared.style.lineHeightPx == null || prepared.text.isEmpty()) return prepared.text
        prepared.cachedLayoutText?.let { return it }

        return synchronized(prepared) {
            prepared.cachedLayoutText
                ?: SpannableString(prepared.text).apply {
                    setSpan(
                        RNTextEngineLineHeightSpan(prepared.style.lineHeightPx),
                        0,
                        prepared.text.length,
                        Spannable.SPAN_INCLUSIVE_INCLUSIVE,
                    )
                }.also { prepared.cachedLayoutText = it }
        }
    }

    private fun buildStyledText(
        text: String,
        baseStyle: ResolvedTextStyle,
        runs: List<TextMeasureRun>,
        resolveRunStyle: (TextMeasureRunStyle) -> ResolvedTextStyle,
    ): StyledTextData {
        val styledText = SpannableString(text)

        if (baseStyle.lineHeightPx != null) {
            applyBaseLineHeightSpans(styledText, text.length, baseStyle.lineHeightPx, runs)
        }

        runs.forEach { run ->
            val runStyle = resolveRunStyle(run.style)
            styledText.setSpan(
                RNTextEngineTextPaintSpan(runStyle.textPaint),
                run.start,
                run.end,
                Spannable.SPAN_EXCLUSIVE_EXCLUSIVE,
            )

            runStyle.lineHeightPx?.let { lineHeightPx ->
                styledText.setSpan(
                    RNTextEngineLineHeightSpan(lineHeightPx),
                    run.start,
                    run.end,
                    Spannable.SPAN_EXCLUSIVE_EXCLUSIVE,
                )
            }
        }

        return StyledTextData(
            text = styledText,
            uniformCapHeightPx = null,
        )
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
                    RNTextEngineLineHeightSpan(lineHeightPx),
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
                RNTextEngineLineHeightSpan(lineHeightPx),
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

            require(styleMask != 0) { "RNTextEngine: each text run must override at least one inline style field." }
            require(start >= 0 && end <= textLength && end > start) {
                "RNTextEngine: text runs must stay within the source text and have positive length."
            }
            require(start >= previousEnd) { "RNTextEngine: text runs must be sorted and non-overlapping." }

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
        require(runCounts.size == texts.size) { "RNTextEngine: batch text runs must align with the batch text input length." }
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
            require(actualSize == expectedSize) { "RNTextEngine: run payload arrays must stay aligned." }
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

    private data class StyledTextData(
        val text: CharSequence,
        val uniformCapHeightPx: Float?,
    )

    private data class OneShotPlainLayoutContext(
        val density: Double,
        val effectiveMaxLines: Int,
        val ellipsize: TextUtils.TruncateAt?,
        val lineHeightDp: Double?,
        val textWidthPx: Int,
        val usesPlainTextLineHeightMetrics: Boolean,
    )

    private fun trimVisibleEnd(text: CharSequence, start: Int, end: Int): Int {
        var visibleEnd = end

        while (visibleEnd > start && text[visibleEnd - 1].isWhitespace()) {
            visibleEnd -= 1
        }

        return visibleEnd
    }

    private fun buildLayout(
        prepared: PreparedTextData,
        width: Double,
        maxLines: Int,
        ellipsize: TextUtils.TruncateAt?,
        anchorToCapHeight: Boolean,
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
        if (!includeLines) {
            val layoutQueryOwner = resolveLayoutQueryOwner(prepared)
            val cacheKey = resolveLayoutCacheKey(textWidthPx, maxLines, ellipsize, anchorToCapHeight)
            synchronized(layoutQueryOwner) {
                layoutQueryOwner.layoutsByKey[cacheKey]?.let { return it }
            }
        }
        val usesPlainTextLineHeightMetrics = !prepared.hasInlineStyleRuns && prepared.style.lineHeightPx != null && !anchorToCapHeight
        val charSequence = if (usesPlainTextLineHeightMetrics) prepared.text else resolvePreparedLayoutText(prepared)
        val paint = TextPaint(prepared.style.textPaint)
        val effectiveMaxLines = if (maxLines > 0) maxLines else Int.MAX_VALUE

        val layout = buildStaticLayoutCompat(
            text = charSequence,
            paint = paint,
            widthPx = textWidthPx,
            includeFontPadding = prepared.style.includeFontPadding,
            breakStrategy = prepared.style.textBreakStrategy,
            hyphenationFrequency = Layout.HYPHENATION_FREQUENCY_NORMAL,
            maxLines = effectiveMaxLines,
            ellipsize = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) ellipsize else null,
        )

        val actualLineCount = min(layout.lineCount, effectiveMaxLines)
        val capHeightInsets =
            if (anchorToCapHeight) {
                val defaultCapHeightPx = measureCapHeightPx(paint)
                resolveCapHeightInsetsPx(
                    layout = layout,
                    text = charSequence,
                    defaultCapHeightPx = defaultCapHeightPx,
                    uniformCapHeightPx = prepared.uniformCapHeightPx ?: resolveUniformCapHeightPx(charSequence, defaultCapHeightPx),
                )
            } else {
                null
            }
        val topInsetPx = capHeightInsets?.top ?: 0f
        var widestLine = 0.0
        var lastLineWidth = 0.0
        var measuredHeight = layout.height.toDouble() / density
        var hasEllipsizedLine = false
        val lines = if (includeLines) ArrayList<LineInfo>(actualLineCount) else emptyList<LineInfo>()

        for (index in 0 until actualLineCount) {
            val lineStart = layout.getLineStart(index)
            val lineEnd = trimVisibleEnd(charSequence, lineStart, layout.getLineVisibleEnd(index))
            val isEllipsizedLine = layout.getEllipsisCount(index) > 0
            val lineWidthPx =
                if (isEllipsizedLine) {
                    min(layout.width.toFloat(), resolveMeasuredLineWidthPx(layout, charSequence, index))
                } else if (prepared.hasInlineStyleRuns) {
                    resolveMeasuredLineWidthPx(layout, charSequence, index)
                } else {
                    resolvePlainTextLineWidthPx(paint, prepared.text, lineStart, lineEnd)
                }
            val lineWidth = lineWidthPx.toDouble() / density
            val lineBottom =
                if (anchorToCapHeight) {
                    (layout.getLineBaseline(index) - topInsetPx).toDouble() / density
                } else if (usesPlainTextLineHeightMetrics) {
                    ((index + 1) * prepared.style.lineHeightPx.toDouble()) / density
                } else {
                    layout.getLineBottom(index).toDouble() / density
                }
            hasEllipsizedLine = hasEllipsizedLine || isEllipsizedLine
            widestLine = max(widestLine, lineWidth)
            lastLineWidth = lineWidth
            measuredHeight = lineBottom

            if (includeLines) {
                (lines as ArrayList).add(
                    LineInfo(
                        bottom = lineBottom,
                        end = (baseOffset + lineEnd).toDouble(),
                        start = (baseOffset + lineStart).toDouble(),
                        width = lineWidth,
                    ),
                )
            }
        }

        if (hasEllipsizedLine) {
            widestLine = max(widestLine, layout.width.toDouble() / density)
        }

        val layoutInfo =
            LayoutInfo(
            height = measuredHeight,
            lastLineWidth = lastLineWidth,
            lineCount = actualLineCount.toDouble(),
            lines = lines,
            width = widestLine,
        )
        if (!includeLines) {
            val layoutQueryOwner = resolveLayoutQueryOwner(prepared)
            val cacheKey = resolveLayoutCacheKey(textWidthPx, maxLines, ellipsize, anchorToCapHeight)
            synchronized(layoutQueryOwner) {
                layoutQueryOwner.layoutsByKey.put(cacheKey, layoutInfo)
            }
        }

        return layoutInfo
    }

    private fun resolveOneShotPlainLayoutContext(
        style: ResolvedTextStyle,
        width: Double,
        maxLines: Int,
        ellipsizeMode: String?,
        anchorToCapHeight: Boolean,
    ): OneShotPlainLayoutContext {
        val density = currentDensity()
        val effectiveMaxLines = if (maxLines > 0) maxLines else Int.MAX_VALUE
        return OneShotPlainLayoutContext(
            density = density,
            effectiveMaxLines = effectiveMaxLines,
            ellipsize = resolveEllipsize(ellipsizeMode, effectiveMaxLines),
            lineHeightDp = style.lineHeightPx?.toDouble()?.div(density),
            textWidthPx = max(1, ceil(max(0.0, width) * density).toInt()),
            usesPlainTextLineHeightMetrics = style.lineHeightPx != null && !anchorToCapHeight,
        )
    }

    private fun buildOneShotPlainLayout(
        text: String,
        style: ResolvedTextStyle,
        context: OneShotPlainLayoutContext,
        anchorToCapHeight: Boolean,
        includeLines: Boolean,
        reusablePaint: TextPaint? = null,
    ): LayoutInfo {
        if (text.isEmpty()) {
            return LayoutInfo(
                height = style.fallbackLineHeight,
                lastLineWidth = 0.0,
                lineCount = 0.0,
                lines = emptyList(),
                width = 0.0,
            )
        }
        if (!anchorToCapHeight && !includeLines && context.usesPlainTextLineHeightMetrics && context.effectiveMaxLines == Int.MAX_VALUE && context.ellipsize == null) {
            return buildOneShotPlainLayoutSimple(text, style, context, reusablePaint)
        }

        val density = context.density
        val charSequence =
            if (context.usesPlainTextLineHeightMetrics || style.lineHeightPx == null) {
                text
            } else {
                SpannableString(text).apply {
                    setSpan(
                        RNTextEngineLineHeightSpan(style.lineHeightPx),
                        0,
                        text.length,
                        Spannable.SPAN_INCLUSIVE_INCLUSIVE,
                    )
                }
            }
        val paint = reusablePaint ?: TextPaint(style.textPaint)
        val layout = buildStaticLayoutCompat(
            text = charSequence,
            paint = paint,
            widthPx = context.textWidthPx,
            includeFontPadding = style.includeFontPadding,
            breakStrategy = style.textBreakStrategy,
            hyphenationFrequency = Layout.HYPHENATION_FREQUENCY_NORMAL,
            maxLines = context.effectiveMaxLines,
            ellipsize = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) context.ellipsize else null,
        )

        val actualLineCount = min(layout.lineCount, context.effectiveMaxLines)
        val capHeightInsets =
            if (anchorToCapHeight) {
                val defaultCapHeightPx = measureCapHeightPx(paint)
                resolveCapHeightInsetsPx(
                    layout = layout,
                    text = charSequence,
                    defaultCapHeightPx = defaultCapHeightPx,
                    uniformCapHeightPx = resolveUniformCapHeightPx(charSequence, defaultCapHeightPx),
                )
            } else {
                null
            }
        val topInsetPx = capHeightInsets?.top ?: 0f
        var widestLine = 0.0
        var lastLineWidth = 0.0
        var measuredHeight = layout.height.toDouble() / density
        var hasEllipsizedLine = false
        val lines = if (includeLines) ArrayList<LineInfo>(actualLineCount) else emptyList<LineInfo>()

        for (index in 0 until actualLineCount) {
            val lineStart = layout.getLineStart(index)
            val lineEnd = trimVisibleEnd(charSequence, lineStart, layout.getLineVisibleEnd(index))
            val isEllipsizedLine = layout.getEllipsisCount(index) > 0
            val lineWidthPx =
                if (isEllipsizedLine) {
                    min(layout.width.toFloat(), resolveMeasuredLineWidthPx(layout, charSequence, index))
                } else {
                    resolvePlainTextLineWidthPx(paint, text, lineStart, lineEnd)
                }
            val lineWidth = lineWidthPx.toDouble() / density
            val lineBottom =
                if (anchorToCapHeight) {
                    (layout.getLineBaseline(index) - topInsetPx).toDouble() / density
                } else if (context.usesPlainTextLineHeightMetrics) {
                    (index + 1) * requireNotNull(context.lineHeightDp)
                } else {
                    layout.getLineBottom(index).toDouble() / density
                }
            hasEllipsizedLine = hasEllipsizedLine || isEllipsizedLine
            widestLine = max(widestLine, lineWidth)
            lastLineWidth = lineWidth
            measuredHeight = lineBottom

            if (includeLines) {
                (lines as ArrayList).add(
                    LineInfo(
                        bottom = lineBottom,
                        end = lineEnd.toDouble(),
                        start = lineStart.toDouble(),
                        width = lineWidth,
                    ),
                )
            }
        }

        if (hasEllipsizedLine) {
            widestLine = max(widestLine, layout.width.toDouble() / density)
        }

        return LayoutInfo(
            height = measuredHeight,
            lastLineWidth = lastLineWidth,
            lineCount = actualLineCount.toDouble(),
            lines = lines,
            width = widestLine,
        )
    }

    private fun buildOneShotPlainLayoutSimple(
        text: String,
        style: ResolvedTextStyle,
        context: OneShotPlainLayoutContext,
        reusablePaint: TextPaint? = null,
    ): LayoutInfo {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            val paint = reusablePaint ?: TextPaint(style.textPaint)
            val layout =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    StaticLayout.Builder.obtain(text, 0, text.length, paint, context.textWidthPx)
                        .setAlignment(Layout.Alignment.ALIGN_NORMAL)
                        .setBreakStrategy(style.textBreakStrategy)
                        .setHyphenationFrequency(Layout.HYPHENATION_FREQUENCY_NORMAL)
                        .setIncludePad(style.includeFontPadding)
                        .build()
                } else {
                    @Suppress("DEPRECATION")
                    StaticLayout(
                        text,
                        paint,
                        context.textWidthPx,
                        Layout.Alignment.ALIGN_NORMAL,
                        1f,
                        0f,
                        style.includeFontPadding,
                    )
                }
            var widestLine = 0.0
            var lastLineWidth = 0.0
            for (index in 0 until layout.lineCount) {
                val lineStart = layout.getLineStart(index)
                val lineEnd = trimVisibleEnd(text, lineStart, layout.getLineVisibleEnd(index))
                val lineWidth = resolvePlainTextLineWidthPx(paint, text, lineStart, lineEnd).toDouble() / context.density
                widestLine = max(widestLine, lineWidth)
                lastLineWidth = lineWidth
            }
            return LayoutInfo(
                height = layout.lineCount * requireNotNull(context.lineHeightDp),
                lastLineWidth = lastLineWidth,
                lineCount = layout.lineCount.toDouble(),
                lines = emptyList(),
                width = widestLine,
            )
        }
        val paint = reusablePaint ?: TextPaint(style.textPaint)
        val measurementChars = resolveLineBreakerMeasurementChars(text)
        val measuredText = buildMeasuredText(measurementChars, paint)
        val result = resolveLineBreaker(style.textBreakStrategy).computeLineBreaks(measuredText, resolveLineBreakerConstraints(context.textWidthPx), 0)
        if (result.lineCount == 0) {
            return LayoutInfo(
                height = 0.0,
                lastLineWidth = 0.0,
                lineCount = 0.0,
                lines = emptyList(),
                width = 0.0,
            )
        }
        var widestLine = 0.0
        var lastLineWidth = 0.0
        var lineStart = 0

        for (index in 0 until result.lineCount) {
            val rawLineEnd = min(text.length, result.getLineBreakOffset(index))
            val lineEnd = trimVisibleEnd(text, lineStart, rawLineEnd)
            val lineWidth = resolvePlainTextLineWidthPx(paint, text, lineStart, lineEnd).toDouble() / context.density
            widestLine = max(widestLine, lineWidth)
            lastLineWidth = lineWidth
            lineStart = rawLineEnd
        }

        return LayoutInfo(
            height = result.lineCount * requireNotNull(context.lineHeightDp),
            lastLineWidth = lastLineWidth,
            lineCount = result.lineCount.toDouble(),
            lines = emptyList(),
            width = widestLine,
        )
    }

    private fun resolveGlyphFieldRenderedRows(field: GlyphFieldData): List<GlyphFieldRowData> {
        field.renderedRows.takeIf { it.isNotEmpty() }?.let { return it }

        return synchronized(field) {
            field.renderedRows.takeIf { it.isNotEmpty() } ?: when {
                field.currentGlyphIndices != null && field.currentVariantIndices != null && field.glyphPalette != null ->
                    rebuildChangedGlyphFieldRows(
                        field = field,
                        glyphPalette = requireNotNull(field.glyphPalette),
                        changedRows = BooleanArray(field.rows) { true },
                    )
                field.currentGlyphs != null && field.currentVariantIndices != null ->
                    buildGlyphFieldRows(field, requireNotNull(field.currentGlyphs), requireNotNull(field.currentVariantIndices))
                else -> emptyList()
            }.also { field.renderedRows = it }
        }
    }

    private fun resolveLayoutQueryOwner(prepared: PreparedTextData): LayoutQueryOwner {
        prepared.layoutQueryOwner?.let { return it }
        return synchronized(prepared) {
            prepared.layoutQueryOwner ?: LayoutQueryOwner().also { prepared.layoutQueryOwner = it }
        }
    }

    private fun resolveLayoutCacheKey(widthPx: Int, maxLines: Int, ellipsize: TextUtils.TruncateAt?, anchorToCapHeight: Boolean): Long {
        val ellipsizeCode = (ellipsize?.ordinal ?: -1) + 1
        val normalizedMaxLines = if (maxLines > 0) maxLines else 0
        val options = ((normalizedMaxLines.toLong() and 0x0FFFFFFFL) shl 4) or ((ellipsizeCode.toLong() and 0x7L) shl 1) or if (anchorToCapHeight) 1L else 0L
        return (widthPx.toLong() shl 32) or options
    }

    private fun measureIntrinsicWidth(prepared: PreparedTextData): Double {
        if (prepared.text.isEmpty()) return 0.0

        val text = resolvePreparedLayoutText(prepared)
        val paint = TextPaint(prepared.style.textPaint)
        val boring = BoringLayout.isBoring(text, paint)
        val layout =
            if (boring != null) {
                BoringLayout.make(
                    text,
                    paint,
                    max(boring.width, 0),
                    Layout.Alignment.ALIGN_NORMAL,
                    1f,
                    0f,
                    boring,
                    prepared.style.includeFontPadding,
                )
            } else {
                buildStaticLayout(
                    text = text,
                    paint = paint,
                    widthPx = max(1, ceil(Layout.getDesiredWidth(text, paint).toDouble()).toInt()),
                    style = prepared.style,
                    maxLines = Int.MAX_VALUE,
                    ellipsizeMode = null,
                )
            }

        return resolveMeasuredLayoutWidthPx(layout, text).toDouble().toDp()
    }

    private fun buildStaticLayout(
        text: CharSequence,
        paint: TextPaint,
        widthPx: Int,
        style: ResolvedTextStyle,
        maxLines: Int,
        ellipsizeMode: String?,
        start: Int = 0,
        end: Int = text.length,
    ): Layout {
        return buildStaticLayoutCompat(
            text = text,
            paint = paint,
            widthPx = widthPx,
            includeFontPadding = style.includeFontPadding,
            breakStrategy = style.textBreakStrategy,
            hyphenationFrequency = Layout.HYPHENATION_FREQUENCY_NORMAL,
            maxLines = maxLines,
            ellipsize = resolveEllipsize(ellipsizeMode, maxLines),
            start = start,
            end = end,
        )
    }

    private fun resolveMeasuredLayoutWidthPx(layout: Layout, text: CharSequence): Float {
        var widestLineWidth = 0f

        for (index in 0 until layout.lineCount) {
            widestLineWidth = max(widestLineWidth, resolveMeasuredLineWidthPx(layout, text, index))
        }

        return widestLineWidth
    }

    private fun resolveMeasuredLineWidthPx(layout: Layout, text: CharSequence, index: Int): Float {
        val lineStart = layout.getLineStart(index)
        val lineVisibleEnd = layout.getLineVisibleEnd(index)
        val visibleEnd = trimVisibleEnd(text, lineStart, layout.getLineVisibleEnd(index))
        if (visibleEnd <= lineStart) return 0f

        val lineEnd = layout.getLineEnd(index)
        if (visibleEnd < lineVisibleEnd || visibleEnd < lineEnd) {
            val visibleWidth = max(0f, layout.getPrimaryHorizontal(visibleEnd) - layout.getLineLeft(index))
            return if (Build.VERSION.SDK_INT > Build.VERSION_CODES.Q) {
                ceil(visibleWidth.toDouble()).toFloat()
            } else {
                visibleWidth
            }
        }

        val endsWithNewLine = text.isNotEmpty() && lineEnd > 0 && text[lineEnd - 1] == '\n'
        return if (endsWithNewLine) {
            roundMeasuredTextWidthPx(layout.getLineMax(index))
        } else {
            roundMeasuredTextWidthPx(layout.getLineWidth(index))
        }
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
        return preparedTexts[handle] ?: error("RNTextEngine: attempted to use an invalid prepared text handle.")
    }

    @JvmStatic
    internal fun resolvePreparedTextViewData(handle: Long): PreparedTextViewData? {
        val prepared = preparedTexts[handle] ?: return null
        return resolvePreparedTextViewData(prepared, mountPlainTextNatively = false)
    }

    internal fun buildTextViewDisplayData(
        text: String,
        textTransform: String?,
        color: Int?,
        fontFamily: String?,
        fontSize: Double,
        fontWeight: String?,
        fontStyle: String?,
        letterSpacing: Double,
        lineHeight: Double,
        allowFontScaling: Boolean,
        includeFontPadding: Boolean = false,
        tabularNumbers: Boolean,
        textBreakStrategy: String?,
        runs: List<RNTextEngineTextRun> = emptyList(),
    ): PreparedTextViewData {
        val colorString = color?.toColorString()
        val baseConfig =
            TextStyleConfig(
                allowFontScaling = allowFontScaling,
                color = colorString,
                fontFamily = fontFamily,
                fontSize = fontSize,
                fontStyle = fontStyle,
                fontWeight = fontWeight,
                includeFontPadding = includeFontPadding,
                letterSpacing = letterSpacing,
                lineHeight = lineHeight,
                tabularNumbers = tabularNumbers,
                textBreakStrategy = textBreakStrategy,
            )
        val baseStyle =
            resolveTextStyle(
                color = colorString,
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
        val prepared =
            if (runs.isEmpty()) {
                buildPreparedTextForTextView(text, textTransform, baseStyle)
            } else {
                val measureRuns =
                    runs.map { run ->
                        TextMeasureRun(
                            end = run.end,
                            start = run.start,
                            style =
                                TextMeasureRunStyle(
                                    color = run.style.color,
                                    fontFamily = run.style.fontFamily,
                                    fontSize = run.style.fontSize,
                                    fontStyle = run.style.fontStyle,
                                    fontWeight = run.style.fontWeight,
                                    hasColor = run.style.hasColor,
                                    hasFontFamily = run.style.hasFontFamily,
                                    hasFontSize = run.style.hasFontSize,
                                    hasFontStyle = run.style.hasFontStyle,
                                    hasFontWeight = run.style.hasFontWeight,
                                    hasLetterSpacing = run.style.hasLetterSpacing,
                                    hasLineHeight = run.style.hasLineHeight,
                                    hasTabularNumbers = run.style.hasTabularNumbers,
                                    letterSpacing = run.style.letterSpacing,
                                    lineHeight = run.style.lineHeight,
                                    tabularNumbers = run.style.tabularNumbers,
                                ),
                        )
                    }

                buildPreparedTextForTextView(text, textTransform, baseStyle, measureRuns) { runStyle ->
                    resolveRunTextStyle(baseStyle, baseConfig, runStyle)
                }
            }

        return resolvePreparedTextViewData(prepared, mountPlainTextNatively = runs.isEmpty())
    }

    private fun resolvePreparedTextViewData(prepared: PreparedTextData, mountPlainTextNatively: Boolean): PreparedTextViewData {
        val baseCapHeightPx = measureCapHeightPx(TextPaint(prepared.style.textPaint))
        val mountNatively = mountPlainTextNatively && !prepared.hasInlineStyleRuns
        return PreparedTextViewData(
            baseCapHeightPx = baseCapHeightPx,
            includeFontPadding = prepared.style.includeFontPadding,
            lineHeightPx = if (mountNatively) prepared.style.lineHeightPx else null,
            mountMode = if (mountNatively) TextMountMode.NATIVE else TextMountMode.SPANNABLE,
            text = if (mountNatively) prepared.text else SpannableString.valueOf(resolvePreparedLayoutText(prepared)),
            textPaint = TextPaint(prepared.style.textPaint),
            uniformCapHeightPx = prepared.uniformCapHeightPx ?: resolveUniformCapHeightPx(resolvePreparedLayoutText(prepared), baseCapHeightPx),
        )
    }

    @JvmStatic
    fun transformTextWithBoundaries(text: String, textTransform: String?, boundaries: IntArray?): Array<Any> {
        val resolvedBoundaries = boundaries ?: IntArray(0)
        val transformed = transformText(text, textTransform, resolvedBoundaries.toList())
        val mappedBoundaries =
            IntArray(resolvedBoundaries.size) { index ->
                transformed.offsetsByOriginal[resolvedBoundaries[index]] ?: resolvedBoundaries[index]
            }
        return arrayOf(transformed.text, mappedBoundaries)
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

    @android.annotation.SuppressLint("ObsoleteSdkInt")
    private fun resolveTextBreakStrategy(value: String?): Int {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return 0
        return when (value) {
            "balanced" -> Layout.BREAK_STRATEGY_BALANCED
            "simple" -> Layout.BREAK_STRATEGY_SIMPLE
            else -> Layout.BREAK_STRATEGY_HIGH_QUALITY
        }
    }

    private fun resolveTextColor(value: String?): Int? {
        return RNTextEngineColorParser.parse(value)
    }

    private fun resolveEllipsize(mode: String?, maxLines: Int): TextUtils.TruncateAt? {
        val code = when (mode) {
            "clip" -> 0
            "head" -> 1
            "middle" -> 2
            else -> 3
        }
        return resolveEllipsize(code, maxLines)
    }

    // The Fabric size call uses these codes instead of allocating a Java mode string.
    private fun resolveEllipsize(mode: Int, maxLines: Int): TextUtils.TruncateAt? {
        if (maxLines <= 0 || maxLines == Int.MAX_VALUE) return null
        return when (mode) {
            0 -> null
            1 -> TextUtils.TruncateAt.START
            2 -> TextUtils.TruncateAt.MIDDLE
            else -> TextUtils.TruncateAt.END
        }
    }

    private fun scale(value: Double, allowFontScaling: Boolean, defaultValue: Double): Float {
        val measure = if (value.isNaN()) defaultValue else value
        return if (allowFontScaling) PixelUtil.toPixelFromSP(measure.toFloat()) else PixelUtil.toPixelFromDIP(measure.toFloat())
    }

    private fun Int.toColorString(): String {
        val unsigned = toLong() and 0xFFFFFFFFL
        return "#${unsigned.toString(16).padStart(8, '0')}"
    }

    @JvmStatic
    fun currentFontScaleMultiplier(): Double {
        if (!::reactContext.isInitialized) return 1.0
        val fontScale = reactContext.resources.configuration.fontScale
        return if (fontScale > 0f) fontScale.toDouble() else 1.0
    }

    private fun currentDensity(): Double {
        return PixelUtil.getDisplayMetricDensity().toDouble()
    }

    private fun Double.toDp(): Double {
        return this / currentDensity()
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
