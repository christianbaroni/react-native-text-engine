#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import <React/RCTView.h>
#import <React/UIView+React.h>
#import <objc/runtime.h>
#import "RNTextEngineTextViewTestHelpers.h"

#include <initializer_list>

#ifdef RCT_NEW_ARCH_ENABLED
#import "../../../ios/RNTextEngineBindings.h"
#import "../../../ios/RNTextEngineAttributedTextDisplayView.h"
#import <React/RCTConversions.h>
#import <React/RCTUtils.h>
#import <React/RCTViewComponentView.h>

#include <atomic>
#include <cmath>
#include <thread>

using namespace facebook;
using namespace facebook::react;
using namespace rntextengine::test;

namespace {

static void WithMethodImplementation(Class owner, SEL selector, id implementation, dispatch_block_t body)
{
  Method method = class_getInstanceMethod(owner, selector);
  IMP replacement = imp_implementationWithBlock(implementation);
  IMP previous = method_setImplementation(method, replacement);
  @try {
    body();
  } @finally {
    method_setImplementation(method, previous);
    imp_removeBlock(replacement);
  }
}

static UIView<RCTComponentViewProtocol> *MountTextViewNode(const RNTextEngineTextViewShadowNode &node)
{
  UIView<RCTComponentViewProtocol> *view = [NSClassFromString(@"RNTextEngineTextViewComponentView") new];
  [view updateProps:node.getProps() oldProps:nullptr];
  [view updateEventEmitter:node.getEventEmitter()];
  [view updateState:node.getState() oldState:nullptr];
  auto metrics = node.getLayoutMetrics();
  metrics.frame.size = {.width = 260, .height = 640};
  [view updateLayoutMetrics:metrics oldLayoutMetrics:EmptyLayoutMetrics];
  [view finalizeUpdates:RNComponentViewUpdateMaskAll];
  [view layoutIfNeeded];
  return view;
}

static RNTextEngineAttributedTextDisplayView *TextViewDisplay(UIView *component)
{
  return [[component valueForKey:@"textView"] valueForKey:@"displayView"];
}

static NSData *ViewPixels(UIView *view, UIUserInterfaceStyle appearance)
{
  view.overrideUserInterfaceStyle = appearance;
  UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
  format.scale = UIScreen.mainScreen.scale;
  format.opaque = NO;
  UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithBounds:view.bounds format:format];
  UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
    [view.layer renderInContext:context.CGContext];
  }];
  return UIImagePNGRepresentation(image);
}

} // namespace
#endif

@interface RNTextEngineTextViewTests : XCTestCase
@end

@implementation RNTextEngineTextViewTests

- (void)testPreparedContentPreservesFabricPropsAndStateOrdering
{
#ifdef RCT_NEW_ARCH_ENABLED
  auto registry = BuildComponentDescriptorRegistry();
  auto context = BuildFabricLayoutContext();
  auto props = BuildTextViewProps("Prepared typography survives unrelated updates.", {.fontSize = 17, .lineHeight = 24}, 260);
  auto node = BuildShadowNode(registry, Element<RNTextEngineTextViewShadowNode>().props(props));
  const auto initialSize = node->measureContent(context, BuildLayoutConstraints(260));
  node->layout(context);
  auto content = node->getStateData().content;
  XCTAssertTrue(content != nullptr);
  XCTAssertFalse([content->attributedText isKindOfClass:NSMutableAttributedString.class]);

  UIView<RCTComponentViewProtocol> *view = MountTextViewNode(*node);
  UIView<RCTComponentViewProtocol> *secondView = MountTextViewNode(*node);
  XCTAssertTrue(TextViewDisplay(view).attributedText == content->attributedText);
  XCTAssertTrue(TextViewDisplay(secondView).attributedText == content->attributedText);
  XCTAssertFalse([TextViewDisplay(view) valueForKey:@"layoutManager"] ==
                 [TextViewDisplay(secondView) valueForKey:@"layoutManager"]);

  NSData *originalPixels = ViewPixels(TextViewDisplay(view), UIUserInterfaceStyleLight);
  auto selectableProps = std::make_shared<RNTextEngineTextViewProps>(*props);
  selectableProps->selectable = true;
  [view updateProps:selectableProps oldProps:props];
  [view finalizeUpdates:RNComponentViewUpdateMaskProps];
  [view layoutIfNeeded];
  XCTAssertNotNil([[view valueForKey:@"textView"] valueForKey:@"interactionTextView"]);
  XCTAssertTrue(TextViewDisplay(view).hidden);
  [view updateProps:props oldProps:selectableProps];
  [view finalizeUpdates:RNComponentViewUpdateMaskProps];
  [view layoutIfNeeded];
  XCTAssertNil([[view valueForKey:@"textView"] valueForKey:@"interactionTextView"]);
  XCTAssertFalse(TextViewDisplay(view).hidden);
  XCTAssertEqualObjects(ViewPixels(TextViewDisplay(view), UIUserInterfaceStyleLight), originalPixels);

  auto unrelatedProps = std::make_shared<RNTextEngineTextViewProps>(*props);
  unrelatedProps->opacity = 0.4;
  auto unrelated = std::static_pointer_cast<RNTextEngineTextViewShadowNode>(node->clone({.props = unrelatedProps}));
  unrelated->layout(context);
  XCTAssertTrue(unrelated->getStateData().content == content);
  [view updateProps:unrelatedProps oldProps:props];
  [view finalizeUpdates:RNComponentViewUpdateMaskProps];
  [view layoutIfNeeded];
  XCTAssertTrue(TextViewDisplay(view).attributedText == content->attributedText);

  auto animatedProps = std::make_shared<RNTextEngineTextViewProps>(*unrelatedProps);
  animatedProps->fontSize = 31;
  [view updateProps:animatedProps oldProps:unrelatedProps];
  [view finalizeUpdates:RNComponentViewUpdateMaskProps];
  [view layoutIfNeeded];
  NSAttributedString *animatedText = TextViewDisplay(view).attributedText;
  XCTAssertEqualWithAccuracy(((UIFont *)[animatedText attribute:NSFontAttributeName atIndex:0 effectiveRange:nil]).pointSize, 31, 0.001);
  [view updateState:node->getState() oldState:unrelated->getState()];
  [view finalizeUpdates:RNComponentViewUpdateMaskState];
  [view layoutIfNeeded];
  XCTAssertTrue(TextViewDisplay(view).attributedText == animatedText);
  XCTAssertTrue(TextViewDisplay(secondView).attributedText == content->attributedText);

  [view updateProps:unrelatedProps oldProps:props];
  [view finalizeUpdates:RNComponentViewUpdateMaskProps];
  [view layoutIfNeeded];
  XCTAssertTrue(TextViewDisplay(view).attributedText == content->attributedText);

  auto queryProps = std::make_shared<RNTextEngineTextViewProps>(*props);
  queryProps->numberOfLines = 1;
  queryProps->ellipsizeMode = "tail";
  auto query = std::static_pointer_cast<RNTextEngineTextViewShadowNode>(node->clone({.props = queryProps}));
  auto fresh = BuildShadowNode(registry, Element<RNTextEngineTextViewShadowNode>().props(queryProps));
  XCTAssertTrue(query->measureContent(context, BuildLayoutConstraints(80)) == fresh->measureContent(context, BuildLayoutConstraints(80)));
  query->layout(context);
  XCTAssertTrue(query->getStateData().content == content);

  rntextengine::cleanup();
  XCTAssertTrue(node->measureContent(context, BuildLayoutConstraints(260)) == initialSize);
  XCTAssertGreaterThan(node->measureContent(context, BuildLayoutConstraints(160)).height, 0);
  NSTextStorage *storage = [TextViewDisplay(view) valueForKey:@"textStorage"];
  NSLayoutManager *manager = [TextViewDisplay(view) valueForKey:@"layoutManager"];
  [view prepareForRecycle];
  XCTAssertEqual(TextViewDisplay(view).attributedText.length, 0u);
  XCTAssertEqual(storage.length, 0u);
  XCTAssertEqual(((NSAttributedString *)[[view valueForKey:@"textView"] valueForKey:@"displayText"]).length, 0u);
  XCTAssertTrue(manager == [TextViewDisplay(view) valueForKey:@"layoutManager"]);
  XCTAssertTrue(storage == [TextViewDisplay(view) valueForKey:@"textStorage"]);
  [view updateProps:props oldProps:nullptr];
  [view updateState:node->getState() oldState:nullptr];
  [view finalizeUpdates:RNComponentViewUpdateMaskAll];
  [view layoutIfNeeded];
  XCTAssertEqualObjects(TextViewDisplay(view).attributedText, content->attributedText);
#endif
}

