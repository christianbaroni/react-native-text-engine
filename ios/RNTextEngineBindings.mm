#import "RNTextEngineBindings.h"
#import "RNTextEngineAttributedTextDisplayView.h"
#import "RNTextEngineTextAttributes.h"
#import "RNTextEngineColorUtils.h"
#import "RNTextEngineTextLayoutMetrics.h"
#import "RNTextEngineTextTransform.h"

#import <CoreText/CoreText.h>
#import <CoreText/SFNTLayoutTypes.h>
#import <React/RCTConvert.h>
#import <React/RCTFont.h>
#import <React/RCTUtils.h>

#import <atomic>
#import <mutex>
#import <memory>
#import <optional>
#import <cstring>
#import <unordered_map>
#import <vector>

#if __has_include(<worklets/WorkletRuntime/WorkletRuntime.h>)
#import <worklets/WorkletRuntime/WorkletRuntime.h>
#import <worklets/Compat/StableApi.h>
#define RNTEXTENGINE_HAS_WORKLETS 1
#else
#define RNTEXTENGINE_HAS_WORKLETS 0
#endif

@interface RNTextEnginePreparedText : NSObject
{
@private
  std::atomic<CTTypesetterRef> _typesetter;
}
@property (nonatomic, strong) NSAttributedString *attributedText;
@property (nonatomic, strong) NSString *text;
@property (nonatomic, assign) CGFloat fallbackLineHeight;
@property (nonatomic, assign) CGFloat uniformCapHeight;
- (CTTypesetterRef)loadTypesetter;
- (void)storeTypesetter:(CTTypesetterRef)typesetter;
@end

@implementation RNTextEnginePreparedText

- (instancetype)init
{
  if ((self = [super init])) {
    _typesetter.store(nullptr, std::memory_order_relaxed);
  }
  return self;
}

- (void)dealloc
{
  CTTypesetterRef typesetter = _typesetter.load(std::memory_order_relaxed);
  if (typesetter != nullptr) {
    CFRelease(typesetter);
  }
}

- (CTTypesetterRef)loadTypesetter
{
  return _typesetter.load(std::memory_order_acquire);
}

- (void)storeTypesetter:(CTTypesetterRef)typesetter
{
  _typesetter.store(typesetter, std::memory_order_release);
}

@end

@interface RNTextEngineGlyphFieldVariant : NSObject
@property (nonatomic, strong) NSDictionary<NSAttributedStringKey, id> *attributes;
@property (nonatomic, strong) UIFont *font;
@end

@implementation RNTextEngineGlyphFieldVariant
@end

@interface RNTextEngineGlyphFieldRun : NSObject
@property (nonatomic, copy) NSString *text;
@property (nonatomic, assign) NSInteger variantIndex;
@property (nonatomic, strong) RNTextEngineGlyphFieldVariant *variant;
@end

@implementation RNTextEngineGlyphFieldRun
@end

@interface RNTextEngineGlyphFieldRow : NSObject
@property (nonatomic, assign) CGFloat baselineOffset;
@property (nonatomic, assign) CTLineRef line;
@property (nonatomic, copy) NSArray<RNTextEngineGlyphFieldRun *> *runs;
@property (nonatomic, assign) CGFloat width;
@end

@implementation RNTextEngineGlyphFieldRow

- (void)dealloc
{
  if (_line != nullptr) {
    CFRelease(_line);
  }
}

@end

@interface RNTextEngineGlyphField : NSObject
@property (nonatomic, assign) NSInteger columns;
@property (nonatomic, copy) NSString *glyphPalette;
@property (nonatomic, strong) NSData *lastGlyphIndexData;
@property (nonatomic, copy) NSString *lastGlyphString;
@property (nonatomic, strong) NSData *lastVariantIndexData;
@property (nonatomic, assign) CGFloat lineHeight;
@property (nonatomic, assign) NSInteger rows;
@property (nonatomic, assign) NSTextAlignment textAlign;
@property (nonatomic, copy) NSArray<RNTextEngineGlyphFieldRow *> *rowsData;
@property (nonatomic, copy) NSArray<RNTextEngineGlyphFieldVariant *> *variants;
@property (nonatomic, strong) NSHashTable<UIView *> *views;
@end

@implementation RNTextEngineGlyphField

- (instancetype)init
{
  if ((self = [super init])) {
    _glyphPalette = @"";
    _lastGlyphIndexData = nil;
    _lastGlyphString = nil;
    _lastVariantIndexData = nil;
    _rowsData = @[];
    _views = [NSHashTable weakObjectsHashTable];
  }

  return self;
}

@end

using namespace facebook::jsi;

namespace rntextengine {

namespace {

using Handle = uint64_t;

struct GlyphFieldMutableBuffer : public MutableBuffer {
  explicit GlyphFieldMutableBuffer(size_t size) : bytes(size) {}

  size_t size() const override {
    return bytes.size();
  }

  uint8_t *data() override {
    return bytes.data();
  }

