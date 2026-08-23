package com.rntextengine

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.Drawable
import android.view.View
import android.widget.FrameLayout
import kotlin.math.floor
import kotlin.math.roundToInt

internal abstract class RNTextEngineCapAnchoredContainer(context: Context) : FrameLayout(context) {
    protected abstract val opacityTargetView: View
    protected open fun prepareAnchoredContentForLayout() = Unit
    protected open fun measureAnchoredContent(width: Int, height: Int) = Unit
    protected abstract fun resolveCapHeightInsets(width: Int): RNTextEngineCapHeightInsetsPx
    protected abstract fun applyAnchoredContentFrame(left: Int, top: Int, right: Int, bottom: Int, translationY: Float)

    private var cachedCapHeightInsets = RNTextEngineCapHeightInsetsPx(bottom = 0f, top = 0f)
    private var cachedCapHeightInsetsWidth = -1
    private var exposesInternalChildren = false
    private var paperOpacity = 1f
    private var opacityBackground: Drawable? = null
    private var opacityBackgroundBaseAlpha = 255

    var anchorToCapHeight = false
        set(value) {
            if (field == value) return
            field = value
            syncPaperOpacity()
            requestCapAnchorLayout()
        }

    init {
        clipChildren = false
        clipToPadding = false
        setBackgroundColor(Color.TRANSPARENT)
    }

    override fun getChildCount(): Int = if (exposesInternalChildren) super.getChildCount() else 0

    override fun getChildAt(index: Int): View? = if (exposesInternalChildren) super.getChildAt(index) else null

    override fun indexOfChild(child: View?): Int = if (exposesInternalChildren) super.indexOfChild(child) else -1

    protected fun addInternalChild(child: View, params: LayoutParams) {
        withInternalChildAccess {
            super.addView(child, params)
        }
    }

    protected fun removeInternalChild(child: View) {
        withInternalChildAccess {
            super.removeView(child)
        }
    }

    private fun withInternalChildAccess(action: () -> Unit) {
        val previouslyExposed = exposesInternalChildren
        exposesInternalChildren = true
        try {
            action()
        } finally {
            exposesInternalChildren = previouslyExposed
        }
    }

    fun requestCapAnchorLayout() {
        cachedCapHeightInsetsWidth = -1
        if (!refreshAnchoredLayoutForCurrentBounds()) requestLayout()
        invalidate()
    }

    fun setPaperOpacity(opacity: Float) {
        paperOpacity = opacity.coerceIn(0f, 1f)
        syncPaperOpacity()
    }

    fun reapplyPaperOpacity() {
        syncPaperOpacity()
    }

    private fun resolveCachedCapHeightInsets(width: Int): RNTextEngineCapHeightInsetsPx {
        if (cachedCapHeightInsetsWidth == width) return cachedCapHeightInsets

        val insets = resolveCapHeightInsets(width)
        cachedCapHeightInsets = insets
        cachedCapHeightInsetsWidth = width
        return insets
    }

    private fun syncPaperOpacity() {
        if (!anchorToCapHeight) {
            opacityTargetView.alpha = 1f
            restoreBackgroundOpacity()
            super.setAlpha(paperOpacity)
            return
        }

        super.setAlpha(1f)
        opacityTargetView.alpha = paperOpacity
        applyBackgroundOpacity()
    }

    private fun resolveOpacityBackground(): Drawable? {
        val background = background ?: return null
        if (background !== opacityBackground) {
            opacityBackground = background
            opacityBackgroundBaseAlpha = background.alpha
        }
        return background
    }

    private fun applyBackgroundOpacity() {
        resolveOpacityBackground()?.alpha = (opacityBackgroundBaseAlpha * paperOpacity).roundToInt()
    }

    private fun restoreBackgroundOpacity() {
        resolveOpacityBackground()?.alpha = opacityBackgroundBaseAlpha
    }

    private fun refreshAnchoredLayoutForCurrentBounds(): Boolean {
        val width = (right - left).coerceAtLeast(0)
        val height = (bottom - top).coerceAtLeast(0)
        if (width == 0 || height == 0) return false
        prepareAnchoredContentForLayout()
        measureAnchoredContent(width, height)
        layoutAnchoredContent(width, height)
        return true
    }

    private fun layoutAnchoredContent(width: Int, height: Int) {
        if (width == 0 || height == 0) {
            applyAnchoredContentFrame(0, 0, width, height, 0f)
            return
        }

        val insets = resolveCachedCapHeightInsets(width)
        val topInsetPx = if (anchorToCapHeight) insets.top else 0f
        val bottomInsetPx = if (anchorToCapHeight) insets.bottom else 0f
        val topInsetFloorPx = floor(topInsetPx.toDouble()).toInt()
        applyAnchoredContentFrame(
            0,
            -topInsetFloorPx,
            width,
            height + kotlin.math.ceil(bottomInsetPx.toDouble()).toInt(),
            -(topInsetPx - topInsetFloorPx),
        )
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val measuredWidth = resolveSizeAndState(suggestedMinimumWidth, widthMeasureSpec, 0)
        val measuredHeight = resolveSizeAndState(suggestedMinimumHeight, heightMeasureSpec, 0)
        setMeasuredDimension(measuredWidth, measuredHeight)
        measureAnchoredContent(measuredWidth, measuredHeight)
    }

    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        val width = (right - left).coerceAtLeast(0)
        val height = (bottom - top).coerceAtLeast(0)
        prepareAnchoredContentForLayout()
        layoutAnchoredContent(width, height)
    }
}
