package com.rntextengine

import android.os.Build
import android.util.TypedValue
import android.widget.TextView.BufferType
import androidx.appcompat.widget.AppCompatTextView
import kotlin.math.max

internal data class RNTextEngineTextRunStyle(
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

internal data class RNTextEngineTextRun(
    val end: Int,
    val start: Int,
    val style: RNTextEngineTextRunStyle,
)

internal data class RNTextEngineMountedTextMetrics(
    val baseCapHeightPx: Float,
    val uniformCapHeightPx: Float?,
)

internal fun applyPreparedTextViewData(
    textView: AppCompatTextView,
    prepared: RNTextEngineBindings.PreparedTextViewData?,
    defaultTextColor: Int,
): RNTextEngineMountedTextMetrics {
    if (prepared == null) {
        textView.setText("", BufferType.NORMAL)
        textView.typeface = null
        textView.setTextColor(defaultTextColor)
        textView.includeFontPadding = false
        textView.letterSpacing = 0f
        textView.setLineSpacing(0f, 1f)
        textView.fontFeatureSettings = null

        return RNTextEngineMountedTextMetrics(baseCapHeightPx = 0f, uniformCapHeightPx = 0f)
    }

    textView.paintFlags = textView.paintFlags or RN_TEXT_ENGINE_SHAPING_FLAGS
    textView.includeFontPadding = prepared.includeFontPadding
    textView.typeface = prepared.textPaint.typeface
    textView.setTextSize(TypedValue.COMPLEX_UNIT_PX, prepared.textPaint.textSize)
    textView.letterSpacing = prepared.textPaint.letterSpacing
    textView.setTextColor(prepared.textColor ?: defaultTextColor)
    textView.fontFeatureSettings = prepared.textPaint.fontFeatureSettings

    if (prepared.mountMode == RNTextEngineBindings.TextMountMode.SPANNABLE) {
        textView.setLineSpacing(0f, 1f)
        textView.setText(prepared.text, BufferType.SPANNABLE)
    } else {
        applyNativeLineHeight(textView, prepared.lineHeightPx)
        textView.setText(prepared.text, BufferType.NORMAL)
    }

    return RNTextEngineMountedTextMetrics(
        baseCapHeightPx = prepared.baseCapHeightPx,
        uniformCapHeightPx = prepared.uniformCapHeightPx,
    )
}

private fun applyNativeLineHeight(textView: AppCompatTextView, lineHeightPx: Float?) {
    if (lineHeightPx == null || lineHeightPx.isNaN()) {
        textView.setLineSpacing(0f, 1f)
        return
    }

    val metrics = textView.paint.fontMetricsInt
    val fontHeight = (-metrics.ascent + metrics.descent).toFloat()
    textView.setLineSpacing(max(0f, lineHeightPx - fontHeight), 1f)
}
