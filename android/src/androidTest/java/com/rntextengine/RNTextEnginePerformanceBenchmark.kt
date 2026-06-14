package com.rntextengine

import android.app.Application
import androidx.benchmark.junit4.BenchmarkRule
import androidx.benchmark.junit4.measureRepeated
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.facebook.react.bridge.Callback
import com.facebook.react.bridge.CatalystInstance
import com.facebook.react.bridge.JavaScriptContextHolder
import com.facebook.react.bridge.JavaScriptModule
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.UIManager
import com.facebook.react.turbomodule.core.interfaces.CallInvokerHolder
import com.facebook.react.uimanager.DisplayMetricsHolder
import java.nio.ByteBuffer
import kotlin.math.max
import kotlin.math.min
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

private class BenchmarkReactApplicationContext(application: Application) : ReactApplicationContext(application) {
    override fun <T : JavaScriptModule> getJSModule(jsInterface: Class<T>): T {
        throw UnsupportedOperationException("JS modules are not used in RNTextEngine performance benchmarks.")
    }

    override fun <T : NativeModule> hasNativeModule(nativeModuleInterface: Class<T>): Boolean = false

    override fun getNativeModules(): MutableCollection<NativeModule> = mutableListOf()

    override fun <T : NativeModule> getNativeModule(nativeModuleInterface: Class<T>): T? = null

    override fun getNativeModule(moduleName: String): NativeModule? = null

    override fun getCatalystInstance(): CatalystInstance {
        throw UnsupportedOperationException("CatalystInstance is not used in RNTextEngine performance benchmarks.")
    }

    @Deprecated("Legacy bridge API")
    override fun hasActiveCatalystInstance(): Boolean = false

    override fun hasActiveReactInstance(): Boolean = false

    @Deprecated("Legacy bridge API")
    override fun hasCatalystInstance(): Boolean = false

    override fun hasReactInstance(): Boolean = false

    override fun destroy() = Unit

    override fun handleException(e: Exception) {
        throw e
    }

    @Deprecated("Legacy bridge API")
    override fun isBridgeless(): Boolean = false

    override fun getJavaScriptContextHolder(): JavaScriptContextHolder? = null

    override fun getJSCallInvokerHolder(): CallInvokerHolder? = null

    override fun getFabricUIManager(): UIManager? = null

    override fun getSourceURL(): String? = null

    override fun registerSegment(segmentId: Int, path: String, callback: Callback) = Unit
}

private data class GlyphFieldState(
    val glyphIndices: ByteArray,
    val glyphs: String,
    val variantIndices: ByteArray,
)

@RunWith(AndroidJUnit4::class)
class RNTextEnginePerformanceBenchmark {
    @get:Rule val benchmarkRule = BenchmarkRule()

    private lateinit var application: Application

    private val chatTexts = buildChatCorpus(128)
    private val inlineText = buildInlineText()
    private val inlineRunData = buildInlineRunData(inlineText.length)
    private val flowText = buildFlowText()
    private val flowWidths = doubleArrayOf(240.0, 180.0, 220.0, 160.0, 200.0, 190.0)
    private val glyphFieldStates = buildGlyphFieldStates(columns = 80, rows = 24)

    @Before
    fun setUp() {
        application = ApplicationProvider.getApplicationContext()
        DisplayMetricsHolder.initDisplayMetricsIfNotInitialized(application)
        RNTextEngineBindings.initialize(BenchmarkReactApplicationContext(application))
        RNTextEngineBindings.cleanup()
    }

    @After
    fun tearDown() {
        RNTextEngineBindings.cleanup()
    }

    @Test
    fun preparedBatchCreateChatLifecycle() {
        benchmarkRule.measureRepeated {
            repeat(2048) {
                val handles =
                    RNTextEngineBindings.prepareBatch(
                        texts = chatTexts,
                        color = null,
                        fontFamily = null,
                        fontSize = 17.0,
                        fontWeight = "500",
                        fontStyle = null,
                        letterSpacing = 0.1,
                        lineHeight = 24.0,
                        allowFontScaling = false,
                        includeFontPadding = false,
                        tabularNumbers = false,
                        textBreakStrategy = "highQuality",
                    )

                runWithTimingDisabled {
                    RNTextEngineBindings.releaseMany(handles)
                }
            }
        }
    }

    @Test
    fun preparedBatchLayoutReuseChat() {
        val handles =
            RNTextEngineBindings.prepareBatch(
                texts = chatTexts,
                color = null,
                fontFamily = null,
                fontSize = 17.0,
                fontWeight = "500",
                fontStyle = null,
                letterSpacing = 0.1,
                lineHeight = 24.0,
                allowFontScaling = false,
                includeFontPadding = false,
                tabularNumbers = false,
                textBreakStrategy = "highQuality",
            )

        try {
            benchmarkRule.measureRepeated {
                repeat(24) {
                    RNTextEngineBindings.layoutBatch(handles, 260.0, 0, null, false)
                }
            }
        } finally {
            RNTextEngineBindings.releaseMany(handles)
        }
    }

