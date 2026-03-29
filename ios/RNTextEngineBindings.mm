#import "RNTextEngineBindings.h"
#import "RNTextEngineColorUtils.h"

#import <CoreText/SFNTLayoutTypes.h>
#import <React/RCTConvert.h>
#import <React/RCTFont.h>
#import <React/RCTUtils.h>

#import <mutex>
#import <optional>
#import <cstring>
#import <vector>

#if __has_include(<worklets/WorkletRuntime/WorkletRuntime.h>)
#import <worklets/WorkletRuntime/WorkletRuntime.h>
#import <worklets/Compat/StableApi.h>
#define RNTEXTENGINE_HAS_WORKLETS 1
#else
#define RNTEXTENGINE_HAS_WORKLETS 0
#endif

@interface RNTextEnginePreparedText : NSObject
@property (nonatomic, strong) NSAttributedString *attributedText;
@property (nonatomic, strong) NSString *text;
@property (nonatomic, assign) CGFloat fallbackLineHeight;
@end

@implementation RNTextEnginePreparedText
@end

@interface RNTextEngineGlyphFieldVariant : NSObject
@property (nonatomic, strong) NSDictionary<NSAttributedStringKey, id> *attributes;
@property (nonatomic, strong) UIFont *font;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *widthCache;
@end

@implementation RNTextEngineGlyphFieldVariant

- (instancetype)init
{
  if ((self = [super init])) {
    _widthCache = [[NSMutableDictionary alloc] init];
  }

  return self;
}

@end

@interface RNTextEngineGlyphField : NSObject
@property (nonatomic, assign) NSInteger columns;
@property (nonatomic, assign) CGFloat lineHeight;
@property (nonatomic, assign) NSInteger rows;
@property (nonatomic, assign) NSTextAlignment textAlign;
@property (nonatomic, copy) NSString *glyphs;
@property (nonatomic, copy) NSData *variantIndices;
@property (nonatomic, copy) NSArray<RNTextEngineGlyphFieldVariant *> *variants;
@property (nonatomic, strong) NSHashTable<UIView *> *views;
@end

@implementation RNTextEngineGlyphField

- (instancetype)init
{
  if ((self = [super init])) {
    _glyphs = @"";
    _variantIndices = [NSData data];
    _views = [NSHashTable weakObjectsHashTable];
  }

  return self;
}

@end

using namespace facebook::jsi;

