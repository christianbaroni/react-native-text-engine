cmake_minimum_required(VERSION 3.22.1)
project("rn-pretext")

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(NODE_MODULES_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../../node_modules")
set(REACT_NATIVE_WORKLETS_DIR "${REACT_NATIVE_WORKLETS_DIR}")

add_library(rn-pretext SHARED
        RNPretextBindings.cpp
        "${NODE_MODULES_DIR}/react-native/ReactCommon/jsi/jsi/jsi.cpp")

target_include_directories(rn-pretext PRIVATE
        "${NODE_MODULES_DIR}/react-native/ReactCommon"
        "${NODE_MODULES_DIR}/react-native/ReactCommon/jsi"
        "${NODE_MODULES_DIR}/react-native/ReactCommon/jsi/jsi")

target_compile_definitions(rn-pretext PRIVATE RNPRETEXT_HAS_WORKLETS=0)

if(REACT_NATIVE_WORKLETS_DIR)
    target_include_directories(rn-pretext PRIVATE
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
        target_compile_definitions(rn-pretext PRIVATE RNPRETEXT_HAS_WORKLETS=1)
    endif()
endif()

find_library(log-lib log)

target_link_libraries(rn-pretext
        android
        ${log-lib})

if(TARGET worklets)
    target_link_libraries(rn-pretext worklets)
endif()