  std::vector<uint8_t> bytes;
};

struct GlyphFieldBufferSet {
  std::shared_ptr<GlyphFieldMutableBuffer> glyphIndices;
  std::shared_ptr<GlyphFieldMutableBuffer> variantIndices;
};

struct Uint8ArrayView {
  const uint8_t *data = nullptr;
  size_t length = 0;
};

struct TextMeasureStyle {
  bool allowFontScaling = false;
  bool hasColor = false;
  bool hasFontFamily = false;
  bool hasFontSize = false;
  bool hasFontStyle = false;
  bool hasFontWeight = false;
  bool hasLetterSpacing = false;
  bool hasLineHeight = false;
  bool tabularNumbers = false;
  double fontSize = 14;
  double letterSpacing = 0;
  double lineHeight = 0;
  std::string color;
  std::string fontFamily;
  std::string fontStyle;
  std::string fontWeight;
};

struct ResolvedTextStyle {
  NSDictionary<NSAttributedStringKey, id> *attributes = nil;
  CGFloat capHeight = 0;
  CGFloat fallbackLineHeight = 0;
};

struct TextMeasureRunStyle {
  bool hasColor = false;
  bool hasFontFamily = false;
  bool hasFontSize = false;
  bool hasFontStyle = false;
  bool hasFontWeight = false;
  bool hasLetterSpacing = false;
  bool hasLineHeight = false;
  bool hasTabularNumbers = false;
  bool tabularNumbers = false;
  double fontSize = 14;
  double letterSpacing = 0;
  double lineHeight = 0;
  std::string color;
  std::string fontFamily;
  std::string fontStyle;
  std::string fontWeight;
};

struct TextMeasureRun {
  NSInteger end = 0;
  NSInteger start = 0;
  TextMeasureRunStyle style;
};

struct TextLayoutMeasurement {
  CGFloat height = 0;
  CGFloat lastLineWidth = 0;
  NSInteger lineCount = 0;
  CGFloat width = 0;
};

struct LayoutOptions {
  bool anchorToCapHeight = false;
  std::optional<std::string> ellipsizeMode;
  std::optional<int> maxLines;
  double width = 0;
};

struct PreparedLayoutCacheKey {
  uint64_t widthBits = 0;
  NSInteger maxLines = 0;
  NSInteger lineBreakMode = NSLineBreakByWordWrapping;
  bool anchorToCapHeight = false;
};

struct PreparedNextLineCacheKey {
  NSInteger start = 0;
  uint64_t widthBits = 0;
  bool anchorToCapHeight = false;
};

struct PreparedNextLineMeasurement {
  NSInteger end = 0;
  CGFloat bottom = 0;
  CGFloat width = 0;
};

inline bool operator==(const PreparedLayoutCacheKey& lhs, const PreparedLayoutCacheKey& rhs) {
  return lhs.widthBits == rhs.widthBits &&
      lhs.maxLines == rhs.maxLines &&
      lhs.lineBreakMode == rhs.lineBreakMode &&
      lhs.anchorToCapHeight == rhs.anchorToCapHeight;
}

inline bool operator==(const PreparedNextLineCacheKey& lhs, const PreparedNextLineCacheKey& rhs) {
  return lhs.start == rhs.start &&
      lhs.widthBits == rhs.widthBits &&
      lhs.anchorToCapHeight == rhs.anchorToCapHeight;
}

template <typename T>
inline void hashCombine(size_t& seed, const T& value) {
  seed ^= std::hash<T> {}(value) + 0x9e3779b97f4a7c15ULL + (seed << 6) + (seed >> 2);
}

struct PreparedLayoutCacheKeyHash {
  size_t operator()(const PreparedLayoutCacheKey& key) const {
    size_t seed = 0;
    hashCombine(seed, key.widthBits);
    hashCombine(seed, key.maxLines);
    hashCombine(seed, key.lineBreakMode);
    hashCombine(seed, key.anchorToCapHeight);
    return seed;
  }
};

struct PreparedNextLineCacheKeyHash {
  size_t operator()(const PreparedNextLineCacheKey& key) const {
    size_t seed = 0;
    hashCombine(seed, key.start);
    hashCombine(seed, key.widthBits);
    hashCombine(seed, key.anchorToCapHeight);
    return seed;
  }
};

struct PreparedQueryOwner {
  std::mutex mutex;
  std::unordered_map<PreparedLayoutCacheKey, TextLayoutMeasurement, PreparedLayoutCacheKeyHash> layoutsByKey;
  std::unordered_map<PreparedNextLineCacheKey, PreparedNextLineMeasurement, PreparedNextLineCacheKeyHash> nextLinesByKey;
};

uint64_t resolveCGFloatBits(CGFloat value);
PreparedLayoutCacheKey resolvePreparedLayoutCacheKey(const LayoutOptions& options);
PreparedNextLineCacheKey resolvePreparedNextLineCacheKey(NSInteger start, CGFloat width, bool anchorToCapHeight);

struct GlyphFieldVariantConfig {
  std::string color;
  std::string fontStyle;
  std::string fontWeight;
  bool hasFontStyle = false;
  bool hasFontWeight = false;
};

struct GlyphFieldConfig {
  NSInteger columns = 0;
  bool hasFontFamily = false;
  double fontSize = 14;
  std::string glyphPalette;
  double letterSpacing = 0;
  double lineHeight = 0;
  NSInteger rows = 0;
  std::string fontFamily;
  std::string textAlign;
  std::vector<GlyphFieldVariantConfig> variants;
};

static std::mutex preparedMutex;
static NSMutableDictionary<NSNumber *, RNTextEnginePreparedText *> *preparedTexts;
static std::mutex preparedQueryMutex;
static std::unordered_map<Handle, std::shared_ptr<PreparedQueryOwner>> preparedQueryOwners;
static std::atomic<bool> preparedQueryOwnersActive = false;
static Handle nextHandle = 1;

static std::mutex glyphFieldMutex;
static NSMutableDictionary<NSNumber *, RNTextEngineGlyphField *> *glyphFields;
static Handle nextGlyphFieldHandle = 1;
static std::mutex glyphFieldBufferMutex;
static std::unordered_map<Handle, std::shared_ptr<GlyphFieldBufferSet>> glyphFieldBuffers;

NSNumber *toKey(Handle handle) {
  return [NSNumber numberWithUnsignedLongLong:handle];
}

NSString *toNSString(const std::string& value) {
  return [NSString stringWithUTF8String:value.c_str()] ?: @"";
}

std::string fromNSString(NSString *value) {
  return value != nil ? std::string(value.UTF8String ?: "") : std::string{};
}

TextMeasureStyle parseStyle(Runtime& runtime, const Value* value, size_t index, size_t count) {
  TextMeasureStyle style;
  if (index >= count) return style;
  if (value[index].isUndefined() || value[index].isNull()) return style;
  if (!value[index].isObject()) return style;

  Object object = value[index].asObject(runtime);

  auto readBool = [&](const char* name, bool& target) {
    Value field = object.getProperty(runtime, name);
    if (!field.isBool()) return;
    target = field.getBool();
  };

  auto readNumber = [&](const char* name, bool& hasValue, double& target) {
    Value field = object.getProperty(runtime, name);
    if (!field.isNumber()) return;
    hasValue = true;
    target = field.asNumber();
  };

  auto readString = [&](const char* name, bool& hasValue, std::string& target) {
    Value field = object.getProperty(runtime, name);
    if (!field.isString()) return;
    hasValue = true;
    target = field.asString(runtime).utf8(runtime);
  };

  readBool("allowFontScaling", style.allowFontScaling);
  readBool("tabularNumbers", style.tabularNumbers);
  readNumber("fontSize", style.hasFontSize, style.fontSize);
  readNumber("letterSpacing", style.hasLetterSpacing, style.letterSpacing);
  readNumber("lineHeight", style.hasLineHeight, style.lineHeight);
  readString("color", style.hasColor, style.color);
  readString("fontFamily", style.hasFontFamily, style.fontFamily);
  readString("fontStyle", style.hasFontStyle, style.fontStyle);
  readString("fontWeight", style.hasFontWeight, style.fontWeight);

  return style;
}

TextMeasureRunStyle parseRunStyle(Runtime& runtime, const Object& object) {
  TextMeasureRunStyle style;

  auto readBool = [&](const char* name, bool& hasValue, bool& target) {
    Value field = object.getProperty(runtime, name);
    if (!field.isBool()) return;
    hasValue = true;
    target = field.getBool();
  };

  auto readNumber = [&](const char* name, bool& hasValue, double& target) {
    Value field = object.getProperty(runtime, name);
    if (!field.isNumber()) return;
    hasValue = true;
    target = field.asNumber();
  };

  auto readString = [&](const char* name, bool& hasValue, std::string& target) {
    Value field = object.getProperty(runtime, name);
    if (!field.isString()) return;
    hasValue = true;
    target = field.asString(runtime).utf8(runtime);
  };

  readString("color", style.hasColor, style.color);
  readString("fontFamily", style.hasFontFamily, style.fontFamily);
  readNumber("fontSize", style.hasFontSize, style.fontSize);
  readString("fontStyle", style.hasFontStyle, style.fontStyle);
  readString("fontWeight", style.hasFontWeight, style.fontWeight);
  readNumber("letterSpacing", style.hasLetterSpacing, style.letterSpacing);
  readNumber("lineHeight", style.hasLineHeight, style.lineHeight);
  readBool("tabularNumbers", style.hasTabularNumbers, style.tabularNumbers);

  return style;
}

bool hasAnyRunOverride(const TextMeasureRunStyle& style) {
  return style.hasColor || style.hasFontFamily || style.hasFontSize || style.hasFontStyle ||
      style.hasFontWeight || style.hasLetterSpacing || style.hasLineHeight || style.hasTabularNumbers;
}

std::vector<TextMeasureRun> parseRuns(Runtime& runtime, const Value& value, NSInteger textLength) {
  if (value.isUndefined() || value.isNull()) return {};
  if (!value.isObject() || !value.asObject(runtime).isArray(runtime)) {
    throw JSError(runtime, "RNTextEngine: text runs must be an array.");
  }

  Array array = value.asObject(runtime).asArray(runtime);
  std::vector<TextMeasureRun> runs;
  runs.reserve(array.size(runtime));
  NSInteger previousEnd = 0;

  for (size_t index = 0; index < array.size(runtime); index++) {
    Value item = array.getValueAtIndex(runtime, index);
    if (!item.isObject()) {
      throw JSError(runtime, "RNTextEngine: each text run must be an object.");
    }

    Object runObject = item.asObject(runtime);
    Value startValue = runObject.getProperty(runtime, "start");
    Value endValue = runObject.getProperty(runtime, "end");
    if (!startValue.isNumber() || !endValue.isNumber()) {
      throw JSError(runtime, "RNTextEngine: text run start and end must be numbers.");
    }

    NSInteger start = static_cast<NSInteger>(startValue.asNumber());
    NSInteger end = static_cast<NSInteger>(endValue.asNumber());
    if (start < 0 || end > textLength || end <= start) {
      throw JSError(runtime, "RNTextEngine: text runs must stay within the source text and have positive length.");
    }
    if (start < previousEnd) {
      throw JSError(runtime, "RNTextEngine: text runs must be sorted and non-overlapping.");
    }

    Value styleValue = runObject.getProperty(runtime, "style");
    if (!styleValue.isObject()) {
      throw JSError(runtime, "RNTextEngine: each text run style must be an object.");
    }

    TextMeasureRunStyle style = parseRunStyle(runtime, styleValue.asObject(runtime));
    if (!hasAnyRunOverride(style)) {
      throw JSError(runtime, "RNTextEngine: each text run must override at least one inline style field.");
    }

    TextMeasureRun run;
    run.end = end;
    run.start = start;
    run.style = style;
    runs.push_back(run);
    previousEnd = end;
  }

  return runs;
}

LayoutOptions parseLayoutOptions(Runtime& runtime, const Value* value, size_t index, size_t count) {
  if (index >= count || !value[index].isObject()) {
    throw JSError(runtime, "RNTextEngine: layout options must be an object.");
  }

  LayoutOptions options;
  Object object = value[index].asObject(runtime);
  Value width = object.getProperty(runtime, "width");
  if (!width.isNumber()) {
    throw JSError(runtime, "RNTextEngine: layout width must be a number.");
  }
  options.width = width.asNumber();

  Value maxLines = object.getProperty(runtime, "maxLines");
  if (maxLines.isNumber()) options.maxLines = static_cast<int>(maxLines.asNumber());

  Value mode = object.getProperty(runtime, "ellipsizeMode");
  if (mode.isString()) options.ellipsizeMode = mode.asString(runtime).utf8(runtime);

  Value anchorToCapHeight = object.getProperty(runtime, "anchorToCapHeight");
  if (anchorToCapHeight.isBool()) options.anchorToCapHeight = anchorToCapHeight.getBool();

  return options;
}

GlyphFieldConfig parseGlyphFieldConfig(Runtime& runtime, const Value& value) {
  if (!value.isObject()) {
    throw JSError(runtime, "RNTextEngine: glyph field config must be an object.");
  }

  Object object = value.asObject(runtime);
  GlyphFieldConfig config;

  auto requireNumber = [&](const char *name, double& target) {
    if (!object.hasProperty(runtime, name)) {
      throw JSError(runtime, ("RNTextEngine: glyph field config must include `" + std::string(name) + "`.").c_str());
    }
    Value field = object.getProperty(runtime, name);
    if (!field.isNumber()) {
      throw JSError(runtime, ("RNTextEngine: glyph field `" + std::string(name) + "` must be numeric.").c_str());
    }
    target = field.asNumber();
  };

  double columns = 0;
  double rows = 0;
  requireNumber("columns", columns);
  requireNumber("rows", rows);
  requireNumber("fontSize", config.fontSize);
  requireNumber("lineHeight", config.lineHeight);

  config.columns = static_cast<NSInteger>(columns);
  config.rows = static_cast<NSInteger>(rows);
  if (config.columns <= 0 || config.rows <= 0) {
    throw JSError(runtime, "RNTextEngine: glyph field columns and rows must be positive.");
  }
  if (config.fontSize <= 0 || config.lineHeight <= 0) {
    throw JSError(runtime, "RNTextEngine: glyph field fontSize and lineHeight must be positive.");
  }

  if (object.hasProperty(runtime, "fontFamily")) {
    Value fontFamily = object.getProperty(runtime, "fontFamily");
    if (!fontFamily.isString()) {
      throw JSError(runtime, "RNTextEngine: glyph field fontFamily must be a string.");
    }
    config.hasFontFamily = true;
    config.fontFamily = fontFamily.asString(runtime).utf8(runtime);
  }

  if (object.hasProperty(runtime, "glyphPalette")) {
    Value glyphPalette = object.getProperty(runtime, "glyphPalette");
    if (!glyphPalette.isString()) {
      throw JSError(runtime, "RNTextEngine: glyph field glyphPalette must be a string.");
    }
    config.glyphPalette = glyphPalette.asString(runtime).utf8(runtime);
    NSString *resolvedGlyphPalette = toNSString(config.glyphPalette);
    if (resolvedGlyphPalette.length == 0 || resolvedGlyphPalette.length > 256) {
      throw JSError(runtime, "RNTextEngine: glyph field glyphPalette must contain between 1 and 256 UTF-16 code units.");
    }
  }

  if (object.hasProperty(runtime, "letterSpacing")) {
    Value letterSpacing = object.getProperty(runtime, "letterSpacing");
    if (!letterSpacing.isNumber()) {
      throw JSError(runtime, "RNTextEngine: glyph field letterSpacing must be numeric.");
    }
    config.letterSpacing = letterSpacing.asNumber();
  }

  if (object.hasProperty(runtime, "textAlign")) {
    Value textAlign = object.getProperty(runtime, "textAlign");
    if (!textAlign.isString()) {
      throw JSError(runtime, "RNTextEngine: glyph field textAlign must be a string.");
    }
    config.textAlign = textAlign.asString(runtime).utf8(runtime);
  }

  if (!object.hasProperty(runtime, "variants")) {
    throw JSError(runtime, "RNTextEngine: glyph field config must include variants.");
  }

  Value variantsValue = object.getProperty(runtime, "variants");
  if (!variantsValue.isObject() || !variantsValue.asObject(runtime).isArray(runtime)) {
    throw JSError(runtime, "RNTextEngine: glyph field variants must be an array.");
  }

  Array variantsArray = variantsValue.asObject(runtime).asArray(runtime);
  if (variantsArray.size(runtime) == 0 || variantsArray.size(runtime) > 255) {
    throw JSError(runtime, "RNTextEngine: glyph field variants must contain between 1 and 255 entries.");
  }

  config.variants.reserve(variantsArray.size(runtime));
  for (size_t index = 0; index < variantsArray.size(runtime); index++) {
    Value item = variantsArray.getValueAtIndex(runtime, index);
    if (!item.isObject()) {
      throw JSError(runtime, "RNTextEngine: each glyph field variant must be an object.");
    }

    Object variantObject = item.asObject(runtime);
    if (!variantObject.hasProperty(runtime, "color")) {
      throw JSError(runtime, "RNTextEngine: each glyph field variant must include a color.");
    }

    Value colorValue = variantObject.getProperty(runtime, "color");
    if (!colorValue.isString()) {
      throw JSError(runtime, "RNTextEngine: glyph field variant color must be a string.");
    }

    GlyphFieldVariantConfig variant;
    variant.color = colorValue.asString(runtime).utf8(runtime);

    if (variantObject.hasProperty(runtime, "fontStyle")) {
      Value fontStyle = variantObject.getProperty(runtime, "fontStyle");
      if (!fontStyle.isString()) {
        throw JSError(runtime, "RNTextEngine: glyph field variant fontStyle must be a string.");
      }
      variant.hasFontStyle = true;
      variant.fontStyle = fontStyle.asString(runtime).utf8(runtime);
    }

    if (variantObject.hasProperty(runtime, "fontWeight")) {
      Value fontWeight = variantObject.getProperty(runtime, "fontWeight");
      if (!fontWeight.isString()) {
        throw JSError(runtime, "RNTextEngine: glyph field variant fontWeight must be a string.");
      }
      variant.hasFontWeight = true;
      variant.fontWeight = fontWeight.asString(runtime).utf8(runtime);
    }

    config.variants.push_back(std::move(variant));
  }

  return config;
}

Uint8ArrayView parseUint8Array(Runtime& runtime, const Value& value, size_t expectedLength) {
  if (!value.isObject()) {
    throw JSError(runtime, "RNTextEngine: glyph field variantIndices must be a Uint8Array.");
  }

  Object object = value.asObject(runtime);
  if (!object.hasProperty(runtime, "buffer")) {
    throw JSError(runtime, "RNTextEngine: glyph field variantIndices must be a Uint8Array.");
  }

  Value bufferValue = object.getProperty(runtime, "buffer");
  Value byteOffsetValue = object.getProperty(runtime, "byteOffset");
  Value lengthValue = object.getProperty(runtime, "length");
  Value bytesPerElementValue = object.getProperty(runtime, "BYTES_PER_ELEMENT");
  if (!bufferValue.isObject() || !byteOffsetValue.isNumber() || !lengthValue.isNumber() || !bytesPerElementValue.isNumber()) {
    throw JSError(runtime, "RNTextEngine: glyph field variantIndices must be a Uint8Array.");
  }

  if (static_cast<int>(bytesPerElementValue.asNumber()) != 1) {
    throw JSError(runtime, "RNTextEngine: glyph field variantIndices must be a Uint8Array.");
  }

  Object bufferObject = bufferValue.asObject(runtime);
  if (!bufferObject.isArrayBuffer(runtime)) {
    throw JSError(runtime, "RNTextEngine: glyph field variantIndices must be backed by an ArrayBuffer.");
  }

  ArrayBuffer buffer = bufferObject.getArrayBuffer(runtime);
  size_t byteOffset = static_cast<size_t>(byteOffsetValue.asNumber());
  size_t length = static_cast<size_t>(lengthValue.asNumber());
  if (length != expectedLength || byteOffset + length > buffer.size(runtime)) {
    throw JSError(runtime, "RNTextEngine: glyph field variantIndices length must match columns * rows.");
  }

  return {.data = buffer.data(runtime) + byteOffset, .length = length};
}

UIFont *applyTabularNumbers(UIFont *font) {
  NSDictionary *featureSettings = @{
    UIFontFeatureTypeIdentifierKey: @(kNumberSpacingType),
    UIFontFeatureSelectorIdentifierKey: @(kMonospacedNumbersSelector),
  };
  UIFontDescriptor *descriptor =
      [font.fontDescriptor fontDescriptorByAddingAttributes:@{
        UIFontDescriptorFeatureSettingsAttribute: @[ featureSettings ]
      }];
  return [UIFont fontWithDescriptor:descriptor size:font.pointSize];
}

UIFont *resolveFont(const TextMeasureStyle& style) {
  NSString *family = style.hasFontFamily ? toNSString(style.fontFamily) : nil;
  NSNumber *size = style.hasFontSize ? @(style.fontSize) : nil;
  NSString *weight = style.hasFontWeight ? toNSString(style.fontWeight) : nil;
  NSString *fontStyle = style.hasFontStyle ? toNSString(style.fontStyle) : nil;
  CGFloat scaleMultiplier = style.allowFontScaling ? RCTFontSizeMultiplier() : 1;

  UIFont *font =
      [RCTFont updateFont:nil
               withFamily:family
                     size:size
                   weight:weight
                    style:fontStyle
                  variant:nil
          scaleMultiplier:scaleMultiplier];
  if (!font) font = [UIFont systemFontOfSize:size ? size.doubleValue : 14];
  if (style.tabularNumbers) font = applyTabularNumbers(font);
  return font;
}

CGFloat resolveLineHeight(const TextMeasureStyle& style, UIFont *font) {
  if (!style.hasLineHeight) return font.lineHeight;
  CGFloat lineHeight = style.lineHeight;
  if (style.allowFontScaling) lineHeight *= RCTFontSizeMultiplier();
  return lineHeight;
}

UIColor *resolveColorString(const std::string& value) {
  return RNTextEngineResolveColorValue(toNSString(value));
}

ResolvedTextStyle resolveTextStyle(const TextMeasureStyle& style) {
  UIFont *font = resolveFont(style);
  CGFloat lineHeight = resolveLineHeight(style, font);

  NSMutableDictionary<NSAttributedStringKey, id> *attributes =
      [NSMutableDictionary dictionaryWithObject:font forKey:NSFontAttributeName];

  if (style.hasColor) {
    UIColor *color = resolveColorString(style.color);
    if (color != nil) attributes[NSForegroundColorAttributeName] = color;
  }

  if (style.hasLetterSpacing) {
    CGFloat letterSpacing = style.letterSpacing;
    if (style.allowFontScaling) letterSpacing *= RCTFontSizeMultiplier();
    attributes[NSKernAttributeName] = @(letterSpacing);
  }

  if (style.hasLineHeight) {
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.minimumLineHeight = lineHeight;
    paragraphStyle.maximumLineHeight = lineHeight;
    attributes[NSParagraphStyleAttributeName] = paragraphStyle;
  }

  ResolvedTextStyle resolvedStyle;
  resolvedStyle.attributes = [attributes copy];
  resolvedStyle.capHeight = font.capHeight;
  resolvedStyle.fallbackLineHeight = lineHeight;
  return resolvedStyle;
}

NSAttributedString *buildAttributedText(NSString *text, const ResolvedTextStyle& style) {
  return [[NSAttributedString alloc] initWithString:text attributes:style.attributes];
}

TextMeasureStyle mergeRunStyle(const TextMeasureStyle& baseStyle, const TextMeasureRunStyle& runStyle) {
  TextMeasureStyle merged = baseStyle;

  if (runStyle.hasColor) {
    merged.hasColor = true;
    merged.color = runStyle.color;
  }
  if (runStyle.hasFontFamily) {
    merged.hasFontFamily = true;
    merged.fontFamily = runStyle.fontFamily;
  }
  if (runStyle.hasFontSize) {
    merged.hasFontSize = true;
    merged.fontSize = runStyle.fontSize;
  }
  if (runStyle.hasFontStyle) {
    merged.hasFontStyle = true;
    merged.fontStyle = runStyle.fontStyle;
  }
  if (runStyle.hasFontWeight) {
    merged.hasFontWeight = true;
    merged.fontWeight = runStyle.fontWeight;
  }
  if (runStyle.hasLetterSpacing) {
    merged.hasLetterSpacing = true;
    merged.letterSpacing = runStyle.letterSpacing;
  }
  if (runStyle.hasLineHeight) {
    merged.hasLineHeight = true;
    merged.lineHeight = runStyle.lineHeight;
  }
  if (runStyle.hasTabularNumbers) {
    merged.tabularNumbers = runStyle.tabularNumbers;
  }

  return merged;
}

CGFloat measureAttributedWidth(NSAttributedString *attributedText);

NSTextAlignment resolveGlyphFieldTextAlignment(const std::string& value) {
  if (value == "right") return NSTextAlignmentRight;
  if (value == "center") return NSTextAlignmentCenter;
  return NSTextAlignmentLeft;
}

RNTextEngineGlyphFieldVariant *buildGlyphFieldVariant(const GlyphFieldConfig& config, const GlyphFieldVariantConfig& variantConfig) {
  TextMeasureStyle style;
  style.hasColor = true;
  style.color = variantConfig.color;
  style.hasFontSize = true;
  style.fontSize = config.fontSize;
  style.hasLineHeight = true;
  style.lineHeight = config.lineHeight;
  style.hasLetterSpacing = config.letterSpacing != 0;
  style.letterSpacing = config.letterSpacing;

  if (config.hasFontFamily) {
    style.hasFontFamily = true;
    style.fontFamily = config.fontFamily;
  }
  if (variantConfig.hasFontStyle) {
    style.hasFontStyle = true;
    style.fontStyle = variantConfig.fontStyle;
  }
  if (variantConfig.hasFontWeight) {
    style.hasFontWeight = true;
    style.fontWeight = variantConfig.fontWeight;
  }

  ResolvedTextStyle resolvedStyle = resolveTextStyle(style);
  RNTextEngineGlyphFieldVariant *variant = [[RNTextEngineGlyphFieldVariant alloc] init];
  variant.attributes = resolvedStyle.attributes;
  variant.font = resolvedStyle.attributes[NSFontAttributeName];
  return variant;
}

NSString *glyphStringForCharacter(unichar character);

NSString *glyphStringForCharacter(unichar character) {
  static NSMutableDictionary<NSNumber *, NSString *> *cache;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    cache = [[NSMutableDictionary alloc] init];
  });

