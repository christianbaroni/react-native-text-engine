package com.rnpretext

import com.facebook.react.TurboReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.model.ReactModuleInfo
import com.facebook.react.module.model.ReactModuleInfoProvider

class RNPretextPackage : TurboReactPackage() {
    override fun getModule(name: String, reactContext: ReactApplicationContext): NativeModule? {
        if (name == RNPretextModule.NAME) {
            return RNPretextModule(reactContext)
        }
        return null
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
