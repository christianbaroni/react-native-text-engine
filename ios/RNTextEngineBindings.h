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
NSAttributedString *preparedAttributedTextForHandle(uint64_t handle);
void drawGlyphFieldHandle(uint64_t handle, CGContextRef context, CGRect bounds);
void registerGlyphFieldView(uint64_t handle, UIView *view);
void unregisterGlyphFieldView(uint64_t handle, UIView *view);
#endif
} // namespace rntextengine