  NSNumber *key = @(character);
  NSString *glyph = cache[key];
  if (glyph != nil) return glyph;

  unichar value = character;
  glyph = [[NSString alloc] initWithCharacters:&value length:1];
  cache[key] = glyph;
  return glyph;
}

RNTextEngineGlyphFieldRun *buildGlyphFieldRun(
    NSMutableString *text,
    RNTextEngineGlyphFieldVariant *variant,
    NSInteger variantIndex) {
  RNTextEngineGlyphFieldRun *run = [[RNTextEngineGlyphFieldRun alloc] init];
  run.text = [text copy];
  run.variant = variant;
  run.variantIndex = variantIndex;
  return run;
}

bool glyphFieldRowMatchesIndices(
    NSInteger row,
    NSInteger columns,
    const uint8_t *glyphIndices,
    const uint8_t *variantIndices,
    const uint8_t *previousGlyphIndices,
    const uint8_t *previousVariantIndices) {
  if (previousGlyphIndices == nullptr || previousVariantIndices == nullptr) return false;

  size_t rowOffset = static_cast<size_t>(row * columns);
  size_t rowSize = static_cast<size_t>(columns);
  return std::memcmp(glyphIndices + rowOffset, previousGlyphIndices + rowOffset, rowSize) == 0 &&
      std::memcmp(variantIndices + rowOffset, previousVariantIndices + rowOffset, rowSize) == 0;
}

bool glyphFieldRowMatchesString(
    NSInteger row,
    NSInteger columns,
    NSString *glyphs,
    const uint8_t *variantIndices,
    NSString *previousGlyphs,
    const uint8_t *previousVariantIndices) {
  if (previousGlyphs == nil || previousVariantIndices == nullptr) return false;

  NSUInteger rowStart = static_cast<NSUInteger>(row * columns);
  for (NSInteger column = 0; column < columns; column += 1) {
    NSUInteger cellIndex = rowStart + static_cast<NSUInteger>(column);
    if ([glyphs characterAtIndex:cellIndex] != [previousGlyphs characterAtIndex:cellIndex]) {
      return false;
    }
  }

  size_t rowOffset = static_cast<size_t>(row * columns);
  size_t rowSize = static_cast<size_t>(columns);
  return std::memcmp(variantIndices + rowOffset, previousVariantIndices + rowOffset, rowSize) == 0;
}

RNTextEngineGlyphFieldRow *buildGlyphFieldRowFromIndices(
    RNTextEngineGlyphField *field,
    NSString *glyphPalette,
    const uint8_t *glyphIndices,
    const uint8_t *variantIndices,
    NSInteger row) {
  NSMutableArray<RNTextEngineGlyphFieldRun *> *runs = [NSMutableArray array];
  NSMutableString *runText = [NSMutableString stringWithCapacity:field.columns];
  RNTextEngineGlyphFieldVariant *runVariant = nil;
  NSInteger runVariantIndex = -1;
  NSUInteger rowStart = static_cast<NSUInteger>(row * field.columns);

  auto flushRun = [&] {
    if (runVariant == nil || runText.length == 0) return;
    [runs addObject:buildGlyphFieldRun(runText, runVariant, runVariantIndex)];
    runText = [NSMutableString stringWithCapacity:field.columns];
    runVariant = nil;
    runVariantIndex = -1;
  };

  for (NSInteger column = 0; column < field.columns; column += 1) {
    NSUInteger cellIndex = rowStart + static_cast<NSUInteger>(column);
    NSInteger glyphIndex = glyphIndices[cellIndex];
    NSInteger variantIndex = variantIndices[cellIndex];
    RNTextEngineGlyphFieldVariant *variant = field.variants[variantIndex];

    if (runVariantIndex != variantIndex) {
      flushRun();
      runVariant = variant;
      runVariantIndex = variantIndex;
    }

    [runText appendString:glyphStringForCharacter([glyphPalette characterAtIndex:glyphIndex])];
  }

  flushRun();

  NSMutableAttributedString *attributedRow = [[NSMutableAttributedString alloc] init];
  for (RNTextEngineGlyphFieldRun *run in runs) {
    NSAttributedString *attributedRun =
        [[NSAttributedString alloc] initWithString:run.text attributes:run.variant.attributes];
    [attributedRow appendAttributedString:attributedRun];
  }

  CGFloat ascent = 0;
  CGFloat descent = 0;
  CGFloat leading = 0;
  CTLineRef line = CTLineCreateWithAttributedString((CFAttributedStringRef)attributedRow);
  CGFloat rowWidth = static_cast<CGFloat>(CTLineGetTypographicBounds(line, &ascent, &descent, &leading));
  CGFloat typographicHeight = ascent + descent;

  RNTextEngineGlyphFieldRow *rowData = [[RNTextEngineGlyphFieldRow alloc] init];
  rowData.baselineOffset = MAX(0, (field.lineHeight - typographicHeight) * 0.5) + ascent;
  rowData.line = line;
  rowData.runs = runs;
  rowData.width = rowWidth;
  return rowData;
}

RNTextEngineGlyphFieldRow *buildGlyphFieldRowFromString(
    RNTextEngineGlyphField *field,
    NSString *glyphs,
    const uint8_t *variantIndices,
    NSInteger row) {
  NSMutableArray<RNTextEngineGlyphFieldRun *> *runs = [NSMutableArray array];
  NSMutableString *runText = [NSMutableString stringWithCapacity:field.columns];
  RNTextEngineGlyphFieldVariant *runVariant = nil;
  NSInteger runVariantIndex = -1;
  NSUInteger rowStart = static_cast<NSUInteger>(row * field.columns);

  auto flushRun = [&] {
    if (runVariant == nil || runText.length == 0) return;
    [runs addObject:buildGlyphFieldRun(runText, runVariant, runVariantIndex)];
    runText = [NSMutableString stringWithCapacity:field.columns];
    runVariant = nil;
    runVariantIndex = -1;
  };

  for (NSInteger column = 0; column < field.columns; column += 1) {
    NSUInteger cellIndex = rowStart + static_cast<NSUInteger>(column);
    unichar glyphCharacter = [glyphs characterAtIndex:cellIndex];
    NSInteger variantIndex = variantIndices[cellIndex];
    RNTextEngineGlyphFieldVariant *variant = field.variants[variantIndex];

    if (runVariantIndex != variantIndex) {
      flushRun();
      runVariant = variant;
      runVariantIndex = variantIndex;
    }

    [runText appendString:glyphStringForCharacter(glyphCharacter)];
  }

  flushRun();

  NSMutableAttributedString *attributedRow = [[NSMutableAttributedString alloc] init];
  for (RNTextEngineGlyphFieldRun *run in runs) {
    NSAttributedString *attributedRun =
        [[NSAttributedString alloc] initWithString:run.text attributes:run.variant.attributes];
    [attributedRow appendAttributedString:attributedRun];
  }

  CGFloat ascent = 0;
  CGFloat descent = 0;
  CGFloat leading = 0;
  CTLineRef line = CTLineCreateWithAttributedString((CFAttributedStringRef)attributedRow);
  CGFloat rowWidth = static_cast<CGFloat>(CTLineGetTypographicBounds(line, &ascent, &descent, &leading));
  CGFloat typographicHeight = ascent + descent;

  RNTextEngineGlyphFieldRow *rowData = [[RNTextEngineGlyphFieldRow alloc] init];
  rowData.baselineOffset = MAX(0, (field.lineHeight - typographicHeight) * 0.5) + ascent;
  rowData.line = line;
  rowData.runs = runs;
  rowData.width = rowWidth;
  return rowData;
}

NSArray<RNTextEngineGlyphFieldRow *> *buildGlyphFieldRows(
    RNTextEngineGlyphField *field,
    NSString *glyphs,
    const uint8_t *variantIndices,
    NSArray<RNTextEngineGlyphFieldRow *> *previousRows,
    NSString *previousGlyphs,
    const uint8_t *previousVariantIndices) {
  NSMutableArray<RNTextEngineGlyphFieldRow *> *rows = [NSMutableArray arrayWithCapacity:field.rows];

  for (NSInteger row = 0; row < field.rows; row += 1) {
    bool shouldReusePreviousRow =
        row < static_cast<NSInteger>(previousRows.count) &&
        glyphFieldRowMatchesString(
            row,
            field.columns,
            glyphs,
            variantIndices,
            previousGlyphs,
            previousVariantIndices);

    if (shouldReusePreviousRow) {
      [rows addObject:previousRows[row]];
      continue;
    }

    [rows addObject:buildGlyphFieldRowFromString(field, glyphs, variantIndices, row)];
  }

  return rows;
}

NSArray<RNTextEngineGlyphFieldRow *> *buildGlyphFieldRows(
    RNTextEngineGlyphField *field,
    NSString *glyphs,
    const Uint8ArrayView& variantIndices) {
  const uint8_t *previousVariantIndices = static_cast<const uint8_t *>(field.lastVariantIndexData.bytes);
  return buildGlyphFieldRows(
      field,
      glyphs,
      variantIndices.data,
      field.rowsData,
      field.lastGlyphString,
      previousVariantIndices);
}

NSArray<RNTextEngineGlyphFieldRow *> *buildGlyphFieldRowsFromIndices(
    RNTextEngineGlyphField *field,
    const uint8_t *glyphIndices,
    const uint8_t *variantIndices,
    NSArray<RNTextEngineGlyphFieldRow *> *previousRows,
    const uint8_t *previousGlyphIndices,
    const uint8_t *previousVariantIndices) {
  NSMutableArray<RNTextEngineGlyphFieldRow *> *rows = [NSMutableArray arrayWithCapacity:field.rows];
  NSString *glyphPalette = field.glyphPalette;

  for (NSInteger row = 0; row < field.rows; row += 1) {
    bool shouldReusePreviousRow =
        row < static_cast<NSInteger>(previousRows.count) &&
        glyphFieldRowMatchesIndices(
            row,
            field.columns,
            glyphIndices,
            variantIndices,
            previousGlyphIndices,
            previousVariantIndices);

    if (shouldReusePreviousRow) {
      [rows addObject:previousRows[row]];
      continue;
    }

    [rows addObject:buildGlyphFieldRowFromIndices(field, glyphPalette, glyphIndices, variantIndices, row)];
  }

  return rows;
}

