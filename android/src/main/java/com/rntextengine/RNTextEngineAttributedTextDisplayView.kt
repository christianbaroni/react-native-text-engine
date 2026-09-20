package com.rntextengine

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.os.Build
import android.text.Layout
import android.text.TextPaint
import android.text.TextUtils
import android.view.View
import android.view.Gravity
import android.widget.TextView
import androidx.core.graphics.withTranslation
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min

internal class RNTextEngineAttributedTextDisplayView(context: Context, private val nativeLineSpacing: Boolean) : View(context) {
    private var cachedLayout: Layout? = null
    private var cachedLayoutWidth = -1
    private var layoutDirty = true
    private var preparedText: RNTextEngineBindings.PreparedText? = null
    private var textAlign: String? = null
    private var textColor: Int? = null
    private var decorationFlags = 0
    private var textShadowColor: Int? = null
    private var textShadowOffsetHeightPx = 0f
    private var textShadowOffsetWidthPx = 0f
    private var textShadowRadiusPx = 0f
    internal var capHeightTopInsetPx: Float = 0f
        set(value) {
            if (field == value) return
            field = value
            invalidate()
        }

    var ellipsizeMode: String? = null
        set(value) {
            if (field == value) return
            field = value
            invalidateLayout()
        }

    var numberOfLines: Int = 0
        set(value) {
            if (field == value) return
            field = value
            invalidateLayout()
        }

    init {
        isFocusable = false
        isClickable = false
        setBackgroundColor(Color.TRANSPARENT)
    }

    fun setPreparedText(value: RNTextEngineBindings.PreparedText?) {
        if (preparedText === value) return
        preparedText = value
        invalidateLayout()
    }

    fun setTextAlignValue(value: String?) {
        if (textAlign == value) return
        textAlign = value
        invalidateLayout()
    }

    fun setTextColorValue(value: Int) {
        if (textColor == value) return
        textColor = value
        invalidateDrawingStyle()
    }

    fun setTextDecorationLineValue(value: String?) {
        var flags = 0
        value?.split(" ")?.forEach { decoration ->
            when (decoration) {
                "underline" -> flags = flags or Paint.UNDERLINE_TEXT_FLAG
                "line-through" -> flags = flags or Paint.STRIKE_THRU_TEXT_FLAG
            }
        }
        if (decorationFlags == flags) return
        decorationFlags = flags
        invalidateDrawingStyle()
    }

    fun setTextShadowColorValue(value: Int?) {
        if (textShadowColor == value) return
        textShadowColor = value
        invalidateDrawingStyle()
    }

    fun setTextShadowOffsetPx(widthPx: Float, heightPx: Float) {
        if (textShadowOffsetWidthPx == widthPx && textShadowOffsetHeightPx == heightPx) return
        textShadowOffsetWidthPx = widthPx
        textShadowOffsetHeightPx = heightPx
        invalidateDrawingStyle()
    }

    fun setTextShadowRadiusPx(value: Float) {
        if (textShadowRadiusPx == value) return
        textShadowRadiusPx = value
        invalidateDrawingStyle()
    }

    fun applySelectionLayout(view: TextView) {
        view.maxLines = if (numberOfLines > 0) numberOfLines else Int.MAX_VALUE
        view.ellipsize = resolveEllipsize(view.maxLines, ellipsizeMode)
        view.textAlignment = View.TEXT_ALIGNMENT_GRAVITY
        view.gravity = Gravity.TOP or when (textAlign) {
            "center" -> Gravity.CENTER_HORIZONTAL
            "right" -> Gravity.END
            else -> Gravity.START
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            view.justificationMode = resolveJustificationMode(textAlign)
        }
        view.setPadding(paddingLeft, paddingTop, paddingRight, paddingBottom)
    }

    fun applyDrawingStyle(view: TextView) {
        textColor?.let(view::setTextColor)
        view.paintFlags = (view.paintFlags and Paint.UNDERLINE_TEXT_FLAG.inv() and Paint.STRIKE_THRU_TEXT_FLAG.inv()) or decorationFlags
        view.setShadowLayer(textShadowRadiusPx, textShadowOffsetWidthPx, textShadowOffsetHeightPx, textShadowColor ?: Color.TRANSPARENT)
    }

    fun resolveCapHeightInsets(width: Int): RNTextEngineCapHeightInsetsPx {
        val prepared = preparedText ?: return RNTextEngineCapHeightInsetsPx(bottom = 0f, top = 0f)
        val layout = ensureLayout(width) ?: return RNTextEngineCapHeightInsetsPx(bottom = 0f, top = 0f)
        val capHeights = prepared.capHeights
        return resolveCapHeightInsetsPx(
            layout = layout,
            text = prepared.displayText(nativeLineSpacing),
            defaultCapHeightPx = capHeights.base,
            uniformCapHeightPx = capHeights.uniform,
        )
    }

