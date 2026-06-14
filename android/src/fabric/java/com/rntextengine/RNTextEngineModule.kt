package com.rntextengine

import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext

class RNTextEngineModule(context: ReactApplicationContext) :
    NativeRNTextEngineSpec(context),
    NativeModule {

    companion object {
        const val NAME = "RNTextEngine"

        init {
            System.loadLibrary("rn-text-engine")
        }
    }

    init {
        RNTextEngineBindings.initialize(context)
    }

    override fun getName(): String = NAME

    override fun initialize() {}

    override fun invalidate() {
        RNTextEngineBindings.cleanup()
    }

    @Suppress("DEPRECATION")
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