- (void)testPaperAccessibilityActionsUseReactViewHandlers
{
  for (NSString *className in @[@"RNTextEngineTextView", @"RNTextEnginePreparedTextView"]) {
    RCTView *view = [NSClassFromString(className) new];
    XCTSkipIf(![view isKindOfClass:RCTView.class], @"Requires the Paper source configuration");
    view.frame = CGRectMake(0, 0, 240, 100);
    view.isAccessibilityElement = YES;
    view.reactTag = @101;
    view.accessibilityLabel = @"Paper paragraph";
    view.accessibilityActions = @[@{@"name": @"activate", @"label": @"Read paragraph"}];
    __block NSString *actionName;
    view.onAccessibilityAction = ^(NSDictionary *event) { actionName = event[@"actionName"]; };
    for (BOOL selectable : {NO, YES, NO}) {
      [view setValue:@(selectable) forKey:@"selectable"];
      [view layoutIfNeeded];
      UIView *target = selectable ? [view valueForKey:@"interactionTextView"] : view;
      XCTAssertTrue(target.isAccessibilityElement);
      XCTAssertEqualObjects(target.accessibilityLabel, @"Paper paragraph");
      XCTAssertEqualObjects(target.accessibilityCustomActions.firstObject.name, @"Read paragraph");
      actionName = nil;
      XCTAssertTrue([target accessibilityActivate]);
      XCTAssertEqualObjects(actionName, @"activate");
      view.isAccessibilityElement = NO;
      XCTAssertFalse(target.isAccessibilityElement);
      view.isAccessibilityElement = YES;
    }
  }
}

- (void)testParagraphAccessibilityPreservesLabelsAndNativeSelection
{
#ifdef RCT_NEW_ARCH_ENABLED
  auto registry = BuildComponentDescriptorRegistry();
  auto context = BuildFabricLayoutContext();
  auto props = BuildTextViewProps("Straße ", {.fontSize = 17}, 260);
  props->textTransform = "uppercase";
  props->accessible = true;
  props->accessibilityHint = "Paragraph hint";
  props->accessibilityActions = {{.name = "activate", .label = "Read paragraph"}};
  auto childProps = BuildTextViewProps("שלום", {.fontSize = 17}, 260);
  auto node = BuildShadowNode(registry, Element<RNTextEngineTextViewShadowNode>().props(props)
      .children({Element<RNTextEngineTextViewShadowNode>().props(childProps)}));
  node->measureContent(context, BuildLayoutConstraints(260));
  node->layout(context);
  auto view = MountTextViewNode(*node);
  NSString *resolved = node->getStateData().content->attributedText.string;
  XCTAssertEqualObjects(resolved, @"STRASSE שלום");
  for (bool selectable : {false, true, false, true}) {
    auto next = std::make_shared<RNTextEngineTextViewProps>(*props);
    next->selectable = selectable;
    next->accessibilityLabel = "Spoken label";
    [view updateProps:next oldProps:props];
    [view finalizeUpdates:RNComponentViewUpdateMaskProps];
    [view layoutIfNeeded];
    UIView *target = selectable ? [[view valueForKey:@"textView"] valueForKey:@"interactionTextView"] : view;
    XCTAssertTrue(target.isAccessibilityElement);
    XCTAssertEqual(view.isAccessibilityElement, !selectable);
    XCTAssertEqualObjects(target.accessibilityLabel, @"Spoken label");
    XCTAssertEqualObjects(target.accessibilityHint, @"Paragraph hint");
    XCTAssertEqualObjects(target.accessibilityCustomActions.firstObject.name, @"Read paragraph");
    if (selectable) {
      UITextView *selection = (UITextView *)target;
      XCTAssertTrue(selection.selectable);
      selection.selectedRange = NSMakeRange(1, 4);
      XCTAssertTrue([selection canPerformAction:@selector(copy:) withSender:nil]);
    }
    auto unlabeled = std::make_shared<RNTextEngineTextViewProps>(*next);
    unlabeled->accessibilityLabel.clear();
    [view updateProps:unlabeled oldProps:next];
    XCTAssertEqualObjects(target.accessibilityLabel ?: target.accessibilityValue, resolved);
    if (selectable) XCTAssertNil(target.accessibilityLabel);
    auto inaccessible = std::make_shared<RNTextEngineTextViewProps>(*unlabeled);
    inaccessible->accessible = false;
    [view updateProps:inaccessible oldProps:unlabeled];
    XCTAssertFalse(target.isAccessibilityElement);
    [view updateProps:unlabeled oldProps:inaccessible];
    props = unlabeled;
  }
  [view prepareForRecycle];
  XCTAssertFalse(view.isAccessibilityElement);
  XCTAssertEqual(view.accessibilityLabel.length, 0u);

  for (NSString *className in @[@"RNTextEngineTextView", @"RNTextEnginePreparedTextView"]) {
    UIView *paper = [NSClassFromString(className) new];
    paper.frame = CGRectMake(0, 0, 260, 100);
    uint64_t handle = 0;
    if ([className isEqual:@"RNTextEngineTextView"]) {
      [paper setValue:@"Straße שלום" forKey:@"text"];
      [paper setValue:@"uppercase" forKey:@"textTransform"];
    } else {
      handle = rntextengine::createPreparedTextHandleForTextView(@"Straße שלום", {.fontSize = 17}, {}, @"uppercase");
      [paper setValue:@(handle) forKey:@"handle"];
    }
    paper.isAccessibilityElement = YES;
    paper.accessibilityHint = @"Paper hint";
    for (BOOL selectable : {NO, YES, NO}) {
      [paper setValue:@(selectable) forKey:@"selectable"];
      [paper layoutIfNeeded];
      UIView *target = selectable ? [paper valueForKey:@"interactionTextView"] : paper;
      XCTAssertTrue(target.isAccessibilityElement);
      XCTAssertEqualObjects(target.accessibilityLabel ?: target.accessibilityValue, @"STRASSE שלום");
      paper.accessibilityLabel = @"Alias";
      XCTAssertEqualObjects(target.accessibilityLabel, @"Alias");
      XCTAssertEqualObjects(target.accessibilityHint, @"Paper hint");
      paper.accessibilityLabel = nil;
      XCTAssertEqualObjects(target.accessibilityLabel ?: target.accessibilityValue, @"STRASSE שלום");
    }
    if (handle) {
      [paper setValue:@0 forKey:@"handle"];
      rntextengine::releasePreparedTextHandle(handle);
      XCTAssertEqual(paper.accessibilityLabel.length, 0u);
    }
  }
#endif
}

