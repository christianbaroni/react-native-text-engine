#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RNTextEngineTextTransformResult : NSObject

@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy, nullable) NSArray<NSNumber *> *runEnds;
@property (nonatomic, copy, nullable) NSArray<NSNumber *> *runStarts;

@end

FOUNDATION_EXTERN NSString *RNTextEngineApplyTextTransform(NSString *text, NSString * _Nullable textTransform);
FOUNDATION_EXTERN RNTextEngineTextTransformResult *RNTextEngineTransformText(
    NSString *text,
    NSString * _Nullable textTransform,
    NSArray<NSNumber *> * _Nullable runStarts,
    NSArray<NSNumber *> * _Nullable runEnds);

NS_ASSUME_NONNULL_END
