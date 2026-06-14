package com.rntextengine

import com.facebook.react.ReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.uimanager.ViewManager

class RNTextEnginePackage : ReactPackage {
    override fun createNativeModules(reactContext: ReactApplicationContext): List<NativeModule> {
        return listOf(RNTextEngineModule(reactContext))
    }

    override fun createViewManagers(reactContext: ReactApplicationContext): List<ViewManager<*, *>> {
        RNTextEngineBindings.initialize(reactContext)
        return listOf(
            RNTextEngineGlyphFieldViewManager(),
            RNTextEngineTextViewManager(),
            RNTextEnginePreparedTextViewManager(),
        )
    }
}
