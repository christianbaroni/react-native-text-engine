package com.rntextengine

import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.module.annotations.ReactModule

@ReactModule(name = RNTextEngineModule.NAME)
class RNTextEngineModule(reactContext: ReactApplicationContext) : ReactContextBaseJavaModule(reactContext) {
    companion object {
        const val NAME = "RNTextEngine"

        init {
            try {
                System.loadLibrary("rn-text-engine")
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    init {
        RNTextEngineBindings.initialize(reactContext)
    }

    override fun getName(): String = NAME

    @ReactMethod(isBlockingSynchronousMethod = true)
    fun install(): Boolean {
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
