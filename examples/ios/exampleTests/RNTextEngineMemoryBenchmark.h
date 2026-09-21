#pragma once

#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <mach/mach.h>
#import <malloc/malloc.h>
#include <array>
#include <memory>
#include <sys/utsname.h>

namespace rntextengine::benchmark {

struct MemorySnapshot {
  uint64_t nativeHeapBytes;
  uint64_t footprintBytes;
};
struct MemorySample {
  MemorySnapshot baseline;
  MemorySnapshot retained;
  MemorySnapshot released;
};

inline MemorySnapshot CaptureMemory()
{
  malloc_statistics_t heap{};
  malloc_zone_statistics(nullptr, &heap);
  task_vm_info_data_t info{};
  mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
  kern_return_t result = task_info(mach_task_self(), TASK_VM_INFO, reinterpret_cast<task_info_t>(&info), &count);
  XCTAssertEqual(result, KERN_SUCCESS);
  XCTAssertGreaterThanOrEqual(count, TASK_VM_INFO_REV1_COUNT);
  return {heap.size_in_use, info.phys_footprint};
}

inline void ValidateMemoryCounter()
{
  constexpr size_t bytes = 8 * 1024 * 1024;
  const auto baseline = CaptureMemory();
  auto allocation = std::make_unique<uint8_t[]>(bytes);
  volatile uint8_t *pages = allocation.get();
  for (size_t index = 0; index < bytes; index += 4096) pages[index] = 1;
  const auto retained = CaptureMemory();
  XCTAssertGreaterThanOrEqual(retained.nativeHeapBytes, baseline.nativeHeapBytes + bytes);
}

template <typename Create, typename Release, typename Collect>
std::array<MemorySample, 5> MeasureMemory(Create create, Release release, Collect collect)
{
  std::array<MemorySample, 5> samples{};
  auto snapshot = [&] {
    @autoreleasepool { collect(); }
    [CATransaction flush];
    return CaptureMemory();
  };
  for (int index = -2; index < 5; ++index) {
    auto baseline = snapshot();
    @autoreleasepool { create(); }
    auto retained = snapshot();
    @autoreleasepool { release(); }
    auto released = snapshot();
    if (index >= 0) samples[index] = {baseline, retained, released};
  }
  return samples;
}

inline NSDictionary *MemoryJSON(const MemorySnapshot &value)
{
  return @{ @"nativeHeapBytes": @(value.nativeHeapBytes), @"footprintBytes": @(value.footprintBytes) };
}

inline void EmitMemory(NSString *suite, NSString *scenario, NSString *implementation, NSUInteger units,
    const std::array<MemorySample, 5> &samples)
{
  NSMutableArray *values = [NSMutableArray new];
  for (const auto &sample : samples) {
    [values addObject:@{@"baseline": MemoryJSON(sample.baseline), @"retained": MemoryJSON(sample.retained),
        @"released": MemoryJSON(sample.released)}];
  }
  struct utsname info{};
  XCTAssertEqual(uname(&info), 0);
  NSDictionary *payload = @{
    @"suite": suite, @"scenario": scenario, @"implementation": implementation, @"units": @(units),
    @"platform": @"ios", @"run": @([NSProcessInfo.processInfo.environment[@"RNTE_BENCHMARK_RUN"] integerValue]),
    @"pid": @(NSProcessInfo.processInfo.processIdentifier), @"warmups": @2, @"samples": values,
    @"deviceName": TARGET_OS_SIMULATOR ? UIDevice.currentDevice.name : [NSString stringWithUTF8String:info.machine],
    @"osVersion": UIDevice.currentDevice.systemVersion, @"scale": @(UIScreen.mainScreen.scale),
    @"simulator": @(TARGET_OS_SIMULATOR != 0),
#ifdef DEBUG
    @"configuration": @"Debug",
#else
    @"configuration": @"Release",
#endif
  };
  NSError *error = nil;
  NSData *json = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&error];
  XCTAssertNil(error);
  printf("RNTEXT_MEMORY_RESULT %s\n", [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding].UTF8String);
}

} // namespace rntextengine::benchmark
