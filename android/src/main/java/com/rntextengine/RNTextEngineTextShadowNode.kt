@file:Suppress("DEPRECATION")

package com.rntextengine

import com.facebook.react.bridge.ReadableArray
import com.facebook.react.common.annotations.internal.LegacyArchitecture
import com.facebook.react.common.annotations.internal.LegacyArchitectureLogLevel
import com.facebook.react.uimanager.LayoutShadowNode
import com.facebook.react.uimanager.ReactShadowNodeImpl
import com.facebook.react.uimanager.UIViewOperationQueue
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.yoga.YogaMeasureFunction
import com.facebook.yoga.YogaMeasureMode
import com.facebook.yoga.YogaMeasureOutput
import com.facebook.yoga.YogaNode

private const val RUN_STYLE_HAS_COLOR = 1 shl 0
private const val RUN_STYLE_HAS_FONT_FAMILY = 1 shl 1
private const val RUN_STYLE_HAS_FONT_SIZE = 1 shl 2
private const val RUN_STYLE_HAS_FONT_STYLE = 1 shl 3
private const val RUN_STYLE_HAS_FONT_WEIGHT = 1 shl 4
private const val RUN_STYLE_HAS_LETTER_SPACING = 1 shl 5
private const val RUN_STYLE_HAS_LINE_HEIGHT = 1 shl 6
private const val RUN_STYLE_HAS_TABULAR_NUMBERS = 1 shl 7

@LegacyArchitecture(logLevel = LegacyArchitectureLogLevel.ERROR)
internal class RNTextEngineTextShadowNode : LayoutShadowNode(), YogaMeasureFunction {
    private var anchorToCapHeight = false
    private var allowFontScaling = false
    private var hasAllowFontScaling = false
    private var isVirtualTextSpan = false
    private var color: Int? = null
    private var ellipsizeMode: String? = null
    private var fontFamily: String? = null
    private var fontSize = 0.0
    private var fontStyle: String? = null
    private var fontWeight: String? = null
    private var hasLetterSpacing = false
    private var hasTabularNumbers = false
    private var letterSpacing = 0.0
    private var lineHeight = 0.0
    private var numberOfLines = 0
    private var tabularNumbers = false
    private var textTransform: String? = null
    private var runCount = 0
    private var runColors: ReadableArray? = null
    private var runEnds: ReadableArray? = null
    private var runFontFamilies: ReadableArray? = null
    private var runFontSizes: ReadableArray? = null
    private var runFontStyles: ReadableArray? = null
    private var runFontWeights: ReadableArray? = null
    private var runLetterSpacings: ReadableArray? = null
    private var runLineHeights: ReadableArray? = null
    private var runStarts: ReadableArray? = null
    private var runStyleMasks: ReadableArray? = null
    private var runTabularNumbers: ReadableArray? = null
    private var text = ""

    private var preparedHandle = 0L
    private var cachedPayload: RNTextEngineResolvedTextPayload? = null
    private var lastEmittedNestedHash: Long? = null
    private var localData: RNTextEngineTextLocalData? = null

    init {
        setMeasureFunction(this)
    }

    override fun isVirtual(): Boolean = isVirtualTextSpan

    override fun isVirtualAnchor(): Boolean = false

    override fun hoistNativeChildren(): Boolean = !isVirtualTextSpan

    @set:ReactProp(name = "anchorToCapHeight", defaultBoolean = false)
    var measureAnchorToCapHeight: Boolean
        get() = anchorToCapHeight
        set(value) {
            if (anchorToCapHeight == value) return
            anchorToCapHeight = value
            markMeasureDirty()
        }

    @set:ReactProp(name = "allowFontScaling", defaultBoolean = false)
    var measureAllowFontScaling: Boolean
        get() = allowFontScaling
        set(value) {
            if (allowFontScaling == value) return
            allowFontScaling = value
            markMeasureDirty()
        }

    @set:ReactProp(name = "rnteHasAllowFontScaling", defaultBoolean = false)
    var measureRnteHasAllowFontScaling: Boolean
        get() = hasAllowFontScaling
        set(value) {
            if (hasAllowFontScaling == value) return
            hasAllowFontScaling = value
            markMeasureDirty()
        }

    @set:ReactProp(name = "rnteIsVirtualTextSpan", defaultBoolean = false)
    var measureRnteIsVirtualTextSpan: Boolean
        get() = isVirtualTextSpan
        set(value) {
            if (isVirtualTextSpan == value) return
            isVirtualTextSpan = value
            invalidateNode(affectsMeasurement = true)
        }

    @set:ReactProp(name = "color", customType = "Color")
    var measureColor: Int?
        get() = color
        set(value) {
            if (color == value) return
            color = value
            invalidateResolvedPayloadOnly()
        }

    @set:ReactProp(name = "ellipsizeMode")
    var measureEllipsizeMode: String?
        get() = ellipsizeMode
        set(value) {
            if (ellipsizeMode == value) return
            ellipsizeMode = value
            markMeasureDirty()
        }

