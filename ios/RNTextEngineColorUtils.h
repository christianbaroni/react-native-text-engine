#import <UIKit/UIKit.h>
#import <React/RCTConvert.h>

NS_ASSUME_NONNULL_BEGIN

static inline BOOL RNTextEngineScanCGFloat(NSScanner *scanner, CGFloat *value)
{
  double parsed = 0;
  if (![scanner scanDouble:&parsed]) return NO;
  *value = (CGFloat)parsed;
  return YES;
}

static inline CGFloat RNTextEngineClampColorComponent(CGFloat value, CGFloat minValue, CGFloat maxValue)
{
  return MIN(MAX(value, minValue), maxValue);
}

static inline UIColor * _Nullable RNTextEngineParseRGBFunction(NSString *string)
{
  NSScanner *scanner = [NSScanner scannerWithString:string.lowercaseString];
  scanner.charactersToBeSkipped = [NSCharacterSet whitespaceAndNewlineCharacterSet];

  BOOL hasAlpha = NO;
  if ([scanner scanString:@"rgba(" intoString:nil]) {
    hasAlpha = YES;
  } else if (![scanner scanString:@"rgb(" intoString:nil]) {
    return nil;
  }

  CGFloat red = 0;
  CGFloat green = 0;
  CGFloat blue = 0;
  CGFloat alpha = 1;
  if (!RNTextEngineScanCGFloat(scanner, &red)) return nil;
  if (![scanner scanString:@"," intoString:nil]) return nil;
  if (!RNTextEngineScanCGFloat(scanner, &green)) return nil;
  if (![scanner scanString:@"," intoString:nil]) return nil;
  if (!RNTextEngineScanCGFloat(scanner, &blue)) return nil;

  if (hasAlpha) {
    if (![scanner scanString:@"," intoString:nil]) return nil;
    if (!RNTextEngineScanCGFloat(scanner, &alpha)) return nil;
  }

  if (![scanner scanString:@")" intoString:nil] || !scanner.isAtEnd) return nil;

  return [UIColor colorWithRed:RNTextEngineClampColorComponent(red, 0, 255) / 255.0
                         green:RNTextEngineClampColorComponent(green, 0, 255) / 255.0
                          blue:RNTextEngineClampColorComponent(blue, 0, 255) / 255.0
                         alpha:RNTextEngineClampColorComponent(alpha, 0, 1)];
}

static inline UIColor * _Nullable RNTextEngineParseHexColor(NSString *string)
{
  if (![string hasPrefix:@"#"]) return nil;

  NSString *hex = [string substringFromIndex:1];
  unsigned long long parsed = 0;
  NSScanner *scanner = [NSScanner scannerWithString:hex];
  if (![scanner scanHexLongLong:&parsed]) return nil;

  CGFloat alpha = 1;
  CGFloat red = 0;
  CGFloat green = 0;
  CGFloat blue = 0;

  if (hex.length == 3) {
    red = ((parsed >> 8) & 0xF) / 15.0;
    green = ((parsed >> 4) & 0xF) / 15.0;
    blue = (parsed & 0xF) / 15.0;
  } else if (hex.length == 6) {
    red = ((parsed >> 16) & 0xFF) / 255.0;
    green = ((parsed >> 8) & 0xFF) / 255.0;
    blue = (parsed & 0xFF) / 255.0;
  } else if (hex.length == 8) {
    alpha = ((parsed >> 24) & 0xFF) / 255.0;
    red = ((parsed >> 16) & 0xFF) / 255.0;
    green = ((parsed >> 8) & 0xFF) / 255.0;
    blue = (parsed & 0xFF) / 255.0;
  } else {
    return nil;
  }

  return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}

static inline UIColor * _Nullable RNTextEngineResolveColorValue(id _Nullable value)
{
  if (value == nil || value == (id)kCFNull) return nil;
  if (![value isKindOfClass:[NSString class]]) {
    return [RCTConvert UIColor:value];
  }

  NSString *string = [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if (string.length == 0) return nil;

  UIColor *color = RNTextEngineParseRGBFunction(string);
  if (color != nil) return color;

  color = RNTextEngineParseHexColor(string);
  if (color != nil) return color;

  return [RCTConvert UIColor:string];
}

NS_ASSUME_NONNULL_END