- (void)testSelectableParagraphAccessibilityPreservesStateAndText
{
#ifdef RCT_NEW_ARCH_ENABLED
  NSString *text = @"Invoice total: $42";
  auto verify = [&](UIView<RCTComponentViewProtocol> *view, auto props, NSString *innerKey) {
    using Props = typename decltype(props)::element_type;
    auto apply = [&](std::shared_ptr<Props> next) {
      [view updateProps:next oldProps:props];
      [view finalizeUpdates:RNComponentViewUpdateMaskProps];
      [view layoutIfNeeded];
      props = next;
    };
    for (AccessibilityState state : {AccessibilityState{.busy = true},
             AccessibilityState{.expanded = true}, AccessibilityState{.checked = AccessibilityState::Checked}}) {
      for (bool selectable : {false, true, false, true}) {
        auto next = std::make_shared<Props>(*props);
        next->selectable = selectable;
        next->accessibilityState = state;
        apply(next);
        UIView *target = selectable ? [[view valueForKey:innerKey] valueForKey:@"interactionTextView"] : view;
        XCTAssertTrue(target.isAccessibilityElement);
        XCTAssertEqual(view.isAccessibilityElement, !selectable);
        XCTAssertGreaterThan(view.accessibilityValue.length, 0u);
        XCTAssertEqualObjects(target.accessibilityLabel, text);
        XCTAssertEqualObjects(target.accessibilityValue, view.accessibilityValue);
        XCTAssertFalse([target.accessibilityValue containsString:text]);
        if (selectable) {
          UITextView *selection = (UITextView *)target;
          UITextPosition *start = [selection positionFromPosition:selection.beginningOfDocument offset:1];
          UITextPosition *end = [selection positionFromPosition:start inDirection:UITextLayoutDirectionRight offset:4];
          selection.selectedTextRange = [selection textRangeFromPosition:start toPosition:end];
          XCTAssertTrue(NSEqualRanges(selection.selectedRange, NSMakeRange(1, 4)));
          XCTAssertTrue([selection canPerformAction:@selector(copy:) withSender:nil]);
        }

        next = std::make_shared<Props>(*props);
        next->accessibilityLabel = "Spoken label";
        next->accessibilityValue.text = "Pending";
        apply(next);
        XCTAssertEqualObjects(target.accessibilityLabel, @"Spoken label");
        XCTAssertEqualObjects(target.accessibilityValue, view.accessibilityValue);
        XCTAssertTrue([target.accessibilityValue containsString:@"Pending"]);
        next = std::make_shared<Props>(*props);
        next->accessibilityLabel.clear();
        next->accessibilityState.reset();
        apply(next);
        XCTAssertEqualObjects(target.accessibilityLabel, text);
        XCTAssertEqualObjects(target.accessibilityValue, @"Pending");
        next = std::make_shared<Props>(*props);
        next->accessibilityValue = {};
        apply(next);
        XCTAssertNil(view.accessibilityValue);
        XCTAssertEqualObjects(target.accessibilityLabel, selectable ? nil : text);
        XCTAssertEqualObjects(target.accessibilityValue, selectable ? text : nil);
        if (selectable) XCTAssertTrue(NSEqualRanges(((UITextView *)target).selectedRange, NSMakeRange(1, 4)));
      }
    }
  };

  auto registry = BuildComponentDescriptorRegistry();
  auto context = BuildFabricLayoutContext();
  auto props = BuildTextViewProps(text.UTF8String, {.fontSize = 17}, 260);
  props->accessible = true;
  auto node = BuildShadowNode(registry, Element<RNTextEngineTextViewShadowNode>().props(props));
  node->measureContent(context, BuildLayoutConstraints(260));
  node->layout(context);
  verify(MountTextViewNode(*node), props, @"textView");

  uint64_t handle = rntextengine::createPreparedTextHandleForTextView(text, {.fontSize = 17});
  auto preparedProps = std::make_shared<RNTextEnginePreparedTextViewProps>();
  preparedProps->accessible = true;
  preparedProps->handle = handle;
  UIView<RCTComponentViewProtocol> *prepared = [NSClassFromString(@"RNTextEnginePreparedTextViewComponentView") new];
  prepared.frame = CGRectMake(0, 0, 260, 100);
  [prepared updateProps:preparedProps oldProps:nullptr];
  [prepared layoutIfNeeded];
  verify(prepared, preparedProps, @"preparedTextView");
  rntextengine::releasePreparedTextHandle(handle);
#endif
}

