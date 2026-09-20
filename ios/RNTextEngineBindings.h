#pragma once

#include <jsi/jsi.h>

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <UIKit/UIKit.h>
#import "RNTextEngineTextAttributes.h"
@class RNTextEnginePreparedText;
#endif

namespace rntextengine {
void cleanup();
void install(facebook::jsi::Runtime& runtime);
#ifdef __OBJC__
RNTextEnginePreparedText * _Nonnull prepareAttributedText(NSAttributedString * _Nonnull text, CGFloat emptyLineHeight, NSTextAlignment alignment);
CGFloat measurePreparedTextWidth(RNTextEnginePreparedText * _Nonnull prepared);
CGSize measurePreparedTextLayout(
    RNTextEnginePreparedText * _Nonnull prepared,
    CGFloat width,
    NSInteger maxLines,
    NSString * _Nullable ellipsizeMode,
    BOOL anchorToCapHeight);
NSAttributedString * _Nullable preparedAttributedTextForHandle(uint64_t handle);
CGFloat preparedUniformCapHeightForHandle(uint64_t handle);
uint64_t createPreparedTextHandleForTextView(
    NSString * _Nonnull text,
    const RNTextEngineTextAttributes &attributes,
    const std::vector<RNTextEngineTextRun> &runs = {},
    NSString * _Nullable textTransform = nil);
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