    @Test
    fun oneShotMeasureBatchChat() {
        benchmarkRule.measureRepeated {
            repeat(2) {
                RNTextEngineBindings.measureBatch(
                    texts = chatTexts,
                    color = null,
                    fontFamily = null,
                    fontSize = 17.0,
                    fontWeight = "500",
                    fontStyle = null,
                    letterSpacing = 0.1,
                    lineHeight = 24.0,
                    allowFontScaling = false,
                    includeFontPadding = false,
                    tabularNumbers = false,
                    textBreakStrategy = "highQuality",
                    width = 260.0,
                    maxLines = 0,
                    ellipsizeMode = null,
                    anchorToCapHeight = false,
                )
            }
        }
    }

    @Test
    fun prepareInlineRunsLifecycle() {
        benchmarkRule.measureRepeated {
            repeat(4096) {
                val handle =
                    RNTextEngineBindings.prepareWithRuns(
                        text = inlineText,
                        color = "#111111",
                        fontFamily = null,
                        fontSize = 18.0,
                        fontWeight = "400",
                        fontStyle = null,
                        letterSpacing = 0.05,
                        lineHeight = 26.0,
                        allowFontScaling = false,
                        includeFontPadding = false,
                        tabularNumbers = false,
                        textBreakStrategy = "highQuality",
                        runStarts = inlineRunData.runStarts,
                        runEnds = inlineRunData.runEnds,
                        runStyleMasks = inlineRunData.runStyleMasks,
                        runColors = inlineRunData.runColors,
                        runFontFamilies = inlineRunData.runFontFamilies,
                        runFontSizes = inlineRunData.runFontSizes,
                        runFontWeights = inlineRunData.runFontWeights,
                        runFontStyles = inlineRunData.runFontStyles,
                        runLetterSpacings = inlineRunData.runLetterSpacings,
                        runLineHeights = inlineRunData.runLineHeights,
                        runTabularNumbers = inlineRunData.runTabularNumbers,
                    )

                runWithTimingDisabled {
                    RNTextEngineBindings.release(handle)
                }
            }
        }
    }

    @Test
    fun layoutNextLineVariableWidthSequence() {
        val handle =
            RNTextEngineBindings.prepare(
                text = flowText,
                color = null,
                fontFamily = null,
                fontSize = 18.0,
                fontWeight = null,
                fontStyle = null,
                letterSpacing = 0.1,
                lineHeight = 26.0,
                allowFontScaling = false,
                includeFontPadding = false,
                tabularNumbers = false,
                textBreakStrategy = "highQuality",
            )

        try {
            benchmarkRule.measureRepeated {
                runLayoutNextLineWidthSequence(handle, anchorToCapHeight = false)
            }
        } finally {
            RNTextEngineBindings.release(handle)
        }
    }

    @Test
    fun layoutNextLineVariableWidthSequenceAnchoredToCapHeight() {
        val handle =
            RNTextEngineBindings.prepare(
                text = flowText,
                color = null,
                fontFamily = null,
                fontSize = 18.0,
                fontWeight = null,
                fontStyle = null,
                letterSpacing = 0.1,
                lineHeight = 26.0,
                allowFontScaling = false,
                includeFontPadding = false,
                tabularNumbers = false,
                textBreakStrategy = "highQuality",
            )

        try {
            benchmarkRule.measureRepeated {
                runLayoutNextLineWidthSequence(handle, anchorToCapHeight = true)
            }
        } finally {
            RNTextEngineBindings.release(handle)
        }
    }

    @Test
    fun glyphFieldIndicesLowChurn() {
        val handle = createBenchmarkGlyphFieldHandle()
        var stateIndex = 0

        try {
            benchmarkRule.measureRepeated {
                repeat(64) {
                    stateIndex = stateIndex xor 1
                    val state = glyphFieldStates.lowChurn[stateIndex]
                    RNTextEngineBindings.updateGlyphFieldIndices(handle, state.glyphIndices, state.variantIndices)
                }
            }
        } finally {
            RNTextEngineBindings.releaseGlyphField(handle)
        }
    }

