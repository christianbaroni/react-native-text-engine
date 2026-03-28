#import "RNPretextBindings.h"

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
#define RNPRETEXT_HAS_WORKLETS 1
#else
#define RNPRETEXT_HAS_WORKLETS 0
#endif

@interface RNPretextPreparedText : NSObject
@property (nonatomic, strong) NSAttributedString *attributedText;
@property (nonatomic, strong) NSString *text;
@property (nonatomic, assign) CGFloat fallbackLineHeight;
@end

@implementation RNPretextPreparedText
@end

using namespace facebook::jsi;

namespace rnpretext {

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

struct LayoutOptions {
  std::optional<std::string> ellipsizeMode;
  std::optional<int> maxLines;
  double width = 0;
};

static std::mutex preparedMutex;
static NSMutableDictionary<NSNumber *, RNPretextPreparedText *> *preparedTexts;
static Handle nextHandle = 1;

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

LayoutOptions parseLayoutOptions(Runtime& runtime, const Value* value, size_t index, size_t count) {
  if (index >= count || !value[index].isObject()) {
    throw JSError(runtime, "RNPretext: layout options must be an object.");
  }

  LayoutOptions options;
  Object object = value[index].asObject(runtime);

  if (!object.hasProperty(runtime, "width")) {
    throw JSError(runtime, "RNPretext: layout options must include a width.");
  }

  Value width = object.getProperty(runtime, "width");
  if (!width.isNumber()) {
    throw JSError(runtime, "RNPretext: layout width must be a number.");
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

NSAttributedString *buildAttributedText(NSString *text, const TextMeasureStyle& style, CGFloat *fallbackLineHeight) {
  UIFont *font = resolveFont(style);
  CGFloat lineHeight = resolveLineHeight(style, font);
  if (fallbackLineHeight) *fallbackLineHeight = lineHeight;

  NSMutableDictionary<NSAttributedStringKey, id> *attributes =
      [NSMutableDictionary dictionaryWithObject:font forKey:NSFontAttributeName];

  if (style.hasColor) {
    UIColor *color = [RCTConvert UIColor:toNSString(style.color)];
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

  return [[NSAttributedString alloc] initWithString:text attributes:attributes];
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
    throw JSError(runtime, "RNPretext: runtime token must be an ArrayBuffer.");
  }

  Object object = value.asObject(runtime);
  if (!object.isArrayBuffer(runtime)) {
    throw JSError(runtime, "RNPretext: runtime token must be an ArrayBuffer.");
  }

  ArrayBuffer buffer = object.getArrayBuffer(runtime);
  if (buffer.size(runtime) < sizeof(uintptr_t)) {
    throw JSError(runtime, "RNPretext: runtime token had an invalid size.");
  }

  uintptr_t pointer = 0;
  std::memcpy(&pointer, buffer.data(runtime), sizeof(uintptr_t));
  return reinterpret_cast<Runtime *>(pointer);
}

Value buildNextLineValue(Runtime& runtime, RNPretextPreparedText *prepared, NSInteger start, double width) {
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

RNPretextPreparedText *buildPreparedText(NSString *text, const TextMeasureStyle& style) {
  CGFloat fallbackLineHeight = 0;
  NSAttributedString *attributedText = buildAttributedText(text, style, &fallbackLineHeight);
  RNPretextPreparedText *prepared = [[RNPretextPreparedText alloc] init];
  prepared.text = text;
  prepared.attributedText = attributedText;
  prepared.fallbackLineHeight = fallbackLineHeight;
  return prepared;
}

Handle storePreparedText(RNPretextPreparedText *prepared) {
  std::lock_guard<std::mutex> lock(preparedMutex);
  if (preparedTexts == nil) preparedTexts = [[NSMutableDictionary alloc] init];
  Handle handle = nextHandle++;
  preparedTexts[toKey(handle)] = prepared;
  return handle;
}

RNPretextPreparedText *getPreparedText(Runtime& runtime, Handle handle) {
  std::lock_guard<std::mutex> lock(preparedMutex);
  RNPretextPreparedText *prepared = preparedTexts[toKey(handle)];
  if (!prepared) {
    throw JSError(runtime, "RNPretext: attempted to use an invalid prepared text handle.");
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
    throw JSError(runtime, "RNPretext: expected an array of prepared text handles.");
  }

  Array array = value.asObject(runtime).asArray(runtime);
  std::vector<Handle> handles;
  handles.reserve(array.size(runtime));
  for (size_t i = 0; i < array.size(runtime); i++) {
    Value item = array.getValueAtIndex(runtime, i);
    if (!item.isNumber()) {
      throw JSError(runtime, "RNPretext: prepared text handles must be numeric.");
    }
    handles.push_back(static_cast<Handle>(item.asNumber()));
  }
  return handles;
}

std::vector<std::string> parseStringArray(Runtime& runtime, const Value& value) {
  if (!value.isObject() || !value.asObject(runtime).isArray(runtime)) {
    throw JSError(runtime, "RNPretext: expected an array of strings.");
  }

  Array array = value.asObject(runtime).asArray(runtime);
  std::vector<std::string> texts;
  texts.reserve(array.size(runtime));
  for (size_t i = 0; i < array.size(runtime); i++) {
    Value item = array.getValueAtIndex(runtime, i);
    if (!item.isString()) {
      throw JSError(runtime, "RNPretext: batch text input must contain strings only.");
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

void cleanup() {
  std::lock_guard<std::mutex> lock(preparedMutex);
  [preparedTexts removeAllObjects];
  preparedTexts = nil;
  nextHandle = 1;
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
      "__RNPretextInstallRuntime",
      1,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0) {
          throw JSError(runtime, "RNPretext: installRuntime() requires a runtime token.");
        }

        Runtime *targetRuntime = extractRuntimeFromToken(runtime, arguments[0]);
        if (targetRuntime == nullptr) return Value(false);

        install(*targetRuntime);
        return Value(true);
      });

#if RNPRETEXT_HAS_WORKLETS
  installFunction(
      "__RNPretextInstallWorkletRuntime",
      1,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0 || !arguments[0].isObject()) {
          throw JSError(
              runtime,
              "RNPretext: installWorkletRuntime() requires a WorkletRuntime.");
        }

        std::shared_ptr<worklets::WorkletRuntime> workletRuntime;
        try {
          workletRuntime =
              worklets::extractWorkletRuntime(runtime, arguments[0]);
        } catch (...) {
          throw JSError(
              runtime,
              "RNPretext: installWorkletRuntime() requires a WorkletRuntime.");
        }

        if (!workletRuntime) return Value(false);

        install(workletRuntime->getJSIRuntime());
        return Value(true);
      });
#endif

  installFunction(
      "__RNPretextPrepare",
      2,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0 || !arguments[0].isString()) {
          throw JSError(runtime, "RNPretext: prepare() requires a text string.");
        }
        TextMeasureStyle style = count > 1 ? parseStyle(runtime, arguments, 1, count) : TextMeasureStyle {};
        NSString *text = toNSString(arguments[0].asString(runtime).utf8(runtime));
        return static_cast<double>(storePreparedText(buildPreparedText(text, style)));
      });