- (void)testRecycleReleasesRetiredTextWithoutLayout
{
#ifdef RCT_NEW_ARCH_ENABLED
  UIView<RCTComponentViewProtocol> *pooledView;
  __weak NSAttributedString *retiredText;
  __weak NSObject *retiredPayload;
  @autoreleasepool {
    auto registry = BuildComponentDescriptorRegistry();
    auto context = BuildFabricLayoutContext();
    auto props = BuildTextViewProps("Retired paragraph with its own shadow.", {.fontSize = 17}, 260);
    props->textShadowColor = colorFromRGBA(255, 0, 0, 255);
    auto node = BuildShadowNode(registry, Element<RNTextEngineTextViewShadowNode>().props(props));
    node->measureContent(context, BuildLayoutConstraints(260));
    node->layout(context);
    pooledView = MountTextViewNode(*node);
    DisplayLayers(pooledView.layer);
    [CATransaction flush];
    XCTAssertNotNil(TextViewDisplay(pooledView).layer.contents);
    retiredText = TextViewDisplay(pooledView).attributedText;
    NSObject *payload = [NSObject new];
    retiredPayload = payload;
    NSTextStorage *storage = [TextViewDisplay(pooledView) valueForKey:@"textStorage"];
    [storage addAttribute:@"RetiredPayload" value:payload range:NSMakeRange(0, storage.length)];
  }
  @autoreleasepool {
    XCTAssertNotNil(retiredText);
  }
  NSTextStorage *storage = [TextViewDisplay(pooledView) valueForKey:@"textStorage"];
  @autoreleasepool { [pooledView prepareForRecycle]; }
  XCTAssertNil(retiredText);
  XCTAssertNil(retiredPayload);
  XCTAssertEqual(storage.length, 0u);
  XCTAssertTrue(storage == [TextViewDisplay(pooledView) valueForKey:@"textStorage"]);
  XCTAssertNil(TextViewDisplay(pooledView).layer.contents);
  auto registry = BuildComponentDescriptorRegistry();
  auto context = BuildFabricLayoutContext();
  auto props = BuildTextViewProps("New paragraph", {.fontSize = 21}, 260);
  auto node = BuildShadowNode(registry, Element<RNTextEngineTextViewShadowNode>().props(props));
  node->measureContent(context, BuildLayoutConstraints(260));
  node->layout(context);
  [pooledView updateProps:props oldProps:nullptr];
  [pooledView updateState:node->getState() oldState:nullptr];
  [pooledView finalizeUpdates:RNComponentViewUpdateMaskAll];
  [pooledView layoutIfNeeded];
  XCTAssertEqualObjects(TextViewDisplay(pooledView).attributedText.string, @"New paragraph");
  XCTAssertNil([TextViewDisplay(pooledView).attributedText attribute:NSShadowAttributeName atIndex:0 effectiveRange:nil]);
  auto freshView = MountTextViewNode(*node);
  XCTAssertEqualObjects(ViewPixels(TextViewDisplay(pooledView), UIUserInterfaceStyleLight), ViewPixels(TextViewDisplay(freshView), UIUserInterfaceStyleLight));
#endif
}

- (void)testNestedDrawingOnlyUpdatesPreserveSelectionAndContentLifetime
{
#ifdef RCT_NEW_ARCH_ENABLED
  std::weak_ptr<const RNTextEngineTextContent> releasedContent;
  @autoreleasepool {
    auto registry = BuildComponentDescriptorRegistry();
    auto context = BuildFabricLayoutContext();
    auto props = BuildTextViewProps("Parent ", {.fontSize = 17, .lineHeight = 24}, 260);
    props->selectable = true;
    auto childProps = BuildTextViewProps("selected child text", {.fontSize = 17, .lineHeight = 24}, 260);
    auto node = BuildShadowNode(registry, Element<RNTextEngineTextViewShadowNode>().props(props)
        .children({Element<RNTextEngineTextViewShadowNode>().props(childProps)}));
    node->measureContent(context, BuildLayoutConstraints(260));
    node->layout(context);
    auto content = node->getStateData().content;
    releasedContent = content;
    auto view = MountTextViewNode(*node);
    UITextView *selection = [[view valueForKey:@"textView"] valueForKey:@"interactionTextView"];
    XCTAssertNotNil(selection);
    selection.selectedRange = NSMakeRange(2, 7);
    NSTextStorage *selectedStorage = selection.textStorage;
    auto changedChildProps = std::make_shared<RNTextEngineTextViewProps>(*childProps);
    changedChildProps->textDecorationLine = "underline";
    changedChildProps->textShadowColor = colorFromRGBA(255, 0, 0, 255);
    changedChildProps->textAlign = "right";
    auto changedChild = node->getChildren().front()->clone({.props = changedChildProps});
    auto changed = std::static_pointer_cast<RNTextEngineTextViewShadowNode>(node->clone({
        .children = std::make_shared<const std::vector<std::shared_ptr<const ShadowNode>>>(
            std::vector<std::shared_ptr<const ShadowNode>>{changedChild})}));
    changed->layout(context);
    XCTAssertTrue(changed->getStateData().content == content);
    [view updateState:changed->getState() oldState:node->getState()];
    [view finalizeUpdates:RNComponentViewUpdateMaskState];
    [view layoutIfNeeded];
    XCTAssertTrue(selection.textStorage == selectedStorage);
    XCTAssertTrue(NSEqualRanges(selection.selectedRange, NSMakeRange(2, 7)));

    changedChildProps = std::make_shared<RNTextEngineTextViewProps>(*changedChildProps);
    changedChildProps->color = colorFromRGBA(0, 0, 255, 255);
    changedChild = changedChild->clone({.props = changedChildProps});
    auto recolored = std::static_pointer_cast<RNTextEngineTextViewShadowNode>(changed->clone({
        .children = std::make_shared<const std::vector<std::shared_ptr<const ShadowNode>>>(
            std::vector<std::shared_ptr<const ShadowNode>>{changedChild})}));
    recolored->layout(context);
    XCTAssertTrue(recolored->getStateData().content != content);
    [view updateState:recolored->getState() oldState:changed->getState()];
    [view finalizeUpdates:RNComponentViewUpdateMaskState];
    [view layoutIfNeeded];
    XCTAssertEqualObjects([selection.attributedText attribute:NSForegroundColorAttributeName atIndex:7 effectiveRange:nil], UIColor.blueColor);
    [view prepareForRecycle];
  }
  XCTAssertTrue(releasedContent.expired());
#endif
}

- (void)testPreparedContentUsesLayoutFontScaleAndRenderedRunHeights
{
#ifdef RCT_NEW_ARCH_ENABLED
  auto registry = BuildComponentDescriptorRegistry();
  for (bool nested : {false, true}) {
    for (double size : {0., 17.}) {
      auto props = BuildTextViewProps("Parent child words wrap onto several lines.", {.fontSize = size, .lineHeight = 24}, 120);
      props->allowFontScaling = true;
      props->runStarts = {0};
      props->runEnds = {6};
      props->runStyleMasks = {64};
      props->runLineHeights = {0};
      auto element = Element<RNTextEngineTextViewShadowNode>().props(props);
      if (nested) {
        auto child = std::make_shared<RNTextEngineTextViewProps>();
        child->text = " inherited";
        element.children({Element<RNTextEngineTextViewShadowNode>().props(child)});
      }
      auto node = BuildShadowNode(registry, element);
      auto context = BuildFabricLayoutContext();
      for (Float scale : {1., 1.3, 2.}) {
        context.fontSizeMultiplier = scale;
        auto previous = node->getStateData().content;
        auto measured = node->measureContent(context, BuildLayoutConstraints(120));
        node->layout(context);
        auto content = node->getStateData().content;
        XCTAssertTrue(content != previous);
        UIFont *font = [content->attributedText attribute:NSFontAttributeName atIndex:0 effectiveRange:nil];
        XCTAssertEqualWithAccuracy(font.pointSize, (size > 0 ? size : 14) * scale, 0.001);
        NSTextStorage *storage = [[NSTextStorage alloc] initWithAttributedString:content->attributedText];
        NSLayoutManager *manager = [NSLayoutManager new];
        NSTextContainer *container = [[NSTextContainer alloc] initWithSize:CGSizeMake(120, CGFLOAT_MAX)];
        container.lineFragmentPadding = 0;
        [manager addTextContainer:container];
        [storage addLayoutManager:manager];
        [manager ensureLayoutForTextContainer:container];
        XCTAssertEqualWithAccuracy(measured.height, [manager usedRectForTextContainer:container].size.height,
            1.0 / UIScreen.mainScreen.scale, @"nested=%d size=%g scale=%g", nested, size, scale);
      }
    }
  }
#endif
}

