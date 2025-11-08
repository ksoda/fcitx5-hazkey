set(SWIFT_BUILD_TYPE "${SWIFT_BUILD_TYPE}")
set(SWIFT_EXECUTABLE "${SWIFT_EXECUTABLE}")
set(SWIFT_DISABLE_DEPENDENCY_CACHE "${SWIFT_DISABLE_DEPENDENCY_CACHE}")
set(SWIFT_DETECTED_LIB_PATH "${SWIFT_DETECTED_LIB_PATH}")
set(SWIFT_LINK_PATH "${SWIFT_LINK_PATH}")
set(SWIFT_WORK_DIR "${SWIFT_WORK_DIR}")
set(LLAMA_STUB_DIR "${LLAMA_STUB_DIR}")


set(SWIFT_COMMAND
    ${SWIFT_EXECUTABLE} build -c ${SWIFT_BUILD_TYPE}
    --scratch-path=${CMAKE_CURRENT_BINARY_DIR}/swift-build
    -Xswiftc -static-stdlib
    -Xlinker -L${LLAMA_STUB_DIR}
)
if(SWIFT_DISABLE_DEPENDENCY_CACHE)
    list(APPEND SWIFT_COMMAND --disable-dependency-cache)
endif()

if(SWIFT_DETECTED_LIB_PATH)
    list(APPEND SWIFT_COMMAND -Xlinker -L${SWIFT_DETECTED_LIB_PATH})
endif()

if(SWIFT_LINK_PATH)
    list(APPEND SWIFT_COMMAND -Xlinker -L${SWIFT_LINK_PATH})
endif()

set(SWIFT_ENV_COMMAND
    ${CMAKE_COMMAND} -E env
    CC=clang
    CXX=clang++
    ${SWIFT_COMMAND}
)

execute_process(
    COMMAND ${SWIFT_ENV_COMMAND}
    WORKING_DIRECTORY ${SWIFT_WORK_DIR}
    RESULT_VARIABLE result
    OUTPUT_VARIABLE swift_stdout
    ERROR_VARIABLE swift_stderr
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_STRIP_TRAILING_WHITESPACE
)

# The first build fails for an unknown reason.
if(NOT result EQUAL 0)
    message(WARNING "Swift build attempt 1 stdout:\n${swift_stdout}")
    message(WARNING "Swift build attempt 1 stderr:\n${swift_stderr}")

    execute_process(
        COMMAND ${SWIFT_ENV_COMMAND}
        WORKING_DIRECTORY ${SWIFT_WORK_DIR}
        RESULT_VARIABLE result2
        OUTPUT_VARIABLE swift_stdout2
        ERROR_VARIABLE swift_stderr2
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_STRIP_TRAILING_WHITESPACE
    )
    if(NOT result2 EQUAL 0)
        message(WARNING "Swift build attempt 2 stdout:\n${swift_stdout2}")
        message(WARNING "Swift build attempt 2 stderr:\n${swift_stderr2}")
        message(FATAL_ERROR "Swift build failed after two attempts.")
    endif()
endif()
