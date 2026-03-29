cmake_minimum_required(VERSION 3.22.1)
project("rn-text-engine")

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(DEFAULT_NODE_MODULES_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../../node_modules")
set(REACT_NATIVE_DIR "${REACT_NATIVE_DIR}")
set(REACT_NATIVE_WORKLETS_DIR "${REACT_NATIVE_WORKLETS_DIR}")

if(NOT REACT_NATIVE_DIR)
    set(REACT_NATIVE_DIR "${DEFAULT_NODE_MODULES_DIR}/react-native")
endif()

if(NOT EXISTS "${REACT_NATIVE_DIR}/ReactAndroid/cmake-utils/folly-flags.cmake")
    message(FATAL_ERROR "React Native Android CMake helpers were not found under ${REACT_NATIVE_DIR}.")
endif()

include("${REACT_NATIVE_DIR}/ReactAndroid/cmake-utils/folly-flags.cmake")
add_compile_options(${folly_FLAGS})

set(RNTEXTENGINE_HAS_WORKLETS 0)

add_library(rn-text-engine SHARED RNTextEngineBindings.cpp)

target_include_directories(rn-text-engine PRIVATE
        "${REACT_NATIVE_DIR}/ReactCommon")

find_package(ReactAndroid REQUIRED CONFIG)

if(REACT_NATIVE_WORKLETS_DIR)
    target_include_directories(rn-text-engine PRIVATE
            "${REACT_NATIVE_DIR}/ReactCommon/yoga"
            "${REACT_NATIVE_DIR}/ReactAndroid/src/main/jni/react/turbomodule"
            "${REACT_NATIVE_DIR}/ReactCommon/react/nativemodule/core/ReactCommon"
            "${REACT_NATIVE_DIR}/ReactCommon/callinvoker"
            "${REACT_NATIVE_DIR}/ReactCommon/runtimeexecutor"
            "${REACT_NATIVE_DIR}/ReactCommon/jsiexecutor"
            "${REACT_NATIVE_DIR}/ReactCommon/react/renderer/graphics/platform/cxx"
            "${REACT_NATIVE_WORKLETS_DIR}/Common/cpp"
            "${REACT_NATIVE_WORKLETS_DIR}/android/src/main/cpp")

    if(${CMAKE_BUILD_TYPE} MATCHES "Debug")
        set(BUILD_TYPE "debug")
    else()
        set(BUILD_TYPE "release")
    endif()

    set(WORKLETS_LIBRARY_PATH
            "${REACT_NATIVE_WORKLETS_DIR}/android/build/intermediates/cmake/${BUILD_TYPE}/obj/${ANDROID_ABI}/libworklets.so")

    if(EXISTS "${WORKLETS_LIBRARY_PATH}")
        add_library(worklets SHARED IMPORTED)
        set_target_properties(worklets PROPERTIES IMPORTED_LOCATION "${WORKLETS_LIBRARY_PATH}")
        set(RNTEXTENGINE_HAS_WORKLETS 1)
    endif()
endif()

target_compile_definitions(rn-text-engine PRIVATE RNTEXTENGINE_HAS_WORKLETS=${RNTEXTENGINE_HAS_WORKLETS})

find_library(log-lib log)

target_link_libraries(rn-text-engine
        android
        ${log-lib}
        ReactAndroid::reactnative
        ReactAndroid::jsi)

if(TARGET worklets)
    target_link_libraries(rn-text-engine worklets)
endif()