- (void)testTextViewHandlesMatchRenderedScaledTypography
{
#ifdef RCT_NEW_ARCH_ENABLED
  WithMethodImplementation(UIApplication.class, @selector(preferredContentSizeCategory),
      ^NSString *(id) { return UIContentSizeCategoryExtraExtraLarge; }, ^{
    for (NSString *alignment in @[@"left", @"center", @"right", @"justify"]) {
      for (double size : {14., 17.}) {
        NSString *text = @"Inline font overrides should preserve the measured line heights while wrapping.";
        NSArray *starts = @[@0];
        NSArray *ends = @[@6];
        NSArray *masks = @[@(4 | 64)];
        NSArray *sizes = @[@22];
        NSArray *heights = @[@0];
        RNTextEngineTextAttributes attributes{
            .allowFontScaling = YES,
            .fontScale = RCTFontSizeMultiplier(),
            .fontSize = size,
            .lineHeight = 24,
            .textAlign = alignment,
        };
        auto handle = rntextengine::createPreparedTextHandleForTextView(text, attributes,
            RNTextEngineTextRunsFromArrays(starts, ends, masks, nil, nil, sizes, nil, nil, nil, heights, nil));
        UIView *view = [[NSClassFromString(@"RNTextEngineTextView") alloc] initWithFrame:CGRectMake(0, 0, 120, 640)];
        [view setValue:text forKey:@"text"];
        [view setValue:@YES forKey:@"allowFontScaling"];
        [view setValue:@(size) forKey:@"fontSize"];
        [view setValue:@24 forKey:@"lineHeight"];
        [view setValue:alignment forKey:@"textAlign"];
        [view setValue:starts forKey:@"runStarts"];
        [view setValue:ends forKey:@"runEnds"];
        [view setValue:masks forKey:@"runStyleMasks"];
        [view setValue:sizes forKey:@"runFontSizes"];
        [view setValue:heights forKey:@"runLineHeights"];
        [view layoutIfNeeded];
        RNTextEngineAttributedTextDisplayView *display = [view valueForKey:@"displayView"];
        NSAttributedString *prepared = rntextengine::preparedAttributedTextForHandle(handle);
        for (NSUInteger index : {0u, 7u}) {
          UIFont *measuredFont = [prepared attribute:NSFontAttributeName atIndex:index effectiveRange:nil];
          UIFont *renderedFont = [display.attributedText attribute:NSFontAttributeName atIndex:index effectiveRange:nil];
          XCTAssertEqualObjects(measuredFont, renderedFont);
        }
        for (NSInteger lines : {0, 2}) {
          NSTextStorage *storage = [[NSTextStorage alloc] initWithAttributedString:display.attributedText];
          NSLayoutManager *manager = [NSLayoutManager new];
          NSTextContainer *container = [[NSTextContainer alloc] initWithSize:CGSizeMake(120, CGFLOAT_MAX)];
          container.lineFragmentPadding = 0;
          container.maximumNumberOfLines = lines;
          container.lineBreakMode = RNTextEngineResolveLineBreakMode(lines, @"tail");
          [manager addTextContainer:container];
          [storage addLayoutManager:manager];
          [manager ensureLayoutForTextContainer:container];
          CGSize measured = rntextengine::measurePreparedTextLayoutForHandle(handle, 120, lines, @"tail", NO);
          XCTAssertEqualWithAccuracy(measured.height, [manager usedRectForTextContainer:container].size.height,
              1.0 / UIScreen.mainScreen.scale, @"alignment=%@ size=%g lines=%ld", alignment, size, (long)lines);
        }
        rntextengine::releasePreparedTextHandle(handle);
      }
    }
  });
#endif
}

- (void)testPropsOnlyUpdatesUseCurrentUIKitFontScaleAndLocale
{
#ifdef RCT_NEW_ARCH_ENABLED
  auto registry = BuildComponentDescriptorRegistry();
  WithMethodImplementation(UIApplication.class, @selector(preferredContentSizeCategory),
      ^NSString *(id) { return UIContentSizeCategoryLarge; }, ^{
    for (double size : {0., 17.}) {
      auto props = BuildTextViewProps("Scaled content", {.fontSize = size}, 260);
      props->allowFontScaling = true;
      auto context = BuildFabricLayoutContext();
      context.fontSizeMultiplier = RCTFontSizeMultiplier();
      auto node = BuildShadowNode(registry, Element<RNTextEngineTextViewShadowNode>().props(props));
      node->measureContent(context, BuildLayoutConstraints(260));
      node->layout(context);
      auto view = MountTextViewNode(*node);
      WithMethodImplementation(UIApplication.class, @selector(preferredContentSizeCategory),
          ^NSString *(id) { return UIContentSizeCategoryExtraExtraLarge; }, ^{
        for (bool colorOnly : {false, true}) {
          auto changed = std::make_shared<RNTextEngineTextViewProps>(*props);
          if (colorOnly) changed->color = colorFromRGBA(0, 0, 255, 255);
          else changed->fontSize = 31;
          [view updateProps:changed oldProps:props];
          [view finalizeUpdates:RNComponentViewUpdateMaskProps];
          [view layoutIfNeeded];
          UIFont *font = [TextViewDisplay(view).attributedText attribute:NSFontAttributeName atIndex:0 effectiveRange:nil];
          CGFloat expectedSize = colorOnly ? (size > 0 ? size : 14) : 31;
          XCTAssertEqualWithAccuracy(font.pointSize, expectedSize * RCTFontSizeMultiplier(), 0.001);
        }
      });
    }
  });

  NSLocale *english = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
  NSLocale *turkish = [[NSLocale alloc] initWithLocaleIdentifier:@"tr_TR"];
  WithMethodImplementation(object_getClass(NSLocale.class), @selector(currentLocale), ^NSLocale *(id) { return english; }, ^{
    auto props = BuildTextViewProps("istanbul izmir", {.fontSize = 17}, 260);
    props->textTransform = "capitalize";
    auto context = BuildFabricLayoutContext();
    auto node = BuildShadowNode(registry, Element<RNTextEngineTextViewShadowNode>().props(props));
    node->measureContent(context, BuildLayoutConstraints(260));
    node->layout(context);
    auto content = node->getStateData().content;
    auto view = MountTextViewNode(*node);
    XCTAssertEqualObjects(TextViewDisplay(view).attributedText.string, @"Istanbul Izmir");
    WithMethodImplementation(object_getClass(NSLocale.class), @selector(currentLocale), ^NSLocale *(id) { return turkish; }, ^{
      auto changed = std::make_shared<RNTextEngineTextViewProps>(*props);
      changed->color = colorFromRGBA(0, 0, 255, 255);
      [view updateProps:changed oldProps:props];
      [view finalizeUpdates:RNComponentViewUpdateMaskProps];
      [view layoutIfNeeded];
      XCTAssertEqualObjects(TextViewDisplay(view).attributedText.string, @"İstanbul İzmir");
      node->measureContent(context, BuildLayoutConstraints(260));
      node->layout(context);
      XCTAssertTrue(node->getStateData().content != content);
      XCTAssertEqualObjects(node->getStateData().content->attributedText.string, @"İstanbul İzmir");
    });
  });
#endif
}