    @set:ReactProp(name = "fontFamily")
    var measureFontFamily: String?
        get() = fontFamily
        set(value) {
            if (fontFamily == value) return
            fontFamily = value
            markMeasureDirty()
        }

    @set:ReactProp(name = "fontSize", defaultFloat = 0f)
    var measureFontSize: Double
        get() = fontSize
        set(value) {
            if (fontSize == value) return
            fontSize = value
            markMeasureDirty()
        }

    @set:ReactProp(name = "fontStyle")
    var measureFontStyle: String?
        get() = fontStyle
        set(value) {
            if (fontStyle == value) return
            fontStyle = value
            markMeasureDirty()
        }

    @set:ReactProp(name = "fontWeight")
    var measureFontWeight: String?
        get() = fontWeight
        set(value) {
            if (fontWeight == value) return
            fontWeight = value
            markMeasureDirty()
        }

    @set:ReactProp(name = "letterSpacing", defaultFloat = 0f)
    var measureLetterSpacing: Double
        get() = letterSpacing
        set(value) {
            if (letterSpacing == value) return
            letterSpacing = value
            markMeasureDirty()
        }

    @set:ReactProp(name = "rnteHasLetterSpacing", defaultBoolean = false)
    var measureRnteHasLetterSpacing: Boolean
        get() = hasLetterSpacing
        set(value) {
            if (hasLetterSpacing == value) return
            hasLetterSpacing = value
            markMeasureDirty()
        }

    @set:ReactProp(name = "lineHeight", defaultFloat = 0f)
    var measureLineHeight: Double
        get() = lineHeight
        set(value) {
            if (lineHeight == value) return
            lineHeight = value
            markMeasureDirty()
        }

    @set:ReactProp(name = "numberOfLines", defaultInt = 0)
    var measureNumberOfLines: Int
        get() = numberOfLines
        set(value) {
            if (numberOfLines == value) return
            numberOfLines = value
            markMeasureDirty()
        }

    @set:ReactProp(name = "tabularNumbers", defaultBoolean = false)
    var measureTabularNumbers: Boolean
        get() = tabularNumbers
        set(value) {
            if (tabularNumbers == value) return
            tabularNumbers = value
            markMeasureDirty()
        }

    @set:ReactProp(name = "rnteHasTabularNumbers", defaultBoolean = false)
    var measureRnteHasTabularNumbers: Boolean
        get() = hasTabularNumbers
        set(value) {
            if (hasTabularNumbers == value) return
            hasTabularNumbers = value
            markMeasureDirty()
        }

    @set:ReactProp(name = "textTransform")
    var measureTextTransform: String?
        get() = textTransform
        set(value) {
            if (textTransform == value) return
            textTransform = value
            markMeasureDirty()
        }

    @set:ReactProp(name = "runCount", defaultInt = 0)
    var measureRunCount: Int
        get() = runCount
        set(value) {
            if (runCount == value) return
            runCount = value
            markMeasureDirty()
        }

    @set:ReactProp(name = "runColors")
    var measureRunColors: ReadableArray?
        get() = runColors
        set(value) {
            runColors = value
            invalidateResolvedPayloadOnly()
        }

    @set:ReactProp(name = "runEnds")
    var measureRunEnds: ReadableArray?
        get() = runEnds
        set(value) {
            runEnds = value
            markMeasureDirty()
        }

    @set:ReactProp(name = "runFontFamilies")
    var measureRunFontFamilies: ReadableArray?
        get() = runFontFamilies
        set(value) {
            runFontFamilies = value
            markMeasureDirty()
        }

    @set:ReactProp(name = "runFontSizes")
    var measureRunFontSizes: ReadableArray?
        get() = runFontSizes
        set(value) {
            runFontSizes = value
            markMeasureDirty()
        }

    @set:ReactProp(name = "runFontStyles")
    var measureRunFontStyles: ReadableArray?
        get() = runFontStyles
        set(value) {
            runFontStyles = value
            markMeasureDirty()
        }

    @set:ReactProp(name = "runFontWeights")
    var measureRunFontWeights: ReadableArray?
        get() = runFontWeights
        set(value) {
            runFontWeights = value
            markMeasureDirty()
        }

    @set:ReactProp(name = "runLetterSpacings")
    var measureRunLetterSpacings: ReadableArray?
        get() = runLetterSpacings
        set(value) {
            runLetterSpacings = value
            markMeasureDirty()
        }

    @set:ReactProp(name = "runLineHeights")
    var measureRunLineHeights: ReadableArray?
        get() = runLineHeights
        set(value) {
            runLineHeights = value
            markMeasureDirty()
        }

    @set:ReactProp(name = "runStarts")
    var measureRunStarts: ReadableArray?
        get() = runStarts
        set(value) {
            runStarts = value
            markMeasureDirty()
        }

    @set:ReactProp(name = "runStyleMasks")
    var measureRunStyleMasks: ReadableArray?
        get() = runStyleMasks
        set(value) {
            runStyleMasks = value
            markMeasureDirty()
        }

    @set:ReactProp(name = "runTabularNumbers")
    var measureRunTabularNumbers: ReadableArray?
        get() = runTabularNumbers
        set(value) {
            runTabularNumbers = value
            markMeasureDirty()
        }

