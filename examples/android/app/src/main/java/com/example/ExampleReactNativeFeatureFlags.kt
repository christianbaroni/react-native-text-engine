package com.example

import android.content.Context
import com.facebook.react.defaults.DefaultNewArchitectureEntryPoint
import com.facebook.react.internal.featureflags.ReactNativeNewArchitectureFeatureFlagsDefaults
import com.facebook.react.internal.featureflags.ReactNativeFeatureFlagsProvider
import com.facebook.react.soloader.OpenSourceMergedSoMapping
import com.facebook.soloader.SoLoader
import java.io.IOException
import java.lang.reflect.Method
import java.lang.reflect.Modifier

private class ExampleReactNativeFeatureFlags : ReactNativeNewArchitectureFeatureFlagsDefaults() {
  override fun preventShadowTreeCommitExhaustion(): Boolean = true

  override fun useFabricInterop(): Boolean = true
}

internal object ExampleReactNativeFeatureFlagsLoader {
  private const val METHOD_PREFIX = "loadWithFeatureFlags\$"

  private val loadMethod: Method by lazy {
    DefaultNewArchitectureEntryPoint::class.java.declaredMethods.firstOrNull { method ->
      Modifier.isStatic(method.modifiers) &&
          method.name.startsWith(METHOD_PREFIX) &&
          method.parameterTypes.contentEquals(arrayOf(ReactNativeFeatureFlagsProvider::class.java))
    } ?: error("Unable to find DefaultNewArchitectureEntryPoint.loadWithFeatureFlags(...)")
  }

  private fun ensureSoLoader(context: Context) {
    try {
      SoLoader.init(context, OpenSourceMergedSoMapping)
    } catch (error: IOException) {
      throw RuntimeException(error)
    }
  }

  fun load(context: Context) {
    ensureSoLoader(context)
    loadMethod.invoke(null, ExampleReactNativeFeatureFlags())
  }
}
