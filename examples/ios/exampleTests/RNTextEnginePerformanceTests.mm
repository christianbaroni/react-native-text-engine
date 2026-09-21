#import <XCTest/XCTest.h>

#import <hermes/hermes.h>

#import "../../../ios/RNTextEngineBindings.h"
#import "RNTextEngineTestRuntimeHelpers.h"
#import "RNTextEngineMemoryBenchmark.h"
#import <jsi/instrumentation.h>

#import <memory>
#import <string>

using namespace facebook;

namespace {

class StringBuffer final : public jsi::Buffer {
 public:
  explicit StringBuffer(std::string source) : source_(std::move(source)) {}

  size_t size() const override
  {
    return source_.size();
  }

  const uint8_t *data() const override
  {
    return reinterpret_cast<const uint8_t *>(source_.data());
  }

 private:
  std::string source_;
};

static std::string JSONStringFromObject(id object)
{
  NSError *error = nil;
  NSData *data = [NSJSONSerialization dataWithJSONObject:object options:NSJSONWritingFragmentsAllowed error:&error];
  if (data == nil || error != nil) {
    @throw [NSException exceptionWithName:@"RNTextEngineJSONError" reason:error.localizedDescription userInfo:nil];
  }

  NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  return json ? json.UTF8String : "";
}

static NSArray<NSString *> *BuildChatCorpus(NSUInteger count)
{
  NSArray<NSString *> *fragments = @[
    @"The renderer should know the bubble height before the row mounts.",
    @"Prepared text keeps width work separate from shaping work in a virtualized list.",
    @"Inline emphasis, tabular numbers, and quoted citations still need exact native metrics.",
    @"Glyph fields should mutate cells instead of rebuilding paragraphs when the surface is fixed-grid.",
    @"Worklet-driven layout needs stable widths, line counts, and last-line geometry to stay smooth.",
  ];

  NSMutableArray<NSString *> *texts = [NSMutableArray arrayWithCapacity:count];
  for (NSUInteger index = 0; index < count; index += 1) {
    NSString *first = fragments[index % fragments.count];
    NSString *second = fragments[(index + 2) % fragments.count];
    NSString *third = fragments[(index + 4) % fragments.count];
    [texts addObject:[NSString stringWithFormat:@"Message %lu. %@ %@ %@", (unsigned long)(index + 1), first, second, third]];
  }

  return texts;
}

static NSString *BuildFlowText(void)
{
  NSMutableString *text = [NSMutableString string];
  for (NSInteger index = 0; index < 48; index += 1) {
    [text appendFormat:@"Flow line %ld needs exact next-line geometry around changing widths. ", (long)(index + 1)];
  }
  return text;
}

static NSString *BuildInlineText(void)
{
  return @"Prepared text performance should cover inline emphasis, quoted insertions, and editorial spans with varied typography while preserving one coherent source string. This scenario intentionally mixes font weight, family, size, spacing, and line-height overrides because those are the inline facts the public contract actually exposes.";
}

static NSArray<NSDictionary *> *BuildInlineRuns(NSInteger textLength)
{
  NSArray<NSNumber *> *starts = @[ @0, @16, @43, @74, @119, @177, @239 ];
  NSArray<NSNumber *> *ends = @[ @15, @42, @73, @118, @176, @238, @(MIN(textLength, 307)) ];
  NSArray<NSDictionary *> *styles = @[
    @{ @"color" : @"#111111", @"fontWeight" : @"700" },
    @{ @"fontFamily" : @"serif" },
    @{ @"fontSize" : @20, @"letterSpacing" : @0.08 },
    @{ @"lineHeight" : @30 },
    @{ @"fontStyle" : @"italic" },
    @{ @"tabularNumbers" : @YES },
    @{ @"color" : @"#5f3300", @"fontSize" : @22, @"fontWeight" : @"700" },
  ];

  NSMutableArray<NSDictionary *> *runs = [NSMutableArray arrayWithCapacity:starts.count];
  for (NSUInteger index = 0; index < starts.count; index += 1) {
    [runs addObject:@{
      @"start" : starts[index],
      @"end" : ends[index],
      @"style" : styles[index],
    }];
  }

  return runs;
}

static NSDictionary *BuildGlyphFieldState(NSString *palette, NSData *glyphIndexData, NSData *variantIndexData)
{
  const uint8_t *glyphIndices = static_cast<const uint8_t *>(glyphIndexData.bytes);
  NSMutableString *glyphs = [NSMutableString stringWithCapacity:glyphIndexData.length];
  for (NSUInteger index = 0; index < glyphIndexData.length; index += 1) {
    [glyphs appendFormat:@"%C", [palette characterAtIndex:glyphIndices[index]]];
  }

  NSMutableArray<NSNumber *> *glyphIndexArray = [NSMutableArray arrayWithCapacity:glyphIndexData.length];
  NSMutableArray<NSNumber *> *variantIndexArray = [NSMutableArray arrayWithCapacity:variantIndexData.length];
  const uint8_t *variants = static_cast<const uint8_t *>(variantIndexData.bytes);
  for (NSUInteger index = 0; index < glyphIndexData.length; index += 1) {
    [glyphIndexArray addObject:@(glyphIndices[index])];
    [variantIndexArray addObject:@(variants[index])];
  }

  return @{
    @"glyphIndices" : glyphIndexArray,
    @"glyphs" : glyphs,
    @"variantIndices" : variantIndexArray,
  };
}

static NSDictionary *BuildGlyphFixtures(void)
{
  NSInteger columns = 80;
  NSInteger rows = 24;
  NSUInteger cellCount = (NSUInteger)(columns * rows);
  NSString *palette = @" .,:;!+-=*#@%&abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

  NSMutableData *lowA = [NSMutableData dataWithLength:cellCount];
  NSMutableData *lowB = [NSMutableData dataWithLength:cellCount];
  NSMutableData *highA = [NSMutableData dataWithLength:cellCount];
  NSMutableData *highB = [NSMutableData dataWithLength:cellCount];
  NSMutableData *lowVariantA = [NSMutableData dataWithLength:cellCount];
  NSMutableData *lowVariantB = [NSMutableData dataWithLength:cellCount];
  NSMutableData *highVariantA = [NSMutableData dataWithLength:cellCount];
  NSMutableData *highVariantB = [NSMutableData dataWithLength:cellCount];

  uint8_t *lowAGlyphs = static_cast<uint8_t *>(lowA.mutableBytes);
  uint8_t *lowBGlyphs = static_cast<uint8_t *>(lowB.mutableBytes);
  uint8_t *highAGlyphs = static_cast<uint8_t *>(highA.mutableBytes);
  uint8_t *highBGlyphs = static_cast<uint8_t *>(highB.mutableBytes);
  uint8_t *lowAVariants = static_cast<uint8_t *>(lowVariantA.mutableBytes);
  uint8_t *lowBVariants = static_cast<uint8_t *>(lowVariantB.mutableBytes);
  uint8_t *highAVariants = static_cast<uint8_t *>(highVariantA.mutableBytes);
  uint8_t *highBVariants = static_cast<uint8_t *>(highVariantB.mutableBytes);

  for (NSUInteger index = 0; index < cellCount; index += 1) {
    uint8_t baseGlyph = (uint8_t)((index * 7) % palette.length);
    uint8_t alternateGlyph = (uint8_t)((index % 7 == 0) ? (baseGlyph + 11) % palette.length : baseGlyph);
    uint8_t highGlyphA = (uint8_t)((index * 13) % palette.length);
    uint8_t highGlyphB = (uint8_t)((palette.length - 1 - highGlyphA + palette.length) % palette.length);

    lowAGlyphs[index] = baseGlyph;
    lowBGlyphs[index] = alternateGlyph;
    highAGlyphs[index] = highGlyphA;
    highBGlyphs[index] = highGlyphB;

    lowAVariants[index] = (uint8_t)(index % 3);
    lowBVariants[index] = (uint8_t)((index % 11 == 0) ? (index + 1) % 3 : index % 3);
    highAVariants[index] = (uint8_t)(index % 3);
    highBVariants[index] = (uint8_t)((index + 1) % 3);
  }

  return @{
    @"columns" : @(columns),
    @"rows" : @(rows),
    @"palette" : palette,
    @"lowChurn" : @[
      BuildGlyphFieldState(palette, lowA, lowVariantA),
      BuildGlyphFieldState(palette, lowB, lowVariantB),
    ],
    @"highChurn" : @[
      BuildGlyphFieldState(palette, highA, highVariantA),
      BuildGlyphFieldState(palette, highB, highVariantB),
    ],
  };
}

} // namespace

