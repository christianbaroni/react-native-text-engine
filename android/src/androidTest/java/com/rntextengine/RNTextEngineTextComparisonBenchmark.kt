package com.rntextengine

import android.app.Application
import android.os.Build
import android.os.Bundle
import android.os.Process
import android.view.Choreographer
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.facebook.react.fabric.FabricUIManager
import com.facebook.react.internal.ChoreographerProvider
import com.facebook.react.modules.core.ReactChoreographer
import com.facebook.react.soloader.OpenSourceMergedSoMapping
import com.facebook.react.uimanager.DisplayMetricsHolder
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
    private external fun runNativeComparison(manager: FabricUIManager, density: Float, run: Int): String

    @Test
    fun compareTextLayout() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val arguments = InstrumentationRegistry.getArguments()
        assumeTrue("Run with yarn perf:compare:android", arguments.getString("rnteComparison") == "true")
        val run = requireNotNull(arguments.getString("rnteRun")).toInt()
        require(run in 1..3)
        val application = ApplicationProvider.getApplicationContext<Application>()
        SoLoader.init(application, OpenSourceMergedSoMapping)
        DisplayMetricsHolder.initDisplayMetricsIfNotInitialized(application)
        System.loadLibrary("rnte-text-comparison")
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
            manager = FabricUIManager(context, ViewManagerRegistry(listOf(ReactTextViewManager()))) {}
        }
        try {
            val density = application.resources.displayMetrics.density
            // Native validation precedes all timing; an exception prevents result emission.
            val results = JSONArray(runNativeComparison(manager, density, run))
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
                .put("rnLayoutCacheEnabled", true)
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
