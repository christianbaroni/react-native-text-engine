package com.rntextengine

import android.content.Context
import android.graphics.Color
import android.text.Layout
import android.text.TextUtils
import android.view.View
import androidx.appcompat.widget.AppCompatTextView
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.ViewProps
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.viewmanagers.RNTextEnginePreparedTextViewManagerDelegate
import com.facebook.react.viewmanagers.RNTextEnginePreparedTextViewManagerInterface

@ReactModule(name = RNTextEnginePreparedTextViewManager.REACT_CLASS)
internal class RNTextEnginePreparedTextViewManager :
    SimpleViewManager<RNTextEnginePreparedTextViewManager.RNTextEnginePreparedTextView>(),
    RNTextEnginePreparedTextViewManagerInterface<RNTextEnginePreparedTextViewManager.RNTextEnginePreparedTextView> {
    private val delegate: ViewManagerDelegate<RNTextEnginePreparedTextView> =
        RNTextEnginePreparedTextViewManagerDelegate<RNTextEnginePreparedTextView, RNTextEnginePreparedTextViewManager>(this)

    override fun getName(): String = REACT_CLASS

    override fun createViewInstance(reactContext: ThemedReactContext): RNTextEnginePreparedTextView {
        return RNTextEnginePreparedTextView(reactContext)
    }

    override fun getDelegate(): ViewManagerDelegate<RNTextEnginePreparedTextView> = delegate

    override fun setBackgroundColor(view: RNTextEnginePreparedTextView, backgroundColor: Int) {
        super.setBackgroundColor(view, backgroundColor)
        view.reapplyPaperOpacity()
    }

    override fun setOpacity(view: RNTextEnginePreparedTextView, opacity: Float) {
        view.setPaperOpacity(opacity)
    }

    @ReactProp(name = "handle", defaultDouble = 0.0)
    override fun setHandle(view: RNTextEnginePreparedTextView, handle: Double) {
        view.setPreparedHandle(handle.toLong())
    }

    @ReactProp(name = ViewProps.NUMBER_OF_LINES, defaultInt = 0)
    override fun setNumberOfLines(view: RNTextEnginePreparedTextView, numberOfLines: Int) {
        view.setNumberOfLines(numberOfLines)
    }

    @ReactProp(name = "selectable", defaultBoolean = false)
    override fun setSelectable(view: RNTextEnginePreparedTextView, selectable: Boolean) {
        view.setSelectable(selectable)
    }

    @ReactProp(name = "anchorToCapHeight", defaultBoolean = false)
    override fun setAnchorToCapHeight(view: RNTextEnginePreparedTextView, anchorToCapHeight: Boolean) {
        view.anchorToCapHeight = anchorToCapHeight
    }

    @ReactProp(name = "ellipsizeMode")
    override fun setEllipsizeMode(view: RNTextEnginePreparedTextView, ellipsizeMode: String?) {
        view.setEllipsizeMode(ellipsizeMode)
    }

    override fun setPadding(view: RNTextEnginePreparedTextView, left: Int, top: Int, right: Int, bottom: Int) {
        view.setContentPadding(left, top, right, bottom)
    }

    internal class RNTextEnginePreparedTextView(context: Context) : RNTextEngineCapAnchoredContainer(context) {
        private var preparedData: RNTextEngineBindings.PreparedTextViewData? = null
        private val attributedDisplayView = RNTextEngineAttributedTextDisplayView(context)
        val textContentView = RNTextEnginePreparedTextContentView(context)
        val displayView: RNTextEngineAttributedTextDisplayView
            get() = attributedDisplayView

        override val opacityTargetView: View
            get() = if (textContentView.parent === this) textContentView else attributedDisplayView

        override fun measureAnchoredContent(width: Int, height: Int) {
            val widthSpec = View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY)
            val heightSpec = View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY)
            attributedDisplayView.measure(widthSpec, heightSpec)
            if (textContentView.parent === this) {
                textContentView.measure(widthSpec, heightSpec)
            }
        }

        override fun resolveCapHeightInsets(width: Int): RNTextEngineCapHeightInsetsPx {
            return attributedDisplayView.resolveCapHeightInsets(width)
        }

        override fun applyAnchoredContentFrame(left: Int, top: Int, right: Int, bottom: Int, translationY: Float) {
            attributedDisplayView.layout(left, top, right, bottom)
            attributedDisplayView.translationY = translationY
            if (textContentView.parent === this) {
                textContentView.layout(left, top, right, bottom)
                textContentView.translationY = translationY
            }
        }

        init {
            addInternalChild(
                attributedDisplayView,
                LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT),
            )
        }

        fun setPreparedHandle(handle: Long) {
            preparedData = RNTextEngineBindings.resolvePreparedTextViewData(handle)
            textContentView.setPreparedData(preparedData)
            attributedDisplayView.setPreparedText(preparedData)
            requestCapAnchorLayout()
        }

        fun setNumberOfLines(numberOfLines: Int) {
            textContentView.maxLines = if (numberOfLines > 0) numberOfLines else Int.MAX_VALUE
            textContentView.setSingleLine(false)
            attributedDisplayView.numberOfLines = numberOfLines
            requestCapAnchorLayout()
        }

        fun setSelectable(value: Boolean) {
            textContentView.setTextIsSelectable(value)
            textContentView.isFocusable = value
            textContentView.isFocusableInTouchMode = value
            textContentView.isClickable = value
            textContentView.isLongClickable = value
            syncInteractionTextView(value)
            reapplyPaperOpacity()
            requestCapAnchorLayout()
        }

        fun setEllipsizeMode(mode: String?) {
            textContentView.ellipsize =
                when (mode) {
                    "head" -> TextUtils.TruncateAt.START
                    "middle" -> TextUtils.TruncateAt.MIDDLE
                    "tail" -> TextUtils.TruncateAt.END
                    else -> null
                }
            attributedDisplayView.ellipsizeMode = mode
            requestCapAnchorLayout()
        }

        fun setContentPadding(left: Int, top: Int, right: Int, bottom: Int) {
            textContentView.setPadding(left, top, right, bottom)
            attributedDisplayView.setPadding(left, top, right, bottom)
            requestCapAnchorLayout()
        }

        private fun syncInteractionTextView(selectable: Boolean) {
            if (selectable) {
                if (textContentView.parent !== this) {
                    addInternalChild(
                        textContentView,
                        LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT),
                    )
                }
                textContentView.setPreparedData(preparedData)
                attributedDisplayView.visibility = View.INVISIBLE
                return
            }

            if (textContentView.parent === this) {
                removeInternalChild(textContentView)
            }
            attributedDisplayView.visibility = View.VISIBLE
        }
    }

    internal class RNTextEnginePreparedTextContentView(context: Context) : AppCompatTextView(context) {
        private var baseCapHeightPx = 0f
        private val defaultTextColor = currentTextColor
        private var uniformCapHeightPx: Float? = 0f

        init {
            includeFontPadding = false
            isFocusable = false
            isClickable = false
            setBackgroundColor(Color.TRANSPARENT)
            setLineSpacing(0f, 1f)
            applyTextViewLineBreakConfig(this, Layout.BREAK_STRATEGY_HIGH_QUALITY, Layout.HYPHENATION_FREQUENCY_NORMAL)
        }

        fun setPreparedData(prepared: RNTextEngineBindings.PreparedTextViewData?) {
            val applied =
                applyPreparedTextViewData(
                    textView = this,
                    prepared = prepared,
                    defaultTextColor = defaultTextColor,
                )
            baseCapHeightPx = applied.baseCapHeightPx
            uniformCapHeightPx = applied.uniformCapHeightPx
        }

        fun resolveCapHeightInsets(width: Int): RNTextEngineCapHeightInsetsPx {
            return resolveCapHeightInsetsPx(
                layout = buildLayoutForTextView(this, width),
                text = text ?: "",
                defaultCapHeightPx = baseCapHeightPx,
                uniformCapHeightPx = uniformCapHeightPx,
            )
        }

        fun resolveLayout(width: Int) = buildLayoutForTextView(this, width)
    }

    companion object {
        const val REACT_CLASS = "RNTextEnginePreparedTextView"
    }
}