    @set:ReactProp(name = "text")
    var measureText: String
        get() = text
        set(value) {
            if (text == value) return
            text = value
            markMeasureDirty()
        }

    override fun addChildAt(child: ReactShadowNodeImpl?, i: Int) {
        super.addChildAt(child, i)
        markMeasureDirty()
    }

    override fun removeChildAt(i: Int): ReactShadowNodeImpl {
        val removed = super.removeChildAt(i)
        markMeasureDirty()
        return removed
    }

    override fun setLocalData(data: Any) {
        require(data is RNTextEngineTextLocalData) { "RNTextEngine: expected RNTextEngineTextLocalData for local text measurement." }
        if (localData == data) return
        localData = data
        invalidateNode(affectsMeasurement = true)
    }

    override fun onCollectExtraUpdates(uiViewOperationQueue: UIViewOperationQueue) {
        super.onCollectExtraUpdates(uiViewOperationQueue)

        if (isVirtualNestedTextNode()) {
            return
        }

        if (!hasValidatedNestedTextChildren()) {
            if (lastEmittedNestedHash != null) {
                uiViewOperationQueue.enqueueUpdateExtraData(getReactTag(), RNTextEngineResolvedTextPayload.EMPTY)
                lastEmittedNestedHash = null
            }
            return
        }

        val payload = resolvePayload()
        if (!payload.hasNested) {
            if (lastEmittedNestedHash != null) {
                uiViewOperationQueue.enqueueUpdateExtraData(getReactTag(), RNTextEngineResolvedTextPayload.EMPTY)
                lastEmittedNestedHash = null
            }
            return
        }

        if (lastEmittedNestedHash == payload.hash) return
        lastEmittedNestedHash = payload.hash
        uiViewOperationQueue.enqueueUpdateExtraData(getReactTag(), payload)
    }

    override fun measure(
        node: YogaNode,
        width: Float,
        widthMode: YogaMeasureMode,
        height: Float,
        heightMode: YogaMeasureMode,
    ): Long {
        if (widthMode == YogaMeasureMode.EXACTLY && heightMode == YogaMeasureMode.EXACTLY) {
            return YogaMeasureOutput.make(width, height)
        }

        val measurement =
            measurePreparedAutoSizeText(
                handle = ensurePreparedHandle(),
                widthPx = width,
                widthMode = widthMode,
                heightPx = height,
                heightMode = heightMode,
                numberOfLines = numberOfLines,
                ellipsizeMode = ellipsizeMode,
                anchorToCapHeight = anchorToCapHeight,
            )

        return YogaMeasureOutput.make(measurement.widthPx, measurement.heightPx)
    }

    override fun dispose() {
        releasePreparedHandle()
        super.dispose()
    }