- (void)testPreparedContentPreservesDynamicColorsAcrossWorkerAndViewTraits
{
#ifdef RCT_NEW_ARCH_ENABLED
  auto registry = BuildComponentDescriptorRegistry();
  auto context = BuildFabricLayoutContext();
  auto props = BuildTextViewProps("Parent ", {.fontSize = 24, .lineHeight = 32}, 260);
  props->textShadowColor = SharedColor(Color(DynamicColor{.lightColor = 0x00000000, .darkColor = static_cast<int32_t>(0xFFFF0000)}));
  props->textShadowOffset = {.width = 3, .height = 2};
  props->textDecorationLine = "underline line-through";
  props->textDecorationStyle = "double";
  auto child = BuildTextViewProps("Child 👩‍💻 測試", {.fontSize = 24, .lineHeight = 32}, 260);
  child->color = SharedColor(Color(DynamicColor{.lightColor = static_cast<int32_t>(0xFF00FF00), .darkColor = static_cast<int32_t>(0xFF0000FF)}));
  const auto makeNode = [&] {
    return BuildShadowNode(registry, Element<RNTextEngineTextViewShadowNode>().props(props)
        .children({Element<RNTextEngineTextViewShadowNode>().props(child)}));
  };
  for (UIUserInterfaceStyle preparedStyle : {UIUserInterfaceStyleLight, UIUserInterfaceStyleDark}) {
    auto node = makeNode();
    UITraitCollection *traits = [UITraitCollection traitCollectionWithUserInterfaceStyle:preparedStyle];
    dispatch_sync(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
      [traits performAsCurrentTraitCollection:^{
        node->measureContent(context, BuildLayoutConstraints(260));
        node->layout(context);
      }];
    });
    NSAttributedString *text = node->getStateData().content->attributedText;
    XCTAssertNotNil([text attribute:NSShadowAttributeName atIndex:0 effectiveRange:nil]);
    UIColor *runColor = [text attribute:NSForegroundColorAttributeName atIndex:7 effectiveRange:nil];
    for (UIUserInterfaceStyle drawnStyle : {UIUserInterfaceStyleLight, UIUserInterfaceStyleDark}) {
      UITraitCollection *drawTraits = [UITraitCollection traitCollectionWithUserInterfaceStyle:drawnStyle];
      XCTAssertEqualObjects([runColor resolvedColorWithTraitCollection:drawTraits],
          [RCTUIColorFromSharedColor(child->color) resolvedColorWithTraitCollection:drawTraits]);
      [drawTraits performAsCurrentTraitCollection:^{
        auto reference = makeNode();
        reference->measureContent(context, BuildLayoutConstraints(260));
        reference->layout(context);
        XCTAssertEqualObjects(ViewPixels(TextViewDisplay(MountTextViewNode(*node)), drawnStyle),
                              ViewPixels(TextViewDisplay(MountTextViewNode(*reference)), drawnStyle));
      }];
    }
  }
#endif
}

- (void)testTextViewMeasurementCacheDistinguishesAdjacentWidths
{
#ifdef RCT_NEW_ARCH_ENABLED
  auto registry = BuildComponentDescriptorRegistry();
  const auto context = BuildFabricLayoutContext();
  const auto makeNode = [&] {
    return BuildShadowNode(registry, Element<RNTextEngineTextViewShadowNode>()
        .props(BuildTextViewProps("Word word word word word word word word", {.fontSize = 17, .lineHeight = 24}, 160)));
  };
  const auto heightAt = [&](Float width) {
    return makeNode()->measureContent(context, BuildLayoutConstraints(width)).height;
  };
  Float low = 20;
  Float high = 160;
  const Float lowerHeight = heightAt(low);
  XCTAssertNotEqual(lowerHeight, heightAt(high));
  while (std::nextafter(low, high) < high) {
    const Float midpoint = low + (high - low) / 2;
    if (heightAt(midpoint) == lowerHeight) low = midpoint;
    else high = midpoint;
  }
  XCTAssertLessThan(high - low, 0.005);
  XCTAssertNotEqual(heightAt(low), heightAt(high));
  for (bool reverse : {false, true}) {
    auto retained = makeNode();
    for (Float width : {reverse ? high : low, reverse ? low : high}) {
      const auto expected = makeNode()->measureContent(context, BuildLayoutConstraints(width));
      const auto actual = retained->measureContent(context, BuildLayoutConstraints(width));
      XCTAssertEqual(actual.height, expected.height, @"width=%.9g reverse=%d", width, reverse);
    }
  }
#endif
}

