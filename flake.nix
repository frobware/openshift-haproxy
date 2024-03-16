{
  description = "A flake offering various versions of HAProxy, built in the style of OpenShift Ingress.";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, ... }: let
    forAllSystems = function: nixpkgs.lib.genAttrs [ "aarch64-darwin" "aarch64-linux" "x86_64-darwin" "x86_64-linux" ] (
      system: function system
    );

    haproxyOverlay = final: prev: let
      makeHAProxyPackage = { version, sha256, patches ? [], debug ? false, target ? "linux-glibc" }: prev.callPackage ./package.nix {
        inherit version sha256 debug patches target;
      };

      haproxyVersions = {
        "2.6.13" = {
          sha256 = "0hsj7zv1dxcz9ryr7hg1bczy7h9f488x307j5q9mg9mw7lizb7yn";
          patches = [
            ./patches/2.6.13/0001-BUG-MAJOR-http-reject-any-empty-content-length-heade.patch
            ./patches/2.6.13/0001-BUG-MINOR-fd-always-remove-late-updates-when-freeing.patch
          ];
        };
        "2.6.14" = {
          sha256 = "sha256-vT3Z+mA5HKCeEiXhrDFj5FvoPD9U8v12owryicxuT9Q=";
        };
        "2.6.15" = {
          sha256 = "sha256-QfjhaV6S+v3/45aQpomT8aD19/BpMamemhU/dJ6jnP0=";
        };
        "2.8.3" = {
          sha256 = "sha256-nsxv/mepd9HtJ5EHu9q3kNc64qYmvDju4j+h9nhqdZ4=";
        };
        "2.8.5" = {
          sha256 = "sha256-P1RZxaWOCzQ6MurvftW+2dP8KdiqnhSzbJLJafwqYNk=";
        };
        "2.8.6" = {
          sha256 = "sha256-n9A0NovmaIC9hqMAwT3AO8E1Ie4mVIgN3fGSeFqijVE=";
        };
      };

      versionsList = builtins.attrNames haproxyVersions;

      haproxyPackages = builtins.listToAttrs (nixpkgs.lib.flatten (nixpkgs.lib.mapAttrsToList (version: value: let
        releaseName = "ocp-haproxy-${builtins.replaceStrings ["."] ["_"] version}";
        debugName = "ocp-haproxy-debug-${builtins.replaceStrings ["."] ["_"] version}";
        releasePackage = makeHAProxyPackage { inherit version; sha256 = value.sha256; patches = value.patches or []; debug = false; };
        debugPackage = makeHAProxyPackage { inherit version; sha256 = value.sha256; patches = value.patches or []; debug = true; };
      in [
        { name = releaseName; value = releasePackage; }
        { name = debugName; value = debugPackage; }
      ]) haproxyVersions));

      createMetaPackage = { name, isDebug ? false }: prev.stdenv.mkDerivation {
        inherit name;
        buildInputs = [ prev.makeWrapper ];

        buildCommand = let
          createSymlinkCommand = version: let
            debugSuffix = prev.lib.optionalString isDebug "-debug";
            packageName = "ocp-haproxy${debugSuffix}-${prev.lib.replaceStrings ["."] ["_"] version}";
            binDir = prev.lib.getBin (haproxyPackages.${packageName});
            symlinkBaseName = "ocp-haproxy${debugSuffix}-${version}";
          in ''
            ln -s ${binDir}/bin/ocp-haproxy${debugSuffix} $out/bin/${symlinkBaseName}
            ${prev.lib.optionalString isDebug ''
              ln -s ${binDir}/bin/ocp-haproxy-gdb $out/bin/ocp-haproxy-gdb-${version}
            ''}
          '';
          symlinkCommands = prev.lib.concatStringsSep "\n" (map createSymlinkCommand versionsList);
        in ''
          mkdir -p $out/bin
          ${symlinkCommands}
        '';
      };

      haproxyMeta = createMetaPackage { name = "ocp-haproxy-meta"; };
      haproxyMetaDebug = createMetaPackage { name = "ocp-haproxy-debug-meta"; isDebug = true; };
    in haproxyPackages // {
      ocp-haproxy-meta = haproxyMeta;
      ocp-haproxy-debug-meta = haproxyMetaDebug;
      ocp-haproxy = final.ocp-haproxy-2_8_6;
    };
  in {
    checks = forAllSystems (system: {
      build = self.packages.${system}.default;
    });

    devShells = forAllSystems (system: let
      pkgs = (import nixpkgs {
        inherit system;
        config.permittedInsecurePackages = [
          "openssl-1.1.1w"
        ];
      });

      sharedNativeBuildInputs = [
        pkgs.gdb
        pkgs.pkg-config
        pkgs.valgrind
      ];

      sharedShellHook = ''
        export LD=$CC
        export CPU="generic"
        export TARGET="linux-glibc"
        export USE_REGPARM="1"
        export USE_OPENSSL="1"
        export USE_PCRE="1"
        export USE_ZLIB="1"
        export USE_CRYPT_H="1"
        export USE_LINUX_TPROXY="1"
        export USE_GETADDRINFO="1"
        export DEBUG_CFLAGS="-g -ggdb3 -O0 -fno-omit-frame-pointer -fno-inline"
        export MAKEFLAGS='-j$(nproc) -e'
        unset NIX_HARDENING_ENABLE
        export SRC=${self.packages.${system}.default.src}
        echo "HAProxy source is at: $SRC"
        # Setting NIX_PATH explicitly so that nix-prefetch-url can
        # find the nixpkgs location. This is essential because a
        # pure shell does not inherit NIX_PATH from the parent
        # environment.
        export NIX_PATH=nixpkgs=${pkgs.path}
      '';
    in rec {
      haproxy22 = pkgs.mkShell {
        buildInputs = [
          self.packages.${system}.default.buildInputs
        ];
        nativeBuildInputs = sharedNativeBuildInputs ++ [
          pkgs.gcc8
          pkgs.openssl_1_1
        ];
        shellHook = ''
          echo "haproxy22 dev environment"
        '' + sharedShellHook;
      };

      haproxy26 = pkgs.mkShell {
        buildInputs = [
          self.packages.${system}.default.buildInputs
        ];
        nativeBuildInputs = sharedNativeBuildInputs ++ [
          pkgs.gcc11
          pkgs.openssl_3
        ];
        shellHook = ''
          echo "haproxy26+ dev environment"
        '' + sharedShellHook;
      };

      haproxy28 = haproxy26;

      default = haproxy28;
    });

    overlays = {
      default = haproxyOverlay;
    };

    packages = forAllSystems (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ self.overlays.default ];
      };
    in {
      default = pkgs.ocp-haproxy;
      ocp-haproxy = pkgs.ocp-haproxy;
      ocp-haproxy-debug-meta = pkgs.ocp-haproxy-debug-meta;
      ocp-haproxy-meta = pkgs.ocp-haproxy-meta;
    });
  };
}