  installFunction(
      "__RNPretextPrepareBatch",
      2,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0) {
          throw JSError(runtime, "RNPretext: prepareBatch() requires an array of strings.");
        }
        TextMeasureStyle style = count > 1 ? parseStyle(runtime, arguments, 1, count) : TextMeasureStyle {};
        std::vector<std::string> texts = parseStringArray(runtime, arguments[0]);
        std::vector<Handle> handles;
        handles.reserve(texts.size());
        for (const std::string& text : texts) {
          handles.push_back(storePreparedText(buildPreparedText(toNSString(text), style)));
        }
        return buildHandleArray(runtime, handles);
      });

  installFunction(
      "__RNPretextRelease",
      1,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0 || !arguments[0].isNumber()) {
          throw JSError(runtime, "RNPretext: release() requires a prepared text handle.");
        }
        releaseHandle(static_cast<Handle>(arguments[0].asNumber()));
        return Value::undefined();
      });

  installFunction(
      "__RNPretextReleaseMany",
      1,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0) {
          throw JSError(runtime, "RNPretext: releaseMany() requires an array of handles.");
        }
        releaseHandles(parseHandleArray(runtime, arguments[0]));
        return Value::undefined();
      });

  installFunction(
      "__RNPretextMeasureWidth",
      2,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0 || !arguments[0].isString()) {
          throw JSError(runtime, "RNPretext: measureWidth() requires a text string.");
        }
        TextMeasureStyle style = count > 1 ? parseStyle(runtime, arguments, 1, count) : TextMeasureStyle {};
        NSString *text = toNSString(arguments[0].asString(runtime).utf8(runtime));
        CGFloat fallbackLineHeight = 0;
        NSAttributedString *attributed = buildAttributedText(text, style, &fallbackLineHeight);
        return measureAttributedWidth(attributed);
      });

  installFunction(
      "__RNPretextLayout",
      2,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0 || !arguments[0].isNumber()) {
          throw JSError(runtime, "RNPretext: layout() requires a prepared text handle.");
        }
        LayoutOptions options = parseLayoutOptions(runtime, arguments, 1, count);
        RNPretextPreparedText *prepared = getPreparedText(runtime, static_cast<Handle>(arguments[0].asNumber()));
        return layoutAttributedText(runtime, prepared.text, prepared.attributedText, prepared.fallbackLineHeight, options, false);
      });

  installFunction(
      "__RNPretextLayoutLines",
      2,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0 || !arguments[0].isNumber()) {
          throw JSError(runtime, "RNPretext: layoutLines() requires a prepared text handle.");
        }
        LayoutOptions options = parseLayoutOptions(runtime, arguments, 1, count);
        RNPretextPreparedText *prepared = getPreparedText(runtime, static_cast<Handle>(arguments[0].asNumber()));
        return layoutAttributedText(runtime, prepared.text, prepared.attributedText, prepared.fallbackLineHeight, options, true);
      });

  installFunction(
      "__RNPretextLayoutNextLine",
      3,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count < 3 || !arguments[0].isNumber() || !arguments[1].isNumber() || !arguments[2].isNumber()) {
          throw JSError(runtime, "RNPretext: layoutNextLine() requires a handle, start offset, and width.");
        }
        RNPretextPreparedText *prepared = getPreparedText(runtime, static_cast<Handle>(arguments[0].asNumber()));
        return buildNextLineValue(
            runtime,
            prepared,
            static_cast<NSInteger>(arguments[1].asNumber()),
            arguments[2].asNumber());
      });

  installFunction(
      "__RNPretextMeasure",
      3,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0 || !arguments[0].isString()) {
          throw JSError(runtime, "RNPretext: measure() requires a text string.");
        }
        TextMeasureStyle style = count > 1 ? parseStyle(runtime, arguments, 1, count) : TextMeasureStyle {};
        LayoutOptions options = parseLayoutOptions(runtime, arguments, 2, count);
        NSString *text = toNSString(arguments[0].asString(runtime).utf8(runtime));
        RNPretextPreparedText *prepared = buildPreparedText(text, style);
        return layoutAttributedText(runtime, prepared.text, prepared.attributedText, prepared.fallbackLineHeight, options, false);
      });

  installFunction(
      "__RNPretextMeasureBatch",
      3,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0) {
          throw JSError(runtime, "RNPretext: measureBatch() requires an array of strings.");
        }
        TextMeasureStyle style = count > 1 ? parseStyle(runtime, arguments, 1, count) : TextMeasureStyle {};
        LayoutOptions options = parseLayoutOptions(runtime, arguments, 2, count);
        std::vector<std::string> texts = parseStringArray(runtime, arguments[0]);
        Array results(runtime, texts.size());
        for (size_t i = 0; i < texts.size(); i++) {
          RNPretextPreparedText *prepared = buildPreparedText(toNSString(texts[i]), style);
          results.setValueAtIndex(
              runtime,
              i,
              layoutAttributedText(runtime, prepared.text, prepared.attributedText, prepared.fallbackLineHeight, options, false));
        }
        return results;
      });

  installFunction(
      "__RNPretextLayoutBatch",
      2,
      [](Runtime& runtime, const Value&, const Value* arguments, size_t count) -> Value {
        if (count == 0) {
          throw JSError(runtime, "RNPretext: layoutBatch() requires an array of handles.");
        }
        LayoutOptions options = parseLayoutOptions(runtime, arguments, 1, count);
        std::vector<Handle> handles = parseHandleArray(runtime, arguments[0]);
        Array results(runtime, handles.size());
        for (size_t i = 0; i < handles.size(); i++) {
          RNPretextPreparedText *prepared = getPreparedText(runtime, handles[i]);
          results.setValueAtIndex(
              runtime,
              i,
              layoutAttributedText(runtime, prepared.text, prepared.attributedText, prepared.fallbackLineHeight, options, false));
        }
        return results;
      });

}

} // namespace rnpretext