    private fun ensurePreparedHandle(): Long {
        if (preparedHandle != 0L) return preparedHandle
        val resolvedText = resolvedTextValue()

        if (!hasValidatedNestedTextChildren()) {
            preparedHandle =
                if (!hasInlineRuns()) {
                    RNTextEngineBindings.prepareTextView(
                        text = resolvedText,
                        textTransform = textTransform,
                        color = null,
                        fontFamily = fontFamily,
                        fontSize = resolvedFontSize(),
                        fontWeight = fontWeight,
                        fontStyle = fontStyle,
                        letterSpacing = letterSpacing,
                        lineHeight = resolvedLineHeight(),
                        allowFontScaling = allowFontScaling,
                        includeFontPadding = false,
                        tabularNumbers = tabularNumbers,
                        textBreakStrategy = null,
                    )
                } else {
                    val preparedRuns = resolvePreparedInlineRuns(resolvedText)
                    if (preparedRuns == null) {
                        RNTextEngineBindings.prepareTextView(
                            text = resolvedText,
                            textTransform = textTransform,
                            color = null,
                            fontFamily = fontFamily,
                            fontSize = resolvedFontSize(),
                            fontWeight = fontWeight,
                            fontStyle = fontStyle,
                            letterSpacing = letterSpacing,
                            lineHeight = resolvedLineHeight(),
                            allowFontScaling = allowFontScaling,
                            includeFontPadding = false,
                            tabularNumbers = tabularNumbers,
                            textBreakStrategy = null,
                        )
                    } else {
                        RNTextEngineBindings.prepareTextViewWithRuns(
                            text = resolvedText,
                            textTransform = textTransform,
                            color = null,
                            fontFamily = fontFamily,
                            fontSize = resolvedFontSize(),
                            fontWeight = fontWeight,
                            fontStyle = fontStyle,
                            letterSpacing = letterSpacing,
                            lineHeight = resolvedLineHeight(),
                            allowFontScaling = allowFontScaling,
                            includeFontPadding = false,
                            tabularNumbers = tabularNumbers,
                            textBreakStrategy = null,
                            runStarts = preparedRuns.runStarts,
                            runEnds = preparedRuns.runEnds,
                            runStyleMasks = preparedRuns.runStyleMasks,
                            runColors = preparedRuns.runColors,
                            runFontFamilies = preparedRuns.runFontFamilies,
                            runFontSizes = preparedRuns.runFontSizes,
                            runFontWeights = preparedRuns.runFontWeights,
                            runFontStyles = preparedRuns.runFontStyles,
                            runLetterSpacings = preparedRuns.runLetterSpacings,
                            runLineHeights = preparedRuns.runLineHeights,
                            runTabularNumbers = preparedRuns.runTabularNumbers,
                        )
                    }
                }

            return preparedHandle
        }

        val payload = resolvePayload()
        val normalizedRootStyle = resolveNodeStyle(parent = null).normalizedForPreparedText()

        preparedHandle =
            if (payload.runStarts.isEmpty()) {
                RNTextEngineBindings.prepareTextView(
                    text = payload.text,
                    textTransform = null,
                    color = null,
                    fontFamily = normalizedRootStyle.fontFamily,
                    fontSize = normalizedRootStyle.fontSize,
                    fontWeight = normalizedRootStyle.fontWeight,
                    fontStyle = normalizedRootStyle.fontStyle,
                    letterSpacing = normalizedRootStyle.letterSpacing,
                    lineHeight = normalizedRootStyle.lineHeight.takeIf { it > 0 } ?: Double.NaN,
                    allowFontScaling = false,
                    includeFontPadding = false,
                    tabularNumbers = normalizedRootStyle.tabularNumbers,
                    textBreakStrategy = null,
                )
            } else {
                RNTextEngineBindings.prepareTextViewWithRuns(
                    text = payload.text,
                    textTransform = null,
                    color = null,
                    fontFamily = normalizedRootStyle.fontFamily,
                    fontSize = normalizedRootStyle.fontSize,
                    fontWeight = normalizedRootStyle.fontWeight,
                    fontStyle = normalizedRootStyle.fontStyle,
                    letterSpacing = normalizedRootStyle.letterSpacing,
                    lineHeight = normalizedRootStyle.lineHeight.takeIf { it > 0 } ?: Double.NaN,
                    allowFontScaling = false,
                    includeFontPadding = false,
                    tabularNumbers = normalizedRootStyle.tabularNumbers,
                    textBreakStrategy = null,
                    runStarts = payload.runStarts,
                    runEnds = payload.runEnds,
                    runStyleMasks = payload.runStyleMasks,
                    runColors = payload.runColors,
                    runFontFamilies = payload.runFontFamilies,
                    runFontSizes = payload.runFontSizes,
                    runFontWeights = payload.runFontWeights,
                    runFontStyles = payload.runFontStyles,
                    runLetterSpacings = payload.runLetterSpacings,
                    runLineHeights = payload.runLineHeights,
                    runTabularNumbers = payload.runTabularNumbers,
                )
            }

        return preparedHandle
    }

    private fun hasInlineRuns(): Boolean {
        return resolvedRunCount() > 0
    }

    private fun hasValidatedNestedTextChildren(): Boolean {
        return validateTextViewChildren(
            children = List(getChildCount()) { index -> getChildAt(index) },
            isTextViewChild = { child -> child is RNTextEngineTextShadowNode },
            describeChild = { child -> child?.javaClass?.name ?: "null" },
        )
    }

    private fun resolvedRunCount(): Int {
        val starts = runStarts ?: return 0
        val ends = runEnds ?: return 0
        val styleMasks = runStyleMasks ?: return 0
        return if (runCount > 0) {
            minOf(runCount, starts.size(), ends.size(), styleMasks.size())
        } else {
            minOf(starts.size(), ends.size(), styleMasks.size())
        }
    }

