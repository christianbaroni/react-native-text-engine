package com.rnpretext

import android.graphics.Color
import android.graphics.Typeface
import android.os.Build
import android.text.Layout
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import androidx.appcompat.widget.AppCompatTextView
import com.facebook.react.bridge.ColorPropConverter
import com.facebook.react.common.assets.ReactFontManager
import com.facebook.react.uimanager.PixelUtil
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewProps
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.views.text.ReactTypefaceUtils
import kotlin.math.ceil
import kotlin.math.max

internal class RNPretextTextViewManager : SimpleViewManager<RNPretextTextViewManager.RNPretextTextView>() {
    override fun getName(): String = REACT_CLASS

    override fun createViewInstance(reactContext: ThemedReactContext): RNPretextTextView {
        return RNPretextTextView(reactContext)
    }

    @ReactProp(name = "text")
    fun setText(view: RNPretextTextView, text: String?) {
        view.text = text ?: ""
    }

    @ReactProp(name = "color", customType = "Color")
    fun setColor(view: RNPretextTextView, color: Any?) {
        val resolved = ColorPropConverter.getColor(color, view.context)
        view.setTextColor(resolved ?: view.defaultTextColor)
    }

    @ReactProp(name = "fontFamily")
    fun setFontFamily(view: RNPretextTextView, fontFamily: String?) {
        view.fontFamily = fontFamily
        view.updateTypeface()
    }

    @ReactProp(name = "fontSize", defaultFloat = 14f)
    fun setFontSize(view: RNPretextTextView, fontSize: Float) {
        view.setTextSizePx(PixelUtil.toPixelFromDIP(fontSize))
    }

    @ReactProp(name = "fontStyle")
    fun setFontStyle(view: RNPretextTextView, fontStyle: String?) {
        view.fontStyle = fontStyle
        view.updateTypeface()
    }

    @ReactProp(name = "fontWeight")
    fun setFontWeight(view: RNPretextTextView, fontWeight: String?) {
        view.fontWeight = fontWeight
        view.updateTypeface()
    }

    @ReactProp(name = "letterSpacing", defaultFloat = 0f)
    fun setLetterSpacing(view: RNPretextTextView, letterSpacing: Float) {
        view.setLetterSpacingPx(PixelUtil.toPixelFromDIP(letterSpacing))
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
    }

    @ReactProp(name = ViewProps.NUMBER_OF_LINES, defaultInt = 0)
    fun setNumberOfLines(view: RNPretextTextView, numberOfLines: Int) {
        view.maxLines = if (numberOfLines > 0) numberOfLines else Int.MAX_VALUE
        view.setSingleLine(false)
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
    }

    internal class RNPretextTextView(context: ThemedReactContext) : AppCompatTextView(context) {
        var fontFamily: String? = null
        var fontStyle: String? = null
        var fontWeight: String? = null
        val defaultTextColor: Int = currentTextColor
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
            updateLineHeight()
            updateTypeface()
        }

        fun setLetterSpacingPx(letterSpacingPx: Float) {
            val currentTextSize = textSize
            letterSpacing = if (currentTextSize > 0f) letterSpacingPx / currentTextSize else 0f
        }

        fun setLineHeightPx(value: Float) {
            lineHeightPx = value
            updateLineHeight()
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

        private fun updateLineHeight() {
            if (lineHeightPx.isNaN()) {
                setLineSpacing(0f, 1f)
                return
            }

            val metrics = paint.fontMetricsInt
            val fontHeight = (-metrics.ascent + metrics.descent).toFloat()
            setLineSpacing(max(0f, lineHeightPx - fontHeight), 1f)
        }
    }

    companion object {
        const val REACT_CLASS = "RNPretextTextView"
    }
}
