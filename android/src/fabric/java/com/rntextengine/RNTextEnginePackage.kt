package com.rntextengine

import com.facebook.react.BaseReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ModuleSpec
import com.facebook.react.module.model.ReactModuleInfo
import com.facebook.react.module.model.ReactModuleInfoProvider

class RNTextEnginePackage : BaseReactPackage() {
    override fun getModule(name: String, reactContext: ReactApplicationContext): NativeModule? {
        if (name == RNTextEngineModule.NAME) {
            return RNTextEngineModule(reactContext)
        }
        return null
    }

    override fun getViewManagers(reactContext: ReactApplicationContext): List<ModuleSpec> {
        return listOf(
            ModuleSpec.viewManagerSpec { RNTextEngineGlyphFieldViewManager() },
            ModuleSpec.viewManagerSpec { RNTextEngineTextViewManager() },
            ModuleSpec.viewManagerSpec { RNTextEnginePreparedTextViewManager() },
        )
    }

    override fun getReactModuleInfoProvider(): ReactModuleInfoProvider {
        return ReactModuleInfoProvider {
            val isTurboModule = BuildConfig.IS_NEW_ARCHITECTURE_ENABLED
            hashMapOf(
                RNTextEngineModule.NAME to ReactModuleInfo(
                    RNTextEngineModule.NAME,
                    RNTextEngineModule.NAME,
                    false,
                    false,
                    false,
                    false,
                    isTurboModule,
                ),
            )
        }
    }
}
