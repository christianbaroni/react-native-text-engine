package com.rntextengine

import android.content.Context
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.ReactStylesDiffMap
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

    override fun updateProperties(view: RNTextEnginePreparedTextView, props: ReactStylesDiffMap) {
        if (props.hasKey("accessible")) setAccessible(view, props.getBoolean("accessible", false))
        super.updateProperties(view, props)
    }

    @ReactProp(name = "accessible")
    fun setAccessible(view: RNTextEnginePreparedTextView, accessible: Boolean) {
        view.isFocusable = accessible
    }

    override fun setAccessibilityLabel(view: RNTextEnginePreparedTextView, label: String?) {
        if (label == null) view.contentDescription = null
        super.setAccessibilityLabel(view, label)
    }

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

    override fun onAfterUpdateTransaction(view: RNTextEnginePreparedTextView) {
        super.onAfterUpdateTransaction(view)
        view.finishUpdates()
    }

    internal class RNTextEnginePreparedTextView(context: Context) : RNTextEngineTextContainer(context) {
        fun setPreparedHandle(handle: Long) {
            setPreparedText(RNTextEngineBindings.preparedText(handle))
        }
    }

    companion object {
        const val REACT_CLASS = "RNTextEnginePreparedTextView"
    }
}
