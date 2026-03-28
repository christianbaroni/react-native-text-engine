package com.rnpretext

import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext

class RNPretextModule(context: ReactApplicationContext) :
    NativeRNPretextSpec(context),
    NativeModule {

    companion object {
        const val NAME = "RNPretext"

        init {
            System.loadLibrary("rn-pretext")
        }
    }

    init {
        RNPretextBindings.initialize(context)
    }

    override fun getName(): String = NAME

    override fun initialize() {}

    override fun invalidate() {
        RNPretextBindings.cleanup()
    }

    override fun install(): Boolean {
        return try {
            val catalystInstance = reactApplicationContext.catalystInstance ?: return false
            val runtimePointer = catalystInstance.javaScriptContextHolder.get()
            if (runtimePointer == 0L) return false
            nativeInstall(runtimePointer, reactApplicationContext)
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private external fun nativeInstall(runtimePointer: Long, context: ReactApplicationContext): Boolean
}
