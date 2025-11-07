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
      in
      let
        swiftTarball = pkgs.fetchurl {
          url = "https://download.swift.org/swift-6.1.3-release/ubuntu2204/swift-6.1.3-RELEASE/swift-6.1.3-RELEASE-ubuntu22.04.tar.gz";
          sha256 = "sha256-KOSySt+bG3grdZGdnyoLCtfhboQ6qiA+C6yngCSNzdY=";
        };

        swiftUnwrapped = pkgs.stdenv.mkDerivation {
          pname = "swift-6.1.3";
          version = "6.1.3";
          src = swiftTarball;
          dontConfigure = true;
          dontBuild = true;
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
        };

        swiftFhsPackages = pkgs: with pkgs; [
          swiftUnwrapped
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

        swiftFhsRunScript = pkgs.writeShellScript "swift-fhs-entry" ''
          export LD_LIBRARY_PATH=/lib:/lib64:/usr/lib:/usr/lib64
          exec ${swiftUnwrapped}/bin/swift "$@"
        '';

        swiftFHS = pkgs.buildFHSUserEnv {
          name = "swift-6.1.3-fhs";
          targetPkgs = swiftFhsPackages;
          runScript = "${swiftFhsRunScript}";
          extraInstallCommands = ''
            ln -s $out/bin/swift-6.1.3-fhs $out/bin/swift
          '';
        };

        fcitx5-hazkey = pkgs.callPackage ./nix/package.nix {
          src = self;
          qt6 = pkgs.qt6;
          hazkeySwiftToolchain = swiftFHS;
          inherit swiftUnwrapped;
       };
      in
      {
        packages.default = fcitx5-hazkey;
        packages.fcitx5-hazkey = fcitx5-hazkey;
        packages.swiftFHS = swiftFHS;

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            cmake
            ninja
            pkg-config
            gettext
            protobuf
            swiftFHS
            qt6.qtbase
            qt6.qttools
            fcitx5
            vulkan-headers
          ];
        };
      });
}
