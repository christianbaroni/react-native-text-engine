#import <UIKit/UIKit.h>

#import "RNTextEngineTextLayoutMetrics.h"

NS_ASSUME_NONNULL_BEGIN

@interface RNTextEngineAttributedTextDisplayView : UIView

@property (nonatomic, copy, null_resettable) NSAttributedString *attributedText;
@property (nonatomic, assign) UIEdgeInsets contentInsets;
@property (nonatomic, copy, nullable) NSString *ellipsizeMode;
@property (nonatomic, assign) NSInteger numberOfLines;
@property (nonatomic, assign) NSTextAlignment textAlignment;
@property (nonatomic, assign) CGFloat uniformCapHeight;

- (CGFloat)capHeightTopInsetForSize:(CGSize)size;
- (UIEdgeInsets)capHeightInsetsForWidth:(CGFloat)width;

@end

@protocol RNTextEngineAccessibilityOwner <NSObject>
- (BOOL)isTextAccessibilityElement;
- (nullable NSString *)explicitAccessibilityLabel;
@end

FOUNDATION_EXTERN NSLineBreakMode RNTextEngineResolveLineBreakMode(
    NSInteger numberOfLines,
    NSString * _Nullable ellipsizeMode);
FOUNDATION_EXTERN UITextView *RNTextEngineCreateInteractionTextView(UIView<RNTextEngineAccessibilityOwner> *view);
FOUNDATION_EXTERN void RNTextEngineApplyInteractionTextViewFrame(
    UITextView *textView,
    CGRect frame,
    UIEdgeInsets contentInsets);

NS_ASSUME_NONNULL_END