NSArray<RNTextEngineGlyphFieldRow *> *buildGlyphFieldRowsFromIndices(
    RNTextEngineGlyphField *field,
    const Uint8ArrayView& glyphIndices,
    const Uint8ArrayView& variantIndices) {
  const uint8_t *previousGlyphIndices = static_cast<const uint8_t *>(field.lastGlyphIndexData.bytes);
  const uint8_t *previousVariantIndices = static_cast<const uint8_t *>(field.lastVariantIndexData.bytes);
  return buildGlyphFieldRowsFromIndices(
      field,
      glyphIndices.data,
      variantIndices.data,
      field.rowsData,
      previousGlyphIndices,
      previousVariantIndices);
}

Handle storeGlyphField(const GlyphFieldConfig& config) {
  RNTextEngineGlyphField *field = [[RNTextEngineGlyphField alloc] init];
  field.columns = config.columns;
  field.glyphPalette = toNSString(config.glyphPalette);
  field.rows = config.rows;
  field.lineHeight = config.lineHeight;
  field.textAlign = resolveGlyphFieldTextAlignment(config.textAlign);

  NSMutableArray<RNTextEngineGlyphFieldVariant *> *variants = [NSMutableArray arrayWithCapacity:config.variants.size()];
  for (const GlyphFieldVariantConfig& variantConfig : config.variants) {
    [variants addObject:buildGlyphFieldVariant(config, variantConfig)];
  }
  field.variants = variants;

  std::lock_guard<std::mutex> lock(glyphFieldMutex);
  if (glyphFields == nil) glyphFields = [[NSMutableDictionary alloc] init];
  Handle handle = nextGlyphFieldHandle++;
  glyphFields[toKey(handle)] = field;
  return handle;
}

RNTextEngineGlyphField *getGlyphField(Runtime& runtime, Handle handle) {
  std::lock_guard<std::mutex> lock(glyphFieldMutex);
  RNTextEngineGlyphField *field = glyphFields[toKey(handle)];
  if (field == nil) {
    throw JSError(runtime, "RNTextEngine: attempted to use an invalid glyph field handle.");
  }
  return field;
}

RNTextEngineGlyphField *getGlyphFieldIfPresent(Handle handle) {
  std::lock_guard<std::mutex> lock(glyphFieldMutex);
  return glyphFields[toKey(handle)];
}

std::shared_ptr<GlyphFieldBufferSet> getOrCreateGlyphFieldBuffers(Handle handle, size_t cellCount) {
  std::lock_guard<std::mutex> lock(glyphFieldBufferMutex);
  auto iterator = glyphFieldBuffers.find(handle);
  if (iterator != glyphFieldBuffers.end()) {
    return iterator->second;
  }

  auto buffers = std::make_shared<GlyphFieldBufferSet>();
  buffers->glyphIndices = std::make_shared<GlyphFieldMutableBuffer>(cellCount);
  buffers->variantIndices = std::make_shared<GlyphFieldMutableBuffer>(cellCount);
  glyphFieldBuffers.emplace(handle, buffers);
  return buffers;
}

std::shared_ptr<GlyphFieldBufferSet> getGlyphFieldBuffers(Runtime& runtime, Handle handle) {
  std::lock_guard<std::mutex> lock(glyphFieldBufferMutex);
  auto iterator = glyphFieldBuffers.find(handle);
  if (iterator == glyphFieldBuffers.end()) {
    throw JSError(runtime, "RNTextEngine: attempted to use glyph field buffers before creating them.");
  }
  return iterator->second;
}

bool glyphFieldRunEquals(RNTextEngineGlyphFieldRun *left, RNTextEngineGlyphFieldRun *right) {
  if (left == right) return true;
  if (left == nil || right == nil) return false;
  return left.variantIndex == right.variantIndex && [left.text isEqualToString:right.text];
}

bool glyphFieldRowEquals(RNTextEngineGlyphFieldRow *left, RNTextEngineGlyphFieldRow *right) {
  if (left == right) return true;
  if (left == nil || right == nil) return false;
  if (left.runs.count != right.runs.count) return false;

  for (NSUInteger index = 0; index < left.runs.count; index += 1) {
    if (!glyphFieldRunEquals(left.runs[index], right.runs[index])) return false;
  }

  return true;
}

std::vector<NSRange> buildGlyphFieldDirtyRanges(
    NSArray<RNTextEngineGlyphFieldRow *> *previousRows,
    NSArray<RNTextEngineGlyphFieldRow *> *nextRows,
    NSInteger rowCount) {
  std::vector<NSRange> dirtyRanges;
  NSInteger rangeStart = NSNotFound;

  for (NSInteger row = 0; row < rowCount; row += 1) {
    RNTextEngineGlyphFieldRow *previousRow = row < static_cast<NSInteger>(previousRows.count) ? previousRows[row] : nil;
    RNTextEngineGlyphFieldRow *nextRow = row < static_cast<NSInteger>(nextRows.count) ? nextRows[row] : nil;
    bool didChange = !glyphFieldRowEquals(previousRow, nextRow);

    if (didChange && rangeStart == NSNotFound) {
      rangeStart = row;
      continue;
    }

    if (!didChange && rangeStart != NSNotFound) {
      dirtyRanges.push_back(NSMakeRange(rangeStart, row - rangeStart));
      rangeStart = NSNotFound;
    }
  }

  if (rangeStart != NSNotFound) {
    dirtyRanges.push_back(NSMakeRange(rangeStart, rowCount - rangeStart));
  }

  return dirtyRanges;
}

void invalidateGlyphFieldViews(RNTextEngineGlyphField *field, const std::vector<NSRange>& dirtyRanges) {
  if (dirtyRanges.empty()) return;

  NSArray<UIView *> *views = field.views.allObjects;
  if (views.count == 0) return;
  std::vector<NSRange> dirtyRangesCopy = dirtyRanges;
  NSInteger rowCount = field.rows;
  CGFloat lineHeight = field.lineHeight;

  dispatch_block_t invalidate = ^{
    bool shouldRedrawWholeView =
        dirtyRangesCopy.size() == 1 && dirtyRangesCopy.front().location == 0 && dirtyRangesCopy.front().length >= rowCount;

    for (UIView *view in views) {
      if (shouldRedrawWholeView || CGRectIsEmpty(view.bounds)) {
        [view setNeedsDisplay];
        continue;
      }

      CGFloat topInset = MAX(0, (CGRectGetHeight(view.bounds) - rowCount * lineHeight) * 0.5);
      for (const NSRange& range : dirtyRangesCopy) {
        CGFloat y = topInset + range.location * lineHeight;
        CGFloat height = range.length * lineHeight;
        CGRect dirtyRect = CGRectIntegral(CGRectMake(0, y, CGRectGetWidth(view.bounds), height));
        [view setNeedsDisplayInRect:dirtyRect];
      }
    }
  };

  if ([NSThread isMainThread]) {
    invalidate();
  } else {
    dispatch_async(dispatch_get_main_queue(), invalidate);
  }
}

void storeGlyphFieldStringSnapshot(
    RNTextEngineGlyphField *field,
    NSString *glyphs,
    const uint8_t *variantIndices,
    size_t cellCount) {
  field.rowsData = @[];
  field.lastGlyphString = glyphs;
  field.lastGlyphIndexData = nil;
  field.lastVariantIndexData = [NSData dataWithBytes:variantIndices length:cellCount];
}

void storeGlyphFieldIndexSnapshot(
    RNTextEngineGlyphField *field,
    const uint8_t *glyphIndices,
    const uint8_t *variantIndices,
    size_t cellCount) {
  field.rowsData = @[];
  field.lastGlyphString = nil;
  field.lastGlyphIndexData = [NSData dataWithBytes:glyphIndices length:cellCount];
  field.lastVariantIndexData = [NSData dataWithBytes:variantIndices length:cellCount];
}

Handle createGlyphField(const GlyphFieldConfig& config) {
  return storeGlyphField(config);
}

void updateGlyphField(Runtime& runtime, Handle handle, const std::string& glyphsValue, const Uint8ArrayView& variantIndices) {
  RNTextEngineGlyphField *field = getGlyphField(runtime, handle);
  size_t cellCount = static_cast<size_t>(field.columns * field.rows);
  NSString *glyphs = toNSString(glyphsValue);
  if (glyphs.length != static_cast<NSInteger>(cellCount)) {
    throw JSError(runtime, "RNTextEngine: glyph field glyphs length must match columns * rows.");
  }
  if (variantIndices.length != cellCount) {
    throw JSError(runtime, "RNTextEngine: glyph field variantIndices length must match columns * rows.");
  }

  for (size_t index = 0; index < cellCount; index += 1) {
    if (variantIndices.data[index] >= field.variants.count) {
      throw JSError(runtime, "RNTextEngine: glyph field variant index exceeded the configured variant count.");
    }
  }

  if (field.views.count == 0) {
    storeGlyphFieldStringSnapshot(field, glyphs, variantIndices.data, cellCount);
    return;
  }

  NSArray<RNTextEngineGlyphFieldRow *> *nextRows = buildGlyphFieldRows(field, glyphs, variantIndices);
  NSArray<RNTextEngineGlyphFieldRow *> *previousRows = field.rowsData;
  std::vector<NSRange> dirtyRanges = buildGlyphFieldDirtyRanges(previousRows, nextRows, field.rows);
  field.rowsData = nextRows;
  field.lastGlyphString = glyphs;
  field.lastGlyphIndexData = nil;
  field.lastVariantIndexData = [NSData dataWithBytes:variantIndices.data length:cellCount];
  invalidateGlyphFieldViews(field, dirtyRanges);
}

void updateGlyphFieldIndices(
    Runtime& runtime,
    Handle handle,
    const Uint8ArrayView& glyphIndices,
    const Uint8ArrayView& variantIndices) {
  RNTextEngineGlyphField *field = getGlyphField(runtime, handle);
  size_t cellCount = static_cast<size_t>(field.columns * field.rows);
  if (field.glyphPalette.length == 0) {
    throw JSError(runtime, "RNTextEngine: updateGlyphFieldIndices() requires glyphPalette on the glyph field config.");
  }
  if (glyphIndices.length != cellCount) {
    throw JSError(runtime, "RNTextEngine: glyph field glyphIndices length must match columns * rows.");
  }
  if (variantIndices.length != cellCount) {
    throw JSError(runtime, "RNTextEngine: glyph field variantIndices length must match columns * rows.");
  }

  for (size_t index = 0; index < cellCount; index += 1) {
    if (glyphIndices.data[index] >= field.glyphPalette.length) {
      throw JSError(runtime, "RNTextEngine: glyph field glyph index exceeded the configured glyphPalette length.");
    }
    if (variantIndices.data[index] >= field.variants.count) {
      throw JSError(runtime, "RNTextEngine: glyph field variant index exceeded the configured variant count.");
    }
  }

  if (field.views.count == 0) {
    storeGlyphFieldIndexSnapshot(field, glyphIndices.data, variantIndices.data, cellCount);
    return;
  }

  const uint8_t *previousGlyphIndices = static_cast<const uint8_t *>(field.lastGlyphIndexData.bytes);
  const uint8_t *previousVariantIndices = static_cast<const uint8_t *>(field.lastVariantIndexData.bytes);
  NSArray<RNTextEngineGlyphFieldRow *> *nextRows = buildGlyphFieldRowsFromIndices(
      field,
      glyphIndices.data,
      variantIndices.data,
      field.rowsData,
      previousGlyphIndices,
      previousVariantIndices);
  NSArray<RNTextEngineGlyphFieldRow *> *previousRows = field.rowsData;
  std::vector<NSRange> dirtyRanges = buildGlyphFieldDirtyRanges(previousRows, nextRows, field.rows);
  field.rowsData = nextRows;
  field.lastGlyphString = nil;
  field.lastGlyphIndexData = [NSData dataWithBytes:glyphIndices.data length:cellCount];
  field.lastVariantIndexData = [NSData dataWithBytes:variantIndices.data length:cellCount];
  invalidateGlyphFieldViews(field, dirtyRanges);
}

void commitGlyphFieldBuffers(Runtime& runtime, Handle handle) {
  RNTextEngineGlyphField *field = getGlyphField(runtime, handle);
  size_t cellCount = static_cast<size_t>(field.columns * field.rows);
  if (field.glyphPalette.length == 0) {
    throw JSError(runtime, "RNTextEngine: commitGlyphFieldBuffers() requires glyphPalette on the glyph field config.");
  }

  std::shared_ptr<GlyphFieldBufferSet> buffers = getGlyphFieldBuffers(runtime, handle);
  const uint8_t *glyphIndices = buffers->glyphIndices->data();
  const uint8_t *variantIndices = buffers->variantIndices->data();

  for (size_t index = 0; index < cellCount; index += 1) {
    if (glyphIndices[index] >= field.glyphPalette.length) {
      throw JSError(runtime, "RNTextEngine: glyph field glyph index exceeded the configured glyphPalette length.");
    }
    if (variantIndices[index] >= field.variants.count) {
      throw JSError(runtime, "RNTextEngine: glyph field variant index exceeded the configured variant count.");
    }
  }

  if (field.views.count == 0) {
    storeGlyphFieldIndexSnapshot(field, glyphIndices, variantIndices, cellCount);
    return;
  }

  const uint8_t *previousGlyphIndices = static_cast<const uint8_t *>(field.lastGlyphIndexData.bytes);
  const uint8_t *previousVariantIndices = static_cast<const uint8_t *>(field.lastVariantIndexData.bytes);
  NSArray<RNTextEngineGlyphFieldRow *> *nextRows = buildGlyphFieldRowsFromIndices(
      field,
      glyphIndices,
      variantIndices,
      field.rowsData,
      previousGlyphIndices,
      previousVariantIndices);
  NSArray<RNTextEngineGlyphFieldRow *> *previousRows = field.rowsData;
  std::vector<NSRange> dirtyRanges = buildGlyphFieldDirtyRanges(previousRows, nextRows, field.rows);
  field.rowsData = nextRows;
  field.lastGlyphString = nil;
  field.lastGlyphIndexData = [NSData dataWithBytes:glyphIndices length:cellCount];
  field.lastVariantIndexData = [NSData dataWithBytes:variantIndices length:cellCount];
  invalidateGlyphFieldViews(field, dirtyRanges);
}