    @Test
    fun glyphFieldBufferCommitLowChurn() {
        val handle = createBenchmarkGlyphFieldHandle()
        val glyphBuffer = ByteBuffer.allocateDirect(glyphFieldStates.cellCount)
        val variantBuffer = ByteBuffer.allocateDirect(glyphFieldStates.cellCount)
        RNTextEngineBindings.attachGlyphFieldBuffers(handle, glyphBuffer, variantBuffer)
        var stateIndex = 0

        try {
            benchmarkRule.measureRepeated {
                repeat(64) {
                    val state = glyphFieldStates.lowChurn[stateIndex]

                    runWithTimingDisabled {
                        glyphBuffer.position(0)
                        glyphBuffer.put(state.glyphIndices)
                        variantBuffer.position(0)
                        variantBuffer.put(state.variantIndices)
                        stateIndex = stateIndex xor 1
                    }

                    RNTextEngineBindings.commitGlyphFieldBuffers(handle)
                }
            }
        } finally {
            RNTextEngineBindings.releaseGlyphField(handle)
        }
    }

    @Test
    fun glyphFieldStringHighChurn() {
        val handle = createBenchmarkGlyphFieldHandle()
        var stateIndex = 0

        try {
            benchmarkRule.measureRepeated {
                repeat(64) {
                    stateIndex = stateIndex xor 1
                    val state = glyphFieldStates.highChurn[stateIndex]
                    RNTextEngineBindings.updateGlyphField(handle, state.glyphs, state.variantIndices)
                }
            }
        } finally {
            RNTextEngineBindings.releaseGlyphField(handle)
        }
    }

    @Test
    fun glyphFieldStringLowChurn() {
        val handle = createBenchmarkGlyphFieldHandle()
        var stateIndex = 0

        try {
            benchmarkRule.measureRepeated {
                repeat(64) {
                    stateIndex = stateIndex xor 1
                    val state = glyphFieldStates.lowChurn[stateIndex]
                    RNTextEngineBindings.updateGlyphField(handle, state.glyphs, state.variantIndices)
                }
            }
        } finally {
            RNTextEngineBindings.releaseGlyphField(handle)
        }
    }

    private fun createBenchmarkGlyphFieldHandle(): Long {
        return RNTextEngineBindings.createGlyphField(
            columns = glyphFieldStates.columns,
            rows = glyphFieldStates.rows,
            fontFamily = null,
            fontSize = 14.0,
            glyphPalette = glyphFieldStates.palette,
            letterSpacing = 0.0,
            lineHeight = 16.0,
            textAlign = "center",
            variantColors = arrayOf("#8b8b8b", "#ffffff", "#ffb000"),
            variantFontWeights = arrayOf("400", "600", "700"),
            variantFontStyles = arrayOfNulls(3),
        )
    }

    private fun runLayoutNextLineWidthSequence(handle: Long, anchorToCapHeight: Boolean) {
        repeat(6) {
            var start = 0
            var widthIndex = 0

            while (true) {
                val nextLine =
                    RNTextEngineBindings.layoutNextLine(handle, start, flowWidths[widthIndex % flowWidths.size], anchorToCapHeight)
                        ?: break
                val nextEnd = nextLine[1].toInt()
                if (nextEnd <= start) break
                start = nextEnd
                widthIndex += 1
            }
        }
    }

    private data class InlineRunData(
        val runColors: Array<String?>,
        val runEnds: IntArray,
        val runFontFamilies: Array<String?>,
        val runFontSizes: DoubleArray,
        val runFontStyles: Array<String?>,
        val runFontWeights: Array<String?>,
        val runLetterSpacings: DoubleArray,
        val runLineHeights: DoubleArray,
        val runStarts: IntArray,
        val runStyleMasks: IntArray,
        val runTabularNumbers: BooleanArray,
    )

    private data class GlyphFieldScenarioSet(
        val cellCount: Int,
        val columns: Int,
        val highChurn: Array<GlyphFieldState>,
        val lowChurn: Array<GlyphFieldState>,
        val palette: String,
        val rows: Int,
    )

    private fun buildChatCorpus(count: Int): Array<String> {
        val fragments =
            listOf(
                "The renderer should know the bubble height before the row mounts.",
                "Prepared text lets layout reuse stay width-bound instead of rebuilding typography.",
                "Inline emphasis, quoted citations, and tabular figures still need exact native metrics.",
                "Glyph fields should mutate cells, not paragraphs, when the phenomenon is fixed-grid text.",
                "Worklet-driven lists need stable line counts, widths, and last-line geometry to avoid jank.",
            )

        return Array(count) { index ->
            val first = fragments[index % fragments.size]
            val second = fragments[(index + 2) % fragments.size]
            val third = fragments[(index + 4) % fragments.size]
            "Message ${index + 1}. $first $second $third"
        }
    }

    private fun buildFlowText(): String {
        return buildString {
            repeat(48) { index ->
                append("Flow line ")
                append(index + 1)
                append(" needs exact next-line geometry around changing widths. ")
            }
        }
    }

