package com.rntextengine

import android.graphics.Color
import android.text.Spanned
import android.util.TypedValue
import android.widget.TextView
import android.widget.TextView.BufferType

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

internal fun applyPreparedText(
    textView: TextView,
    prepared: RNTextEngineBindings.PreparedText?,
    nativeLineSpacing: Boolean,
) {
    if (prepared == null) {
        textView.setText("", BufferType.NORMAL)
        textView.typeface = null
        textView.setTextColor(Color.BLACK)
        textView.includeFontPadding = false
        textView.letterSpacing = 0f
        textView.setLineSpacing(0f, 1f)
        textView.fontFeatureSettings = null

        return
    }

    val paint = prepared.style.textPaint
    textView.paintFlags = textView.paintFlags or RN_TEXT_ENGINE_SHAPING_FLAGS
    textView.includeFontPadding = prepared.style.includeFontPadding
    textView.typeface = paint.typeface
    textView.setTextSize(TypedValue.COMPLEX_UNIT_PX, paint.textSize)
    textView.letterSpacing = paint.letterSpacing
    textView.setTextColor(paint.color)
    textView.fontFeatureSettings = paint.fontFeatureSettings

    textView.setLineSpacing(prepared.lineSpacingAdd(nativeLineSpacing), 1f)
    val text = prepared.displayText(nativeLineSpacing)
    textView.setText(text, if (text is Spanned) BufferType.SPANNABLE else BufferType.NORMAL)
}
