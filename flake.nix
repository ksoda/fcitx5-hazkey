{
  description = "fcitx5-hazkey development shell and package";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        lib = pkgs.lib;
        swiftDependencies = with pkgs; [
          stdenv.cc.cc
          stdenv.cc.cc.lib
          glibc
          glibc.dev
          ncurses
          zlib
          libxml2
          libbsd
          openssl
          sqlite
          icu
          curl
          nghttp2
          libpsl
          libidn2
          libssh2
          krb5
          openldap
          zstd
          brotli
          xz
          libunistring
          gnutls
          nettle
          gmp
          libtasn1
          p11-kit
          keyutils
          c-ares
          rtmpdump
          cyrus_sasl
          libffi
          util-linux
          gitMinimal
          clang
          gnustep.libobjc
        ];
        swiftDepsLib = lib.makeLibraryPath swiftDependencies;
        swiftSdk = pkgs.runCommand "swift-sdk-sysroot" {} ''
          set -euo pipefail
          shopt -s nullglob
          mkdir -p $out/lib $out/lib64 $out/usr/lib $out/usr/lib64
          mkdir -p $out/include $out/usr/include
          link_dir() {
            local source="$1"
            local dest="$2"
            if [ -d "$source" ]; then
              mkdir -p "$dest"
              for item in "$source"/*; do
                ln -sfn "$item" "$dest/$(basename "$item")"
              done
            fi
          }
          for src in ${pkgs.glibc}/lib ${pkgs.gcc}/lib; do
            link_dir "$src" "$out/lib"
            link_dir "$src" "$out/usr/lib"
          done
          for src in ${pkgs.glibc}/lib64 ${pkgs.gcc}/lib64; do
            link_dir "$src" "$out/lib64"
            link_dir "$src" "$out/usr/lib64"
          done
          link_dir ${pkgs.glibc.dev}/include "$out/include"
          link_dir ${pkgs.glibc.dev}/include "$out/usr/include"
          if [ -d ${pkgs.gcc}/lib/gcc ]; then
            for targetDir in ${pkgs.gcc}/lib/gcc/*; do
              target=$(basename "$targetDir")
              for versionDir in "$targetDir"/*; do
                ver=$(basename "$versionDir")
                dest="$out/usr/lib/gcc/$target/$ver"
                mkdir -p "$dest"
                for file in "$versionDir"/*; do
                  ln -sfn "$file" "$dest/$(basename "$file")"
                done
              done
            done
          fi
        '';
      in
      let
        swiftTarball = pkgs.fetchurl {
          url = "https://download.swift.org/swift-6.1.3-release/ubuntu2204/swift-6.1.3-RELEASE/swift-6.1.3-RELEASE-ubuntu22.04.tar.gz";
          sha256 = "sha256-KOSySt+bG3grdZGdnyoLCtfhboQ6qiA+C6yngCSNzdY=";
        };

        swiftRuntimeLibPaths =
          "${swiftDepsLib}:${swiftUnwrapped}/lib:${swiftUnwrapped}/lib/swift/linux:${swiftUnwrapped}/lib/swift/host:${swiftUnwrapped}/lib/swift/host/compiler:${swiftSdk}/lib";

        swiftUnwrapped = pkgs.stdenv.mkDerivation {
          pname = "swift-6.1.3";
          version = "6.1.3";
          src = swiftTarball;
          dontConfigure = true;
          dontBuild = true;
          nativeBuildInputs = [ pkgs.patchelf pkgs.file pkgs.findutils pkgs.makeWrapper ];
          buildInputs = swiftDependencies;
          installPhase = ''
            runHook preInstall
            mkdir -p $out
            tar -xzf $src --strip-components=1 -C $out
            if [ -d $out/usr ]; then
              shopt -s dotglob
              for entry in $out/usr/*; do
                mv "$entry" $out/
              done
              shopt -u dotglob
              rm -r $out/usr
            fi
            runHook postInstall
          '';
          postFixup = ''
            ${pkgs.findutils}/bin/find $out -type f -perm -0100 | while IFS= read -r f; do
              if ${pkgs.file}/bin/file -b "$f" | grep -q ELF; then
                ${pkgs.patchelf}/bin/patchelf \
                  --set-interpreter ${pkgs.stdenv.cc.bintools.dynamicLinker} \
                  --set-rpath ${swiftDepsLib}:$out/lib:$out/lib/swift/linux:$out/lib/swift/host:$out/lib/swift/host/compiler:${swiftSdk}/lib \
                  "$f" || true
              fi
            done
            runtimePath="${swiftDepsLib}:$out/lib:$out/lib/swift/linux:$out/lib/swift/host:$out/lib/swift/host/compiler:${swiftSdk}/lib"
            if [ -x "$out/bin/swiftc" ]; then
              wrapProgram "$out/bin/swiftc" \
                --prefix LD_LIBRARY_PATH : "$runtimePath" \
                --prefix LIBRARY_PATH : "${swiftDepsLib}:${swiftSdk}/lib" \
                --add-flags "-tools-directory" \
                --add-flags "${pkgs.clang}/bin"
            fi
          '';
        };

        fcitx5-hazkey = pkgs.callPackage ./nix/package.nix {
          src = self;
          qt6 = pkgs.qt6;
          hazkeySwiftToolchain = swiftUnwrapped;
          swiftRuntimeLibPaths = swiftRuntimeLibPaths;
          swiftSdkPath = swiftSdk;
          inherit swiftUnwrapped;
       };
      in
      {
        packages.default = fcitx5-hazkey;
        packages.fcitx5-hazkey = fcitx5-hazkey;
        packages.swiftUnwrapped = swiftUnwrapped;

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            cmake
            ninja
            pkg-config
            gettext
            protobuf
            swiftUnwrapped
            qt6.qtbase
            qt6.qttools
            fcitx5
            vulkan-headers
          ];
        };
      });
}
