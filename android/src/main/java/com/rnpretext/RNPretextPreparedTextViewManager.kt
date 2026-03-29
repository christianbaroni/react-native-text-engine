package com.rnpretext

import android.graphics.Color
import android.os.Build
import android.text.TextUtils
import android.util.TypedValue
import android.widget.TextView.BufferType
import androidx.appcompat.widget.AppCompatTextView
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewProps
import com.facebook.react.uimanager.annotations.ReactProp

internal class RNPretextPreparedTextViewManager :
    SimpleViewManager<RNPretextPreparedTextViewManager.RNPretextPreparedTextView>() {
    override fun getName(): String = REACT_CLASS

    override fun createViewInstance(reactContext: ThemedReactContext): RNPretextPreparedTextView {
        return RNPretextPreparedTextView(reactContext)
    }

    @ReactProp(name = "handle", defaultDouble = 0.0)
    fun setHandle(view: RNPretextPreparedTextView, handle: Double) {
        view.setPreparedHandle(handle.toLong())
    }

    @ReactProp(name = ViewProps.NUMBER_OF_LINES, defaultInt = 0)
    fun setNumberOfLines(view: RNPretextPreparedTextView, numberOfLines: Int) {
        view.maxLines = if (numberOfLines > 0) numberOfLines else Int.MAX_VALUE
        view.setSingleLine(false)
    }

    @ReactProp(name = "selectable", defaultBoolean = false)
    fun setSelectable(view: RNPretextPreparedTextView, selectable: Boolean) {
        view.setTextIsSelectable(selectable)
        view.isFocusable = selectable
        view.isFocusableInTouchMode = selectable
        view.isClickable = selectable
        view.isLongClickable = selectable
    }

    @ReactProp(name = "ellipsizeMode")
    fun setEllipsizeMode(view: RNPretextPreparedTextView, ellipsizeMode: String?) {
        view.ellipsize =
            when (ellipsizeMode) {
                "head" -> TextUtils.TruncateAt.START
                "middle" -> TextUtils.TruncateAt.MIDDLE
                "tail" -> TextUtils.TruncateAt.END
                else -> null
            }
    }

    internal class RNPretextPreparedTextView(context: ThemedReactContext) : AppCompatTextView(context) {
        private val defaultTextColor = currentTextColor
        private var preparedHandle = 0L

        init {
            includeFontPadding = false
            isFocusable = false
            isClickable = false
            setBackgroundColor(Color.TRANSPARENT)
            setLineSpacing(0f, 1f)
        }

        fun setPreparedHandle(handle: Long) {
            if (preparedHandle == handle) return
            preparedHandle = handle

            val prepared = RNPretextBindings.resolvePreparedTextViewData(handle)
            if (prepared == null) {
                clearPreparedText()
                return
            }

            includeFontPadding = prepared.includeFontPadding
            typeface = prepared.textPaint.typeface
            setTextSize(TypedValue.COMPLEX_UNIT_PX, prepared.textPaint.textSize)
            letterSpacing = prepared.textPaint.letterSpacing
            setTextColor(prepared.textColor ?: defaultTextColor)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                fontFeatureSettings = prepared.textPaint.fontFeatureSettings
            }

            setText(prepared.text, BufferType.SPANNABLE)
        }

        private fun clearPreparedText() {
            setText("", BufferType.NORMAL)
            typeface = null
            setTextColor(defaultTextColor)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                fontFeatureSettings = null
            }
        }
    }

    companion object {
        const val REACT_CLASS = "RNPretextPreparedTextView"
    }
}
