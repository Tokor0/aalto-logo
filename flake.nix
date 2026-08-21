{
  description = "Aalto University logo Typst package";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      perSystem =
        { config, pkgs, ... }:
        let
          # typst.toml is the single source of truth for the package identity;
          # the derivation and its install path follow it rather than repeating
          # it, so a version bump is a one-line change.
          manifest = (builtins.fromTOML (builtins.readFile ./typst.toml)).package;
        in
        {
          devShells.default =
            let
              typst-packages = pkgs.symlinkJoin {
                name = "typst-packages";
                paths = [ config.packages.default ];
              };
            in
            pkgs.mkShell {
              # Build inputs for the logo pipeline: download_logos.py fetches the
              # vector PDFs, build_vectors.py turns them into Typst curve data.
              packages = [
                (pkgs.python3.withPackages (ps: [ ps.pillow ]))
                pkgs.mupdf # mutool, for PDF -> SVG with text as paths
                pkgs.typst
                pkgs.gnumake # the Makefile drives the pipeline and the packaging
              ];
              TYPST_PACKAGE_PATH = "${typst-packages}/share/typst/packages";
            };

          packages.default = pkgs.stdenv.mkDerivation {
            pname = "typst-${manifest.name}";
            inherit (manifest) version;

            src = ./.;

            dontBuild = true;

            # Installs exactly what the published bundle contains -- see the
            # exclude list in typst.toml.
            installPhase = ''
              local dest="$out/share/typst/packages/local/${manifest.name}/${manifest.version}"
              mkdir -p "$dest"
              cp typst.toml lib.typ README.md LICENSE "$dest"
              cp -r logos "$dest"
            '';
          };
        };
    };
}
