set(PROTO_FILES
    ${CMAKE_CURRENT_SOURCE_DIR}/../../protocol/base.proto
    ${CMAKE_CURRENT_SOURCE_DIR}/../../protocol/commands.proto
    ${CMAKE_CURRENT_SOURCE_DIR}/../../protocol/config.proto
)
set(PROTO_GEN_DIR ${CMAKE_CURRENT_BINARY_DIR}/generated)
file(MAKE_DIRECTORY ${PROTO_GEN_DIR})

add_library(fcitx5-hazkey SHARED hazkey_state.cpp hazkey_engine.cpp hazkey_candidate.cpp hazkey_preedit.cpp hazkey_server_connector.cpp)

if(Protobuf_VERSION VERSION_LESS "3.12")
    message(FATAL_ERROR "protobuf 3.12+ required for proto3 optional support. Current version: ${Protobuf_VERSION}")
endif()

set(PROTO_SRCS)
set(PROTO_HDRS)
set(_PROTO_OPTS)
if(Protobuf_VERSION VERSION_LESS "3.15")
    list(APPEND _PROTO_OPTS --experimental_allow_proto3_optional)
endif()

foreach(PROTO_FILE ${PROTO_FILES})
    get_filename_component(PROTO_NAME ${PROTO_FILE} NAME_WE)
    set(PROTO_SRC "${PROTO_GEN_DIR}/${PROTO_NAME}.pb.cc")
    set(PROTO_HDR "${PROTO_GEN_DIR}/${PROTO_NAME}.pb.h")

    list(APPEND PROTO_SRCS ${PROTO_SRC})
    list(APPEND PROTO_HDRS ${PROTO_HDR})

    add_custom_command(
        OUTPUT ${PROTO_SRC} ${PROTO_HDR}
        COMMAND ${Protobuf_PROTOC_EXECUTABLE}
        ARGS --cpp_out=${PROTO_GEN_DIR}
             ${_PROTO_OPTS}
             --proto_path=${CMAKE_CURRENT_SOURCE_DIR}/../../protocol
             ${CMAKE_CURRENT_SOURCE_DIR}/../../protocol/${PROTO_NAME}.proto
        DEPENDS ${PROTO_FILE}
        COMMENT "Generating C++ protobuf files from ${PROTO_FILE}"
        VERBATIM
    )
endforeach()

target_sources(fcitx5-hazkey PRIVATE ${PROTO_SRCS} ${PROTO_HDRS})

target_include_directories(fcitx5-hazkey PRIVATE ${PROTO_GEN_DIR} ${Protobuf_INCLUDE_DIRS})
target_link_libraries(fcitx5-hazkey PRIVATE Fcitx5::Core Fcitx5::Config ${Protobuf_LITE_LIBRARIES})


set_target_properties(fcitx5-hazkey PROPERTIES PREFIX "")
install(TARGETS fcitx5-hazkey DESTINATION "${FCITX_INSTALL_LIBDIR}/fcitx5")

configure_file(hazkey-addon.conf.in.in hazkey-addon.conf.in @ONLY)
fcitx5_translate_desktop_file("${CMAKE_CURRENT_BINARY_DIR}/hazkey-addon.conf.in" "hazkey-addon.conf")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/hazkey-addon.conf" RENAME hazkey.conf DESTINATION "${FCITX_INSTALL_PKGDATADIR}/addon")

fcitx5_translate_desktop_file(hazkey-im.conf.in hazkey-im.conf)
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/hazkey-im.conf" RENAME hazkey.conf DESTINATION "${FCITX_INSTALL_PKGDATADIR}/inputmethod")