    private fun buildInlineText(): String {
        return buildString {
            append("Prepared text performance should cover inline emphasis, quoted insertions, and ")
            append("editorial spans with varied typography while preserving one coherent source string. ")
            append("This scenario intentionally mixes font weight, family, size, spacing, and line-height overrides ")
            append("because those are the inline facts the public contract actually exposes.")
        }
    }

    private fun buildInlineRunData(textLength: Int): InlineRunData {
        val runStarts = intArrayOf(0, 16, 43, 74, 119, 177, 239)
        val runEnds = intArrayOf(15, 42, 73, 118, 176, 238, min(textLength, 307))
        val runStyleMasks = intArrayOf(1 or 16, 2, 4 or 32, 64, 8, 128, 1 or 4 or 16)
        val runColors = arrayOf("#111111", null, null, null, null, null, "#5f3300")
        val runFontFamilies = arrayOfNulls<String?>(runStarts.size).also { families ->
            families[1] = "serif"
        }
        val runFontSizes = doubleArrayOf(0.0, 0.0, 20.0, 0.0, 0.0, 0.0, 22.0)
        val runFontWeights = arrayOfNulls<String?>(runStarts.size).also { weights ->
            weights[0] = "700"
            weights[6] = "700"
        }
        val runFontStyles = arrayOfNulls<String?>(runStarts.size).also { styles ->
            styles[4] = "italic"
        }
        val runLetterSpacings = doubleArrayOf(0.0, 0.0, 0.08, 0.0, 0.0, 0.0, 0.0)
        val runLineHeights = doubleArrayOf(0.0, 0.0, 0.0, 30.0, 0.0, 0.0, 0.0)
        val runTabularNumbers = booleanArrayOf(false, false, false, false, false, true, false)

        return InlineRunData(
            runColors = runColors,
            runEnds = runEnds,
            runFontFamilies = runFontFamilies,
            runFontSizes = runFontSizes,
            runFontStyles = runFontStyles,
            runFontWeights = runFontWeights,
            runLetterSpacings = runLetterSpacings,
            runLineHeights = runLineHeights,
            runStarts = runStarts,
            runStyleMasks = runStyleMasks,
            runTabularNumbers = runTabularNumbers,
        )
    }

    private fun buildGlyphFieldStates(columns: Int, rows: Int): GlyphFieldScenarioSet {
        val palette = " .,:;!+-=*#@%&abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        val cellCount = columns * rows
        val lowA = ByteArray(cellCount)
        val lowB = ByteArray(cellCount)
        val highA = ByteArray(cellCount)
        val highB = ByteArray(cellCount)
        val lowVariantsA = ByteArray(cellCount)
        val lowVariantsB = ByteArray(cellCount)
        val highVariantsA = ByteArray(cellCount)
        val highVariantsB = ByteArray(cellCount)

        repeat(cellCount) { index ->
            val baseGlyph = (index * 7) % palette.length
            val alternateGlyph = if (index % 7 == 0) (baseGlyph + 11) % palette.length else baseGlyph
            val highGlyphA = (index * 13) % palette.length
            val highGlyphB = (palette.length - 1 - highGlyphA + palette.length) % palette.length

            lowA[index] = baseGlyph.toByte()
            lowB[index] = alternateGlyph.toByte()
            highA[index] = highGlyphA.toByte()
            highB[index] = highGlyphB.toByte()

            lowVariantsA[index] = (index % 3).toByte()
            lowVariantsB[index] = if (index % 11 == 0) ((index + 1) % 3).toByte() else (index % 3).toByte()
            highVariantsA[index] = (index % 3).toByte()
            highVariantsB[index] = ((index + 1) % 3).toByte()
        }

        return GlyphFieldScenarioSet(
            cellCount = cellCount,
            columns = columns,
            highChurn = arrayOf(buildGlyphFieldState(palette, highA, highVariantsA), buildGlyphFieldState(palette, highB, highVariantsB)),
            lowChurn = arrayOf(buildGlyphFieldState(palette, lowA, lowVariantsA), buildGlyphFieldState(palette, lowB, lowVariantsB)),
            palette = palette,
            rows = rows,
        )
    }

    private fun buildGlyphFieldState(palette: String, glyphIndices: ByteArray, variantIndices: ByteArray): GlyphFieldState {
        val glyphBuilder = StringBuilder(glyphIndices.size)
        glyphIndices.forEach { glyphIndex ->
            glyphBuilder.append(palette[glyphIndex.toInt() and 0xFF])
        }

        return GlyphFieldState(
            glyphIndices = glyphIndices,
            glyphs = glyphBuilder.toString(),
            variantIndices = variantIndices,
        )
    }
}