    private fun resolvePreparedInlineRuns(textValue: String): PreparedInlineRuns? {
        val starts = runStarts ?: return null
        val ends = runEnds ?: return null
        val styleMasks = runStyleMasks ?: return null
        val resolvedRunCount = resolvedRunCount()
        if (resolvedRunCount == 0) return null

        val textLength = textValue.length
        val resolvedStarts = ArrayList<Int>(resolvedRunCount)
        val resolvedEnds = ArrayList<Int>(resolvedRunCount)
        val resolvedStyleMasks = ArrayList<Int>(resolvedRunCount)
        val resolvedColors = ArrayList<String?>(resolvedRunCount)
        val resolvedFontFamilies = ArrayList<String?>(resolvedRunCount)
        val resolvedFontSizes = ArrayList<Double>(resolvedRunCount)
        val resolvedFontWeights = ArrayList<String?>(resolvedRunCount)
        val resolvedFontStyles = ArrayList<String?>(resolvedRunCount)
        val resolvedLetterSpacings = ArrayList<Double>(resolvedRunCount)
        val resolvedLineHeights = ArrayList<Double>(resolvedRunCount)
        val resolvedTabularNumbers = ArrayList<Boolean>(resolvedRunCount)
        var previousEnd = 0

        for (index in 0 until resolvedRunCount) {
            if (starts.isNull(index) || ends.isNull(index) || styleMasks.isNull(index)) continue

            val start = starts.getInt(index)
            val end = ends.getInt(index)
            val styleMask = styleMasks.getInt(index)
            if (styleMask == 0 || start < 0 || end <= start || start < previousEnd || end > textLength) continue

            resolvedStarts.add(start)
            resolvedEnds.add(end)
            resolvedStyleMasks.add(styleMask)
            resolvedColors.add(runColors?.readString(index))
            resolvedFontFamilies.add(runFontFamilies?.readString(index))
            resolvedFontSizes.add(runFontSizes?.readDouble(index) ?: 0.0)
            resolvedFontWeights.add(runFontWeights?.readString(index))
            resolvedFontStyles.add(runFontStyles?.readString(index))
            resolvedLetterSpacings.add(runLetterSpacings?.readDouble(index) ?: 0.0)
            resolvedLineHeights.add(runLineHeights?.readDouble(index) ?: 0.0)
            resolvedTabularNumbers.add(runTabularNumbers?.readBoolean(index) ?: false)
            previousEnd = end
        }

        if (resolvedStarts.isEmpty()) return null
        return PreparedInlineRuns(
            runStarts = resolvedStarts.toIntArray(),
            runEnds = resolvedEnds.toIntArray(),
            runStyleMasks = resolvedStyleMasks.toIntArray(),
            runColors = resolvedColors.toTypedArray(),
            runFontFamilies = resolvedFontFamilies.toTypedArray(),
            runFontSizes = resolvedFontSizes.toDoubleArray(),
            runFontWeights = resolvedFontWeights.toTypedArray(),
            runFontStyles = resolvedFontStyles.toTypedArray(),
            runLetterSpacings = resolvedLetterSpacings.toDoubleArray(),
            runLineHeights = resolvedLineHeights.toDoubleArray(),
            runTabularNumbers = resolvedTabularNumbers.toBooleanArray(),
        )
    }

    private fun resolvePayload(): RNTextEngineResolvedTextPayload {
        cachedPayload?.let { return it }

        val rootStyle = resolveNodeStyle(parent = null)
        val builder = StringBuilder()
        val segments = ArrayList<ResolvedSegment>(8)
        val hasNested = appendNodePayload(this, rootStyle, builder, segments)
        val payload =
            RNTextEngineResolvedTextPayload.from(
                text = builder.toString(),
                segments = segments,
                rootStyle = rootStyle.normalizedForPreparedText(),
                hasNested = hasNested,
            )
        cachedPayload = payload
        return payload
    }

    private fun appendNodePayload(
        node: RNTextEngineTextShadowNode,
        parentStyle: ResolvedStyle,
        textBuilder: StringBuilder,
        segments: MutableList<ResolvedSegment>,
    ): Boolean {
        val nodeStyle = node.resolveNodeStyle(parentStyle)
        val localRuns = node.resolveLocalRuns(nodeStyle)
        val localText = node.resolveTransformedText(localRuns)
        emitStyledText(localText, nodeStyle, localRuns, textBuilder, segments)

        var hasNested = false
        val children = List(node.getChildCount()) { index -> node.getChildAt(index) }
        hasNested =
            validateTextViewChildren(
                children = children,
                isTextViewChild = { child -> child is RNTextEngineTextShadowNode },
                describeChild = { child -> child?.javaClass?.name ?: "null" },
            )
        for (child in children) {
            appendNodePayload(child as RNTextEngineTextShadowNode, nodeStyle, textBuilder, segments)
        }

        return hasNested
    }

    private fun emitStyledText(
        text: String,
        baseStyle: ResolvedStyle,
        runs: List<ResolvedRun>,
        textBuilder: StringBuilder,
        segments: MutableList<ResolvedSegment>,
    ) {
        if (text.isEmpty()) return

        if (runs.isEmpty()) {
            appendSegment(textBuilder, segments, text, baseStyle)
            return
        }

        var cursor = 0
        runs.forEach { run ->
            if (run.start > cursor) {
                appendSegment(textBuilder, segments, text.substring(cursor, run.start), baseStyle)
            }

            val segmentText = text.substring(run.start, run.end)
            appendSegment(textBuilder, segments, segmentText, run.style)
            cursor = run.end
        }

        if (cursor < text.length) {
            appendSegment(textBuilder, segments, text.substring(cursor), baseStyle)
        }
    }

    private fun appendSegment(
        textBuilder: StringBuilder,
        segments: MutableList<ResolvedSegment>,
        text: String,
        style: ResolvedStyle,
    ) {
        if (text.isEmpty()) return
        val normalizedStyle = style.normalizedForPreparedText()

        val start = textBuilder.length
        textBuilder.append(text)
        val end = textBuilder.length

        val last = segments.lastOrNull()
        if (last != null && last.end == start && last.style == normalizedStyle) {
            segments[segments.lastIndex] = last.copy(end = end)
            return
        }

        segments.add(ResolvedSegment(start = start, end = end, style = normalizedStyle))
    }

