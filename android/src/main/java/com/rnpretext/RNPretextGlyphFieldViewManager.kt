package com.rnpretext

import android.graphics.Canvas
import android.graphics.Color
import android.view.View
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.viewmanagers.RNPretextGlyphFieldViewManagerDelegate
import com.facebook.react.viewmanagers.RNPretextGlyphFieldViewManagerInterface

@ReactModule(name = RNPretextGlyphFieldViewManager.REACT_CLASS)
internal class RNPretextGlyphFieldViewManager :
    SimpleViewManager<RNPretextGlyphFieldViewManager.RNPretextGlyphFieldView>(),
    RNPretextGlyphFieldViewManagerInterface<RNPretextGlyphFieldViewManager.RNPretextGlyphFieldView> {
    private val delegate: ViewManagerDelegate<RNPretextGlyphFieldView> =
        RNPretextGlyphFieldViewManagerDelegate<RNPretextGlyphFieldView, RNPretextGlyphFieldViewManager>(this)

    override fun getName(): String = REACT_CLASS

    override fun createViewInstance(reactContext: ThemedReactContext): RNPretextGlyphFieldView {
        return RNPretextGlyphFieldView(reactContext)
    }

    override fun getDelegate(): ViewManagerDelegate<RNPretextGlyphFieldView> = delegate

    @ReactProp(name = "handle", defaultDouble = 0.0)
    override fun setHandle(view: RNPretextGlyphFieldView, handle: Double) {
        view.updateHandle(handle.toLong())
    }

    internal class RNPretextGlyphFieldView(context: ThemedReactContext) : View(context) {
        private var handle: Long = 0

        init {
            setBackgroundColor(Color.TRANSPARENT)
        }

        fun updateHandle(nextHandle: Long) {
            if (handle == nextHandle) return

            RNPretextBindings.unregisterGlyphFieldView(handle, this)
            handle = nextHandle
            RNPretextBindings.registerGlyphFieldView(handle, this)
            invalidate()
        }

        override fun onDetachedFromWindow() {
            RNPretextBindings.unregisterGlyphFieldView(handle, this)
            super.onDetachedFromWindow()
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            RNPretextBindings.drawGlyphField(handle, canvas, width.toFloat(), height.toFloat())
        }
    }

    companion object {
        const val REACT_CLASS = "RNPretextGlyphFieldView"
    }
}