@interface RNTextEnginePerformanceTests : XCTestCase
@end

@implementation RNTextEnginePerformanceTests {
  std::unique_ptr<jsi::Runtime> _runtime;
}

- (void)setUp
{
  [super setUp];
  _runtime = facebook::hermes::makeHermesRuntime();
  rntextengine::install(*_runtime);
  rntextengine::testhelpers::installRuntimeHandleTracking(*_runtime);
  [self installPerformanceFixtures];
}

- (void)tearDown
{
  rntextengine::testhelpers::releaseTrackedRuntimeHandles(*_runtime);
  _runtime.reset();
  [super tearDown];
}

- (jsi::Value)evaluateSource:(const std::string &)source
{
  return _runtime->evaluateJavaScript(
      std::make_unique<StringBuffer>(source),
      "RNTextEnginePerformanceTests.js");
}

- (void)installPerformanceFixtures
{
  NSArray<NSString *> *chatTexts = BuildChatCorpus(128);
  NSDictionary *chatStyle = @{
    @"fontSize" : @17,
    @"fontWeight" : @"500",
    @"letterSpacing" : @0.1,
    @"lineHeight" : @24,
  };
  NSDictionary *chatLayout = @{ @"width" : @260 };

  NSString *inlineText = BuildInlineText();
  NSDictionary *inlineStyle = @{
    @"color" : @"#111111",
    @"fontSize" : @18,
    @"fontWeight" : @"400",
    @"letterSpacing" : @0.05,
    @"lineHeight" : @26,
  };
  NSArray<NSDictionary *> *inlineRuns = BuildInlineRuns(inlineText.length);

  NSDictionary *flowStyle = @{
    @"fontSize" : @18,
    @"letterSpacing" : @0.1,
    @"lineHeight" : @26,
  };
  NSArray<NSNumber *> *flowWidths = @[ @240, @180, @220, @160, @200, @190 ];
  NSDictionary *glyphFixtures = BuildGlyphFixtures();

  NSDictionary *glyphConfig = @{
    @"columns" : glyphFixtures[@"columns"],
    @"rows" : glyphFixtures[@"rows"],
    @"fontSize" : @14,
    @"lineHeight" : @16,
    @"textAlign" : @"center",
    @"glyphPalette" : glyphFixtures[@"palette"],
    @"variants" : @[
      @{ @"color" : @"#8b8b8b", @"fontWeight" : @"400" },
      @{ @"color" : @"#ffffff", @"fontWeight" : @"600" },
      @{ @"color" : @"#ffb000", @"fontWeight" : @"700" },
    ],
  };

  std::string source =
      "(() => {"
      "const CHAT_TEXTS = " + JSONStringFromObject(chatTexts) + ";" +
      "const CHAT_STYLE = " + JSONStringFromObject(chatStyle) + ";" +
      "const CHAT_LAYOUT = " + JSONStringFromObject(chatLayout) + ";" +
      "const INLINE_TEXT = " + JSONStringFromObject(inlineText) + ";" +
      "const INLINE_STYLE = " + JSONStringFromObject(inlineStyle) + ";" +
      "const INLINE_RUNS = " + JSONStringFromObject(inlineRuns) + ";" +
      "const FLOW_TEXT = " + JSONStringFromObject(BuildFlowText()) + ";" +
      "const FLOW_STYLE = " + JSONStringFromObject(flowStyle) + ";" +
      "const FLOW_WIDTHS = " + JSONStringFromObject(flowWidths) + ";" +
      "const GLYPH_CONFIG = " + JSONStringFromObject(glyphConfig) + ";" +
      "const GLYPH_LOW = " + JSONStringFromObject(glyphFixtures[@"lowChurn"]) + ".map(state => ({ glyphIndices: Uint8Array.from(state.glyphIndices), glyphs: state.glyphs, variantIndices: Uint8Array.from(state.variantIndices) }));" +
      "const GLYPH_HIGH = " + JSONStringFromObject(glyphFixtures[@"highChurn"]) + ".map(state => ({ glyphIndices: Uint8Array.from(state.glyphIndices), glyphs: state.glyphs, variantIndices: Uint8Array.from(state.variantIndices) }));" +
      "globalThis.__perf = {"
      "prepareChatBatchLifecycle(iterations) {"
      "  for (let index = 0; index < iterations; index += 1) {"
      "    const handles = __RNTextEnginePrepareBatch(CHAT_TEXTS, CHAT_STYLE);"
      "    __RNTextEngineReleaseMany(handles);"
      "  }"
      "  return true;"
      "},"
      "installChatLayoutHandles() {"
      "  if (globalThis.__chatHandles) __RNTextEngineReleaseMany(globalThis.__chatHandles);"
      "  globalThis.__chatHandles = __RNTextEnginePrepareBatch(CHAT_TEXTS, CHAT_STYLE);"
      "},"
      "releaseChatLayoutHandles() {"
      "  if (!globalThis.__chatHandles) return;"
      "  __RNTextEngineReleaseMany(globalThis.__chatHandles);"
      "  globalThis.__chatHandles = null;"
      "},"
      "layoutChatBatch(iterations) {"
      "  for (let index = 0; index < iterations; index += 1) {"
      "    __RNTextEngineLayoutBatch(globalThis.__chatHandles, CHAT_LAYOUT);"
      "  }"
      "  return true;"
      "},"
      "measureChatBatch(iterations) {"
      "  for (let index = 0; index < iterations; index += 1) {"
      "    __RNTextEngineMeasureBatch(CHAT_TEXTS, CHAT_STYLE, CHAT_LAYOUT);"
      "  }"
      "  return true;"
      "},"
      "prepareInlineRunsLifecycle(iterations) {"
      "  for (let index = 0; index < iterations; index += 1) {"
      "    const handle = __RNTextEnginePrepare(INLINE_TEXT, INLINE_STYLE, INLINE_RUNS);"
      "    __RNTextEngineRelease(handle);"
      "  }"
      "  return true;"
      "},"
      "installFlowHandle() {"
      "  if (globalThis.__flowHandle) __RNTextEngineRelease(globalThis.__flowHandle);"
      "  globalThis.__flowHandle = __RNTextEnginePrepare(FLOW_TEXT, FLOW_STYLE);"
      "},"
      "releaseFlowHandle() {"
      "  if (!globalThis.__flowHandle) return;"
      "  __RNTextEngineRelease(globalThis.__flowHandle);"
      "  globalThis.__flowHandle = null;"
      "},"
      "layoutNextLineSequence(iterations, anchorToCapHeight) {"
      "  for (let iteration = 0; iteration < iterations; iteration += 1) {"
      "    let start = 0;"
      "    let widthIndex = 0;"
      "    while (true) {"
      "      const next = __RNTextEngineLayoutNextLine(globalThis.__flowHandle, start, FLOW_WIDTHS[widthIndex % FLOW_WIDTHS.length], !!anchorToCapHeight);"
      "      if (next === null) break;"
      "      if (next.end <= start) break;"
      "      start = next.end;"
      "      widthIndex += 1;"
      "    }"
      "  }"
      "  return true;"
      "},"
      "installMemoryGlyphFields() {"
      "  globalThis.__memoryGlyphFields = [];"
      "  const state = GLYPH_LOW[0];"
      "  for (let index = 0; index < 64; ++index) {"
      "    const handle = __RNTextEngineCreateGlyphField(GLYPH_CONFIG);"
      "    globalThis.__memoryGlyphFields.push(handle);"
      "    __RNTextEngineUpdateGlyphFieldIndices(handle, state.glyphIndices, state.variantIndices);"
      "  }"
      "},"
      "releaseMemoryGlyphFields() {"
      "  globalThis.__memoryGlyphFields.forEach(handle => __RNTextEngineReleaseGlyphField(handle));"
      "  globalThis.__memoryGlyphFields = null;"
      "},"
      "installGlyphIndexFieldLowChurn() {"
      "  if (globalThis.__glyphIndexFieldLow) __RNTextEngineReleaseGlyphField(globalThis.__glyphIndexFieldLow);"
      "  globalThis.__glyphIndexFieldLow = __RNTextEngineCreateGlyphField(GLYPH_CONFIG);"
      "  globalThis.__glyphIndexFieldLowState = 0;"
      "  const state = GLYPH_LOW[0];"
      "  __RNTextEngineUpdateGlyphFieldIndices(globalThis.__glyphIndexFieldLow, state.glyphIndices, state.variantIndices);"
      "},"
      "releaseGlyphIndexFieldLowChurn() {"
      "  if (!globalThis.__glyphIndexFieldLow) return;"
      "  __RNTextEngineReleaseGlyphField(globalThis.__glyphIndexFieldLow);"
      "  globalThis.__glyphIndexFieldLow = null;"
      "},"
      "glyphIndicesLowChurn(iterations) {"
      "  for (let iteration = 0; iteration < iterations; iteration += 1) {"
      "    globalThis.__glyphIndexFieldLowState ^= 1;"
      "    const state = GLYPH_LOW[globalThis.__glyphIndexFieldLowState];"
      "    __RNTextEngineUpdateGlyphFieldIndices(globalThis.__glyphIndexFieldLow, state.glyphIndices, state.variantIndices);"
      "  }"
      "  return true;"
      "},"
      "installGlyphBufferFieldLowChurn() {"
      "  if (globalThis.__glyphBufferFieldLow) __RNTextEngineReleaseGlyphField(globalThis.__glyphBufferFieldLow);"
      "  globalThis.__glyphBufferFieldLow = __RNTextEngineCreateGlyphField(GLYPH_CONFIG);"
      "  globalThis.__glyphBufferFieldLowState = 0;"
      "  const buffers = __RNTextEngineCreateGlyphFieldBuffers(globalThis.__glyphBufferFieldLow);"
      "  globalThis.__glyphBufferGlyphIndices = new Uint8Array(buffers.glyphIndices);"
      "  globalThis.__glyphBufferVariantIndices = new Uint8Array(buffers.variantIndices);"
      "  const state = GLYPH_LOW[0];"
      "  globalThis.__glyphBufferGlyphIndices.set(state.glyphIndices);"
      "  globalThis.__glyphBufferVariantIndices.set(state.variantIndices);"
      "  __RNTextEngineCommitGlyphFieldBuffers(globalThis.__glyphBufferFieldLow);"
      "},"
      "releaseGlyphBufferFieldLowChurn() {"
      "  if (!globalThis.__glyphBufferFieldLow) return;"
      "  __RNTextEngineReleaseGlyphField(globalThis.__glyphBufferFieldLow);"
      "  globalThis.__glyphBufferFieldLow = null;"
      "},"
      "glyphBufferCommitLowChurn(iterations) {"
      "  for (let iteration = 0; iteration < iterations; iteration += 1) {"
      "    globalThis.__glyphBufferFieldLowState ^= 1;"
      "    const state = GLYPH_LOW[globalThis.__glyphBufferFieldLowState];"
      "    globalThis.__glyphBufferGlyphIndices.set(state.glyphIndices);"
      "    globalThis.__glyphBufferVariantIndices.set(state.variantIndices);"
      "    __RNTextEngineCommitGlyphFieldBuffers(globalThis.__glyphBufferFieldLow);"
      "  }"
      "  return true;"
      "},"
      "installGlyphStringFieldHighChurn() {"
      "  if (globalThis.__glyphStringFieldHigh) __RNTextEngineReleaseGlyphField(globalThis.__glyphStringFieldHigh);"
      "  globalThis.__glyphStringFieldHigh = __RNTextEngineCreateGlyphField(GLYPH_CONFIG);"
      "  globalThis.__glyphStringFieldHighState = 0;"
      "  const state = GLYPH_HIGH[0];"
      "  __RNTextEngineUpdateGlyphField(globalThis.__glyphStringFieldHigh, state.glyphs, state.variantIndices);"
      "},"
      "installGlyphStringFieldLowChurn() {"
      "  if (globalThis.__glyphStringFieldLow) __RNTextEngineReleaseGlyphField(globalThis.__glyphStringFieldLow);"
      "  globalThis.__glyphStringFieldLow = __RNTextEngineCreateGlyphField(GLYPH_CONFIG);"
      "  globalThis.__glyphStringFieldLowState = 0;"
      "  const state = GLYPH_LOW[0];"
      "  __RNTextEngineUpdateGlyphField(globalThis.__glyphStringFieldLow, state.glyphs, state.variantIndices);"
      "},"
      "releaseGlyphStringFieldLowChurn() {"
      "  if (!globalThis.__glyphStringFieldLow) return;"
      "  __RNTextEngineReleaseGlyphField(globalThis.__glyphStringFieldLow);"
      "  globalThis.__glyphStringFieldLow = null;"
      "},"
      "releaseGlyphStringFieldHighChurn() {"
      "  if (!globalThis.__glyphStringFieldHigh) return;"
      "  __RNTextEngineReleaseGlyphField(globalThis.__glyphStringFieldHigh);"
      "  globalThis.__glyphStringFieldHigh = null;"
      "},"
      "glyphStringLowChurn(iterations) {"
      "  for (let iteration = 0; iteration < iterations; iteration += 1) {"
      "    globalThis.__glyphStringFieldLowState ^= 1;"
      "    const state = GLYPH_LOW[globalThis.__glyphStringFieldLowState];"
      "    __RNTextEngineUpdateGlyphField(globalThis.__glyphStringFieldLow, state.glyphs, state.variantIndices);"
      "  }"
      "  return true;"
      "},"
      "glyphStringHighChurn(iterations) {"
      "  for (let iteration = 0; iteration < iterations; iteration += 1) {"
      "    globalThis.__glyphStringFieldHighState ^= 1;"
      "    const state = GLYPH_HIGH[globalThis.__glyphStringFieldHighState];"
      "    __RNTextEngineUpdateGlyphField(globalThis.__glyphStringFieldHigh, state.glyphs, state.variantIndices);"
      "  }"
      "  return true;"
      "}"
      "};"
      "})();";

  [self evaluateSource:source];
}

