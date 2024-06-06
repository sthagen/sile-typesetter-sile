{
  description = "Simon’s Improved Layout Engine";

  # To make user overrides of the nixpkgs flake not take effect
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.gitignore = {
    url = "github:hercules-ci/gitignore.nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  # TODO: Should this be replaced with libtexpdf package from nixpkgs? or
  # should we keep it that way, so that it'd be easy to test new versions
  # of libtexpdf when developing?
  inputs.libtexpdf-src = {
    url = "github:sile-typesetter/libtexpdf";
    flake = false;
  };

  # https://wiki.nixos.org/wiki/Flakes#Using_flakes_with_stable_Nix
  inputs.flake-compat = {
    url = "github:edolstra/flake-compat";
    flake = false;
  };

  outputs = { self
    , nixpkgs
    , flake-utils
    , flake-compat
    , gitignore
    , libtexpdf-src
  }:
  flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs {
        inherit system;
      };
      inherit (gitignore.lib) gitignoreSource;
      # https://discourse.nixos.org/t/passing-git-commit-hash-and-tag-to-build-with-flakes/11355/2
      version_rev = if (self ? rev) then (builtins.substring 0 7 self.rev) else "dirty";
      sile = pkgs.callPackage ./build-aux/pkg.nix {
        version = "${(pkgs.lib.importJSON ./package.json).version}-${version_rev}-flake";
        src = pkgs.lib.cleanSourceWith {
          # Ignore many files that gitignoreSource doesn't ignore, see:
          # https://github.com/hercules-ci/gitignore.nix/issues/9#issuecomment-635458762
          filter = path: type:
          ! (builtins.any (r: (builtins.match r (builtins.baseNameOf path)) != null) [
            # Nix files
            "flake.nix"
            "flake.lock"
            "default.nix"
            "shell.nix"
            # git commit and editing format files
            ".commitlintrc.yml"
            "package.json"
            ".husky"
            ".editorconfig"
            # CI files
            ".cirrus.yml"
            ".github"
            "action.yml"
            "azure-pipelines.yml"
            "Dockerfile"
            # Git files
            ".gitattributes"
            ".git"
          ]);
          src = gitignoreSource ./.;
        };
        inherit libtexpdf-src;
      };
      inherit (sile.passthru) luaEnv;
    in rec {
      devShells = {
        default = pkgs.mkShell {
          inherit (sile)
            buildInputs
            nativeCheckInputs
            FONTCONFIG_FILE
          ;
          configureFlags =  sile.configureFlags ++ [ "--enable-developer-mode" "--with-manual" ];
          nativeBuildInputs = sile.nativeBuildInputs ++ [
            pkgs.luarocks
            # For regression test diff highlighting
            pkgs.delta
            # For commitlint git hook
            pkgs.yarn
            # For npx
            pkgs.nodejs
            # For gs, dot, and bsdtar used in building the manual
            pkgs.ghostscript
            pkgs.graphviz
            pkgs.libarchive
          ];
        };
      };
      packages = {
        sile-lua5_2 = sile;
        sile-lua5_3 = sile.override {
          lua = pkgs.lua5_3;
        };
        sile-lua5_4 = sile.override {
          lua = pkgs.lua5_4;
        };
        sile-luajit = sile.override {
          lua = pkgs.luajit;
        };
        sile-clang = sile.override {
          lua = pkgs.luajit;
          # Use the same clang version as Nixpkgs' rust clang stdenv
          stdenv = pkgs.rustc.llvmPackages.stdenv;
        };
      };
      defaultPackage = packages.sile-luajit;
      apps = rec {
        default = sile;
        sile = {
          type = "app";
          program = "${self.defaultPackage.${system}}/bin/sile";
        };
      };
      defaultApp = apps.sile;
    }
  );
}
