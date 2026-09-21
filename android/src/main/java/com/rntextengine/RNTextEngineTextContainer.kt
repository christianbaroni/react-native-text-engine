package com.rntextengine

import android.content.Context
import android.graphics.drawable.Drawable
import android.text.Layout
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.FrameLayout
import androidx.appcompat.widget.AppCompatTextView
import androidx.core.widget.TextViewCompat
import kotlin.math.floor
import kotlin.math.roundToInt

internal open class RNTextEngineTextContainer(context: Context) : FrameLayout(context) {
    val displayView = RNTextEngineAttributedTextDisplayView(context)
    var selectionView: AppCompatTextView? = null
        private set
    protected var preparedText: RNTextEngineBindings.PreparedText? = null
        private set

    private val activeSelectionView: AppCompatTextView?
        get() = selectionView?.takeIf { it.parent === this }
    private val opacityTargetView: View
        get() = activeSelectionView ?: displayView

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
            requestTextLayout()
        }

    init {
        clipChildren = false
        clipToPadding = false
        background = null
        addInternalChild(displayView)
    }

    protected open fun prepareTextForLayout() = Unit

    protected fun setPreparedText(prepared: RNTextEngineBindings.PreparedText?) {
        if (preparedText === prepared) return
        val previousText = preparedText?.text
        preparedText = prepared
        displayView.setPreparedText(prepared)
        activeSelectionView?.let {
            applyPreparedText(it, prepared)
            displayView.applyDrawingStyle(it)
        }
        if (isAttachedToWindow && previousText != prepared?.text) {
            sendAccessibilityEvent(AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED)
        }
        requestTextLayout()
    }

    override fun getAccessibilityClassName(): CharSequence = android.widget.TextView::class.java.name

    override fun onInitializeAccessibilityNodeInfo(info: AccessibilityNodeInfo) {
        val selection = activeSelectionView
        selection?.onInitializeAccessibilityNodeInfo(info)
        info.text = preparedText?.text
        val granularities = info.movementGranularities
        val extraData = if (Build.VERSION.SDK_INT >= 26) info.availableExtraData else emptyList()
        super.onInitializeAccessibilityNodeInfo(info)
        if (selection != null) {
            info.setTextSelection(selection.selectionStart, selection.selectionEnd)
            info.movementGranularities = granularities
            if (Build.VERSION.SDK_INT >= 26) info.availableExtraData = extraData
            info.isFocused = selection.isFocused
            info.removeAction(if (selection.isFocused) AccessibilityNodeInfo.AccessibilityAction.ACTION_FOCUS
                else AccessibilityNodeInfo.AccessibilityAction.ACTION_CLEAR_FOCUS)
        }
    }

    override fun performAccessibilityAction(action: Int, arguments: Bundle?): Boolean {
        val selection = activeSelectionView
        if (selection != null && (action == AccessibilityNodeInfo.ACTION_SET_SELECTION ||
                action == AccessibilityNodeInfo.ACTION_NEXT_AT_MOVEMENT_GRANULARITY ||
                action == AccessibilityNodeInfo.ACTION_PREVIOUS_AT_MOVEMENT_GRANULARITY ||
                action == AccessibilityNodeInfo.ACTION_FOCUS || action == AccessibilityNodeInfo.ACTION_CLEAR_FOCUS)) {
            return selection.performAccessibilityAction(action, arguments)
        }
        return super.performAccessibilityAction(action, arguments) ||
            selection?.performAccessibilityAction(action, arguments) == true
    }

    override fun addExtraDataToAccessibilityNodeInfo(info: AccessibilityNodeInfo, key: String, arguments: Bundle?) {
        val selection = activeSelectionView
        if (selection != null) selection.addExtraDataToAccessibilityNodeInfo(info, key, arguments)
        else super.addExtraDataToAccessibilityNodeInfo(info, key, arguments)
    }

    override fun onRequestSendAccessibilityEvent(child: View, event: AccessibilityEvent): Boolean {
        if (child === activeSelectionView) event.setSource(this)
        return super.onRequestSendAccessibilityEvent(child, event)
    }

    fun setNumberOfLines(value: Int) {
        displayView.numberOfLines = value
        activeSelectionView?.let(displayView::applySelectionLayout)
        requestTextLayout()
    }

    fun setEllipsizeMode(value: String?) {
        displayView.ellipsizeMode = value
        activeSelectionView?.let(displayView::applySelectionLayout)
        requestTextLayout()
    }

    fun setTextAlignValue(value: String?) {
        displayView.setTextAlignValue(value)
        activeSelectionView?.let(displayView::applySelectionLayout)
        requestTextLayout()
    }

    fun setContentPadding(left: Int, top: Int, right: Int, bottom: Int) {
        displayView.setPadding(left, top, right, bottom)
        activeSelectionView?.setPadding(left, top, right, bottom)
        requestTextLayout()
    }

    fun setTextColorValue(value: Int) {
        displayView.setTextColorValue(value)
        activeSelectionView?.let(displayView::applyDrawingStyle)
    }

    fun setTextDecorationLineValue(value: String?) {
        displayView.setTextDecorationLineValue(value)
        activeSelectionView?.let(displayView::applyDrawingStyle)
    }

    fun setTextShadowColorValue(value: Int?) {
        displayView.setTextShadowColorValue(value)
        activeSelectionView?.let(displayView::applyDrawingStyle)
    }

    fun setTextShadowOffsetPx(widthPx: Float, heightPx: Float) {
        displayView.setTextShadowOffsetPx(widthPx, heightPx)
        activeSelectionView?.let(displayView::applyDrawingStyle)
    }

    fun setTextShadowRadiusPx(value: Float) {
        displayView.setTextShadowRadiusPx(value)
        activeSelectionView?.let(displayView::applyDrawingStyle)
    }

    fun setSelectable(value: Boolean) {
        if (value == (activeSelectionView != null)) return
        if (value) {
            val view = selectionView ?: AppCompatTextView(context, null, 0).also {
                it.background = null
                it.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
                it.setSingleLine(false)
                it.setHorizontallyScrolling(false)
                it.transformationMethod = null
                it.minimumWidth = 0
                it.minimumHeight = 0
                it.minWidth = 0
                it.minHeight = 0
                it.textDirection = View.TEXT_DIRECTION_FIRST_STRONG_LTR
                TextViewCompat.setAutoSizeTextTypeWithDefaults(it, TextViewCompat.AUTO_SIZE_TEXT_TYPE_NONE)
                applyTextViewLineBreakConfig(it, Layout.BREAK_STRATEGY_HIGH_QUALITY, Layout.HYPHENATION_FREQUENCY_NORMAL)
                selectionView = it
            }
            view.setTextIsSelectable(true)
            view.isFocusable = true
            applyPreparedText(view, preparedText)
            displayView.applySelectionLayout(view)
            displayView.applyDrawingStyle(view)
            addInternalChild(view)
            displayView.visibility = View.INVISIBLE
        } else {
            activeSelectionView?.let {
                it.setTextIsSelectable(false)
                it.isFocusable = false
                it.text = null
                removeInternalChild(it)
            }
            displayView.visibility = View.VISIBLE
        }
        syncPaperOpacity()
        requestTextLayout()
    }

    fun finishUpdates() {
        // Fabric updates props before state on creation; prepare once both reach layout.
        if (width > 0 && height > 0) {
            prepareTextForLayout()
            measureContent(width, height)
            layoutAnchoredContent(width, height)
        }
    }

    private fun measureContent(width: Int, height: Int) {
        val widthSpec = View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY)
        val heightSpec = View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY)
        displayView.measure(widthSpec, heightSpec)
        activeSelectionView?.measure(widthSpec, heightSpec)
    }

    private fun applyContentFrame(left: Int, top: Int, right: Int, bottom: Int, translationY: Float) {
        displayView.layout(left, top, right, bottom)
        displayView.translationY = translationY
        activeSelectionView?.let {
            it.layout(left, top, right, bottom)
            it.translationY = translationY
        }
    }

    override fun getChildCount(): Int = if (exposesInternalChildren) super.getChildCount() else 0

    override fun getChildAt(index: Int): View? = if (exposesInternalChildren) super.getChildAt(index) else null

    override fun indexOfChild(child: View?): Int = if (exposesInternalChildren) super.indexOfChild(child) else -1

    private fun addInternalChild(child: View) {
        withInternalChildAccess {
            super.addView(child, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
        }
    }

    private fun removeInternalChild(child: View) {
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

    protected fun requestTextLayout() {
        cachedCapHeightInsetsWidth = -1
        requestLayout()
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

        val insets = displayView.resolveCapHeightInsets(width)
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

    private fun layoutAnchoredContent(width: Int, height: Int) {
        if (!anchorToCapHeight || width == 0 || height == 0) {
            applyContentFrame(0, 0, width, height, 0f)
            return
        }

        val insets = resolveCachedCapHeightInsets(width)
        val topInsetPx = insets.top
        val bottomInsetPx = insets.bottom
        val topInsetFloorPx = floor(topInsetPx.toDouble()).toInt()
        applyContentFrame(
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
        prepareTextForLayout()
        measureContent(measuredWidth, measuredHeight)
    }

    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        val width = (right - left).coerceAtLeast(0)
        val height = (bottom - top).coerceAtLeast(0)
        prepareTextForLayout()
        layoutAnchoredContent(width, height)
    }
}