namespace rntextengine {

namespace {

using Handle = uint64_t;

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

struct LayoutOptions {
  std::optional<std::string> ellipsizeMode;
  std::optional<int> maxLines;
  double width = 0;
};

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
  double letterSpacing = 0;
  double lineHeight = 0;
  NSInteger rows = 0;
  std::string fontFamily;
  std::string textAlign;
  std::vector<GlyphFieldVariantConfig> variants;
};

static std::mutex preparedMutex;
static NSMutableDictionary<NSNumber *, RNTextEnginePreparedText *> *preparedTexts;
static Handle nextHandle = 1;
static std::mutex glyphFieldMutex;
static NSMutableDictionary<NSNumber *, RNTextEngineGlyphField *> *glyphFields;
static Handle nextGlyphFieldHandle = 1;

NSNumber *toKey(Handle handle) {
  return [NSNumber numberWithUnsignedLongLong:handle];
}

NSString *toNSString(const std::string& value) {
  return [NSString stringWithUTF8String:value.c_str()] ?: @"";
}

TextMeasureStyle parseStyle(Runtime& runtime, const Value* value, size_t index, size_t count) {
  TextMeasureStyle style;
  if (index >= count) return style;
  if (value[index].isUndefined() || value[index].isNull()) return style;
  if (!value[index].isObject()) return style;

  Object object = value[index].asObject(runtime);

  auto readBool = [&](const char* name, bool& target) {
    if (!object.hasProperty(runtime, name)) return;
    Value field = object.getProperty(runtime, name);
    if (!field.isBool()) return;
    target = field.getBool();
  };

  auto readNumber = [&](const char* name, bool& hasValue, double& target) {
    if (!object.hasProperty(runtime, name)) return;
    Value field = object.getProperty(runtime, name);
    if (!field.isNumber()) return;
    hasValue = true;
    target = field.asNumber();
  };

  auto readString = [&](const char* name, bool& hasValue, std::string& target) {
    if (!object.hasProperty(runtime, name)) return;
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
    if (!object.hasProperty(runtime, name)) return;
    Value field = object.getProperty(runtime, name);
    if (!field.isBool()) return;
    hasValue = true;
    target = field.getBool();
  };

  auto readNumber = [&](const char* name, bool& hasValue, double& target) {
    if (!object.hasProperty(runtime, name)) return;
    Value field = object.getProperty(runtime, name);
    if (!field.isNumber()) return;
    hasValue = true;
    target = field.asNumber();
  };

  auto readString = [&](const char* name, bool& hasValue, std::string& target) {
    if (!object.hasProperty(runtime, name)) return;
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
    if (!runObject.hasProperty(runtime, "start") || !runObject.hasProperty(runtime, "end")) {
      throw JSError(runtime, "RNTextEngine: each text run must include start and end offsets.");
    }

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

    if (!runObject.hasProperty(runtime, "style")) {
      throw JSError(runtime, "RNTextEngine: each text run must include a style object.");
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

  if (!object.hasProperty(runtime, "width")) {
    throw JSError(runtime, "RNTextEngine: layout options must include a width.");
  }

  Value width = object.getProperty(runtime, "width");
  if (!width.isNumber()) {
    throw JSError(runtime, "RNTextEngine: layout width must be a number.");
  }
  options.width = width.asNumber();

  if (object.hasProperty(runtime, "maxLines")) {
    Value maxLines = object.getProperty(runtime, "maxLines");
    if (maxLines.isNumber()) options.maxLines = static_cast<int>(maxLines.asNumber());
  }

  if (object.hasProperty(runtime, "ellipsizeMode")) {
    Value mode = object.getProperty(runtime, "ellipsizeMode");
    if (mode.isString()) options.ellipsizeMode = mode.asString(runtime).utf8(runtime);
  }

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

std::vector<uint8_t> parseUint8Array(Runtime& runtime, const Value& value, size_t expectedLength) {
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

  std::vector<uint8_t> values(length);
  if (length > 0) {
    std::memcpy(values.data(), buffer.data(runtime) + byteOffset, length);
  }
  return values;
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

CGFloat measureGlyphWidth(RNTextEngineGlyphFieldVariant *variant, NSString *glyph) {
  NSNumber *cachedWidth = variant.widthCache[@(glyph.length == 0 ? 0 : [glyph characterAtIndex:0])];
  if (cachedWidth != nil) return cachedWidth.doubleValue;

  NSAttributedString *attributedGlyph = [[NSAttributedString alloc] initWithString:glyph attributes:variant.attributes];
  CGFloat width = measureAttributedWidth(attributedGlyph);
  variant.widthCache[@(glyph.length == 0 ? 0 : [glyph characterAtIndex:0])] = @(width);
  return width;
}

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

Handle storeGlyphField(const GlyphFieldConfig& config) {
  RNTextEngineGlyphField *field = [[RNTextEngineGlyphField alloc] init];
  field.columns = config.columns;
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

void invalidateGlyphFieldViews(RNTextEngineGlyphField *field) {
  NSArray<UIView *> *views = field.views.allObjects;
  if (views.count == 0) return;

  dispatch_block_t invalidate = ^{
    for (UIView *view in views) {
      [view setNeedsDisplay];
    }
  };

  if ([NSThread isMainThread]) {
    invalidate();
  } else {
    dispatch_async(dispatch_get_main_queue(), invalidate);
  }
}

Handle createGlyphField(const GlyphFieldConfig& config) {
  return storeGlyphField(config);
}

void updateGlyphField(Runtime& runtime, Handle handle, const std::string& glyphsValue, const std::vector<uint8_t>& variantIndices) {
  RNTextEngineGlyphField *field = getGlyphField(runtime, handle);
  size_t cellCount = static_cast<size_t>(field.columns * field.rows);
  NSString *glyphs = toNSString(glyphsValue);
  if (glyphs.length != static_cast<NSInteger>(cellCount)) {
    throw JSError(runtime, "RNTextEngine: glyph field glyphs length must match columns * rows.");
  }
  if (variantIndices.size() != cellCount) {
    throw JSError(runtime, "RNTextEngine: glyph field variantIndices length must match columns * rows.");
  }

  for (uint8_t variantIndex : variantIndices) {
    if (variantIndex >= field.variants.count) {
      throw JSError(runtime, "RNTextEngine: glyph field variant index exceeded the configured variant count.");
    }
  }

  field.glyphs = glyphs;
  field.variantIndices = [NSData dataWithBytes:variantIndices.data() length:variantIndices.size()];
  invalidateGlyphFieldViews(field);
}

void releaseGlyphFieldHandle(Handle handle) {
  std::lock_guard<std::mutex> lock(glyphFieldMutex);
  [glyphFields removeObjectForKey:toKey(handle)];
}

CGFloat glyphFieldRowWidth(RNTextEngineGlyphField *field, NSUInteger rowIndex) {
  const uint8_t *variantIndices = static_cast<const uint8_t *>(field.variantIndices.bytes);
  if (variantIndices == nullptr) return 0;

  CGFloat width = 0;
  NSUInteger rowStart = rowIndex * field.columns;
  for (NSInteger column = 0; column < field.columns; column += 1) {
    NSUInteger cellIndex = rowStart + column;
    unichar glyphCharacter = [field.glyphs characterAtIndex:cellIndex];
    RNTextEngineGlyphFieldVariant *variant = field.variants[variantIndices[cellIndex]];
    width += measureGlyphWidth(variant, glyphStringForCharacter(glyphCharacter));
  }
  return width;
}

CGFloat glyphFieldRowOriginX(RNTextEngineGlyphField *field, CGRect bounds, CGFloat rowWidth) {
  if (field.textAlign == NSTextAlignmentRight) return CGRectGetWidth(bounds) - rowWidth;
  if (field.textAlign == NSTextAlignmentCenter) return (CGRectGetWidth(bounds) - rowWidth) * 0.5;
  return 0;
}

NSString *trimTrailingWhitespace(NSString *text) {
  NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
  NSInteger end = text.length;
  while (end > 0 && [whitespace characterIsMember:[text characterAtIndex:end - 1]]) {
    end -= 1;
  }
  return end == text.length ? text : [text substringToIndex:end];
}

Runtime *extractRuntimeFromToken(Runtime& runtime, const Value& value) {
  if (!value.isObject()) {
    throw JSError(runtime, "RNTextEngine: runtime token must be an ArrayBuffer.");
  }

  Object object = value.asObject(runtime);
  if (!object.isArrayBuffer(runtime)) {
    throw JSError(runtime, "RNTextEngine: runtime token must be an ArrayBuffer.");
  }

  ArrayBuffer buffer = object.getArrayBuffer(runtime);
  if (buffer.size(runtime) < sizeof(uintptr_t)) {
    throw JSError(runtime, "RNTextEngine: runtime token had an invalid size.");
  }

  uintptr_t pointer = 0;
  std::memcpy(&pointer, buffer.data(runtime), sizeof(uintptr_t));
  return reinterpret_cast<Runtime *>(pointer);
}

Value buildNextLineValue(Runtime& runtime, RNTextEnginePreparedText *prepared, NSInteger start, double width) {
  NSInteger textLength = prepared.text.length;
  if (start >= textLength) return Value::null();
  if (start < 0) start = 0;

  NSRange range = NSMakeRange(start, textLength - start);
  NSString *substring = [prepared.text substringWithRange:range];
  NSAttributedString *attributedSubstring = [prepared.attributedText attributedSubstringFromRange:range];

  NSTextStorage *textStorage = [[NSTextStorage alloc] initWithAttributedString:attributedSubstring];
  NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
  NSTextContainer *textContainer = [[NSTextContainer alloc] initWithSize:CGSizeMake(MAX(width, 0), CGFLOAT_MAX)];
  textContainer.lineFragmentPadding = 0;
  textContainer.lineBreakMode = NSLineBreakByWordWrapping;
  textContainer.maximumNumberOfLines = 1;

  [layoutManager addTextContainer:textContainer];
  [textStorage addLayoutManager:layoutManager];
  [layoutManager ensureLayoutForTextContainer:textContainer];

  if (layoutManager.numberOfGlyphs == 0) return Value::null();

  NSRange glyphRange = NSMakeRange(0, 0);
  CGRect usedRect = [layoutManager lineFragmentUsedRectForGlyphAtIndex:0 effectiveRange:&glyphRange];
  NSRange charRange = [layoutManager characterRangeForGlyphRange:glyphRange actualGlyphRange:nil];

  NSString *lineString = trimTrailingWhitespace([substring substringWithRange:charRange]);
  NSInteger visibleEnd = start + lineString.length;

  Object line(runtime);
  line.setProperty(runtime, "start", static_cast<double>(start));
  line.setProperty(runtime, "end", static_cast<double>(visibleEnd));
  line.setProperty(runtime, "width", CGRectGetWidth(usedRect));
  line.setProperty(runtime, "bottom", CGRectGetMaxY(usedRect));
  return line;
}

NSLineBreakMode resolveLineBreakMode(const LayoutOptions& options) {
  if (!options.maxLines.has_value()) return NSLineBreakByWordWrapping;
  if (!options.ellipsizeMode.has_value()) return NSLineBreakByTruncatingTail;

  const std::string& mode = *options.ellipsizeMode;
  if (mode == "clip") return NSLineBreakByClipping;
  if (mode == "head") return NSLineBreakByTruncatingHead;
  if (mode == "middle") return NSLineBreakByTruncatingMiddle;
  return NSLineBreakByTruncatingTail;
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

Value layoutAttributedText(Runtime& runtime, NSString *text, NSAttributedString *attributedText, CGFloat fallbackLineHeight, const LayoutOptions& options, bool includeLines) {
  if (text.length == 0) {
    Object empty = buildLayoutObject(runtime, 0, fallbackLineHeight, 0, 0);
    if (includeLines) empty.setProperty(runtime, "lines", Array(runtime, 0));
    return empty;
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
  NSInteger lineCount = 0;
  std::vector<Object> collectedLines;

  NSUInteger glyphIndex = 0;
  while (glyphIndex < layoutManager.numberOfGlyphs) {
    NSRange glyphRange = NSMakeRange(0, 0);
    CGRect usedRect = [layoutManager lineFragmentUsedRectForGlyphAtIndex:glyphIndex effectiveRange:&glyphRange];
    NSRange charRange = [layoutManager characterRangeForGlyphRange:glyphRange actualGlyphRange:nil];

    NSString *lineString = trimTrailingWhitespace([text substringWithRange:charRange]);
    NSInteger visibleEnd = static_cast<NSInteger>(charRange.location + lineString.length);

    lineCount += 1;
    measuredWidth = MAX(measuredWidth, CGRectGetWidth(usedRect));
    measuredHeight = MAX(measuredHeight, CGRectGetMaxY(usedRect));
    lastLineWidth = CGRectGetWidth(usedRect);

    if (includeLines) {
      Object line(runtime);
      line.setProperty(runtime, "index", static_cast<double>(lineCount - 1));
      line.setProperty(runtime, "start", static_cast<double>(charRange.location));
      line.setProperty(runtime, "end", static_cast<double>(visibleEnd));
      line.setProperty(runtime, "width", CGRectGetWidth(usedRect));
      line.setProperty(runtime, "bottom", CGRectGetMaxY(usedRect));
      collectedLines.push_back(std::move(line));
    }

    glyphIndex = NSMaxRange(glyphRange);
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
  std::lock_guard<std::mutex> lock(preparedMutex);
  return preparedTexts[toKey(handle)].attributedText;
}

void releaseHandle(Handle handle) {
  std::lock_guard<std::mutex> lock(preparedMutex);
  [preparedTexts removeObjectForKey:toKey(handle)];
}

void releaseHandles(const std::vector<Handle>& handles) {
  std::lock_guard<std::mutex> lock(preparedMutex);
  for (Handle handle : handles) {
    [preparedTexts removeObjectForKey:toKey(handle)];
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

std::vector<std::string> parseStringArray(Runtime& runtime, const Value& value) {
  if (!value.isObject() || !value.asObject(runtime).isArray(runtime)) {
    throw JSError(runtime, "RNTextEngine: expected an array of strings.");
  }

  Array array = value.asObject(runtime).asArray(runtime);
  std::vector<std::string> texts;
  texts.reserve(array.size(runtime));
  for (size_t i = 0; i < array.size(runtime); i++) {
    Value item = array.getValueAtIndex(runtime, i);
    if (!item.isString()) {
      throw JSError(runtime, "RNTextEngine: batch text input must contain strings only.");
    }
    texts.push_back(item.asString(runtime).utf8(runtime));
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

} // namespace

NSAttributedString *preparedAttributedTextForHandle(uint64_t handle) {
  return preparedAttributedTextForHandleLocked(static_cast<Handle>(handle));
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

void drawGlyphFieldHandle(uint64_t handle, CGContextRef context, CGRect bounds) {
  if (handle == 0 || context == nullptr) return;

  RNTextEngineGlyphField *field = getGlyphFieldIfPresent(static_cast<Handle>(handle));
  if (field == nil || field.glyphs.length == 0 || field.variantIndices.length == 0) return;

  CGFloat contentHeight = field.rows * field.lineHeight;
  CGFloat topInset = MAX(0, (CGRectGetHeight(bounds) - contentHeight) * 0.5);
  const uint8_t *variantIndices = static_cast<const uint8_t *>(field.variantIndices.bytes);
  if (variantIndices == nullptr) return;

  for (NSInteger row = 0; row < field.rows; row += 1) {
    CGFloat rowWidth = glyphFieldRowWidth(field, row);
    CGFloat x = glyphFieldRowOriginX(field, bounds, rowWidth);
    NSUInteger rowStart = static_cast<NSUInteger>(row * field.columns);

    for (NSInteger column = 0; column < field.columns; column += 1) {
      NSUInteger cellIndex = rowStart + static_cast<NSUInteger>(column);
      unichar glyphCharacter = [field.glyphs characterAtIndex:cellIndex];
      RNTextEngineGlyphFieldVariant *variant = field.variants[variantIndices[cellIndex]];
      NSString *glyph = glyphStringForCharacter(glyphCharacter);
      CGFloat glyphWidth = measureGlyphWidth(variant, glyph);
      CGFloat y = topInset + row * field.lineHeight + MAX(0, (field.lineHeight - variant.font.lineHeight) * 0.5);
      [glyph drawAtPoint:CGPointMake(x, y) withAttributes:variant.attributes];
      x += glyphWidth;
    }
  }
}

void cleanup() {
  {
    std::lock_guard<std::mutex> lock(preparedMutex);
    [preparedTexts removeAllObjects];
    preparedTexts = nil;
    nextHandle = 1;
  }
  {
    std::lock_guard<std::mutex> lock(glyphFieldMutex);
    [glyphFields removeAllObjects];
    glyphFields = nil;
    nextGlyphFieldHandle = 1;
  }
}

void install(Runtime& runtime) {
  auto installFunction = [&](const char *name, unsigned int argCount, auto fn) {
    runtime.global().setProperty(
        runtime,
        name,
        Function::createFromHostFunction(
            runtime,
            PropNameID::forAscii(runtime, name),
            argCount,
            fn));
  };

  installFunction(
      "__RNTextEngineInstallRuntime",
      1,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0) {
          throw JSError(runtime, "RNTextEngine: installRuntime() requires a runtime token.");
        }

        Runtime *targetRuntime = extractRuntimeFromToken(runtime, arguments[0]);
        if (targetRuntime == nullptr) return Value(false);

        install(*targetRuntime);
        return Value(true);
      });

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
        std::vector<uint8_t> variantIndices = parseUint8Array(runtime, arguments[2], cellCount);
        updateGlyphField(runtime, handle, glyphs, variantIndices);
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
        std::vector<std::string> texts = parseStringArray(runtime, arguments[0]);
        std::vector<std::vector<TextMeasureRun>> runsByText(texts.size());
        if (count > 2 && !arguments[2].isUndefined() && !arguments[2].isNull()) {
          if (!arguments[2].isObject() || !arguments[2].asObject(runtime).isArray(runtime)) {
            throw JSError(runtime, "RNTextEngine: batch text runs must be an array aligned with the batch text input.");
          }

          Array runsArray = arguments[2].asObject(runtime).asArray(runtime);
          if (runsArray.size(runtime) != texts.size()) {
            throw JSError(runtime, "RNTextEngine: batch text runs must align with the batch text input length.");
          }

          for (size_t index = 0; index < texts.size(); index++) {
            runsByText[index] = parseRuns(runtime, runsArray.getValueAtIndex(runtime, index), toNSString(texts[index]).length);
          }
        }

        std::vector<Handle> handles;
        handles.reserve(texts.size());
        for (size_t index = 0; index < texts.size(); index++) {
          NSString *text = toNSString(texts[index]);
          handles.push_back(storePreparedText(buildPreparedText(text, style, resolvedStyle, runsByText[index])));
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
        return layoutAttributedText(runtime, prepared.text, prepared.attributedText, prepared.fallbackLineHeight, options, false);
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
        return layoutAttributedText(runtime, prepared.text, prepared.attributedText, prepared.fallbackLineHeight, options, true);
      });

  installFunction(
      "__RNTextEngineLayoutNextLine",
      3,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count < 3 || !arguments[0].isNumber() || !arguments[1].isNumber() || !arguments[2].isNumber()) {
          throw JSError(runtime, "RNTextEngine: layoutNextLine() requires a handle, start offset, and width.");
        }
        RNTextEnginePreparedText *prepared = getPreparedText(runtime, static_cast<Handle>(arguments[0].asNumber()));
        return buildNextLineValue(
            runtime,
            prepared,
            static_cast<NSInteger>(arguments[1].asNumber()),
            arguments[2].asNumber());
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
        RNTextEnginePreparedText *prepared = buildPreparedText(text, style, resolvedStyle, runs);
        return layoutAttributedText(runtime, prepared.text, prepared.attributedText, prepared.fallbackLineHeight, options, false);
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
        std::vector<std::string> texts = parseStringArray(runtime, arguments[0]);
        std::vector<std::vector<TextMeasureRun>> runsByText(texts.size());
        if (count > 3 && !arguments[3].isUndefined() && !arguments[3].isNull()) {
          if (!arguments[3].isObject() || !arguments[3].asObject(runtime).isArray(runtime)) {
            throw JSError(runtime, "RNTextEngine: batch text runs must be an array aligned with the batch text input.");
          }

          Array runsArray = arguments[3].asObject(runtime).asArray(runtime);
          if (runsArray.size(runtime) != texts.size()) {
            throw JSError(runtime, "RNTextEngine: batch text runs must align with the batch text input length.");
          }

          for (size_t index = 0; index < texts.size(); index++) {
            runsByText[index] = parseRuns(runtime, runsArray.getValueAtIndex(runtime, index), toNSString(texts[index]).length);
          }
        }

        Array results(runtime, texts.size());
        for (size_t i = 0; i < texts.size(); i++) {
          NSString *text = toNSString(texts[i]);
          RNTextEnginePreparedText *prepared = buildPreparedText(text, style, resolvedStyle, runsByText[i]);
          results.setValueAtIndex(
              runtime,
              i,
              layoutAttributedText(runtime, prepared.text, prepared.attributedText, prepared.fallbackLineHeight, options, false));
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
          results.setValueAtIndex(
              runtime,
              i,
              layoutAttributedText(runtime, prepared.text, prepared.attributedText, prepared.fallbackLineHeight, options, false));
        }
        return results;
      });

}

} // namespace rntextengine
