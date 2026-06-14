#pragma once

#include <jsi/jsi.h>

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <UIKit/UIKit.h>
#endif

namespace rntextengine {
void cleanup();
void install(facebook::jsi::Runtime& runtime);
#ifdef __OBJC__
NSAttributedString * _Nullable preparedAttributedTextForHandle(uint64_t handle);
CGFloat preparedUniformCapHeightForHandle(uint64_t handle);
uint64_t createPreparedTextHandleForTextView(
    NSString * _Nonnull text,
    BOOL allowFontScaling,
    NSString * _Nullable fontFamily,
    CGFloat fontSize,
    NSString * _Nullable fontWeight,
    NSString * _Nullable fontStyle,
    CGFloat letterSpacing,
    CGFloat lineHeight,
    BOOL tabularNumbers,
    NSString * _Nullable textTransform,
    NSArray<NSNumber *> * _Nullable runStarts,
    NSArray<NSNumber *> * _Nullable runEnds,
    NSArray<NSNumber *> * _Nullable runStyleMasks,
    NSArray<NSString *> * _Nullable runFontFamilies,
    NSArray<NSNumber *> * _Nullable runFontSizes,
    NSArray<NSString *> * _Nullable runFontStyles,
    NSArray<NSString *> * _Nullable runFontWeights,
    NSArray<NSNumber *> * _Nullable runLetterSpacings,
    NSArray<NSNumber *> * _Nullable runLineHeights,
    NSArray<NSNumber *> * _Nullable runTabularNumbers);
CGFloat measurePreparedTextWidthForHandle(uint64_t handle);
CGSize measurePreparedTextLayoutForHandle(
    uint64_t handle,
    CGFloat width,
    NSInteger maxLines,
    NSString * _Nullable ellipsizeMode,
    BOOL anchorToCapHeight);
void releasePreparedTextHandle(uint64_t handle);
void drawGlyphFieldHandle(uint64_t handle, CGContextRef _Nonnull context, CGRect bounds, CGRect dirtyRect);
void registerGlyphFieldView(uint64_t handle, UIView * _Nullable view);
void unregisterGlyphFieldView(uint64_t handle, UIView * _Nullable view);
#endif
} // namespace rntextengine