    private fun resolveLocalRuns(baseStyle: ResolvedStyle): MutableList<ResolvedRun> {
        val starts = runStarts ?: return arrayListOf()
        val ends = runEnds ?: return arrayListOf()
        val styleMasks = runStyleMasks ?: return arrayListOf()
        val textLength = resolvedTextValue().length

        val resolvedRunCount =
            if (runCount > 0) {
                minOf(runCount, starts.size(), ends.size(), styleMasks.size())
            } else {
                minOf(starts.size(), ends.size(), styleMasks.size())
            }
        if (resolvedRunCount == 0) return arrayListOf()

        val runs = ArrayList<ResolvedRun>(resolvedRunCount)
        var previousEnd = 0

        for (index in 0 until resolvedRunCount) {
            if (starts.isNull(index) || ends.isNull(index) || styleMasks.isNull(index)) continue
            val start = starts.getInt(index)
            val end = ends.getInt(index)
            val styleMask = styleMasks.getInt(index)
            if (styleMask == 0 || start < 0 || end <= start || start < previousEnd || end > textLength) continue

            val style =
                baseStyle.override(
                    styleMask = styleMask,
                    colorString = runColors?.readString(index),
                    fontFamilyValue = runFontFamilies?.readString(index),
                    fontSizeValue = runFontSizes?.readDouble(index) ?: 0.0,
                    fontStyleValue = runFontStyles?.readString(index),
                    fontWeightValue = runFontWeights?.readString(index),
                    letterSpacingValue = runLetterSpacings?.readDouble(index) ?: 0.0,
                    lineHeightValue = runLineHeights?.readDouble(index) ?: 0.0,
                    tabularNumbersValue = runTabularNumbers?.readBoolean(index) ?: false,
                )

            runs.add(ResolvedRun(start = start, end = end, style = style))
            previousEnd = end
        }

        return runs
    }

    private fun resolveTransformedText(localRuns: MutableList<ResolvedRun>): String {
        val sourceText = resolvedTextValue()
        if (sourceText.isEmpty()) return ""
        if (localRuns.isEmpty()) return applyTextTransform(sourceText, textTransform)

        val transformed = transformText(sourceText, textTransform) {
            ArrayList<Int>(localRuns.size * 2).apply {
                localRuns.forEach { run ->
                    add(run.start)
                    add(run.end)
                }
            }
        }
        if (transformed.offsetsByOriginal.isEmpty()) return transformed.text

        localRuns.replaceAll { run ->
            run.copy(
                start = transformed.offsetsByOriginal[run.start] ?: run.start,
                end = transformed.offsetsByOriginal[run.end] ?: run.end,
            )
        }

        return transformed.text
    }

    private fun resolvedTextValue(): String {
        return localData?.text ?: text
    }

    private fun resolveNodeStyle(parent: ResolvedStyle?): ResolvedStyle {
        val resolved = resolveTextViewNodeStyle(
            parent = parent?.let {
                RNTextEngineResolvedStyleSnapshot(
                    allowFontScaling = it.allowFontScaling,
                    colorString = it.colorString,
                    fontFamily = it.fontFamily,
                    fontSize = it.fontSize,
                    fontStyle = it.fontStyle,
                    fontWeight = it.fontWeight,
                    letterSpacing = it.letterSpacing,
                    lineHeight = it.lineHeight,
                    tabularNumbers = it.tabularNumbers,
                )
            },
            input =
                RNTextEngineNodeStyleInput(
                    hasAllowFontScaling = hasAllowFontScaling,
                    allowFontScaling = allowFontScaling,
                    colorString = color?.toColorString(),
                    fontFamily = fontFamily,
                    fontSize = fontSize,
                    fontStyle = fontStyle,
                    fontWeight = fontWeight,
                    hasLetterSpacing = hasLetterSpacing,
                    letterSpacing = letterSpacing,
                    lineHeight = lineHeight,
                    hasTabularNumbers = hasTabularNumbers,
                    tabularNumbers = tabularNumbers,
                ),
        )

        return ResolvedStyle(
            allowFontScaling = resolved.allowFontScaling,
            colorString = resolved.colorString,
            fontFamily = resolved.fontFamily,
            fontSize = resolved.fontSize,
            fontStyle = resolved.fontStyle,
            fontWeight = resolved.fontWeight,
            letterSpacing = resolved.letterSpacing,
            lineHeight = resolved.lineHeight,
            tabularNumbers = resolved.tabularNumbers,
        )
    }

    private fun resolvedLineHeight(): Double = if (lineHeight > 0) lineHeight else Double.NaN
    private fun resolvedFontSize(): Double = if (fontSize > 0) fontSize else 14.0

    private fun ResolvedStyle.normalizedForPreparedText(): ResolvedStyle {
        if (!allowFontScaling) return this
        return copy(
            allowFontScaling = false,
            fontSize = RNTextEngineBindings.scaleTypographyValue(fontSize),
            letterSpacing = RNTextEngineBindings.scaleTypographyValue(letterSpacing),
            lineHeight = if (lineHeight > 0.0) RNTextEngineBindings.scaleTypographyValue(lineHeight) else lineHeight,
        )
    }

    private fun isVirtualNestedTextNode(): Boolean = getParent() is RNTextEngineTextShadowNode

