package com.rntextengine

import android.graphics.Canvas
import android.graphics.text.LineBreaker
import android.graphics.text.MeasuredText
import android.graphics.Typeface
import android.os.Build
import android.os.LocaleList
import android.text.BoringLayout
import android.text.Layout
import android.text.Spannable
import android.text.SpannableString
import android.text.SpannedString
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils
import android.text.style.ForegroundColorSpan
import android.util.LongSparseArray
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.common.assets.ReactFontManager
import com.facebook.react.uimanager.DisplayMetricsHolder
import com.facebook.react.uimanager.PixelUtil
import com.facebook.react.views.text.ReactTypefaceUtils.parseFontWeight
import java.lang.ref.WeakReference
import java.nio.ByteBuffer
import java.util.Locale
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

    @Volatile private var textEnvironment: TextEnvironment? = null
    private var nextEnvironmentVersion = 1L

    private class TextEnvironment(val version: Long) {
        val metrics = DisplayMetricsHolder.getScreenDisplayMetrics()
        val density = PixelUtil.getDisplayMetricDensity()
        val scaledPixel = PixelUtil.toPixelFromSP(1f)
        val fontScale = reactContext.resources.configuration.fontScale
        val locale = Locale.getDefault()
        val paintLocales = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) LocaleList.getAdjustedDefault() else null

        fun isCurrent(): Boolean =
            metrics === DisplayMetricsHolder.getScreenDisplayMetrics() &&
                density == PixelUtil.getDisplayMetricDensity() && scaledPixel == PixelUtil.toPixelFromSP(1f) &&
                fontScale == reactContext.resources.configuration.fontScale && locale == Locale.getDefault() &&
                (Build.VERSION.SDK_INT < Build.VERSION_CODES.N || paintLocales == LocaleList.getAdjustedDefault())
    }

    @JvmStatic
    fun textEnvironmentVersion(): Long {
        textEnvironment?.let { if (it.isCurrent()) return it.version }
        return synchronized(this) {
            textEnvironment?.takeIf { it.isCurrent() }
                ?: TextEnvironment(nextEnvironmentVersion++).also { textEnvironment = it }
        }.version
    }

    internal data class ResolvedTextStyle(
        val fallbackLineHeight: Double,
        val includeFontPadding: Boolean,
        val lineHeightPx: Float?,
        val textBreakStrategy: Int,
        val textPaint: TextPaint,
    )

    internal data class TextStyleConfig(
        val allowFontScaling: Boolean,
        val fontFamily: String?,
        val fontSize: Double,
        val fontStyle: String?,
        val fontWeight: String?,
        val letterSpacing: Double,
        val lineHeight: Double,
        val tabularNumbers: Boolean,
    )

    internal class TextSource(
        val text: String,
        val textTransform: String?,
        val style: TextStyleConfig,
        val runs: List<RNTextEngineTextRun>,
        val nested: Boolean,
    )

    internal class PreparedText(
        val hasInlineStyleRuns: Boolean,
        val style: ResolvedTextStyle,
        val text: String,
        val textWithLineHeight: CharSequence,
        val source: TextSource? = null,
        val environmentVersion: Long = 0,
    ) {
        @Volatile var cachedLayoutText: CharSequence? = null
        @Volatile private var cachedCapHeights: CapHeights? = null
        private class MeasuredLayout(val layout: Layout, val maxLines: Int, val ellipsize: TextUtils.TruncateAt?)
        private var measuredLayout: MeasuredLayout? = null

        // Layout mutates its drawing paint, so only one view may own a measured layout.
        fun takeMeasuredLayout(
            width: Int,
            maxLines: Int,
            ellipsize: TextUtils.TruncateAt?,
            alignment: Layout.Alignment,
            justificationMode: Int,
        ): Layout? = synchronized(this) {
            val measured = measuredLayout
            measuredLayout = null
            measured?.layout?.takeIf {
                it.width == width && measured.maxLines == maxLines && measured.ellipsize == ellipsize &&
                    it.matchesAlignment(alignment) && justificationMode == 0
            }
        }

        fun retainMeasuredLayout(layout: Layout, maxLines: Int, ellipsize: TextUtils.TruncateAt?) {
            synchronized(this) { measuredLayout = MeasuredLayout(layout, maxLines, ellipsize) }
        }

        fun displayText(): CharSequence = resolvePreparedLayoutText(this)

        val capHeights: CapHeights
            get() {
                cachedCapHeights?.let { return it }
                return synchronized(this) {
                    cachedCapHeights ?: run {
                        val base = measureCapHeightPx(style.textPaint)
                        CapHeights(base, if (hasInlineStyleRuns) resolveUniformCapHeightPx(textWithLineHeight, base) else base)
                    }.also { cachedCapHeights = it }
                }
            }
    }

    internal data class CapHeights(val base: Float, val uniform: Float?)

    private class PreparedTextData(val content: PreparedText) {
        private var layoutsByKey: LongSparseArray<LayoutInfo>? = null
        private var nextLayout = 0
        @Volatile var plainNextLineOwner: PlainNextLineOwner? = null

        fun layout(width: Double, maxLines: Int, ellipsize: TextUtils.TruncateAt?, anchorToCapHeight: Boolean): LayoutInfo {
            val density = currentDensity()
            val widthPx = max(1, ceil(max(0.0, width) * density).toInt())
            val cacheKey = resolveLayoutCacheKey(widthPx, maxLines, ellipsize, anchorToCapHeight)
            synchronized(this) {
                layoutsByKey?.get(cacheKey)?.let { return it }
            }
            val result = buildLayout(content, width, maxLines, ellipsize, anchorToCapHeight, includeLines = false, density = density)
            if (content.text.isNotEmpty()) {
                synchronized(this) {
                    val layouts = layoutsByKey ?: LongSparseArray<LayoutInfo>().also { layoutsByKey = it }
                    // Private preparation survives Fabric revisions; query history must stay bounded.
                    if (content.environmentVersion != 0L && layouts.size() == 8 && layouts.indexOfKey(cacheKey) < 0) {
                        layouts.removeAt(nextLayout)
                        nextLayout = (nextLayout + 1) % 8
                    }
                    layouts.put(cacheKey, result)
                }
            }
            return result
        }
    }

    private data class PlainLineInfo(
        val end: Int,
        val widthPx: Float,
    )

    private class PlainNextLineOwner {
        val linesByKey = LongSparseArray<PlainLineInfo>()
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
        synchronized(this) {
            if (::reactContext.isInitialized && reactContext === context) return
            reactContext = context
            textEnvironment = null
        }
    }

    @JvmStatic
    fun cleanup() {
        preparedTexts.clear()
        glyphFields.clear()
        synchronized(this) { textEnvironment = null }
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
        val rowHeightPx = PixelUtil.toPixelFromDIP(lineHeight.toFloat())

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
                    yOffset = (rowHeightPx - (metrics.descent - metrics.ascent)) * 0.5f - metrics.ascent,
                )
            }

        val handle = nextGlyphFieldHandle.getAndIncrement()
        glyphFields[handle] =
            GlyphFieldData(
                columns = columns,
                glyphPaletteChars = glyphPaletteChars,
                glyphPalette = glyphPalette,
                lineHeightPx = rowHeightPx,
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
        preparedTexts[handle] = PreparedTextData(buildPreparedText(text, style))
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
        environmentVersion: Long = 0,
        hasNested: Boolean = false,
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
        val source = if (environmentVersion != 0L) TextSource(
            text, textTransform,
            TextStyleConfig(allowFontScaling, fontFamily, fontSize, fontStyle, fontWeight, letterSpacing, lineHeight, tabularNumbers),
            emptyList(), hasNested,
        ) else null
        preparedTexts[handle] = PreparedTextData(buildPreparedTextForTextView(text, textTransform, style, source, environmentVersion))
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
            preparedTexts[handle] = PreparedTextData(buildPreparedText(texts[index], style))
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
                fontFamily = fontFamily,
                fontSize = fontSize,
                fontStyle = fontStyle,
                fontWeight = fontWeight,
                letterSpacing = letterSpacing,
                lineHeight = lineHeight,
                tabularNumbers = tabularNumbers,
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
            PreparedTextData(
                buildPreparedText(text, baseStyle, baseConfig, runs),
            )
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
        environmentVersion: Long = 0,
        hasNested: Boolean = false,
    ): Long {
        val baseConfig =
            TextStyleConfig(
                allowFontScaling = allowFontScaling,
                fontFamily = fontFamily,
                fontSize = fontSize,
                fontStyle = fontStyle,
                fontWeight = fontWeight,
                letterSpacing = letterSpacing,
                lineHeight = lineHeight,
                tabularNumbers = tabularNumbers,
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
            PreparedTextData(
                buildPreparedTextForTextView(text, textTransform, baseStyle, baseConfig, runs,
                    if (environmentVersion != 0L) TextSource(text, textTransform, baseConfig, runs, hasNested) else null,
                    environmentVersion,
                ),
            )
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
                fontFamily = fontFamily,
                fontSize = fontSize,
                fontStyle = fontStyle,
                fontWeight = fontWeight,
                letterSpacing = letterSpacing,
                lineHeight = lineHeight,
                tabularNumbers = tabularNumbers,
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
                PreparedTextData(
                    buildPreparedText(texts[index], baseStyle, baseConfig, runsByText[index]),
                )
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
        return measureIntrinsicWidth(requirePrepared(handle).content)
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
                fontFamily = fontFamily,
                fontSize = fontSize,
                fontStyle = fontStyle,
                fontWeight = fontWeight,
                letterSpacing = letterSpacing,
                lineHeight = lineHeight,
                tabularNumbers = tabularNumbers,
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
            buildPreparedText(text, baseStyle, baseConfig, runs)
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
        val context = resolveOneShotPlainLayoutContext(style, width, maxLines, ellipsizeMode)
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
                fontFamily = fontFamily,
                fontSize = fontSize,
                fontStyle = fontStyle,
                fontWeight = fontWeight,
                letterSpacing = letterSpacing,
                lineHeight = lineHeight,
                tabularNumbers = tabularNumbers,
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
            buildPreparedText(text, baseStyle, baseConfig, runs)
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
        val context = resolveOneShotPlainLayoutContext(style, width, maxLines, ellipsizeMode)
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
                fontFamily = fontFamily,
                fontSize = fontSize,
                fontStyle = fontStyle,
                fontWeight = fontWeight,
                letterSpacing = letterSpacing,
                lineHeight = lineHeight,
                tabularNumbers = tabularNumbers,
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
                    buildPreparedText(text, baseStyle, baseConfig, runsByText[index]),
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
        val layout = requirePrepared(handle).layout(width, maxLines, ellipsize, anchorToCapHeight)
        val widthBits = layout.width.toFloat().toRawBits().toLong()
        // Sign-extending a negative height would overwrite the packed width.
        val heightBits = layout.height.toFloat().toRawBits().toLong() and 0xFFFFFFFFL
        return (widthBits shl 32) or heightBits
    }

    @JvmStatic
    fun layout(handle: Long, width: Double, maxLines: Int, ellipsizeMode: String?, anchorToCapHeight: Boolean): DoubleArray {
        val prepared = requirePrepared(handle)
        val ellipsize = resolveEllipsize(ellipsizeMode, maxLines)
        return packLayout(prepared.layout(width, maxLines, ellipsize, anchorToCapHeight))
    }

    @JvmStatic
    fun layoutBatch(handles: LongArray, width: Double, maxLines: Int, ellipsizeMode: String?, anchorToCapHeight: Boolean): DoubleArray {
        val ellipsize = resolveEllipsize(ellipsizeMode, maxLines)
        val packed = DoubleArray(handles.size * PACKED_LAYOUT_SIZE)
        handles.forEachIndexed { index, handle ->
            packLayoutInto(
                packed,
                index * PACKED_LAYOUT_SIZE,
                requirePrepared(handle).layout(width, maxLines, ellipsize, anchorToCapHeight),
            )
        }
        return packed
    }

    @JvmStatic
    fun layoutLines(handle: Long, width: Double, maxLines: Int, ellipsizeMode: String?, anchorToCapHeight: Boolean): DoubleArray {
        val prepared = requirePrepared(handle).content
        val ellipsize = resolveEllipsize(ellipsizeMode, maxLines)
        return packLayoutWithLines(buildLayout(prepared, width, maxLines, ellipsize, anchorToCapHeight, includeLines = true))
    }

    @JvmStatic
    fun layoutNextLine(handle: Long, start: Int, width: Double, anchorToCapHeight: Boolean): DoubleArray? {
        val preparedData = requirePrepared(handle)
        val prepared = preparedData.content
        val queryStart = resolveNextLineStart(prepared.text, start)
        if (queryStart < 0) return null
        resolvePlainNextLine(preparedData, queryStart, width, anchorToCapHeight)?.let { return it }

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
                val capHeights = prepared.capHeights
                resolveCapHeightInsetsPx(
                    layout = layout,
                    text = text,
                    defaultCapHeightPx = capHeights.base,
                    uniformCapHeightPx = capHeights.uniform,
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
        preparedData: PreparedTextData,
        start: Int,
        width: Double,
        anchorToCapHeight: Boolean,
    ): DoubleArray? {
        val prepared = preparedData.content
        if (prepared.hasInlineStyleRuns || prepared.style.includeFontPadding) return null
        if (start < 0 || start >= prepared.text.length) return null

        val density = currentDensity()
        val widthPx = max(1, ceil(max(0.0, width) * density).toInt())
        val nextLineOwner = resolvePlainNextLineOwner(preparedData)
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
                prepared.capHeights.base
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

        val lineHeightPx = if (lineHeight.isNaN()) null else {
            ceil(scale(lineHeight, allowFontScaling, defaultValue = lineHeight).toDouble()).toFloat()
        }
        val fallbackLineHeight = lineHeightPx?.toDouble()?.toDp() ?: textPaint.fontMetricsInt.let {
            (it.descent - it.ascent).toDouble().toDp()
        }

        return ResolvedTextStyle(
            fallbackLineHeight = fallbackLineHeight,
            includeFontPadding = includeFontPadding,
            lineHeightPx = lineHeightPx,
            textBreakStrategy = resolveTextBreakStrategy(textBreakStrategy),
            textPaint = textPaint,
        )
    }

    private fun resolveRunTextPaint(
        baseStyle: ResolvedTextStyle,
        baseConfig: TextStyleConfig,
        runStyle: RNTextEngineTextRunStyle,
    ): TextPaint {
        val fontFamily = if (runStyle.hasFontFamily) runStyle.fontFamily else baseConfig.fontFamily
        val fontSize = if (runStyle.hasFontSize) runStyle.fontSize else baseConfig.fontSize
        val fontWeight = if (runStyle.hasFontWeight) runStyle.fontWeight else baseConfig.fontWeight
        val fontStyle = if (runStyle.hasFontStyle) runStyle.fontStyle else baseConfig.fontStyle
        val letterSpacing = if (runStyle.hasLetterSpacing) runStyle.letterSpacing else baseConfig.letterSpacing
        val tabularNumbers = if (runStyle.hasTabularNumbers) runStyle.tabularNumbers else baseConfig.tabularNumbers

        val textPaint = TextPaint(baseStyle.textPaint)
        if (runStyle.hasColor) {
            textPaint.color = resolveTextColor(runStyle.color) ?: defaultTextPaintColor
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

        return textPaint
    }

    private fun buildPreparedText(
        text: String, style: ResolvedTextStyle, source: TextSource? = null, environmentVersion: Long = 0,
    ): PreparedText {
        return PreparedText(
            hasInlineStyleRuns = false,
            style = style,
            text = text,
            textWithLineHeight = text,
            source = source,
            environmentVersion = environmentVersion,
        )
    }

    private fun buildPreparedTextForTextView(
        text: String,
        textTransform: String?,
        style: ResolvedTextStyle,
        source: TextSource? = null,
        environmentVersion: Long = 0,
    ): PreparedText {
        return buildPreparedText(applyTextTransform(text, textTransform), style, source, environmentVersion)
    }

    private fun buildPreparedText(
        text: String,
        style: ResolvedTextStyle,
        baseConfig: TextStyleConfig,
        runs: List<RNTextEngineTextRun>,
        source: TextSource? = null,
        environmentVersion: Long = 0,
    ): PreparedText {
        val styledText =
            if (text.isEmpty()) {
                text
            } else {
                buildStyledText(text, style, baseConfig, runs)
            }

        return PreparedText(
            hasInlineStyleRuns = runs.isNotEmpty(),
            style = style,
            text = text,
            textWithLineHeight = styledText,
            source = source,
            environmentVersion = environmentVersion,
        )
    }

    private fun buildPreparedTextForTextView(
        text: String,
        textTransform: String?,
        style: ResolvedTextStyle,
        baseConfig: TextStyleConfig,
        runs: List<RNTextEngineTextRun>,
        source: TextSource? = null,
        environmentVersion: Long = 0,
    ): PreparedText {
        if (runs.isEmpty()) return buildPreparedTextForTextView(text, textTransform, style, source, environmentVersion)

        val transformed = transformText(text, textTransform) {
            ArrayList<Int>(runs.size * 2).apply {
                runs.forEach { run ->
                    add(run.start)
                    add(run.end)
                }
            }
        }
        val transformedRuns =
            if (transformed.offsetsByOriginal.isEmpty()) runs else runs.map { run ->
                run.copy(
                    start = transformed.offsetsByOriginal[run.start] ?: run.start,
                    end = transformed.offsetsByOriginal[run.end] ?: run.end,
                )
            }

        return buildPreparedText(transformed.text, style, baseConfig, transformedRuns, source, environmentVersion)
    }

    private fun resolvePreparedLayoutText(prepared: PreparedText): CharSequence {
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
                }.let(::SpannedString).also { prepared.cachedLayoutText = it }
        }
    }

    private fun buildStyledText(
        text: String,
        baseStyle: ResolvedTextStyle,
        baseConfig: TextStyleConfig,
        runs: List<RNTextEngineTextRun>,
    ): CharSequence {
        val styledText = SpannableString(text)

        if (baseStyle.lineHeightPx != null) {
            applyBaseLineHeightSpans(styledText, text.length, baseStyle.lineHeightPx, runs)
        }

        runs.forEach { run ->
            val runStyle = run.style
            // Only typography overrides should split Android's shaping context.
            val span = when {
                runStyle.hasFontFamily || runStyle.hasFontSize || runStyle.hasFontStyle || runStyle.hasFontWeight ||
                    runStyle.hasLetterSpacing || runStyle.hasTabularNumbers ->
                    RNTextEngineTextPaintSpan(resolveRunTextPaint(baseStyle, baseConfig, runStyle), runStyle.hasColor)
                runStyle.hasColor -> ForegroundColorSpan(resolveTextColor(runStyle.color) ?: defaultTextPaintColor)
                else -> null
            }
            if (span != null) {
                styledText.setSpan(span, run.start, run.end, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE)
            }

            val lineHeightPx = if (runStyle.hasLineHeight) {
                val lineHeight = runStyle.lineHeight
                if (lineHeight.isNaN()) null else scale(lineHeight, baseConfig.allowFontScaling, defaultValue = lineHeight)
            } else {
                baseStyle.lineHeightPx
            }
            if (lineHeightPx != null) {
                styledText.setSpan(
                    RNTextEngineLineHeightSpan(lineHeightPx),
                    run.start,
                    run.end,
                    Spannable.SPAN_EXCLUSIVE_EXCLUSIVE,
                )
            }
        }

        return SpannedString(styledText)
    }

    private fun applyBaseLineHeightSpans(
        styledText: SpannableString,
        textLength: Int,
        lineHeightPx: Float,
        runs: List<RNTextEngineTextRun>,
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
    ): List<RNTextEngineTextRun> {
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
    ): List<RNTextEngineTextRun> {
        val runs = ArrayList<RNTextEngineTextRun>(runCount)
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
                RNTextEngineTextRun(
                    end = end,
                    start = start,
                    style =
                        RNTextEngineTextRunStyle(
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
    ): List<List<RNTextEngineTextRun>> {
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

        val runsByText = ArrayList<List<RNTextEngineTextRun>>(texts.size)
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



    private data class OneShotPlainLayoutContext(
        val density: Double,
        val effectiveMaxLines: Int,
        val ellipsize: TextUtils.TruncateAt?,
        val lineHeightDp: Double?,
        val textWidthPx: Int,
    )

    private fun trimVisibleEnd(text: CharSequence, start: Int, end: Int): Int {
        var visibleEnd = end

        while (visibleEnd > start && text[visibleEnd - 1].isWhitespace()) {
            visibleEnd -= 1
        }

        return visibleEnd
    }

    // Android leaves trailing empty paragraphs unspanned and can pad an ellipsized final line.
    private fun canUseFixedLineHeight(
        style: ResolvedTextStyle,
        text: String,
        ellipsize: TextUtils.TruncateAt?,
        anchorToCapHeight: Boolean,
    ): Boolean =
        style.lineHeightPx != null && !anchorToCapHeight &&
            (!style.includeFontPadding || ellipsize == null) && !text.endsWith('\n')

    private fun buildLayout(
        prepared: PreparedText,
        width: Double,
        maxLines: Int,
        ellipsize: TextUtils.TruncateAt?,
        anchorToCapHeight: Boolean,
        includeLines: Boolean,
        density: Double = currentDensity(),
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

        val layoutWidth = max(0.0, width) * density
        val textWidthPx = max(1, ceil(layoutWidth).toInt())
        val useFixedLineHeight = !prepared.hasInlineStyleRuns &&
            canUseFixedLineHeight(prepared.style, prepared.text, ellipsize, anchorToCapHeight)
        val retainLayout = prepared.source != null && !includeLines && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            prepared.style.textBreakStrategy == Layout.BREAK_STRATEGY_HIGH_QUALITY
        val charSequence = if (useFixedLineHeight && !retainLayout) prepared.text else prepared.displayText()
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
                val capHeights = prepared.capHeights
                resolveCapHeightInsetsPx(
                    layout = layout,
                    text = charSequence,
                    defaultCapHeightPx = capHeights.base,
                    uniformCapHeightPx = capHeights.uniform,
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
                } else if (useFixedLineHeight) {
                    ((index + 1) * requireNotNull(prepared.style.lineHeightPx).toDouble()) / density
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

        if (retainLayout) prepared.retainMeasuredLayout(layout, effectiveMaxLines, ellipsize)

        return LayoutInfo(
            height = measuredHeight,
            lastLineWidth = lastLineWidth,
            lineCount = actualLineCount.toDouble(),
            lines = lines,
            width = widestLine,
        )
    }

    private fun resolveOneShotPlainLayoutContext(
        style: ResolvedTextStyle,
        width: Double,
        maxLines: Int,
        ellipsizeMode: String?,
    ): OneShotPlainLayoutContext {
        val density = currentDensity()
        val effectiveMaxLines = if (maxLines > 0) maxLines else Int.MAX_VALUE
        return OneShotPlainLayoutContext(
            density = density,
            effectiveMaxLines = effectiveMaxLines,
            ellipsize = resolveEllipsize(ellipsizeMode, effectiveMaxLines),
            lineHeightDp = style.lineHeightPx?.toDouble()?.div(density),
            textWidthPx = max(1, ceil(max(0.0, width) * density).toInt()),
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
        val useFixedLineHeight = canUseFixedLineHeight(style, text, context.ellipsize, anchorToCapHeight)
        // LineBreaker accepts one paragraph; StaticLayout owns explicit paragraph boundaries.
        if (!includeLines && useFixedLineHeight && context.effectiveMaxLines == Int.MAX_VALUE &&
            context.ellipsize == null && '\n' !in text) {
            return buildOneShotPlainLayoutSimple(text, style, context, reusablePaint)
        }

        val density = context.density
        val charSequence =
            if (useFixedLineHeight || style.lineHeightPx == null) {
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
                } else if (useFixedLineHeight) {
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


    private fun resolveLayoutCacheKey(widthPx: Int, maxLines: Int, ellipsize: TextUtils.TruncateAt?, anchorToCapHeight: Boolean): Long {
        val ellipsizeCode = (ellipsize?.ordinal ?: -1) + 1
        val normalizedMaxLines = if (maxLines > 0) maxLines else 0
        val options = ((normalizedMaxLines.toLong() and 0x0FFFFFFFL) shl 4) or ((ellipsizeCode.toLong() and 0x7L) shl 1) or if (anchorToCapHeight) 1L else 0L
        return (widthPx.toLong() shl 32) or options
    }

    private fun measureIntrinsicWidth(prepared: PreparedText): Double {
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

    internal fun preparedText(handle: Long): PreparedText? = preparedTexts[handle]?.content

    internal fun prepareTextViewContent(
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
        prepared: PreparedText? = null,
        current: PreparedText? = null,
        retainSource: Boolean = false,
    ): PreparedText {
        val environmentVersion = textEnvironmentVersion()
        val source = prepared?.source
        val nestedSource = source?.takeIf { it.nested }
        val sourceText = nestedSource?.text ?: text
        val sourceTransform = if (nestedSource != null) null else textTransform
        val sourceRuns = nestedSource?.runs ?: runs
        val scaleRoot = nestedSource != null && allowFontScaling
        val sourceFontSize = if (scaleRoot) scaleTypographyValue(fontSize) else fontSize
        val sourceLetterSpacing = if (scaleRoot) scaleTypographyValue(letterSpacing) else letterSpacing
        val sourceLineHeight = if (scaleRoot && !lineHeight.isNaN()) scaleTypographyValue(lineHeight) else lineHeight
        val sourceAllowScaling = allowFontScaling && nestedSource == null
        fun matches(candidate: PreparedText?): Boolean {
            val input = candidate?.source ?: return false
            return candidate.environmentVersion == environmentVersion &&
                input.nested == (nestedSource != null) && input.text == sourceText &&
                input.textTransform == sourceTransform && input.runs == sourceRuns &&
                input.style.matches(sourceAllowScaling, fontFamily, sourceFontSize, fontStyle, fontWeight,
                    sourceLetterSpacing, sourceLineHeight, tabularNumbers)
        }
        if (current != null && matches(current)) return current
        if (prepared != null && prepared !== current && matches(prepared)) return prepared

        val baseStyle = resolveTextStyle(
            color = color?.toColorString(),
            fontFamily = fontFamily,
            fontSize = sourceFontSize,
            fontWeight = fontWeight,
            fontStyle = fontStyle,
            letterSpacing = sourceLetterSpacing,
            lineHeight = sourceLineHeight,
            allowFontScaling = sourceAllowScaling,
            includeFontPadding = includeFontPadding,
            tabularNumbers = tabularNumbers,
            textBreakStrategy = textBreakStrategy,
        )
        if (sourceRuns.isEmpty() && !retainSource) return buildPreparedTextForTextView(sourceText, sourceTransform, baseStyle, environmentVersion = environmentVersion)

        val baseConfig = TextStyleConfig(sourceAllowScaling, fontFamily, sourceFontSize, fontStyle, fontWeight,
            sourceLetterSpacing, sourceLineHeight, tabularNumbers)
        val nextSource = if (retainSource) TextSource(
            sourceText, sourceTransform, baseConfig, sourceRuns, nestedSource != null,
        ) else null
        if (sourceRuns.isEmpty()) return buildPreparedTextForTextView(sourceText, sourceTransform, baseStyle, nextSource, environmentVersion)
        return buildPreparedTextForTextView(sourceText, sourceTransform, baseStyle, baseConfig, sourceRuns, nextSource, environmentVersion)
    }

    private fun TextStyleConfig.matches(
        allowScaling: Boolean,
        family: String?,
        size: Double,
        style: String?,
        weight: String?,
        spacing: Double,
        height: Double,
        tabular: Boolean,
    ): Boolean {
        return allowFontScaling == allowScaling && fontFamily == family && fontStyle == style && fontWeight == weight &&
            fontSize.toFloat().toBits() == size.toFloat().toBits() &&
            letterSpacing.toFloat().toBits() == spacing.toFloat().toBits() &&
            lineHeight.toFloat().toBits() == height.toFloat().toBits() && tabularNumbers == tabular
    }

    @JvmStatic
    fun transformTextWithBoundaries(text: String, textTransform: String?, boundaries: IntArray?): Array<Any> {
        val resolvedBoundaries = boundaries ?: IntArray(0)
        val transformed = transformText(text, textTransform) { resolvedBoundaries.toList() }
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
    fun scaleTypographyValue(value: Double): Double {
        return PixelUtil.toPixelFromSP(value.toFloat()).toDouble() / currentDensity()
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