void releaseGlyphFieldHandle(Handle handle) {
  {
    std::lock_guard<std::mutex> lock(glyphFieldMutex);
    [glyphFields removeObjectForKey:toKey(handle)];
  }
  {
    std::lock_guard<std::mutex> lock(glyphFieldBufferMutex);
    glyphFieldBuffers.erase(handle);
  }
}

CGFloat glyphFieldRowOriginX(RNTextEngineGlyphField *field, CGRect bounds, CGFloat rowWidth) {
  if (field.textAlign == NSTextAlignmentRight) return CGRectGetWidth(bounds) - rowWidth;
  if (field.textAlign == NSTextAlignmentCenter) return (CGRectGetWidth(bounds) - rowWidth) * 0.5;
  return 0;
}

NSArray<RNTextEngineGlyphFieldRow *> *resolveGlyphFieldRows(RNTextEngineGlyphField *field) {
  if (field.rowsData.count > 0) return field.rowsData;

  @synchronized(field) {
    if (field.rowsData.count > 0) return field.rowsData;

    size_t cellCount = static_cast<size_t>(field.columns * field.rows);
    NSData *variantData = field.lastVariantIndexData;
    if (variantData.length != cellCount) return field.rowsData;

    const uint8_t *variantIndices = static_cast<const uint8_t *>(variantData.bytes);
    if (field.lastGlyphString != nil) {
      field.rowsData = buildGlyphFieldRows(field, field.lastGlyphString, variantIndices, @[], nil, nullptr);
      return field.rowsData;
    }

    NSData *glyphData = field.lastGlyphIndexData;
    if (glyphData.length != cellCount || field.glyphPalette.length == 0) return field.rowsData;

    field.rowsData = buildGlyphFieldRowsFromIndices(
        field,
        static_cast<const uint8_t *>(glyphData.bytes),
        variantIndices,
        @[],
        nullptr,
        nullptr);
    return field.rowsData;
  }
}

NSInteger resolveVisibleEnd(NSString *text, NSRange range) {
  NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
  NSInteger end = NSMaxRange(range);
  while (end > range.location && [whitespace characterIsMember:[text characterAtIndex:end - 1]]) {
    end -= 1;
  }
  return end;
}

struct CoreTextLineContext {
  NSUInteger end;
  NSUInteger contentEnd;
  CGFloat lineHeight;
};

CoreTextLineContext resolveCoreTextLineContext(NSAttributedString *text, NSUInteger start) {
  NSRange range = NSMakeRange(start, 0);
  CoreTextLineContext context;
  [text.string getLineStart:nil end:&context.end contentsEnd:&context.contentEnd forRange:range];
  NSUInteger paragraphStart = 0;
  [text.string getParagraphStart:&paragraphStart end:nil contentsEnd:nil forRange:range];
  NSParagraphStyle *style = [text attribute:NSParagraphStyleAttributeName atIndex:paragraphStart effectiveRange:nil];
  context.lineHeight = MAX(style.maximumLineHeight, style.minimumLineHeight);
  return context;
}

struct CoreTextLineMetrics {
  CGFloat width;
  CGFloat height;
  CGFloat descent;
};

CoreTextLineMetrics resolveCoreTextLineMetrics(
    CTLineRef line,
    NSRange range,
    const CoreTextLineContext &context,
    CGFloat fallbackLineHeight,
    bool anchorToCapHeight) {
  CGFloat width = CTLineGetTypographicBounds(line, nullptr, nullptr, nullptr);
  width = MAX(0, width - CTLineGetTrailingWhitespaceWidth(line));
  if (context.lineHeight > 0 && !anchorToCapHeight) return {width, context.lineHeight, 0};

  // A separator contributes metrics only when it occupies an otherwise empty line.
  NSUInteger metricsEnd = context.contentEnd > range.location
      ? MIN(context.contentEnd, NSMaxRange(range)) : NSMaxRange(range);
  CGFloat ascent = 0;
  CGFloat descent = 0;
  CGFloat leading = 0;
  CFArrayRef runs = CTLineGetGlyphRuns(line);
  for (CFIndex index = 0; index < CFArrayGetCount(runs); ++index) {
    CTRunRef run = static_cast<CTRunRef>(CFArrayGetValueAtIndex(runs, index));
    if (CTRunGetStringRange(run).location >= metricsEnd) continue;
    NSDictionary *attributes = (__bridge NSDictionary *)CTRunGetAttributes(run);
    CTFontRef font = (__bridge CTFontRef)attributes[(id)kCTFontAttributeName];
    ascent = MAX(ascent, CTFontGetAscent(font));
    descent = MAX(descent, CTFontGetDescent(font));
    leading = MAX(leading, CTFontGetLeading(font));
  }
  CGFloat height = context.lineHeight > 0 ? context.lineHeight : ascent + descent + leading;
  return {width, height > 0 ? height : fallbackLineHeight, descent};
}

CGFloat resolveVisibleLineWidth(
    NSLayoutManager *layoutManager,
    NSRange glyphRange,
    NSRange charRange,
    NSInteger visibleEnd,
    CGRect usedRect) {
  if (visibleEnd >= NSMaxRange(charRange)) {
    return CGRectGetWidth(usedRect);
  }
  if (visibleEnd <= charRange.location) {
    return 0;
  }

  NSRange visibleGlyphRange = [layoutManager glyphRangeForCharacterRange:NSMakeRange(charRange.location, visibleEnd - charRange.location)
                                                   actualCharacterRange:nil];
  NSUInteger trailingGlyphIndex = NSMaxRange(visibleGlyphRange);
  if (trailingGlyphIndex <= glyphRange.location || trailingGlyphIndex > NSMaxRange(glyphRange)) {
    return 0;
  }
  if (trailingGlyphIndex == NSMaxRange(glyphRange)) {
    return CGRectGetWidth(usedRect);
  }

  CGFloat leadingOverhang = MIN(0, CGRectGetMinX(usedRect));
  CGPoint trailingGlyphLocation = [layoutManager locationForGlyphAtIndex:trailingGlyphIndex];
  return MAX(0, trailingGlyphLocation.x - leadingOverhang);
}

NSRange resolveNextLineCharacterRange(CTTypesetterRef typesetter, NSInteger start, CGFloat width, NSUInteger lineEnd) {
  CGFloat constrainedWidth = MAX(width, 0);
  CFIndex count = CTTypesetterSuggestLineBreak(typesetter, start, constrainedWidth);
  if (count == 0 && start < lineEnd) {
    count = CTTypesetterSuggestClusterBreak(typesetter, start, constrainedWidth);
  }
  if (count == 0 && start < lineEnd) {
    count = 1;
  }

  NSInteger clampedCount = MIN(static_cast<NSInteger>(count), static_cast<NSInteger>(lineEnd) - start);
  return NSMakeRange(start, MAX(0, clampedCount));
}

CTTypesetterRef resolvePreparedTypesetter(RNTextEnginePreparedText *prepared) {
  CTTypesetterRef typesetter = [prepared loadTypesetter];
  if (typesetter != nullptr) return typesetter;

  @synchronized(prepared) {
    typesetter = [prepared loadTypesetter];
    if (typesetter == nullptr) {
      typesetter = CTTypesetterCreateWithAttributedString((CFAttributedStringRef)prepared.attributedText);
      [prepared storeTypesetter:typesetter];
    }
    return typesetter;
  }
}

std::shared_ptr<PreparedQueryOwner> resolvePreparedQueryOwner(Handle handle) {
  std::lock_guard<std::mutex> lock(preparedQueryMutex);
  auto &queryOwner = preparedQueryOwners[handle];
  if (queryOwner == nullptr) {
    queryOwner = std::make_shared<PreparedQueryOwner>();
    preparedQueryOwnersActive.store(true, std::memory_order_relaxed);
  }
  return queryOwner;
}

CGFloat resolveCoreTextOpticalWidth(CTLineRef line) {
  if (line == nullptr) return 0;
  CGRect bounds = CTLineGetBoundsWithOptions(line, kCTLineBoundsUseOpticalBounds);
  CGFloat leadingOverhang = MIN(0, CGRectGetMinX(bounds));
  return MAX(0, CGRectGetMaxX(bounds) - leadingOverhang);
}

Object buildNextLineObject(
    Runtime& runtime,
    NSInteger start,
    const PreparedNextLineMeasurement& measurement) {
  Object result(runtime);
  result.setProperty(runtime, "start", static_cast<double>(start));
  result.setProperty(runtime, "end", static_cast<double>(measurement.end));
  result.setProperty(runtime, "width", measurement.width);
  result.setProperty(runtime, "bottom", measurement.bottom);
  return result;
}

Value buildNextLineValue(
    Runtime& runtime,
    Handle handle,
    RNTextEnginePreparedText *prepared,
    NSInteger start,
    double width,
    bool anchorToCapHeight) {
  if (start < 0) start = 0;
  NSInteger textLength = prepared.text.length;
  if (start >= textLength) return Value::null();

  PreparedNextLineCacheKey cacheKey = resolvePreparedNextLineCacheKey(start, width, anchorToCapHeight);
  std::shared_ptr<PreparedQueryOwner> queryOwner = resolvePreparedQueryOwner(handle);
  {
    std::lock_guard<std::mutex> lock(queryOwner->mutex);
    auto cached = queryOwner->nextLinesByKey.find(cacheKey);
    if (cached != queryOwner->nextLinesByKey.end()) {
      return buildNextLineObject(runtime, start, cached->second);
    }
  }

  CTTypesetterRef typesetter = resolvePreparedTypesetter(prepared);
  auto lineContext = resolveCoreTextLineContext(prepared.attributedText, start);
  NSRange charRange = resolveNextLineCharacterRange(typesetter, start, width, lineContext.end);
  if (charRange.length == 0) return Value::null();

  CTLineRef ctLine = CTTypesetterCreateLine(typesetter, CFRangeMake(charRange.location, charRange.length));
  if (ctLine == nullptr) return Value::null();

  NSInteger visibleEnd = resolveVisibleEnd(prepared.text, charRange);
  CoreTextLineMetrics metrics = resolveCoreTextLineMetrics(ctLine, charRange, lineContext, prepared.fallbackLineHeight, anchorToCapHeight);
  CGFloat lineBottom = metrics.height;
  if (anchorToCapHeight) {
    CGFloat capHeight = prepared.uniformCapHeight > 0 ? prepared.uniformCapHeight : RNTextEngineMaxCapHeightForRange(prepared.attributedText, charRange);
    lineBottom = MAX(0, MIN(capHeight, metrics.height - metrics.descent));
  }

  CFRelease(ctLine);
  PreparedNextLineMeasurement measurement {
    .end = visibleEnd,
    .bottom = lineBottom,
    .width = metrics.width,
  };
  {
    std::lock_guard<std::mutex> lock(queryOwner->mutex);
    queryOwner->nextLinesByKey.emplace(cacheKey, measurement);
  }

  return buildNextLineObject(runtime, start, measurement);
}

NSLineBreakMode resolveLineBreakMode(const LayoutOptions& options) {
  NSString *ellipsizeMode = options.ellipsizeMode.has_value() ? toNSString(*options.ellipsizeMode) : nil;
  return RNTextEngineResolveLineBreakMode(options.maxLines.value_or(0), ellipsizeMode);
}

uint64_t resolveCGFloatBits(CGFloat value) {
  double normalized = MAX(static_cast<double>(value), 0);
  uint64_t bits = 0;
  std::memcpy(&bits, &normalized, sizeof(bits));
  return bits;
}

PreparedLayoutCacheKey resolvePreparedLayoutCacheKey(const LayoutOptions& options) {
  PreparedLayoutCacheKey key;
  key.widthBits = resolveCGFloatBits(options.width);
  key.maxLines = options.maxLines.value_or(0);
  key.lineBreakMode = resolveLineBreakMode(options);
  key.anchorToCapHeight = options.anchorToCapHeight;
  return key;
}

PreparedNextLineCacheKey resolvePreparedNextLineCacheKey(NSInteger start, CGFloat width, bool anchorToCapHeight) {
  PreparedNextLineCacheKey key;
  key.start = start;
  key.widthBits = resolveCGFloatBits(width);
  key.anchorToCapHeight = anchorToCapHeight;
  return key;
}

Object buildLayoutObject(Runtime& runtime, CGFloat width, CGFloat height, NSInteger lineCount, CGFloat lastLineWidth) {
  Object result(runtime);
  result.setProperty(runtime, "width", width);
  result.setProperty(runtime, "height", height);
  result.setProperty(runtime, "lineCount", static_cast<double>(lineCount));
  result.setProperty(runtime, "lastLineWidth", lastLineWidth);
  return result;
}

CGFloat measureAttributedWidth(NSAttributedString *attributedText) {
  CGRect bounds = [attributedText boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)
                                               options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                               context:nil];
  return RCTCeilPixelValue(CGRectGetWidth(bounds) + 0.001);
}