- (void)testConcurrentTextViewMeasurements
{
#ifdef RCT_NEW_ARCH_ENABLED
  auto registry = BuildComponentDescriptorRegistry();
  const auto context = BuildFabricLayoutContext();
  const TextStyleFixture style{.fontSize = 17, .lineHeight = 24};
  const std::string text =
      "Message 1. The renderer should know the bubble height before the row mounts. "
      "Inline emphasis, tabular numbers, and quoted citations still need exact native metrics. "
      "A text surface should update content without rebuilding unrelated host objects.";
  const auto buildNode = [&](bool nested) {
    auto element = Element<RNTextEngineTextViewShadowNode>()
        .props(BuildTextViewProps(text, style, 260));
    if (nested) {
      element.children({Element<RNTextEngineTextViewShadowNode>()
          .props(BuildTextViewProps(" Nested emphasis with more wrapping.",
              {.fontSize = 23, .lineHeight = 29, .fontWeight = "700"}, 260))});
    }
    return BuildShadowNode(registry, element);
  };

  for (bool nested : {false, true}) {
    auto reference = buildNode(nested);
    std::vector<LayoutConstraints> constraints;
    std::vector<facebook::react::Size> expected;
    for (int index = 0; index < 32; ++index) {
      constraints.push_back(BuildLayoutConstraints(80 + index * 7));
      expected.push_back(reference->measureContent(context, constraints.back()));
    }
    auto retained = buildNode(nested);
    retained->measureContent(context, constraints.front());
    retained->layout(context);
    for (int index = 0; index < 4096; ++index) {
      auto props = std::make_shared<RNTextEngineTextViewProps>(retained->getConcreteProps());
      props->numberOfLines = index % 3;
      props->anchorToCapHeight = index % 2 == 0;
      retained = std::static_pointer_cast<RNTextEngineTextViewShadowNode>(retained->clone({.props = props}));
      const auto query = BuildLayoutConstraints(80 + index * 0.25f);
      auto freshNode = buildNode(nested);
      freshNode = std::static_pointer_cast<RNTextEngineTextViewShadowNode>(freshNode->clone({.props = props}));
      const auto actual = retained->measureContent(context, query);
      const auto fresh = freshNode->measureContent(context, query);
      XCTAssertTrue(actual == fresh, @"Width history changed geometry");
    }
    for (bool warm : {false, true}) {
      auto source = buildNode(nested);
      if (warm) source->measureContent(context, constraints.front());
      source->sealRecursive();
      std::atomic<bool> start{false};
      std::atomic<bool> matches{true};
      std::vector<std::thread> workers;
      for (int worker = 0; worker < 6; ++worker) {
        workers.emplace_back([&, worker] {
          @autoreleasepool {
            while (!start.load()) std::this_thread::yield();
            for (int iteration = 0; iteration < 128; ++iteration) {
              auto clone = std::static_pointer_cast<RNTextEngineTextViewShadowNode>(source->clone({}));
              const auto &node = worker == 0 ? source : clone;
              const auto index = (iteration * 7 + worker * 11) % constraints.size();
              if (node->measureContent(context, constraints[index]) != expected[index]) {
                matches.store(false);
              }
            }
          }
        });
      }
      start.store(true);
      for (auto &worker : workers) worker.join();
      XCTAssertTrue(matches.load(), @"Concurrent geometry differs: nested=%d warm=%d", nested, warm);
    }
  }
  auto nested = buildNode(true);
  nested->layout(context);
  XCTAssertTrue(nested->getStateData().content->nestedText != nil);
  const auto nestedState = nested->getState();
  auto unchanged = std::static_pointer_cast<RNTextEngineTextViewShadowNode>(
      nested->clone({.props = nested->getProps()}));
  unchanged->layout(context);
  XCTAssertTrue(unchanged->getState() == nestedState);
  auto flat = std::static_pointer_cast<RNTextEngineTextViewShadowNode>(nested->clone({
      .children = std::make_shared<const std::vector<std::shared_ptr<const ShadowNode>>>()}));
  flat->layout(context);
  XCTAssertFalse(flat->getStateData().content->nestedText != nil);
#endif
}

- (void)testDisplayPreservesLayoutForIdenticalImmutableText
{
#ifdef RCT_NEW_ARCH_ENABLED
  auto view = [[RNTextEngineAttributedTextDisplayView alloc] initWithFrame:CGRectMake(0, 0, 240, 100)];
  auto mutableText = [[NSMutableAttributedString alloc] initWithString:@"Shared immutable typography" attributes:@{
      NSFontAttributeName:[UIFont systemFontOfSize:19], NSForegroundColorAttributeName:UIColor.labelColor}];
  NSAttributedString *text = [mutableText copy];
  view.attributedText = text;
  UIEdgeInsets insets = [view capHeightInsetsForWidth:240];
  view.attributedText = text;
  XCTAssertFalse([[view valueForKey:@"layoutDirty"] boolValue]);
  XCTAssertFalse([[view valueForKey:@"capHeightInsetsDirty"] boolValue]);
  XCTAssertTrue(UIEdgeInsetsEqualToEdgeInsets(insets, [view capHeightInsetsForWidth:240]));

  view.attributedText = mutableText;
  XCTAssertFalse(view.attributedText == mutableText);
  [view capHeightInsetsForWidth:240];
  [mutableText replaceCharactersInRange:NSMakeRange(0, mutableText.length) withString:@"Replacement text"];
  XCTAssertEqualObjects(view.attributedText.string, text.string);
  view.attributedText = mutableText;
  XCTAssertTrue([[view valueForKey:@"layoutDirty"] boolValue]);
  XCTAssertTrue([[view valueForKey:@"capHeightInsetsDirty"] boolValue]);
  XCTAssertEqualObjects(view.attributedText.string, @"Replacement text");
#endif
}

- (void)testPreparedNaturalAlignmentMatchesNativeSelection
{
#ifdef RCT_NEW_ARCH_ENABLED
  for (NSString *text in @[@"שלום", @"مرحبا", @"Hello שלום", @"שלום Hello"]) {
    for (CGFloat width : {35., 240.}) for (NSInteger lines : {0, 1}) {
      uint64_t handle = rntextengine::createPreparedTextHandleForTextView(text, {.fontSize = 17, .lineHeight = 30});
      UIView *view = [NSClassFromString(@"RNTextEnginePreparedTextView") new];
      view.frame = CGRectMake(0, 0, width, 120);
      [view setValue:@(handle) forKey:@"handle"];
      [view setValue:@(lines) forKey:@"numberOfLines"];
      [view setValue:@"tail" forKey:@"ellipsizeMode"];
      [view layoutIfNeeded];
      NSData *ordinary = ViewPixels(view, UIUserInterfaceStyleLight);
      [view setValue:@YES forKey:@"selectable"];
      [view layoutIfNeeded];
      NSData *selected = ViewPixels(view, UIUserInterfaceStyleLight);
      XCTAssertEqualObjects(selected, ordinary, @"%@ width=%g lines=%ld", text, width, (long)lines);
      [view setValue:@NO forKey:@"selectable"];
      [view layoutIfNeeded];
      XCTAssertEqualObjects(ViewPixels(view, UIUserInterfaceStyleLight), ordinary);
      rntextengine::releasePreparedTextHandle(handle);
    }
  }
#endif
}

