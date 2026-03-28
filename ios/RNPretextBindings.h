#pragma once

#include <jsi/jsi.h>

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#endif

namespace rnpretext {
void cleanup();
void install(facebook::jsi::Runtime& runtime);
#ifdef __OBJC__
NSAttributedString *preparedAttributedTextForHandle(uint64_t handle);
#endif
} // namespace rnpretext