TextLayoutMeasurement measureAttributedTextLayout(
    NSString *text,
    NSAttributedString *attributedText,
    CGFloat fallbackLineHeight,
    CGFloat uniformCapHeight,
    const LayoutOptions& options) {
  TextLayoutMeasurement measurement;
  if (text.length == 0) {
    measurement.height = fallbackLineHeight;
    return measurement;
  }

  NSTextStorage *textStorage = [[NSTextStorage alloc] initWithAttributedString:attributedText];
  NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
  NSTextContainer *textContainer =
      [[NSTextContainer alloc] initWithSize:CGSizeMake(MAX(options.width, 0), CGFLOAT_MAX)];
  textContainer.lineFragmentPadding = 0;
  textContainer.lineBreakMode = resolveLineBreakMode(options);
  textContainer.maximumNumberOfLines = options.maxLines.value_or(0);

  [layoutManager addTextContainer:textContainer];
  [textStorage addLayoutManager:layoutManager];
  [layoutManager ensureLayoutForTextContainer:textContainer];

  CGFloat measuredHeight = 0;
  CGFloat measuredWidth = 0;
  CGFloat lastBaseline = 0;
  CGFloat lastLineWidth = 0;
  CGFloat topInset = 0;
  NSInteger lineCount = 0;
  BOOL resolvedCapAnchor = NO;

  NSUInteger glyphIndex = 0;
  while (glyphIndex < layoutManager.numberOfGlyphs) {
    NSRange glyphRange = NSMakeRange(0, 0);
    CGRect usedRect = [layoutManager lineFragmentUsedRectForGlyphAtIndex:glyphIndex effectiveRange:&glyphRange];
    CGRect lineRect = [layoutManager lineFragmentRectForGlyphAtIndex:glyphIndex effectiveRange:nil];
    NSRange charRange = [layoutManager characterRangeForGlyphRange:glyphRange actualGlyphRange:nil];
    CGFloat lineWidth = CGRectGetWidth(usedRect);
    CGFloat lineBaseline = RNTextEngineLineBaselineForGlyphIndex(layoutManager, glyphIndex, lineRect);

    if (options.anchorToCapHeight && !resolvedCapAnchor && charRange.length > 0) {
      topInset = MAX(
          0,
          lineBaseline -
              (uniformCapHeight > 0 ? uniformCapHeight : RNTextEngineMaxCapHeightForRange(attributedText, charRange)));
      resolvedCapAnchor = YES;
    }

    lineCount += 1;
    measuredWidth = MAX(measuredWidth, lineWidth);
    measuredHeight = MAX(measuredHeight, CGRectGetMaxY(usedRect));
    lastLineWidth = lineWidth;
    lastBaseline = lineBaseline;
    glyphIndex = NSMaxRange(glyphRange);
  }

  if (options.anchorToCapHeight && resolvedCapAnchor) {
    measuredHeight = MAX(0, lastBaseline - topInset);
  }

  measurement.width = measuredWidth;
  measurement.height = measuredHeight;
  measurement.lineCount = lineCount;
  measurement.lastLineWidth = lastLineWidth;
  return measurement;
}

Value layoutAttributedText(
    Runtime& runtime,
    NSString *text,
    NSAttributedString *attributedText,
    CGFloat fallbackLineHeight,
    CGFloat uniformCapHeight,
    const LayoutOptions& options,
    bool includeLines);

bool shouldTruncatePreparedLayout(const LayoutOptions& options) {
  return options.maxLines.has_value() && options.maxLines.value_or(0) > 0;
}

bool canUsePreparedCoreTextLayout(const LayoutOptions& options, bool includeLines) {
  return !includeLines && !shouldTruncatePreparedLayout(options) && !options.ellipsizeMode.has_value();
}

TextLayoutMeasurement measureCoreTextLayout(
    CTTypesetterRef typesetter,
    NSAttributedString *attributedText,
    CGFloat fallbackLineHeight,
    CGFloat uniformCapHeight,
    const LayoutOptions& options) {
  NSString *text = attributedText.string;
  if (text.length == 0 || typesetter == nullptr) {
    return TextLayoutMeasurement {.height = fallbackLineHeight};
  }

  TextLayoutMeasurement measurement;
  NSInteger start = 0;
  CGFloat cumulativeLineHeight = 0;
  CGFloat topInset = 0;
  CoreTextLineContext lineContext{};
  while (start < text.length) {
    if (start >= lineContext.end) lineContext = resolveCoreTextLineContext(attributedText, start);
    NSRange range = resolveNextLineCharacterRange(typesetter, start, options.width, lineContext.end);
    if (range.length == 0) break;
    CTLineRef line = CTTypesetterCreateLine(typesetter, CFRangeMake(range.location, range.length));
    if (line == nullptr) break;

    CoreTextLineMetrics metrics = resolveCoreTextLineMetrics(line, range, lineContext, fallbackLineHeight, options.anchorToCapHeight);
    CGFloat baseline = cumulativeLineHeight + metrics.height - metrics.descent;
    if (options.anchorToCapHeight && measurement.lineCount == 0) {
      CGFloat capHeight = uniformCapHeight > 0 ? uniformCapHeight : RNTextEngineMaxCapHeightForRange(attributedText, range);
      topInset = MAX(0, baseline - capHeight);
    }
    cumulativeLineHeight += metrics.height;
    measurement.width = MAX(measurement.width, metrics.width);
    measurement.height = options.anchorToCapHeight ? MAX(0, baseline - topInset) : cumulativeLineHeight;
    measurement.lastLineWidth = metrics.width;
    measurement.lineCount += 1;
    start = NSMaxRange(range);
    CFRelease(line);
  }
  return measurement;
}

TextLayoutMeasurement measurePreparedTextLayoutWithCoreText(
    RNTextEnginePreparedText *prepared,
    const LayoutOptions& options) {
  return measureCoreTextLayout(
      prepared.text.length > 0 ? resolvePreparedTypesetter(prepared) : nullptr,
      prepared.attributedText,
      prepared.fallbackLineHeight,
      prepared.uniformCapHeight,
      options);
}

TextLayoutMeasurement measurePreparedLayout(
    RNTextEnginePreparedText *prepared,
    const LayoutOptions& options) {
  return canUsePreparedCoreTextLayout(options, false)
      ? measurePreparedTextLayoutWithCoreText(prepared, options)
      : measureAttributedTextLayout(prepared.text, prepared.attributedText,
            prepared.fallbackLineHeight, prepared.uniformCapHeight, options);
}

TextLayoutMeasurement resolvePreparedLayoutMeasurement(
    Handle handle,
    RNTextEnginePreparedText *prepared,
    const LayoutOptions& options) {
  PreparedLayoutCacheKey cacheKey = resolvePreparedLayoutCacheKey(options);
  std::shared_ptr<PreparedQueryOwner> queryOwner = resolvePreparedQueryOwner(handle);
  {
    std::lock_guard<std::mutex> lock(queryOwner->mutex);
    auto cached = queryOwner->layoutsByKey.find(cacheKey);
    if (cached != queryOwner->layoutsByKey.end()) return cached->second;
  }

  TextLayoutMeasurement measurement = measurePreparedLayout(prepared, options);

  {
    std::lock_guard<std::mutex> lock(queryOwner->mutex);
    queryOwner->layoutsByKey.emplace(cacheKey, measurement);
  }

  return measurement;
}

TextLayoutMeasurement measureUniformTextLayoutWithCoreText(
    NSString *text,
    NSAttributedString *attributedText,
    CGFloat fallbackLineHeight,
    CGFloat uniformCapHeight,
    const LayoutOptions& options) {
  CTTypesetterRef typesetter = text.length > 0
      ? CTTypesetterCreateWithAttributedString((CFAttributedStringRef)attributedText)
      : nullptr;
  TextLayoutMeasurement measurement =
      measureCoreTextLayout(typesetter, attributedText, fallbackLineHeight, uniformCapHeight, options);
  if (typesetter != nullptr) CFRelease(typesetter);
  return measurement;
}

Value layoutUniformText(
    Runtime& runtime,
    NSString *text,
    NSAttributedString *attributedText,
    const ResolvedTextStyle& resolvedStyle,
    const LayoutOptions& options) {
  CGFloat uniformCapHeight = text.length > 0 ? resolvedStyle.capHeight : 0;
  if (canUsePreparedCoreTextLayout(options, false)) {
    TextLayoutMeasurement measurement =
        measureUniformTextLayoutWithCoreText(text, attributedText, resolvedStyle.fallbackLineHeight, uniformCapHeight, options);
    return buildLayoutObject(runtime, measurement.width, measurement.height, measurement.lineCount, measurement.lastLineWidth);
  }

  return layoutAttributedText(
      runtime,
      text,
      attributedText,
      resolvedStyle.fallbackLineHeight,
      uniformCapHeight,
      options,
      false);
}

Value layoutPreparedTextWithCoreText(
    Runtime& runtime,
    RNTextEnginePreparedText *prepared,
    const LayoutOptions& options,
    bool includeLines) {
  TextLayoutMeasurement measurement = measurePreparedTextLayoutWithCoreText(prepared, options);
  Object result =
      buildLayoutObject(runtime, measurement.width, measurement.height, measurement.lineCount, measurement.lastLineWidth);
  if (includeLines) {
    result.setProperty(runtime, "lines", Array(runtime, 0));
  }
  return result;
}

Value layoutPreparedText(
    Runtime& runtime,
    RNTextEnginePreparedText *prepared,
    const LayoutOptions& options,
    bool includeLines) {
  if (canUsePreparedCoreTextLayout(options, includeLines)) {
    return layoutPreparedTextWithCoreText(runtime, prepared, options, includeLines);
  }

  return layoutAttributedText(
      runtime,
      prepared.text,
      prepared.attributedText,
      prepared.fallbackLineHeight,
      prepared.uniformCapHeight,
      options,
      includeLines);
}

Value layoutPreparedTextForHandle(
    Runtime& runtime,
    Handle handle,
    RNTextEnginePreparedText *prepared,
    const LayoutOptions& options,
    bool includeLines) {
  if (!includeLines) {
    TextLayoutMeasurement measurement = resolvePreparedLayoutMeasurement(handle, prepared, options);
    return buildLayoutObject(runtime, measurement.width, measurement.height, measurement.lineCount, measurement.lastLineWidth);
  }

  return layoutPreparedText(runtime, prepared, options, true);
}

Value layoutAttributedText(
    Runtime& runtime,
    NSString *text,
    NSAttributedString *attributedText,
    CGFloat fallbackLineHeight,
    CGFloat uniformCapHeight,
    const LayoutOptions& options,
    bool includeLines) {
  if (text.length == 0) {
    Object empty = buildLayoutObject(runtime, 0, fallbackLineHeight, 0, 0);
    if (includeLines) empty.setProperty(runtime, "lines", Array(runtime, 0));
    return empty;
  }

  if (!includeLines) {
    TextLayoutMeasurement layout =
        measureAttributedTextLayout(text, attributedText, fallbackLineHeight, uniformCapHeight, options);
    return buildLayoutObject(runtime, layout.width, layout.height, layout.lineCount, layout.lastLineWidth);
  }

  NSTextStorage *textStorage = [[NSTextStorage alloc] initWithAttributedString:attributedText];
  NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
  NSTextContainer *textContainer =
      [[NSTextContainer alloc] initWithSize:CGSizeMake(MAX(options.width, 0), CGFLOAT_MAX)];
  textContainer.lineFragmentPadding = 0;
  textContainer.lineBreakMode = resolveLineBreakMode(options);
  textContainer.maximumNumberOfLines = options.maxLines.value_or(0);

  [layoutManager addTextContainer:textContainer];
  [textStorage addLayoutManager:layoutManager];
  [layoutManager ensureLayoutForTextContainer:textContainer];

  CGFloat measuredWidth = 0;
  CGFloat measuredHeight = 0;
  CGFloat lastLineWidth = 0;
  CGFloat topInset = 0;
  CGFloat lastBaseline = 0;
  NSInteger lineCount = 0;
  BOOL resolvedCapAnchor = NO;
  std::vector<Object> collectedLines;

  NSUInteger glyphIndex = 0;
  while (glyphIndex < layoutManager.numberOfGlyphs) {
    NSRange glyphRange = NSMakeRange(0, 0);
    CGRect usedRect = [layoutManager lineFragmentUsedRectForGlyphAtIndex:glyphIndex effectiveRange:&glyphRange];
    CGRect lineRect = [layoutManager lineFragmentRectForGlyphAtIndex:glyphIndex effectiveRange:nil];
    NSRange charRange = [layoutManager characterRangeForGlyphRange:glyphRange actualGlyphRange:nil];
    NSInteger visibleEnd = resolveVisibleEnd(text, charRange);
    CGFloat lineWidth = CGRectGetWidth(usedRect);
    CGFloat lineBaseline = RNTextEngineLineBaselineForGlyphIndex(layoutManager, glyphIndex, lineRect);

    if (options.anchorToCapHeight && !resolvedCapAnchor && charRange.length > 0) {
      topInset = MAX(
          0,
          lineBaseline -
              (uniformCapHeight > 0 ? uniformCapHeight : RNTextEngineMaxCapHeightForRange(attributedText, charRange)));
      resolvedCapAnchor = YES;
    }

    if (includeLines) {
      lineWidth = resolveVisibleLineWidth(layoutManager, glyphRange, charRange, visibleEnd, usedRect);
    }

    lineCount += 1;
    measuredWidth = MAX(measuredWidth, lineWidth);
    measuredHeight = MAX(measuredHeight, CGRectGetMaxY(usedRect));
    lastLineWidth = lineWidth;
    lastBaseline = lineBaseline;

    if (includeLines) {
      Object line(runtime);
      line.setProperty(runtime, "index", static_cast<double>(lineCount - 1));
      line.setProperty(runtime, "start", static_cast<double>(charRange.location));
      line.setProperty(runtime, "end", static_cast<double>(visibleEnd));
      line.setProperty(runtime, "width", lineWidth);
      line.setProperty(runtime, "bottom", options.anchorToCapHeight ? lineBaseline - topInset : CGRectGetMaxY(usedRect));
      collectedLines.push_back(std::move(line));
    }

    glyphIndex = NSMaxRange(glyphRange);
  }

  if (options.anchorToCapHeight && resolvedCapAnchor) {
    measuredHeight = MAX(0, lastBaseline - topInset);
  }

  Object result = buildLayoutObject(runtime, measuredWidth, measuredHeight, lineCount, lastLineWidth);
  if (includeLines) {
    Array lines(runtime, collectedLines.size());
    for (size_t i = 0; i < collectedLines.size(); i++) {
      lines.setValueAtIndex(runtime, i, collectedLines[i]);
    }
    result.setProperty(runtime, "lines", lines);
  }
  return result;
}