    private fun markMeasureDirty() {
        invalidateNode(affectsMeasurement = true)
    }

    private fun invalidateResolvedPayloadOnly() {
        invalidateNode(affectsMeasurement = false)
    }

    private fun invalidateNode(affectsMeasurement: Boolean) {
        if (affectsMeasurement) {
            releasePreparedHandle()
        }
        cachedPayload = null
        markUpdated()

        if (isVirtualNestedTextNode()) {
            val parentNode = getParent()
            if (parentNode is RNTextEngineTextShadowNode) {
                parentNode.invalidateNode(affectsMeasurement)
            }
            return
        }

        if (affectsMeasurement) {
            dirty()
        }
    }

    private fun releasePreparedHandle() {
        if (preparedHandle == 0L) return
        RNTextEngineBindings.release(preparedHandle)
        preparedHandle = 0L
    }

    private fun readBooleanArray(values: ReadableArray?, expectedSize: Int): BooleanArray {
        return BooleanArray(expectedSize) { index -> values != null && index < values.size() && !values.isNull(index) && values.getBoolean(index) }
    }

    private fun readDoubleArray(values: ReadableArray?, expectedSize: Int): DoubleArray {
        return DoubleArray(expectedSize) { index -> if (values == null || index >= values.size() || values.isNull(index)) 0.0 else values.getDouble(index) }
    }

    private fun readIntArray(values: ReadableArray?, expectedSize: Int): IntArray {
        return IntArray(expectedSize) { index -> if (values == null || index >= values.size() || values.isNull(index)) 0 else values.getInt(index) }
    }

    private fun readStringArray(values: ReadableArray?, expectedSize: Int): Array<String?> {
        return Array(expectedSize) { index -> if (values == null || index >= values.size() || values.isNull(index)) null else values.getString(index) }
    }

    private fun Int.toColorString(): String {
        val unsigned = this.toLong() and 0xFFFFFFFFL
        return "#${unsigned.toString(16).padStart(8, '0')}"
    }

    private fun ReadableArray.readBoolean(index: Int): Boolean {
        if (index >= size() || isNull(index)) return false
        return getBoolean(index)
    }

    private fun ReadableArray.readDouble(index: Int): Double {
        if (index >= size() || isNull(index)) return 0.0
        return getDouble(index)
    }

    private fun ReadableArray.readString(index: Int): String? {
        if (index >= size() || isNull(index)) return null
        return getString(index)
    }

    data class ResolvedStyle(
        val allowFontScaling: Boolean,
        val colorString: String?,
        val fontFamily: String?,
        val fontSize: Double,
        val fontStyle: String?,
        val fontWeight: String?,
        val letterSpacing: Double,
        val lineHeight: Double,
        val tabularNumbers: Boolean,
    ) {
        fun override(
            styleMask: Int,
            colorString: String?,
            fontFamilyValue: String?,
            fontSizeValue: Double,
            fontStyleValue: String?,
            fontWeightValue: String?,
            letterSpacingValue: Double,
            lineHeightValue: Double,
            tabularNumbersValue: Boolean,
        ): ResolvedStyle {
            var next = this
            if (styleMask and RUN_STYLE_HAS_COLOR != 0) next = next.copy(colorString = colorString)
            if (styleMask and RUN_STYLE_HAS_FONT_FAMILY != 0) next = next.copy(fontFamily = fontFamilyValue)
            if (styleMask and RUN_STYLE_HAS_FONT_SIZE != 0) next = next.copy(fontSize = fontSizeValue)
            if (styleMask and RUN_STYLE_HAS_FONT_STYLE != 0) next = next.copy(fontStyle = fontStyleValue)
            if (styleMask and RUN_STYLE_HAS_FONT_WEIGHT != 0) next = next.copy(fontWeight = fontWeightValue)
            if (styleMask and RUN_STYLE_HAS_LETTER_SPACING != 0) next = next.copy(letterSpacing = letterSpacingValue)
            if (styleMask and RUN_STYLE_HAS_LINE_HEIGHT != 0) next = next.copy(lineHeight = lineHeightValue)
            if (styleMask and RUN_STYLE_HAS_TABULAR_NUMBERS != 0) next = next.copy(tabularNumbers = tabularNumbersValue)
            return next
        }
    }

    data class ResolvedRun(
        var start: Int,
        var end: Int,
        val style: ResolvedStyle,
    )

    data class PreparedInlineRuns(
        val runStarts: IntArray,
        val runEnds: IntArray,
        val runStyleMasks: IntArray,
        val runColors: Array<String?>,
        val runFontFamilies: Array<String?>,
        val runFontSizes: DoubleArray,
        val runFontWeights: Array<String?>,
        val runFontStyles: Array<String?>,
        val runLetterSpacings: DoubleArray,
        val runLineHeights: DoubleArray,
        val runTabularNumbers: BooleanArray,
    )

    data class ResolvedSegment(
        val start: Int,
        val end: Int,
        val style: ResolvedStyle,
    )

