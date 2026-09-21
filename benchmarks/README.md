# Benchmarks

| Suite                                                                   | Measures                                                     | Results                               |
| ----------------------------------------------------------------------- | ------------------------------------------------------------ | ------------------------------------- |
| [TextView and PreparedTextView vs React Native Text](rn-text/README.md) | Native layout, drawing, and held/released memory             | [RN comparison](rn-text/results.md)   |
| [Library benchmarks](library/README.md)                                 | Preparation, layout, glyph updates, and held/released memory | [Library results](library/results.md) |

Run benchmark commands from the repository root after installing the library and [example app dependencies](../examples/README.md#run). iOS runs also require the example's CocoaPods dependencies. The RN Text comparison supports simulators and physical devices; the library benchmarks use a booted simulator. Android runs require a connected device or emulator.

Run logs are saved under `.results/` and ignored by Git. Each suite keeps its latest results for each platform in the file linked above.

## Memory

Each runner includes separate memory processes. To refresh memory without rerunning timings, prefix any benchmark command with `BENCHMARK_MEMORY_ONLY=1`, for example:

```sh
BENCHMARK_MEMORY_ONLY=1 yarn perf:compare:android
BENCHMARK_MEMORY_ONLY=1 yarn perf:ios
```

Memory passes record three snapshots: before constructing the workload, while its objects are held, and after releasing them. Two complete warm-up passes precede five recorded passes in each of three fresh processes. The report subtracts each pass's own baseline, takes the median within each process, and reports the median and median absolute deviation across processes. All absolute snapshots are retained in the results. Negative changes are preserved.

| Platform | Counter           | Meaning                                                                                                       |
| -------- | ----------------- | ------------------------------------------------------------------------------------------------------------- |
| iOS      | Native heap       | `malloc_zone_statistics(nullptr).size_in_use`, summed across malloc zones, including Objective-C allocations. |
| iOS      | Process footprint | `task_info(TASK_VM_INFO).phys_footprint`, including non-heap costs such as offscreen drawing backing stores.  |
| Android  | Native heap       | `Debug.getNativeHeapAllocatedSize()`, allocated bytes reported by the native allocator.                       |
| Android  | Managed heap      | `Runtime.totalMemory() - Runtime.freeMemory()` after collection.                                              |

The iOS counters overlap and must not be added. Warm allocators can satisfy new objects from pages already counted in process footprint; a zero footprint change can accompany a substantial live heap increase. Android's managed and native counters do not include every process mapping or graphics allocation. These measurements describe steady-state memory changes for the stated workload, not cumulative allocation, a sampled peak, or an object-graph retained-size inventory. [Apple memory accounting](https://developer.apple.com/library/archive/technotes/tn2434/_index.html) and [Android counter definitions](https://developer.android.com/reference/android/os/Debug) describe the platform boundaries.

iOS drains autorelease pools and flushes Core Animation before sampling; the library suite also explicitly collects its Hermes runtime. The Android comparison also waits for the UI queue to become idle before each snapshot. Android requests two garbage collections with finalization between them and verifies that ART's collection count advanced. Each memory process first checks that its heap counter responds to a deliberately held 8 MiB allocation. The Android managed-heap check permits a 1% shortfall because collection can also reclaim unrelated objects; this allowance does not alter the recorded samples. No memory sampling or forced collection occurs inside the timing passes.

The released column shows the change still present at that snapshot, including allocator and platform caches. It is not a leak count. The reference holders needed by the harness also matter: Android's drawn-view pass retains each view and state wrapper through a teardown callback, and those callbacks contribute to its held heap delta. Compare implementations within a platform and workload; the suites do not impose identical runtime or graphics allocation models across platforms.
