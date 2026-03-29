package com.rnpretext

import com.facebook.react.BaseReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ModuleSpec
import com.facebook.react.module.model.ReactModuleInfo
import com.facebook.react.module.model.ReactModuleInfoProvider

class RNPretextPackage : BaseReactPackage() {
    override fun getModule(name: String, reactContext: ReactApplicationContext): NativeModule? {
        if (name == RNPretextModule.NAME) {
            return RNPretextModule(reactContext)
        }
        return null
    }

    override fun getViewManagers(reactContext: ReactApplicationContext): List<ModuleSpec> {
        return listOf(
            ModuleSpec.viewManagerSpec { RNPretextGlyphFieldViewManager() },
            ModuleSpec.viewManagerSpec { RNPretextTextViewManager() },
            ModuleSpec.viewManagerSpec { RNPretextPreparedTextViewManager() },
        )
    }

    override fun getReactModuleInfoProvider(): ReactModuleInfoProvider {
        return ReactModuleInfoProvider {
            val isTurboModule = BuildConfig.IS_NEW_ARCHITECTURE_ENABLED
            hashMapOf(
                RNPretextModule.NAME to ReactModuleInfo(
                    RNPretextModule.NAME,
                    RNPretextModule.NAME,
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
