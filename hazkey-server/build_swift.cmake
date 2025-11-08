set(SWIFT_BUILD_TYPE "${SWIFT_BUILD_TYPE}")
set(SWIFT_EXECUTABLE "${SWIFT_EXECUTABLE}")
set(SWIFT_BUILD_EXECUTABLE "${SWIFT_BUILD_EXECUTABLE}")
if(NOT SWIFT_BUILD_EXECUTABLE)
    set(SWIFT_BUILD_EXECUTABLE "${SWIFT_EXECUTABLE}-build")
endif()
set(SWIFT_DISABLE_DEPENDENCY_CACHE "${SWIFT_DISABLE_DEPENDENCY_CACHE}")
set(SWIFT_DETECTED_LIB_PATH "${SWIFT_DETECTED_LIB_PATH}")
set(SWIFT_LINK_PATH "${SWIFT_LINK_PATH}")
set(SWIFT_RUNTIME_LIBRARY_PATH "${SWIFT_RUNTIME_LIBRARY_PATH}")
set(SWIFT_SDK_PATH "${SWIFT_SDK_PATH}")
set(SWIFT_WORK_DIR "${SWIFT_WORK_DIR}")
set(SWIFT_OUTPUT_DIR "${SWIFT_OUTPUT_DIR}")
set(SWIFT_TARGET_TRIPLE "${SWIFT_TARGET_TRIPLE}")
file(MAKE_DIRECTORY "${SWIFT_OUTPUT_DIR}")
if(NOT SWIFT_TARGET_TRIPLE)
    set(SWIFT_TARGET_TRIPLE "x86_64-unknown-linux-gnu")
endif()
set(LLAMA_STUB_DIR "${LLAMA_STUB_DIR}")


set(SWIFT_COMMAND
    ${SWIFT_BUILD_EXECUTABLE} -c ${SWIFT_BUILD_TYPE}
    --scratch-path=${SWIFT_OUTPUT_DIR}/swift-build
    --build-path=${SWIFT_OUTPUT_DIR}/swift-build
    --package-path=${SWIFT_WORK_DIR}
    -Xswiftc -static-stdlib
    -Xlinker -L${LLAMA_STUB_DIR}
)
message(STATUS "Running Swift command: ${SWIFT_COMMAND}")
if(SWIFT_DISABLE_DEPENDENCY_CACHE)
    list(APPEND SWIFT_COMMAND --disable-dependency-cache)
endif()

if(SWIFT_DETECTED_LIB_PATH)
    list(APPEND SWIFT_COMMAND -Xlinker -L${SWIFT_DETECTED_LIB_PATH})
endif()

if(SWIFT_LINK_PATH)
    list(APPEND SWIFT_COMMAND -Xlinker -L${SWIFT_LINK_PATH})
endif()
if(SWIFT_SDK_PATH)
    list(APPEND SWIFT_COMMAND -Xcc "--sysroot=${SWIFT_SDK_PATH}")
    list(APPEND SWIFT_COMMAND -Xlinker "--sysroot=${SWIFT_SDK_PATH}")
endif()

set(SWIFT_ENV_COMMAND
    ${CMAKE_COMMAND} -E env
    CC=clang
    CXX=clang++
)
file(MAKE_DIRECTORY "${SWIFT_OUTPUT_DIR}/.swift-home")
if(SWIFT_RUNTIME_LIBRARY_PATH)
    list(APPEND SWIFT_ENV_COMMAND "LD_LIBRARY_PATH=${SWIFT_RUNTIME_LIBRARY_PATH}:$ENV{LD_LIBRARY_PATH}")
    list(APPEND SWIFT_ENV_COMMAND "LIBRARY_PATH=${SWIFT_RUNTIME_LIBRARY_PATH}:$ENV{LIBRARY_PATH}")
endif()
list(APPEND SWIFT_ENV_COMMAND "HOME=${SWIFT_OUTPUT_DIR}/.swift-home")
list(APPEND SWIFT_ENV_COMMAND ${SWIFT_COMMAND})

execute_process(
    COMMAND ${SWIFT_ENV_COMMAND}
    WORKING_DIRECTORY ${SWIFT_OUTPUT_DIR}
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
        WORKING_DIRECTORY ${SWIFT_OUTPUT_DIR}
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
    else()
        set(result 0)
    endif()
endif()

if(result EQUAL 0)
    set(SWIFT_ARTIFACT_DIR "${SWIFT_OUTPUT_DIR}/swift-build/${SWIFT_BUILD_TYPE}")
    set(SWIFT_BINARY_FOUND FALSE)
    set(SWIFT_BINARY_CANDIDATES
        "${SWIFT_OUTPUT_DIR}/swift-build/${SWIFT_BUILD_TYPE}/hazkey-server"
        "${SWIFT_WORK_DIR}/.build/${SWIFT_TARGET_TRIPLE}/${SWIFT_BUILD_TYPE}/hazkey-server"
        "${SWIFT_WORK_DIR}/.build/${SWIFT_TARGET_TRIPLE}/${SWIFT_BUILD_TYPE}/hazkey_server"
        "${SWIFT_WORK_DIR}/.build/${SWIFT_BUILD_TYPE}/hazkey-server"
        "${SWIFT_WORK_DIR}/.build/${SWIFT_BUILD_TYPE}/hazkey_server"
    )
    foreach(candidate ${SWIFT_BINARY_CANDIDATES})
        if(NOT SWIFT_BINARY_FOUND AND EXISTS "${candidate}")
            file(MAKE_DIRECTORY "${SWIFT_ARTIFACT_DIR}")
            file(COPY "${candidate}" DESTINATION "${SWIFT_ARTIFACT_DIR}")
            set(SWIFT_BINARY_FOUND TRUE)
        endif()
    endforeach()
    if(NOT SWIFT_BINARY_FOUND)
        message(FATAL_ERROR "Swift build succeeded but hazkey-server binary was not found.")
    endif()
endif()