    internal fun resolveLayout(width: Int): Layout? {
        return ensureLayout(width)
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        setMeasuredDimension(
            resolveSizeAndState(suggestedMinimumWidth, widthMeasureSpec, 0),
            resolveSizeAndState(suggestedMinimumHeight, heightMeasureSpec, 0),
        )
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        val layout = ensureLayout(width) ?: return
        val contentWidth = (width - paddingLeft - paddingRight).coerceAtLeast(0)
        val drawOriginX = paddingLeft.toFloat() + resolveHorizontalDrawOrigin(layout, contentWidth, textAlign)
        val drawOriginY = paddingTop.toFloat() - capHeightTopInsetPx

        canvas.withTranslation(drawOriginX, drawOriginY) {
            layout.draw(this)
        }
    }

    override fun setPadding(left: Int, top: Int, right: Int, bottom: Int) {
        super.setPadding(left, top, right, bottom)
        invalidateLayout()
    }

    private fun ensureLayout(width: Int): Layout? {
        val prepared = preparedText ?: return null
        val contentWidth = (width - paddingLeft - paddingRight).coerceAtLeast(0)
        if (!layoutDirty && cachedLayoutWidth == contentWidth) return cachedLayout

        val maxLines = if (numberOfLines > 0) numberOfLines else Int.MAX_VALUE
        val ellipsize = resolveEllipsize(maxLines, ellipsizeMode)
        val alignment = resolveAlignment(textAlign)
        val justificationMode = resolveJustificationMode(textAlign)
        cachedLayout = prepared.takeMeasuredLayout(max(1, contentWidth), maxLines, ellipsize,
            alignment, justificationMode, nativeLineSpacing)?.also { applyDrawingStyle(it.paint) }
            ?: buildStaticLayoutCompat(
                text = prepared.displayText(nativeLineSpacing),
                paint = TextPaint(prepared.style.textPaint).also(::applyDrawingStyle),
                widthPx = max(1, contentWidth),
                includeFontPadding = prepared.style.includeFontPadding,
                breakStrategy = Layout.BREAK_STRATEGY_HIGH_QUALITY,
                hyphenationFrequency = Layout.HYPHENATION_FREQUENCY_NORMAL,
                maxLines = maxLines,
                ellipsize = ellipsize,
                alignment = alignment,
                justificationMode = justificationMode,
                lineSpacingAdd = prepared.lineSpacingAdd(nativeLineSpacing),
            )
        cachedLayoutWidth = contentWidth
        layoutDirty = false
        return cachedLayout
    }

    private fun invalidateLayout() {
        cachedLayout = null
        cachedLayoutWidth = -1
        layoutDirty = true
        invalidate()
    }

    private fun invalidateDrawingStyle() {
        cachedLayout?.paint?.let(::applyDrawingStyle)
        invalidate()
    }

    private fun applyDrawingStyle(paint: TextPaint) {
        textColor?.let { paint.color = it }
        paint.flags = (paint.flags and Paint.UNDERLINE_TEXT_FLAG.inv() and Paint.STRIKE_THRU_TEXT_FLAG.inv()) or decorationFlags
        paint.setShadowLayer(textShadowRadiusPx, textShadowOffsetWidthPx, textShadowOffsetHeightPx, textShadowColor ?: Color.TRANSPARENT)
    }

    private fun resolveAlignment(value: String?): Layout.Alignment {
        return when (value) {
            "center" -> Layout.Alignment.ALIGN_CENTER
            "right" -> Layout.Alignment.ALIGN_OPPOSITE
            else -> Layout.Alignment.ALIGN_NORMAL
        }
    }

    private fun resolveJustificationMode(value: String?): Int {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return 0
        return if (value == "justify") Layout.JUSTIFICATION_MODE_INTER_WORD else Layout.JUSTIFICATION_MODE_NONE
    }

    private fun resolveEllipsize(maxLines: Int, mode: String?): TextUtils.TruncateAt? {
        if (maxLines <= 0 || maxLines == Int.MAX_VALUE) return null
        return when (mode) {
            "clip" -> null
            "head" -> TextUtils.TruncateAt.START
            "middle" -> TextUtils.TruncateAt.MIDDLE
            else -> TextUtils.TruncateAt.END
        }
    }

    private fun resolveHorizontalDrawOrigin(layout: Layout, contentWidth: Int, textAlign: String?): Float {
        if (layout.lineCount == 0 || textAlign == "center") return 0f

        var minLeft = 0f
        var maxRight = 0f
        for (index in 0 until layout.lineCount) {
            minLeft = min(minLeft, layout.getLineLeft(index))
            maxRight = max(maxRight, layout.getLineRight(index))
        }

        val leftInset = max(0f, -minLeft)
        val rightOverflow = max(0f, maxRight - contentWidth)
        return if (textAlign == "right") {
            -ceil(rightOverflow.toDouble()).toFloat()
        } else {
            ceil(leftInset.toDouble()).toFloat()
        }
    }
}
