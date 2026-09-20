#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXTERN NSAttributedStringKey const RNTextEngineUniformCapHeightAttributeName;
FOUNDATION_EXTERN void RNTextEngineSetUniformCapHeight(NSMutableAttributedString *attributedText, CGFloat capHeight);
FOUNDATION_EXTERN CGFloat RNTextEngineUniformCapHeightForAttributedText(NSAttributedString *attributedText);
FOUNDATION_EXTERN CGFloat RNTextEngineLineBaselineForGlyphIndex(
    NSLayoutManager *layoutManager,
    NSUInteger glyphIndex,
    CGRect lineRect);
FOUNDATION_EXTERN CGFloat RNTextEngineMaxCapHeightForRange(NSAttributedString *attributedText, NSRange characterRange);
FOUNDATION_EXTERN UIEdgeInsets RNTextEngineCapHeightInsetsForLayoutManager(
    NSLayoutManager *layoutManager,
    NSTextContainer *textContainer,
    NSAttributedString *attributedText);
FOUNDATION_EXTERN UIEdgeInsets RNTextEngineCapHeightInsetsForLayoutManagerWithUniformCapHeight(
    NSLayoutManager *layoutManager,
    NSTextContainer *textContainer,
    NSAttributedString *attributedText,
    CGFloat uniformCapHeight);

NS_ASSUME_NONNULL_END