- (void)measurePerfScript:(const std::string &)script setup:(const std::string &)setup teardown:(const std::string &)teardown
{
  [self measureMetrics:@[ XCTPerformanceMetric_WallClockTime ]
  automaticallyStartMeasuring:NO
                  forBlock:^{
                    if (!setup.empty()) {
                      [self evaluateSource:setup];
                    }

                    [self evaluateSource:script];
                    [self startMeasuring];
                    [self evaluateSource:script];
                    [self stopMeasuring];

                    if (!teardown.empty()) {
                      [self evaluateSource:teardown];
                    }
                  }];
}

- (void)testMemoryFootprint
{
  XCTSkipIf(![NSProcessInfo.processInfo.environment[@"RNTE_BENCHMARK"] isEqualToString:@"1"], @"Run with the library benchmark runner.");
  rntextengine::benchmark::ValidateMemoryCounter();
  auto collect = [&] { _runtime->instrumentation().collectGarbage("Memory benchmark"); };
  auto prepared = rntextengine::benchmark::MeasureMemory([&] {
    [self evaluateSource:"__perf.installChatLayoutHandles(); __perf.layoutChatBatch(1)"];
    XCTAssertEqual([self evaluateSource:"__chatHandles.length"].asNumber(), 128);
  }, [&] { [self evaluateSource:"__perf.releaseChatLayoutHandles()"]; }, collect);
  rntextengine::benchmark::EmitMemory(@"library", @"prepared_chat", @"Text Engine", 128, prepared);
  auto glyphs = rntextengine::benchmark::MeasureMemory([&] {
    [self evaluateSource:"__perf.installMemoryGlyphFields()"];
    XCTAssertEqual([self evaluateSource:"__memoryGlyphFields.length"].asNumber(), 64);
  }, [&] { [self evaluateSource:"__perf.releaseMemoryGlyphFields()"]; }, collect);
  rntextengine::benchmark::EmitMemory(@"library", @"glyph_fields", @"Text Engine", 64, glyphs);
}