RNTextEnginePreparedText *buildPreparedText(
    NSString *text,
    const TextMeasureStyle& baseStyle,
    const ResolvedTextStyle& resolvedBaseStyle,
    const std::vector<TextMeasureRun>& runs) {
  NSAttributedString *baseAttributedText = buildAttributedText(text, resolvedBaseStyle);
  if (runs.empty()) {
    RNTextEnginePreparedText *prepared = [[RNTextEnginePreparedText alloc] init];
    prepared.text = text;
    prepared.attributedText = baseAttributedText;
    prepared.fallbackLineHeight = resolvedBaseStyle.fallbackLineHeight;
    prepared.uniformCapHeight = text.length > 0 ? resolvedBaseStyle.capHeight : 0;
    return prepared;
  }

  NSMutableAttributedString *attributedText =
      [[NSMutableAttributedString alloc] initWithAttributedString:baseAttributedText];

  for (const TextMeasureRun& run : runs) {
    TextMeasureStyle mergedStyle = mergeRunStyle(baseStyle, run.style);
    ResolvedTextStyle resolvedRunStyle = resolveTextStyle(mergedStyle);
    [attributedText addAttributes:resolvedRunStyle.attributes
                            range:NSMakeRange(run.start, run.end - run.start)];
  }

  RNTextEnginePreparedText *prepared = [[RNTextEnginePreparedText alloc] init];
  prepared.text = text;
  prepared.attributedText = attributedText;
  prepared.fallbackLineHeight = resolvedBaseStyle.fallbackLineHeight;
  prepared.uniformCapHeight = 0;
  return prepared;
}

Handle storePreparedText(RNTextEnginePreparedText *prepared) {
  std::lock_guard<std::mutex> lock(preparedMutex);
  if (preparedTexts == nil) preparedTexts = [[NSMutableDictionary alloc] init];
  Handle handle = nextHandle++;
  preparedTexts[toKey(handle)] = prepared;
  return handle;
}

RNTextEnginePreparedText *getPreparedText(Runtime& runtime, Handle handle) {
  std::lock_guard<std::mutex> lock(preparedMutex);
  RNTextEnginePreparedText *prepared = preparedTexts[toKey(handle)];
  if (!prepared) {
    throw JSError(runtime, "RNTextEngine: attempted to use an invalid prepared text handle.");
  }
  return prepared;
}

NSAttributedString *preparedAttributedTextForHandleLocked(Handle handle) {
  RNTextEnginePreparedText *prepared = nil;
  {
    std::lock_guard<std::mutex> lock(preparedMutex);
    prepared = preparedTexts[toKey(handle)];
  }
  return prepared.attributedText;
}

CGFloat preparedUniformCapHeightForHandleLocked(Handle handle) {
  RNTextEnginePreparedText *prepared = nil;
  {
    std::lock_guard<std::mutex> lock(preparedMutex);
    prepared = preparedTexts[toKey(handle)];
  }
  return prepared.uniformCapHeight;
}

void releaseHandle(Handle handle) {
  {
    std::lock_guard<std::mutex> lock(preparedMutex);
    [preparedTexts removeObjectForKey:toKey(handle)];
  }
  if (!preparedQueryOwnersActive.load(std::memory_order_relaxed)) return;
  std::lock_guard<std::mutex> queryLock(preparedQueryMutex);
  preparedQueryOwners.erase(handle);
  if (preparedQueryOwners.empty()) {
    preparedQueryOwnersActive.store(false, std::memory_order_relaxed);
  }
}

void releaseHandles(const std::vector<Handle>& handles) {
  {
    std::lock_guard<std::mutex> lock(preparedMutex);
    for (Handle handle : handles) {
      [preparedTexts removeObjectForKey:toKey(handle)];
    }
  }
  if (!preparedQueryOwnersActive.load(std::memory_order_relaxed)) return;
  std::lock_guard<std::mutex> queryLock(preparedQueryMutex);
  for (Handle handle : handles) {
    preparedQueryOwners.erase(handle);
  }
  if (preparedQueryOwners.empty()) {
    preparedQueryOwnersActive.store(false, std::memory_order_relaxed);
  }
}

std::vector<Handle> parseHandleArray(Runtime& runtime, const Value& value) {
  if (!value.isObject() || !value.asObject(runtime).isArray(runtime)) {
    throw JSError(runtime, "RNTextEngine: expected an array of prepared text handles.");
  }

  Array array = value.asObject(runtime).asArray(runtime);
  std::vector<Handle> handles;
  handles.reserve(array.size(runtime));
  for (size_t i = 0; i < array.size(runtime); i++) {
    Value item = array.getValueAtIndex(runtime, i);
    if (!item.isNumber()) {
      throw JSError(runtime, "RNTextEngine: prepared text handles must be numeric.");
    }
    handles.push_back(static_cast<Handle>(item.asNumber()));
  }
  return handles;
}

NSArray<NSString *> *parseNSStringArray(Runtime& runtime, const Value& value) {
  if (!value.isObject() || !value.asObject(runtime).isArray(runtime)) {
    throw JSError(runtime, "RNTextEngine: expected an array of strings.");
  }

  Array array = value.asObject(runtime).asArray(runtime);
  NSMutableArray<NSString *> *texts = [NSMutableArray arrayWithCapacity:array.size(runtime)];
  for (size_t i = 0; i < array.size(runtime); i++) {
    Value item = array.getValueAtIndex(runtime, i);
    if (!item.isString()) {
      throw JSError(runtime, "RNTextEngine: batch text input must contain strings only.");
    }
    [texts addObject:toNSString(item.asString(runtime).utf8(runtime))];
  }
  return texts;
}

Array buildHandleArray(Runtime& runtime, const std::vector<Handle>& handles) {
  Array array(runtime, handles.size());
  for (size_t i = 0; i < handles.size(); i++) {
    array.setValueAtIndex(runtime, i, static_cast<double>(handles[i]));
  }
  return array;
}

CGFloat measurePreparedTextWidthForHandleInternal(uint64_t handle) {
  RNTextEnginePreparedText *prepared = nil;
  {
    std::lock_guard<std::mutex> lock(preparedMutex);
    prepared = preparedTexts[toKey(static_cast<Handle>(handle))];
  }
  if (prepared == nil) return 0;
  return measureAttributedWidth(prepared.attributedText);
}

CGSize measurePreparedTextLayoutForHandleInternal(
    uint64_t handle,
    CGFloat width,
    NSInteger maxLines,
    NSString *ellipsizeMode,
    BOOL anchorToCapHeight) {
  RNTextEnginePreparedText *prepared = nil;
  {
    std::lock_guard<std::mutex> lock(preparedMutex);
    prepared = preparedTexts[toKey(static_cast<Handle>(handle))];
  }
  if (prepared == nil) return CGSizeZero;

  LayoutOptions options;
  options.width = width;
  options.anchorToCapHeight = anchorToCapHeight;
  if (maxLines > 0) options.maxLines = static_cast<int>(maxLines);
  if (ellipsizeMode.length > 0) options.ellipsizeMode = fromNSString(ellipsizeMode);

  TextLayoutMeasurement measurement = resolvePreparedLayoutMeasurement(static_cast<Handle>(handle), prepared, options);
  return CGSizeMake(measurement.width, measurement.height);
}

void releasePreparedTextHandleInternal(uint64_t handle) {
  releaseHandle(static_cast<Handle>(handle));
}

} // namespace

RNTextEnginePreparedText *prepareAttributedText(NSAttributedString *text, CGFloat emptyLineHeight, NSTextAlignment alignment) {
  RNTextEnginePreparedText *prepared = [RNTextEnginePreparedText new];
  __block NSMutableAttributedString *measurementText = nil;
  if (alignment != NSTextAlignmentLeft) {
    [text enumerateAttribute:NSParagraphStyleAttributeName inRange:NSMakeRange(0, text.length) options:0
                 usingBlock:^(NSParagraphStyle *paragraph, NSRange range, BOOL *) {
      if (paragraph == nil || paragraph.alignment == NSTextAlignmentLeft) return;
      if (measurementText == nil) measurementText = [text mutableCopy];
      NSMutableParagraphStyle *unaligned = [paragraph mutableCopy];
      unaligned.alignment = NSTextAlignmentLeft;
      [measurementText addAttribute:NSParagraphStyleAttributeName value:unaligned range:range];
    }];
  }
  prepared.attributedText = measurementText ?: text;
  prepared.text = text.string;
  prepared.fallbackLineHeight = emptyLineHeight;
  prepared.uniformCapHeight = RNTextEngineUniformCapHeightForAttributedText(text);
  return prepared;
}

CGFloat measurePreparedTextWidth(RNTextEnginePreparedText *prepared) {
  return measureAttributedWidth(prepared.attributedText);
}

CGSize measurePreparedTextLayout(RNTextEnginePreparedText *prepared, CGFloat width,
                                NSInteger maxLines, NSString *ellipsizeMode, BOOL anchorToCapHeight) {
  LayoutOptions options;
  options.width = width;
  options.anchorToCapHeight = anchorToCapHeight;
  if (maxLines > 0) options.maxLines = static_cast<int>(maxLines);
  if (ellipsizeMode.length > 0) options.ellipsizeMode = fromNSString(ellipsizeMode);
  auto measurement = measurePreparedLayout(prepared, options);
  return CGSizeMake(measurement.width, measurement.height);
}

uint64_t createPreparedTextHandleForTextView(
    NSString *text,
    const RNTextEngineTextAttributes &attributes,
    const std::vector<RNTextEngineTextRun> &runs,
    NSString *textTransform) {
  CGFloat emptyLineHeight = 0;
  NSAttributedString *attributedText = RNTextEngineBuildAttributedText(
      text, attributes, runs, textTransform, NO, &emptyLineHeight);
  return storePreparedText(prepareAttributedText(
      attributedText, emptyLineHeight, RNTextEngineTextResolveAlignment(attributes.textAlign)));
}

CGFloat measurePreparedTextWidthForHandle(uint64_t handle) {
  return measurePreparedTextWidthForHandleInternal(handle);
}

CGSize measurePreparedTextLayoutForHandle(
    uint64_t handle,
    CGFloat width,
    NSInteger maxLines,
    NSString *ellipsizeMode,
    BOOL anchorToCapHeight) {
  return measurePreparedTextLayoutForHandleInternal(handle, width, maxLines, ellipsizeMode, anchorToCapHeight);
}

void releasePreparedTextHandle(uint64_t handle) {
  releasePreparedTextHandleInternal(handle);
}

NSAttributedString *preparedAttributedTextForHandle(uint64_t handle) {
  return preparedAttributedTextForHandleLocked(static_cast<Handle>(handle));
}

CGFloat preparedUniformCapHeightForHandle(uint64_t handle) {
  return preparedUniformCapHeightForHandleLocked(static_cast<Handle>(handle));
}

void registerGlyphFieldView(uint64_t handle, UIView *view) {
  if (handle == 0 || view == nil) return;

  std::lock_guard<std::mutex> lock(glyphFieldMutex);
  RNTextEngineGlyphField *field = glyphFields[toKey(static_cast<Handle>(handle))];
  [field.views addObject:view];
}

void unregisterGlyphFieldView(uint64_t handle, UIView *view) {
  if (handle == 0 || view == nil) return;

  std::lock_guard<std::mutex> lock(glyphFieldMutex);
  RNTextEngineGlyphField *field = glyphFields[toKey(static_cast<Handle>(handle))];
  [field.views removeObject:view];
}

void drawGlyphFieldHandle(uint64_t handle, CGContextRef context, CGRect bounds, CGRect dirtyRect) {
  if (handle == 0 || context == nullptr) return;

  RNTextEngineGlyphField *field = getGlyphFieldIfPresent(static_cast<Handle>(handle));
  if (field == nil) return;

  NSArray<RNTextEngineGlyphFieldRow *> *rows = resolveGlyphFieldRows(field);
  if (rows.count == 0) return;

  CGFloat contentHeight = field.rows * field.lineHeight;
  CGFloat topInset = MAX(0, (CGRectGetHeight(bounds) - contentHeight) * 0.5);

  NSInteger startRow = MAX(0, static_cast<NSInteger>(floor((CGRectGetMinY(dirtyRect) - topInset) / field.lineHeight)));
  NSInteger endRow = MIN(field.rows, static_cast<NSInteger>(ceil((CGRectGetMaxY(dirtyRect) - topInset) / field.lineHeight)));
  if (CGRectIsEmpty(dirtyRect)) {
    startRow = 0;
    endRow = field.rows;
  }

  CGContextSaveGState(context);
  CGContextSetTextMatrix(context, CGAffineTransformIdentity);
  CGContextTranslateCTM(context, 0, CGRectGetHeight(bounds));
  CGContextScaleCTM(context, 1.0, -1.0);

  for (NSInteger row = startRow; row < endRow; row += 1) {
    RNTextEngineGlyphFieldRow *rowData = rows[row];
    CGFloat x = glyphFieldRowOriginX(field, bounds, rowData.width);
    CGFloat baseline = CGRectGetHeight(bounds) - (topInset + row * field.lineHeight + rowData.baselineOffset);
    CGContextSetTextPosition(context, x, baseline);
    CTLineDraw(rowData.line, context);
  }

  CGContextRestoreGState(context);
}

void cleanup() {
  {
    std::lock_guard<std::mutex> lock(preparedMutex);
    [preparedTexts removeAllObjects];
    preparedTexts = nil;
  }
  {
    std::lock_guard<std::mutex> lock(preparedQueryMutex);
    preparedQueryOwners.clear();
    preparedQueryOwnersActive.store(false, std::memory_order_relaxed);
  }
  {
    std::lock_guard<std::mutex> lock(glyphFieldMutex);
    [glyphFields removeAllObjects];
    glyphFields = nil;
  }
  {
    std::lock_guard<std::mutex> lock(glyphFieldBufferMutex);
    glyphFieldBuffers.clear();
  }
}

