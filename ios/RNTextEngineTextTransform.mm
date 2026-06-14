#import "RNTextEngineTextTransform.h"

@implementation RNTextEngineTextTransformResult
@end

namespace {

BOOL RNTextEngineUsesIdentityTextTransform(NSString *textTransform)
{
  return textTransform.length == 0 || [textTransform isEqualToString:@"none"];
}

NSString *RNTextEngineCapitalizeText(NSString *text)
{
  return [text capitalizedStringWithLocale:NSLocale.currentLocale];
}

NSInteger RNTextEngineResolveTransformedOffset(
    NSString *text,
    NSString *transformedText,
    NSString *textTransform,
    NSInteger originalOffset)
{
  if (originalOffset <= 0) return 0;
  if (originalOffset >= text.length) return transformedText.length;
  return RNTextEngineApplyTextTransform([text substringToIndex:originalOffset], textTransform).length;
}

} // namespace

NSString *RNTextEngineApplyTextTransform(NSString *text, NSString *textTransform)
{
  if (RNTextEngineUsesIdentityTextTransform(textTransform)) return text ?: @"";
  if ([textTransform isEqualToString:@"uppercase"]) return text.uppercaseString;
  if ([textTransform isEqualToString:@"lowercase"]) return text.lowercaseString;
  if ([textTransform isEqualToString:@"capitalize"]) return RNTextEngineCapitalizeText(text ?: @"");
  return text ?: @"";
}

RNTextEngineTextTransformResult *RNTextEngineTransformText(
    NSString *text,
    NSString *textTransform,
    NSArray<NSNumber *> *runStarts,
    NSArray<NSNumber *> *runEnds)
{
  NSString *resolvedText = text ?: @"";
  RNTextEngineTextTransformResult *result = [RNTextEngineTextTransformResult new];
  result.text = RNTextEngineApplyTextTransform(resolvedText, textTransform);
  result.runStarts = [runStarts copy];
  result.runEnds = [runEnds copy];

  if (RNTextEngineUsesIdentityTextTransform(textTransform) || runStarts.count == 0 || runEnds.count == 0 || resolvedText.length == 0) {
    return result;
  }

  NSMutableIndexSet *boundaries = [NSMutableIndexSet indexSetWithIndex:0];
  [boundaries addIndex:resolvedText.length];

  for (NSNumber *value in runStarts) {
    NSInteger boundary = value.integerValue;
    if (boundary >= 0 && boundary <= resolvedText.length) [boundaries addIndex:(NSUInteger)boundary];
  }

  for (NSNumber *value in runEnds) {
    NSInteger boundary = value.integerValue;
    if (boundary >= 0 && boundary <= resolvedText.length) [boundaries addIndex:(NSUInteger)boundary];
  }

  NSMutableDictionary<NSNumber *, NSNumber *> *offsetsByBoundary = [NSMutableDictionary dictionary];
  [boundaries enumerateIndexesUsingBlock:^(NSUInteger boundary, __unused BOOL *stop) {
    offsetsByBoundary[@(boundary)] = @(RNTextEngineResolveTransformedOffset(resolvedText, result.text, textTransform, (NSInteger)boundary));
  }];

  NSMutableArray<NSNumber *> *mappedStarts = [NSMutableArray arrayWithCapacity:runStarts.count];
  for (NSNumber *value in runStarts) {
    NSNumber *mapped = offsetsByBoundary[value];
    [mappedStarts addObject:mapped ?: value];
  }

  NSMutableArray<NSNumber *> *mappedEnds = [NSMutableArray arrayWithCapacity:runEnds.count];
  for (NSNumber *value in runEnds) {
    NSNumber *mapped = offsetsByBoundary[value];
    [mappedEnds addObject:mapped ?: value];
  }

  result.runStarts = mappedStarts;
  result.runEnds = mappedEnds;
  return result;
}
