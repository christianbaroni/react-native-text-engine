package com.rntextengine

import android.os.Build
import android.os.Bundle
import android.os.Debug
import android.os.Process
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONArray
import org.json.JSONObject

object BenchmarkMemory {
    fun validateCounter() {
        val baseline = snapshot()
        val allocation = ByteArray(8 * 1024 * 1024) { 1 }
        val retained = snapshot()
        // A process-wide reading also includes unrelated reclamation during collection.
        check(retained[1] - baseline[1] >= allocation.size * 99L / 100) {
            "Managed memory counter did not track a retained allocation: ${baseline[1]} -> ${retained[1]}, expected +${allocation.size}"
        }
        check(allocation.last() == 1.toByte())
    }

    fun snapshot(): LongArray {
        val runtime = Runtime.getRuntime()
        val before = requireNotNull(Debug.getRuntimeStat("art.gc.gc-count")).toLong()
        runtime.gc()
        System.runFinalization()
        runtime.gc()
        check(requireNotNull(Debug.getRuntimeStat("art.gc.gc-count")).toLong() > before) {
            "Memory sampling requires a completed garbage collection"
        }
        return longArrayOf(Debug.getNativeHeapAllocatedSize(), runtime.totalMemory() - runtime.freeMemory())
    }

    fun measure(create: () -> Unit, release: () -> Unit): JSONArray {
        val samples = JSONArray()
        repeat(7) { pass ->
            val baseline = snapshot()
            val retained = try {
                create()
                snapshot()
            } finally {
                release()
            }
            val released = snapshot()
            if (pass >= 2) samples.put(JSONObject()
                .put("baseline", json(baseline)).put("retained", json(retained)).put("released", json(released)))
        }
        return samples
    }

    private fun json(values: LongArray) = JSONObject()
        .put("nativeHeapBytes", values[0]).put("managedHeapBytes", values[1])

    fun emit(suite: String, scenario: String, implementation: String, units: Int, samples: JSONArray, prepared: Boolean = false) {
        val arguments = InstrumentationRegistry.getArguments()
        val run = requireNotNull(arguments.getString("rnteRun")).toInt()
        require(run in 1..3)
        val payload = JSONObject()
            .put("suite", suite).put("scenario", scenario).put("implementation", implementation).put("units", units)
            .put("platform", "android").put("run", run).put("pid", Process.myPid()).put("warmups", 2).put("samples", samples)
            .put("deviceName", Build.MODEL).put("osVersion", Build.VERSION.RELEASE).put("apiLevel", Build.VERSION.SDK_INT)
            .put("abi", Build.SUPPORTED_ABIS[0]).put("density", InstrumentationRegistry.getInstrumentation().targetContext.resources.displayMetrics.density)
            .put("configuration", if (BuildConfig.DEBUG) "Debug" else "Release").put("prepared", prepared)
        InstrumentationRegistry.getInstrumentation().sendStatus(0, Bundle().apply {
            putString("stream", "RNTEXT_MEMORY_RESULT $payload\n")
        })
    }
}