void install(Runtime& runtime) {
  auto installFunction = [&](const char *name, unsigned int argCount, auto fn) {
    auto wrappedFn = [fn = std::move(fn)](Runtime& runtime, const Value& thisValue, const Value* arguments, size_t count) -> Value {
      @autoreleasepool {
        return fn(runtime, thisValue, arguments, count);
      }
    };

    runtime.global().setProperty(
        runtime,
        name,
        Function::createFromHostFunction(
            runtime,
            PropNameID::forAscii(runtime, name),
            argCount,
            wrappedFn));
  };

#if RNTEXTENGINE_HAS_WORKLETS
  installFunction(
      "__RNTextEngineInstallWorkletRuntime",
      1,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0 || !arguments[0].isObject()) {
          throw JSError(
              runtime,
              "RNTextEngine: installWorkletRuntime() requires a WorkletRuntime.");
        }

        std::shared_ptr<worklets::WorkletRuntime> workletRuntime;
        try {
          Object runtimeObject = arguments[0].asObject(runtime);
          if (runtimeObject.isHostObject<worklets::WorkletRuntime>(runtime)) {
            workletRuntime = worklets::extractWorkletRuntime(runtime, arguments[0]);
          } else {
            workletRuntime = worklets::getWorkletRuntimeFromHolder(runtime, runtimeObject);
          }
        } catch (...) {
          throw JSError(
              runtime,
              "RNTextEngine: installWorkletRuntime() requires a WorkletRuntime.");
        }

        if (!workletRuntime) return Value(false);

        install(workletRuntime->getJSIRuntime());
        return Value(true);
      });
#endif

  installFunction(
      "__RNTextEngineCreateGlyphField",
      1,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0) {
          throw JSError(runtime, "RNTextEngine: createGlyphField() requires a config object.");
        }
        return static_cast<double>(createGlyphField(parseGlyphFieldConfig(runtime, arguments[0])));
      });

  installFunction(
      "__RNTextEngineCreateGlyphFieldBuffers",
      1,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0 || !arguments[0].isNumber()) {
          throw JSError(runtime, "RNTextEngine: createGlyphFieldBuffers() requires a glyph field handle.");
        }

        Handle handle = static_cast<Handle>(arguments[0].asNumber());
        RNTextEngineGlyphField *field = getGlyphField(runtime, handle);
        size_t cellCount = static_cast<size_t>(field.columns * field.rows);
        std::shared_ptr<GlyphFieldBufferSet> buffers = getOrCreateGlyphFieldBuffers(handle, cellCount);

        Object result(runtime);
        result.setProperty(runtime, "glyphIndices", ArrayBuffer(runtime, buffers->glyphIndices));
        result.setProperty(runtime, "variantIndices", ArrayBuffer(runtime, buffers->variantIndices));
        return result;
      });

  installFunction(
      "__RNTextEngineCommitGlyphFieldBuffers",
      1,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0 || !arguments[0].isNumber()) {
          throw JSError(runtime, "RNTextEngine: commitGlyphFieldBuffers() requires a glyph field handle.");
        }

        commitGlyphFieldBuffers(runtime, static_cast<Handle>(arguments[0].asNumber()));
        return Value::undefined();
      });

  installFunction(
      "__RNTextEngineUpdateGlyphField",
      3,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count < 3 || !arguments[0].isNumber() || !arguments[1].isString()) {
          throw JSError(runtime, "RNTextEngine: updateGlyphField() requires a handle, glyph string, and Uint8Array.");
        }

        Handle handle = static_cast<Handle>(arguments[0].asNumber());
        std::string glyphs = arguments[1].asString(runtime).utf8(runtime);
        RNTextEngineGlyphField *field = getGlyphField(runtime, handle);
        size_t cellCount = static_cast<size_t>(field.columns * field.rows);
        Uint8ArrayView variantIndices = parseUint8Array(runtime, arguments[2], cellCount);
        updateGlyphField(runtime, handle, glyphs, variantIndices);
        return Value::undefined();
      });

  installFunction(
      "__RNTextEngineUpdateGlyphFieldIndices",
      3,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count < 3 || !arguments[0].isNumber()) {
          throw JSError(runtime, "RNTextEngine: updateGlyphFieldIndices() requires a handle, glyphIndices Uint8Array, and Uint8Array.");
        }

        Handle handle = static_cast<Handle>(arguments[0].asNumber());
        RNTextEngineGlyphField *field = getGlyphField(runtime, handle);
        size_t cellCount = static_cast<size_t>(field.columns * field.rows);
        Uint8ArrayView glyphIndices = parseUint8Array(runtime, arguments[1], cellCount);
        Uint8ArrayView variantIndices = parseUint8Array(runtime, arguments[2], cellCount);
        updateGlyphFieldIndices(runtime, handle, glyphIndices, variantIndices);
        return Value::undefined();
      });

  installFunction(
      "__RNTextEngineReleaseGlyphField",
      1,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0 || !arguments[0].isNumber()) {
          throw JSError(runtime, "RNTextEngine: releaseGlyphField() requires a glyph field handle.");
        }

        releaseGlyphFieldHandle(static_cast<Handle>(arguments[0].asNumber()));
        return Value::undefined();
      });

  installFunction(
      "__RNTextEnginePrepare",
      3,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0 || !arguments[0].isString()) {
          throw JSError(runtime, "RNTextEngine: prepare() requires a text string.");
        }
        TextMeasureStyle style = count > 1 ? parseStyle(runtime, arguments, 1, count) : TextMeasureStyle {};
        NSString *text = toNSString(arguments[0].asString(runtime).utf8(runtime));
        std::vector<TextMeasureRun> runs =
            count > 2 ? parseRuns(runtime, arguments[2], text.length) : std::vector<TextMeasureRun> {};
        ResolvedTextStyle resolvedStyle = resolveTextStyle(style);
        return static_cast<double>(storePreparedText(buildPreparedText(text, style, resolvedStyle, runs)));
      });

  installFunction(
      "__RNTextEnginePrepareBatch",
      3,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0) {
          throw JSError(runtime, "RNTextEngine: prepareBatch() requires an array of strings.");
        }
        TextMeasureStyle style = count > 1 ? parseStyle(runtime, arguments, 1, count) : TextMeasureStyle {};
        ResolvedTextStyle resolvedStyle = resolveTextStyle(style);
        NSArray<NSString *> *texts = parseNSStringArray(runtime, arguments[0]);
        NSUInteger textCount = texts.count;
        std::vector<std::vector<TextMeasureRun>> runsByText(textCount);
        if (count > 2 && !arguments[2].isUndefined() && !arguments[2].isNull()) {
          if (!arguments[2].isObject() || !arguments[2].asObject(runtime).isArray(runtime)) {
            throw JSError(runtime, "RNTextEngine: batch text runs must be an array aligned with the batch text input.");
          }

          Array runsArray = arguments[2].asObject(runtime).asArray(runtime);
          if (runsArray.size(runtime) != textCount) {
            throw JSError(runtime, "RNTextEngine: batch text runs must align with the batch text input length.");
          }

          for (NSUInteger index = 0; index < textCount; index++) {
            runsByText[index] = parseRuns(runtime, runsArray.getValueAtIndex(runtime, index), texts[index].length);
          }
        }

        std::vector<Handle> handles;
        handles.reserve(textCount);
        for (NSUInteger index = 0; index < textCount; index++) {
          handles.push_back(storePreparedText(buildPreparedText(texts[index], style, resolvedStyle, runsByText[index])));
        }
        return buildHandleArray(runtime, handles);
      });

  installFunction(
      "__RNTextEngineRelease",
      1,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0 || !arguments[0].isNumber()) {
          throw JSError(runtime, "RNTextEngine: release() requires a prepared text handle.");
        }
        releaseHandle(static_cast<Handle>(arguments[0].asNumber()));
        return Value::undefined();
      });

  installFunction(
      "__RNTextEngineReleaseMany",
      1,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0) {
          throw JSError(runtime, "RNTextEngine: releaseMany() requires an array of handles.");
        }
        releaseHandles(parseHandleArray(runtime, arguments[0]));
        return Value::undefined();
      });

  installFunction(
      "__RNTextEngineMeasureWidth",
      3,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0 || !arguments[0].isString()) {
          throw JSError(runtime, "RNTextEngine: measureWidth() requires a text string.");
        }
        TextMeasureStyle style = count > 1 ? parseStyle(runtime, arguments, 1, count) : TextMeasureStyle {};
        NSString *text = toNSString(arguments[0].asString(runtime).utf8(runtime));
        std::vector<TextMeasureRun> runs =
            count > 2 ? parseRuns(runtime, arguments[2], text.length) : std::vector<TextMeasureRun> {};
        ResolvedTextStyle resolvedStyle = resolveTextStyle(style);
        RNTextEnginePreparedText *prepared = buildPreparedText(text, style, resolvedStyle, runs);
        NSAttributedString *attributed = prepared.attributedText;
        return measureAttributedWidth(attributed);
      });

  installFunction(
      "__RNTextEngineLayout",
      2,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0 || !arguments[0].isNumber()) {
          throw JSError(runtime, "RNTextEngine: layout() requires a prepared text handle.");
        }
        LayoutOptions options = parseLayoutOptions(runtime, arguments, 1, count);
        RNTextEnginePreparedText *prepared = getPreparedText(runtime, static_cast<Handle>(arguments[0].asNumber()));
        return layoutPreparedTextForHandle(runtime, static_cast<Handle>(arguments[0].asNumber()), prepared, options, false);
      });

  installFunction(
      "__RNTextEngineLayoutLines",
      2,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0 || !arguments[0].isNumber()) {
          throw JSError(runtime, "RNTextEngine: layoutLines() requires a prepared text handle.");
        }
        LayoutOptions options = parseLayoutOptions(runtime, arguments, 1, count);
        RNTextEnginePreparedText *prepared = getPreparedText(runtime, static_cast<Handle>(arguments[0].asNumber()));
        return layoutPreparedText(runtime, prepared, options, true);
      });

  installFunction(
      "__RNTextEngineLayoutNextLine",
      3,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count < 3 || !arguments[0].isNumber() || !arguments[1].isNumber() || !arguments[2].isNumber()) {
          throw JSError(runtime, "RNTextEngine: layoutNextLine() requires a handle, start offset, and width.");
        }
        RNTextEnginePreparedText *prepared = getPreparedText(runtime, static_cast<Handle>(arguments[0].asNumber()));
        bool anchorToCapHeight = count > 3 && arguments[3].isBool() ? arguments[3].getBool() : false;
        return buildNextLineValue(
            runtime,
            static_cast<Handle>(arguments[0].asNumber()),
            prepared,
            static_cast<NSInteger>(arguments[1].asNumber()),
            arguments[2].asNumber(),
            anchorToCapHeight);
      });

  installFunction(
      "__RNTextEngineMeasure",
      4,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0 || !arguments[0].isString()) {
          throw JSError(runtime, "RNTextEngine: measure() requires a text string.");
        }
        TextMeasureStyle style = count > 1 ? parseStyle(runtime, arguments, 1, count) : TextMeasureStyle {};
        LayoutOptions options = parseLayoutOptions(runtime, arguments, 2, count);
        NSString *text = toNSString(arguments[0].asString(runtime).utf8(runtime));
        std::vector<TextMeasureRun> runs =
            count > 3 ? parseRuns(runtime, arguments[3], text.length) : std::vector<TextMeasureRun> {};
        ResolvedTextStyle resolvedStyle = resolveTextStyle(style);
        if (runs.empty()) {
          return layoutUniformText(runtime, text, buildAttributedText(text, resolvedStyle), resolvedStyle, options);
        }
        RNTextEnginePreparedText *prepared = buildPreparedText(text, style, resolvedStyle, runs);
        return layoutPreparedText(runtime, prepared, options, false);
      });

  installFunction(
      "__RNTextEngineMeasureBatch",
      4,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0) {
          throw JSError(runtime, "RNTextEngine: measureBatch() requires an array of strings.");
        }
        TextMeasureStyle style = count > 1 ? parseStyle(runtime, arguments, 1, count) : TextMeasureStyle {};
        LayoutOptions options = parseLayoutOptions(runtime, arguments, 2, count);
        ResolvedTextStyle resolvedStyle = resolveTextStyle(style);
        NSArray<NSString *> *texts = parseNSStringArray(runtime, arguments[0]);
        if (count <= 3 || arguments[3].isUndefined() || arguments[3].isNull()) {
          Array results(runtime, texts.count);
          for (NSUInteger i = 0; i < texts.count; i++) {
            NSString *text = texts[i];
            results.setValueAtIndex(
                runtime,
                i,
                layoutUniformText(runtime, text, buildAttributedText(text, resolvedStyle), resolvedStyle, options));
          }
          return results;
        }

        std::vector<std::vector<TextMeasureRun>> runsByText(texts.count);
        if (!arguments[3].isObject() || !arguments[3].asObject(runtime).isArray(runtime)) {
          throw JSError(runtime, "RNTextEngine: batch text runs must be an array aligned with the batch text input.");
        }
        Array runsArray = arguments[3].asObject(runtime).asArray(runtime);
        if (runsArray.size(runtime) != texts.count) {
          throw JSError(runtime, "RNTextEngine: batch text runs must align with the batch text input length.");
        }
        for (NSUInteger index = 0; index < texts.count; index++) {
          runsByText[index] = parseRuns(runtime, runsArray.getValueAtIndex(runtime, index), texts[index].length);
        }

        Array results(runtime, texts.count);
        for (NSUInteger i = 0; i < texts.count; i++) {
          NSString *text = texts[i];
          RNTextEnginePreparedText *prepared = buildPreparedText(text, style, resolvedStyle, runsByText[i]);
          results.setValueAtIndex(runtime, i, layoutPreparedText(runtime, prepared, options, false));
        }
        return results;
      });

  installFunction(
      "__RNTextEngineLayoutBatch",
      2,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0) {
          throw JSError(runtime, "RNTextEngine: layoutBatch() requires an array of handles.");
        }
        LayoutOptions options = parseLayoutOptions(runtime, arguments, 1, count);
        std::vector<Handle> handles = parseHandleArray(runtime, arguments[0]);
        Array results(runtime, handles.size());
        for (size_t i = 0; i < handles.size(); i++) {
          RNTextEnginePreparedText *prepared = getPreparedText(runtime, handles[i]);
          results.setValueAtIndex(runtime, i, layoutPreparedTextForHandle(runtime, handles[i], prepared, options, false));
        }
        return results;
      });

}

} // namespace rntextengine