- (void)testPreparedBatchCreateChatLifecycle
{
  [self measurePerfScript:"__perf.prepareChatBatchLifecycle(2048)"
                    setup:""
                 teardown:""];
}

- (void)testPreparedBatchLayoutReuseChat
{
  [self measurePerfScript:"__perf.layoutChatBatch(24)"
                    setup:"__perf.installChatLayoutHandles()"
                 teardown:"__perf.releaseChatLayoutHandles()"];
}

- (void)testOneShotMeasureBatchChat
{
  [self measurePerfScript:"__perf.measureChatBatch(2)"
                    setup:""
                 teardown:""];
}

- (void)testPrepareInlineRunsLifecycle
{
  [self measurePerfScript:"__perf.prepareInlineRunsLifecycle(4096)"
                    setup:""
                 teardown:""];
}

- (void)testLayoutNextLineVariableWidthSequence
{
  [self measurePerfScript:"__perf.layoutNextLineSequence(6, false)"
                    setup:"__perf.installFlowHandle()"
                 teardown:"__perf.releaseFlowHandle()"];
}

- (void)testLayoutNextLineVariableWidthSequenceAnchoredToCapHeight
{
  [self measurePerfScript:"__perf.layoutNextLineSequence(6, true)"
                    setup:"__perf.installFlowHandle()"
                 teardown:"__perf.releaseFlowHandle()"];
}

- (void)testGlyphIndicesLowChurn
{
  [self measurePerfScript:"__perf.glyphIndicesLowChurn(64)"
                    setup:"__perf.installGlyphIndexFieldLowChurn()"
                 teardown:"__perf.releaseGlyphIndexFieldLowChurn()"];
}

- (void)testGlyphBufferCommitLowChurn
{
  [self measurePerfScript:"__perf.glyphBufferCommitLowChurn(64)"
                    setup:"__perf.installGlyphBufferFieldLowChurn()"
                 teardown:"__perf.releaseGlyphBufferFieldLowChurn()"];
}

- (void)testGlyphStringHighChurn
{
  [self measurePerfScript:"__perf.glyphStringHighChurn(64)"
                    setup:"__perf.installGlyphStringFieldHighChurn()"
                 teardown:"__perf.releaseGlyphStringFieldHighChurn()"];
}

- (void)testGlyphStringLowChurn
{
  [self measurePerfScript:"__perf.glyphStringLowChurn(64)"
                    setup:"__perf.installGlyphStringFieldLowChurn()"
                 teardown:"__perf.releaseGlyphStringFieldLowChurn()"];
}

@end