- (void)testParagraphAlignmentPreservesPhysicalEdgesAndPlatformDefault
{
#ifdef RCT_NEW_ARCH_ENABLED
  auto lineBounds = ^CGRect(NSAttributedString *text) {
    NSTextStorage *storage = [[NSTextStorage alloc] initWithAttributedString:text];
    NSLayoutManager *manager = [NSLayoutManager new];
    NSTextContainer *container = [[NSTextContainer alloc] initWithSize:CGSizeMake(240, CGFLOAT_MAX)];
    container.lineFragmentPadding = 0;
    [manager addTextContainer:container];
    [storage addLayoutManager:manager];
    [manager ensureLayoutForTextContainer:container];
    return [manager lineFragmentUsedRectForGlyphAtIndex:0 effectiveRange:nil];
  };
  for (NSString *string in @[@"שלום", @"مرحبا", @"Hello שלום", @"שלום Hello"]) {
    UIFont *font = [UIFont systemFontOfSize:17];
    NSAttributedString *nativeDefault = [[NSAttributedString alloc] initWithString:string
        attributes:@{NSFontAttributeName: font}];
    CGFloat naturalOrigin = CGRectGetMinX(lineBounds(nativeDefault));
    for (NSString *alignment in @[@"", @"auto", @"left", @"right"]) {
      for (CGFloat rootHeight : {0., 30.}) for (CGFloat runHeight : {-1., 0., 35.}) {
        RNTextEngineTextAttributes base{.fontSize = 17, .lineHeight = rootHeight, .textAlign = alignment};
        std::vector<RNTextEngineTextRun> runs;
        if (runHeight >= 0) runs.push_back({.start = 0, .end = (NSInteger)string.length, .style = {.lineHeight = runHeight}});
        auto text = RNTextEngineBuildAttributedText(string, base, runs, nil, NO);
        NSParagraphStyle *paragraph = [text attribute:NSParagraphStyleAttributeName atIndex:0 effectiveRange:nil];
        NSTextAlignment expected = [alignment isEqual:@"left"] ? NSTextAlignmentLeft :
            [alignment isEqual:@"right"] ? NSTextAlignmentRight : NSTextAlignmentNatural;
        XCTAssertEqual((paragraph ?: NSParagraphStyle.defaultParagraphStyle).alignment, expected);
        XCTAssertEqualWithAccuracy(paragraph.maximumLineHeight, runHeight >= 0 ? runHeight : rootHeight, 0.001);
        CGRect bounds = lineBounds(text);
        if (expected == NSTextAlignmentLeft) XCTAssertEqualWithAccuracy(CGRectGetMinX(bounds), 0, 0.01);
        else if (expected == NSTextAlignmentRight) XCTAssertEqualWithAccuracy(CGRectGetMaxX(bounds), 240, 0.01);
        else XCTAssertEqualWithAccuracy(CGRectGetMinX(bounds), naturalOrigin, 0.01);
        auto prepared = rntextengine::prepareAttributedText(text, font.lineHeight, expected);
        if (expected == NSTextAlignmentNatural) {
          XCTAssertTrue([(id)prepared valueForKey:@"attributedText"] == text);
        }
        for (NSInteger maxLines : {0, 1}) {
          auto size = rntextengine::measurePreparedTextLayout(prepared, 35, maxLines, @"tail", NO);
          auto left = base;
          left.textAlign = @"left";
          auto leftText = RNTextEngineBuildAttributedText(string, left, runs, nil, NO);
          auto leftPrepared = rntextengine::prepareAttributedText(leftText, font.lineHeight, NSTextAlignmentLeft);
          auto leftSize = rntextengine::measurePreparedTextLayout(leftPrepared, 35, maxLines, @"tail", NO);
          XCTAssertEqualWithAccuracy(size.width, leftSize.width, 0.01);
          XCTAssertEqualWithAccuracy(size.height, leftSize.height, 0.01);
        }
      }
    }
  }
#endif
}

- (void)testInlineAttributesInheritParagraphStyleAndOverrideTypography
{
#ifdef RCT_NEW_ARCH_ENABLED
  NSString *text = @"0123456789 0123456789";
  for (BOOL scaled : {NO, YES}) for (BOOL preScaled : {NO, YES}) {
    RNTextEngineTextAttributes base{
        .allowFontScaling = scaled, .fontScale = 1.4, .color = UIColor.blackColor,
        .fontSize = 17, .letterSpacing = 0.2, .lineHeight = 25, .tabularNumbers = YES,
        .textAlign = @"right", .textDecorationLine = @"underline line-through",
        .textDecorationStyle = @"dotted", .textShadowColor = UIColor.blueColor,
        .textShadowOffset = CGSizeMake(1, -2), .textShadowRadius = 2,
    };
    for (BOOL explicitDecoration : {NO, YES}) {
      base.textDecorationColor = explicitDecoration ? UIColor.greenColor : nil;
      auto colored = RNTextEngineBuildAttributedText(text, base,
          {{.start = 0, .end = 5, .style = {.color = UIColor.redColor}}}, nil, preScaled);
      auto root = [colored attributesAtIndex:10 effectiveRange:nil];
      auto run = [colored attributesAtIndex:0 effectiveRange:nil];
      for (NSAttributedStringKey key in @[NSFontAttributeName, NSParagraphStyleAttributeName,
          NSShadowAttributeName, NSKernAttributeName, NSUnderlineStyleAttributeName, NSStrikethroughStyleAttributeName]) {
        XCTAssertEqualObjects(run[key], root[key]);
      }
      XCTAssertEqualObjects(run[NSForegroundColorAttributeName], UIColor.redColor);
      XCTAssertEqualObjects(run[NSUnderlineColorAttributeName], base.textDecorationColor ?: UIColor.redColor);
      XCTAssertEqualObjects(run[NSStrikethroughColorAttributeName], base.textDecorationColor ?: UIColor.redColor);
      XCTAssertEqualObjects(run[RNTextEngineUniformCapHeightAttributeName], @(((UIFont *)root[NSFontAttributeName]).capHeight));

      RNTextEngineTextRunStyle override{.fontSize = 23, .lineHeight = 31, .tabularNumbers = false};
      auto mixed = RNTextEngineBuildAttributedText(text, base, {{.start = 0, .end = 5, .style = override}}, nil, preScaled);
      auto expectedBase = base;
      expectedBase.allowFontScaling = NO;
      CGFloat scale = scaled && !preScaled ? 1.4 : 1;
      expectedBase.fontSize = 23 * scale;
      expectedBase.lineHeight = 31 * scale;
      expectedBase.tabularNumbers = NO;
      auto expected = RNTextEngineBuildAttributedText(text, expectedBase, {}, nil, NO);
      XCTAssertEqualObjects([mixed attribute:NSFontAttributeName atIndex:0 effectiveRange:nil],
          [expected attribute:NSFontAttributeName atIndex:0 effectiveRange:nil]);
      XCTAssertEqualObjects([mixed attribute:NSParagraphStyleAttributeName atIndex:0 effectiveRange:nil],
          [expected attribute:NSParagraphStyleAttributeName atIndex:0 effectiveRange:nil]);
      XCTAssertNil([mixed attribute:RNTextEngineUniformCapHeightAttributeName atIndex:0 effectiveRange:nil]);
    }
  }
#endif
}

@end
