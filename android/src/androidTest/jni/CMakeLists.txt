set(CODEGEN_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../build/generated/source/codegen/jni")
set(COMPONENT_DIR "${CODEGEN_DIR}/react/renderer/components/RNTextEngineSpec")
set(MAIN_JNI_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../main/jni")

add_library(rnte-text-comparison SHARED
    RNTextEngineTextComparison.cpp
    "${MAIN_JNI_DIR}/react/renderer/components/RNTextEngineSpec/RNTextEngineTextViewShadowNode.cpp"
    "${COMPONENT_DIR}/Props.cpp"
    "${COMPONENT_DIR}/EventEmitters.cpp"
    "${COMPONENT_DIR}/States.cpp"
    "${COMPONENT_DIR}/ShadowNodes.cpp")

target_include_directories(rnte-text-comparison PRIVATE
    "${MAIN_JNI_DIR}"
    "${CODEGEN_DIR}"
    "${COMPONENT_DIR}"
    "${REACT_NATIVE_DIR}/ReactCommon"
    "${REACT_NATIVE_DIR}/ReactCommon/react/renderer/components/text/platform/android"
    "${REACT_NATIVE_DIR}/ReactCommon/react/renderer/components/view/platform/android"
    "${REACT_NATIVE_DIR}/ReactCommon/react/renderer/textlayoutmanager/platform/android")
target_compile_definitions(rnte-text-comparison PRIVATE RN_SERIALIZABLE_STATE)
find_package(fbjni REQUIRED CONFIG)
target_link_libraries(rnte-text-comparison
    ReactAndroid::reactnative ReactAndroid::jsi fbjni::fbjni android log)
