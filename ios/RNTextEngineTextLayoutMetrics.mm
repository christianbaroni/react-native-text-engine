#import "RNTextEngineTextLayoutMetrics.h"

NSAttributedStringKey const RNTextEngineUniformCapHeightAttributeName = @"RNTextEngineUniformCapHeight";

static CGFloat RNTextEngineCapHeightEpsilon = 0.001;

void RNTextEngineSetUniformCapHeight(NSMutableAttributedString *attributedText, CGFloat capHeight)
{
  if (attributedText.length == 0) return;
  [attributedText addAttribute:RNTextEngineUniformCapHeightAttributeName
                         value:@(capHeight)
                         range:NSMakeRange(0, attributedText.length)];
}

void RNTextEngineAnnotateUniformCapHeight(NSMutableAttributedString *attributedText)
{
  if (attributedText.length == 0) return;

  __block CGFloat uniformCapHeight = -1;
  __block BOOL isUniform = YES;

  [attributedText enumerateAttribute:NSFontAttributeName
                             inRange:NSMakeRange(0, attributedText.length)
                             options:0
                          usingBlock:^(id value, NSRange, BOOL *stop) {
    UIFont *font = [value isKindOfClass:[UIFont class]] ? (UIFont *)value : nil;
    if (font == nil) return;

    CGFloat capHeight = font.capHeight;
    if (uniformCapHeight < 0) {
      uniformCapHeight = capHeight;
      return;
    }

    if (fabs(uniformCapHeight - capHeight) <= RNTextEngineCapHeightEpsilon) return;
    isUniform = NO;
    *stop = YES;
  }];

  if (!isUniform || uniformCapHeight < 0) {
    [attributedText removeAttribute:RNTextEngineUniformCapHeightAttributeName
                              range:NSMakeRange(0, attributedText.length)];
    return;
  }

  RNTextEngineSetUniformCapHeight(attributedText, uniformCapHeight);
}

CGFloat RNTextEngineUniformCapHeightForAttributedText(NSAttributedString *attributedText)
{
  if (attributedText.length == 0) return 0;

  NSNumber *value = [attributedText attribute:RNTextEngineUniformCapHeightAttributeName
                                      atIndex:0
                               effectiveRange:nil];
  return [value isKindOfClass:[NSNumber class]] ? value.doubleValue : 0;
}

CGFloat RNTextEngineLineBaselineForGlyphIndex(
    NSLayoutManager *layoutManager,
    NSUInteger glyphIndex,
    CGRect lineRect)
{
  return CGRectGetMinY(lineRect) + [layoutManager locationForGlyphAtIndex:glyphIndex].y;
}

CGFloat RNTextEngineMaxCapHeightForRange(NSAttributedString *attributedText, NSRange characterRange)
{
  CGFloat uniformCapHeight = RNTextEngineUniformCapHeightForAttributedText(attributedText);
  if (uniformCapHeight > 0) return uniformCapHeight;

  __block CGFloat maxCapHeight = 0;

  [attributedText enumerateAttribute:NSFontAttributeName
                             inRange:characterRange
                             options:0
                          usingBlock:^(id value, NSRange, BOOL *) {
    UIFont *font = [value isKindOfClass:[UIFont class]] ? (UIFont *)value : nil;
    if (font != nil) {
      maxCapHeight = MAX(maxCapHeight, font.capHeight);
    }
  }];

  return maxCapHeight;
}

static CGFloat RNTextEngineResolveMaxCapHeightForRange(
    NSAttributedString *attributedText,
    NSRange characterRange,
    CGFloat uniformCapHeight)
{
  if (uniformCapHeight > 0) return uniformCapHeight;
  return RNTextEngineMaxCapHeightForRange(attributedText, characterRange);
}

UIEdgeInsets RNTextEngineCapHeightInsetsForLayoutManager(
    NSLayoutManager *layoutManager,
    NSTextContainer *textContainer,
    NSAttributedString *attributedText)
{
  return RNTextEngineCapHeightInsetsForLayoutManagerWithUniformCapHeight(
      layoutManager,
      textContainer,
      attributedText,
      0);
}

UIEdgeInsets RNTextEngineCapHeightInsetsForLayoutManagerWithUniformCapHeight(
    NSLayoutManager *layoutManager,
    NSTextContainer *textContainer,
    NSAttributedString *attributedText,
    CGFloat uniformCapHeight)
{
  if (attributedText.length == 0) return UIEdgeInsetsZero;

  NSRange visibleGlyphRange = [layoutManager glyphRangeForTextContainer:textContainer];
  if (visibleGlyphRange.length == 0) return UIEdgeInsetsZero;

  CGFloat measuredHeight = 0;
  CGFloat topInset = 0;
  CGFloat lastBaseline = 0;
  BOOL resolvedFirstLine = NO;
  NSUInteger glyphIndex = visibleGlyphRange.location;

  while (glyphIndex < NSMaxRange(visibleGlyphRange)) {
    NSRange lineGlyphRange = NSMakeRange(0, 0);
    CGRect lineRect = [layoutManager lineFragmentRectForGlyphAtIndex:glyphIndex effectiveRange:&lineGlyphRange];
    if (lineGlyphRange.length == 0) break;

    CGRect usedRect = [layoutManager lineFragmentUsedRectForGlyphAtIndex:glyphIndex effectiveRange:nil];
    NSRange characterRange = [layoutManager characterRangeForGlyphRange:lineGlyphRange actualGlyphRange:nil];
    CGFloat baseline = RNTextEngineLineBaselineForGlyphIndex(layoutManager, glyphIndex, lineRect);

    if (!resolvedFirstLine && characterRange.length > 0) {
      topInset = MAX(0, baseline - RNTextEngineResolveMaxCapHeightForRange(attributedText, characterRange, uniformCapHeight));
      resolvedFirstLine = YES;
    }

    lastBaseline = baseline;
    measuredHeight = MAX(measuredHeight, CGRectGetMaxY(usedRect));
    glyphIndex = NSMaxRange(lineGlyphRange);
  }

  if (!resolvedFirstLine) return UIEdgeInsetsZero;
  return UIEdgeInsetsMake(topInset, 0, MAX(0, measuredHeight - lastBaseline), 0);
}
