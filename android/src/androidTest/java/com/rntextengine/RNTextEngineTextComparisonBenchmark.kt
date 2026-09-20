package com.rntextengine

import android.app.Application
import android.util.DisplayMetrics
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.os.Process
import android.view.Choreographer
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.facebook.react.fabric.FabricUIManager
import com.facebook.react.internal.ChoreographerProvider
import com.facebook.react.internal.featureflags.ReactNativeFeatureFlags
import com.facebook.react.internal.featureflags.ReactNativeFeatureFlagsDefaults
import com.facebook.react.modules.core.ReactChoreographer
import com.facebook.react.shell.MainReactPackage
import com.facebook.react.soloader.OpenSourceMergedSoMapping
import com.facebook.react.uimanager.DisplayMetricsHolder
import com.facebook.react.uimanager.PixelUtil
import com.facebook.react.uimanager.ViewManagerRegistry
import com.facebook.react.views.text.ReactTextViewManager
import com.facebook.soloader.SoLoader
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class RNTextEngineTextComparisonBenchmark {
    private external fun checkNativeMeasurement(): String
    private external fun checkNestedFontScaling(density: Float, fontSize: Double, lineHeight: Double, letterSpacing: Double)
    private external fun checkConcurrentMeasurement(density: Float)
    private external fun runNativeComparison(manager: FabricUIManager, density: Float, run: Int, prepared: Boolean): String

    @Test
    @Suppress("DEPRECATION")
    fun nestedTextUsesPlatformFontScaling() {
        assumeTrue(InstrumentationRegistry.getArguments().getString("rnteFontScaling") == "true")
        val application = ApplicationProvider.getApplicationContext<Application>()
        SoLoader.init(application, OpenSourceMergedSoMapping)
        SoLoader.loadLibrary("fabricjni")
        System.loadLibrary("rnte-text-comparison")
        DisplayMetricsHolder.initDisplayMetricsIfNotInitialized(application)
        RNTextEngineBindings.initialize(BenchmarkReactApplicationContext(application))
        val originalConfiguration = Configuration(application.resources.configuration)
        val originalMetrics = DisplayMetrics().apply { setTo(DisplayMetricsHolder.getScreenDisplayMetrics()) }
        try {
            for (fontScale in floatArrayOf(1f, 1.5f, 2f)) {
                application.resources.updateConfiguration(
                    Configuration(originalConfiguration).apply { this.fontScale = fontScale },
                    application.resources.displayMetrics,
                )
                DisplayMetricsHolder.setScreenDisplayMetrics(application.resources.displayMetrics)
                val density = PixelUtil.getDisplayMetricDensity()
                checkNestedFontScaling(density,
                    (PixelUtil.toPixelFromSP(18f) / density).toDouble(),
                    (PixelUtil.toPixelFromSP(40f) / density).toDouble(),
                    (PixelUtil.toPixelFromSP(2f) / density).toDouble())
            }
        } finally {
            RNTextEngineBindings.cleanup()
            application.resources.updateConfiguration(originalConfiguration, application.resources.displayMetrics)
            DisplayMetricsHolder.setScreenDisplayMetrics(originalMetrics)
        }
    }

    @Test
    fun concurrentTextViewMeasurements() {
        assumeTrue(InstrumentationRegistry.getArguments().getString("rnteConcurrency") == "true")
        val application = ApplicationProvider.getApplicationContext<Application>()
        SoLoader.init(application, OpenSourceMergedSoMapping)
        SoLoader.loadLibrary("fabricjni")
        System.loadLibrary("rnte-text-comparison")
        DisplayMetricsHolder.initDisplayMetricsIfNotInitialized(application)
        RNTextEngineBindings.initialize(BenchmarkReactApplicationContext(application))
        try {
            checkConcurrentMeasurement(application.resources.displayMetrics.density)
        } finally {
            RNTextEngineBindings.cleanup()
        }
    }

    @Test
    fun compareTextLayout() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val arguments = InstrumentationRegistry.getArguments()
        assumeTrue("Run with yarn perf:compare:android", arguments.getString("rnteComparison") == "true")
        val run = requireNotNull(arguments.getString("rnteRun")).toInt()
        val prepared = requireNotNull(arguments.getString("rntePreparedTextLayout")).toBooleanStrict()
        require(run in 1..3)
        val application = ApplicationProvider.getApplicationContext<Application>()
        SoLoader.init(application, OpenSourceMergedSoMapping)
        System.loadLibrary("rnte-text-comparison")
        ReactNativeFeatureFlags.override(object : ReactNativeFeatureFlagsDefaults() {
            override fun enablePreparedTextLayout() = prepared
        })
        DisplayMetricsHolder.initDisplayMetricsIfNotInitialized(application)
        val context = BenchmarkReactApplicationContext(application)
        RNTextEngineBindings.initialize(context)
        RNTextEngineBindings.cleanup()
        lateinit var manager: FabricUIManager
        instrumentation.runOnMainSync {
            ReactChoreographer.initialize(object : ChoreographerProvider {
                override fun getChoreographer() = object : ChoreographerProvider.Choreographer {
                    private val choreographer = Choreographer.getInstance()
                    override fun postFrameCallback(callback: Choreographer.FrameCallback) = choreographer.postFrameCallback(callback)
                    override fun removeFrameCallback(callback: Choreographer.FrameCallback) = choreographer.removeFrameCallback(callback)
                }
            })
            val textManager = requireNotNull(MainReactPackage().createViewManager(context, ReactTextViewManager.REACT_CLASS))
            manager = FabricUIManager(context, ViewManagerRegistry(listOf(textManager))) {}
        }
        try {
            val density = application.resources.displayMetrics.density
            // Native validation precedes all timing; an exception prevents result emission.
            val measurementChecksum = checkNativeMeasurement()
            val results = JSONArray(runNativeComparison(manager, density, run, prepared))
            assertTrue(results.length() == 10)
            val meta = JSONObject()
                .put("platform", "android")
                .put("deviceName", Build.MODEL)
                .put("osVersion", Build.VERSION.RELEASE)
                .put("apiLevel", Build.VERSION.SDK_INT)
                .put("abi", Build.SUPPORTED_ABIS[0])
                .put("density", density)
                .put("run", run)
                .put("pid", Process.myPid())
                .put("configuration", if (BuildConfig.DEBUG) "Debug" else "Release")
                .put("host", "native-only")
                .put("geometryValidated", true)
                .put("warmups", 10)
                .put("samples", 9)
                .put("enablePreparedTextLayout", ReactNativeFeatureFlags.enablePreparedTextLayout())
                .put("disableTextLayoutManagerCacheAndroid", ReactNativeFeatureFlags.disableTextLayoutManagerCacheAndroid())
                .put("preparedTextCacheSize", ReactNativeFeatureFlags.preparedTextCacheSize())
                .put("measurementChecksum", measurementChecksum)
            emit("RNTEXT_BENCHMARK_META", meta)
            for (index in 0 until results.length()) {
                emit("RNTEXT_BENCHMARK_RESULT", results.getJSONObject(index))
            }
        } finally {
            instrumentation.runOnMainSync { manager.invalidate() }
            RNTextEngineBindings.cleanup()
        }
    }

    private fun emit(marker: String, payload: JSONObject) {
        InstrumentationRegistry.getInstrumentation().sendStatus(0, Bundle().apply {
            putString("stream", "$marker $payload\n")
        })
    }
}
