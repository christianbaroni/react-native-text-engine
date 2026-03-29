package com.rntextengine

import android.graphics.Canvas
import android.graphics.Color
import android.view.View
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.viewmanagers.RNTextEngineGlyphFieldViewManagerDelegate
import com.facebook.react.viewmanagers.RNTextEngineGlyphFieldViewManagerInterface

@ReactModule(name = RNTextEngineGlyphFieldViewManager.REACT_CLASS)
internal class RNTextEngineGlyphFieldViewManager :
    SimpleViewManager<RNTextEngineGlyphFieldViewManager.RNTextEngineGlyphFieldView>(),
    RNTextEngineGlyphFieldViewManagerInterface<RNTextEngineGlyphFieldViewManager.RNTextEngineGlyphFieldView> {
    private val delegate: ViewManagerDelegate<RNTextEngineGlyphFieldView> =
        RNTextEngineGlyphFieldViewManagerDelegate<RNTextEngineGlyphFieldView, RNTextEngineGlyphFieldViewManager>(this)

    override fun getName(): String = REACT_CLASS

    override fun createViewInstance(reactContext: ThemedReactContext): RNTextEngineGlyphFieldView {
        return RNTextEngineGlyphFieldView(reactContext)
    }

    override fun getDelegate(): ViewManagerDelegate<RNTextEngineGlyphFieldView> = delegate

    @ReactProp(name = "handle", defaultDouble = 0.0)
    override fun setHandle(view: RNTextEngineGlyphFieldView, handle: Double) {
        view.updateHandle(handle.toLong())
    }

    internal class RNTextEngineGlyphFieldView(context: ThemedReactContext) : View(context) {
        private var handle: Long = 0

        init {
            setBackgroundColor(Color.TRANSPARENT)
        }

        fun updateHandle(nextHandle: Long) {
            if (handle == nextHandle) return

            RNTextEngineBindings.unregisterGlyphFieldView(handle, this)
            handle = nextHandle
            RNTextEngineBindings.registerGlyphFieldView(handle, this)
            invalidate()
        }

        override fun onDetachedFromWindow() {
            RNTextEngineBindings.unregisterGlyphFieldView(handle, this)
            super.onDetachedFromWindow()
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            RNTextEngineBindings.drawGlyphField(handle, canvas, width.toFloat(), height.toFloat())
        }
    }

    companion object {
        const val REACT_CLASS = "RNTextEngineGlyphFieldView"
    }
}
