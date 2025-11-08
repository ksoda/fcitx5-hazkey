{ stdenv
, lib
, src
, cmake
, ninja
, pkg-config
, gettext
, protobuf
, swiftUnwrapped
, hazkeySwiftToolchain
, git
, qt6
, fcitx5
, vulkan-headers
, python3
, patchelf
, swiftRuntimeLibPaths
, swiftSdkPath
}:

assert hazkeySwiftToolchain != null;
assert swiftUnwrapped != null;

stdenv.mkDerivation rec {
  pname = "fcitx5-hazkey";
  version = "0.0.9";
  inherit src;

  nativeBuildInputs =
    [
      cmake
      ninja
      pkg-config
      gettext
      git
      qt6.wrapQtAppsHook
      python3
      hazkeySwiftToolchain
      patchelf
    ]
    ;

  buildInputs = [
    protobuf
    qt6.qtbase
    qt6.qttools
    fcitx5
    vulkan-headers
  ];

  cmakeFlags =
    [
      "-GNinja"
      "-DCMAKE_BUILD_TYPE=Release"
      "-DSWIFT_EXECUTABLE=${hazkeySwiftToolchain}/bin/swift"
      "-DSWIFT_BUILD_EXECUTABLE=${hazkeySwiftToolchain}/bin/swift-build"
      "-DSWIFT_LINK_PATH=${swiftUnwrapped}/lib/swift/linux"
      "-DSWIFT_RUNTIME_LIBRARY_PATH=${swiftRuntimeLibPaths}"
      "-DSWIFT_SDK_PATH=${swiftSdkPath}"
    ]
    ;

  postInstall = ''
    if [ -x "$out/lib/hazkey/hazkey-server" ]; then
      patchelf --set-rpath "${swiftUnwrapped}/lib/swift/linux:$out/lib/hazkey" \
        "$out/lib/hazkey/hazkey-server"
    fi
  '';

  meta = with lib; {
    description = "Hazkey input method for fcitx5";
    homepage = "https://github.com/7ka-Hiira/fcitx5-hazkey";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