    internal data class RNTextEngineResolvedTextPayload(
        val hasNested: Boolean,
        val hash: Long,
        val text: String,
        val runStarts: IntArray,
        val runEnds: IntArray,
        val runStyleMasks: IntArray,
        val runColors: Array<String?>,
        val runFontFamilies: Array<String?>,
        val runFontSizes: DoubleArray,
        val runFontWeights: Array<String?>,
        val runFontStyles: Array<String?>,
        val runLetterSpacings: DoubleArray,
        val runLineHeights: DoubleArray,
        val runTabularNumbers: BooleanArray,
    ) {
        companion object {
            val EMPTY =
                RNTextEngineResolvedTextPayload(
                    hasNested = false,
                    hash = 0L,
                    text = "",
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

            fun from(
                text: String,
                segments: List<ResolvedSegment>,
                rootStyle: ResolvedStyle,
                hasNested: Boolean,
            ): RNTextEngineResolvedTextPayload {
                if (text.isEmpty() || segments.isEmpty()) {
                    return EMPTY.copy(text = text, hash = text.hashCode().toLong(), hasNested = hasNested)
                }

                val runStarts = ArrayList<Int>()
                val runEnds = ArrayList<Int>()
                val runStyleMasks = ArrayList<Int>()
                val runColors = ArrayList<String?>()
                val runFontFamilies = ArrayList<String?>()
                val runFontSizes = ArrayList<Double>()
                val runFontWeights = ArrayList<String?>()
                val runFontStyles = ArrayList<String?>()
                val runLetterSpacings = ArrayList<Double>()
                val runLineHeights = ArrayList<Double>()
                val runTabularNumbers = ArrayList<Boolean>()

                segments.forEach { segment ->
                    val style = segment.style
                    var styleMask = 0

                    if (style.colorString != rootStyle.colorString) styleMask = styleMask or RUN_STYLE_HAS_COLOR
                    if (style.fontFamily != rootStyle.fontFamily) styleMask = styleMask or RUN_STYLE_HAS_FONT_FAMILY
                    if (style.fontSize != rootStyle.fontSize) styleMask = styleMask or RUN_STYLE_HAS_FONT_SIZE
                    if (style.fontStyle != rootStyle.fontStyle) styleMask = styleMask or RUN_STYLE_HAS_FONT_STYLE
                    if (style.fontWeight != rootStyle.fontWeight) styleMask = styleMask or RUN_STYLE_HAS_FONT_WEIGHT
                    if (style.letterSpacing != rootStyle.letterSpacing) styleMask = styleMask or RUN_STYLE_HAS_LETTER_SPACING
                    if (style.lineHeight != rootStyle.lineHeight) styleMask = styleMask or RUN_STYLE_HAS_LINE_HEIGHT
                    if (style.tabularNumbers != rootStyle.tabularNumbers) styleMask = styleMask or RUN_STYLE_HAS_TABULAR_NUMBERS

                    if (styleMask == 0) return@forEach

                    runStarts.add(segment.start)
                    runEnds.add(segment.end)
                    runStyleMasks.add(styleMask)
                    runColors.add(style.colorString)
                    runFontFamilies.add(style.fontFamily)
                    runFontSizes.add(style.fontSize)
                    runFontWeights.add(style.fontWeight)
                    runFontStyles.add(style.fontStyle)
                    runLetterSpacings.add(style.letterSpacing)
                    runLineHeights.add(style.lineHeight)
                    runTabularNumbers.add(style.tabularNumbers)
                }

                var hash = 17L
                hash = 31L * hash + text.hashCode().toLong()
                hash = 31L * hash + runStarts.hashCode().toLong()
                hash = 31L * hash + runEnds.hashCode().toLong()
                hash = 31L * hash + runStyleMasks.hashCode().toLong()
                hash = 31L * hash + runColors.hashCode().toLong()
                hash = 31L * hash + runFontFamilies.hashCode().toLong()
                hash = 31L * hash + runFontSizes.hashCode().toLong()
                hash = 31L * hash + runFontWeights.hashCode().toLong()
                hash = 31L * hash + runFontStyles.hashCode().toLong()
                hash = 31L * hash + runLetterSpacings.hashCode().toLong()
                hash = 31L * hash + runLineHeights.hashCode().toLong()
                hash = 31L * hash + runTabularNumbers.hashCode().toLong()

                return RNTextEngineResolvedTextPayload(
                    hasNested = hasNested,
                    hash = hash,
                    text = text,
                    runStarts = runStarts.toIntArray(),
                    runEnds = runEnds.toIntArray(),
                    runStyleMasks = runStyleMasks.toIntArray(),
                    runColors = runColors.toTypedArray(),
                    runFontFamilies = runFontFamilies.toTypedArray(),
                    runFontSizes = runFontSizes.toDoubleArray(),
                    runFontWeights = runFontWeights.toTypedArray(),
                    runFontStyles = runFontStyles.toTypedArray(),
                    runLetterSpacings = runLetterSpacings.toDoubleArray(),
                    runLineHeights = runLineHeights.toDoubleArray(),
                    runTabularNumbers = runTabularNumbers.toBooleanArray(),
                )
            }
        }
    }
}
