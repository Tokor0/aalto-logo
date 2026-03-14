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
        { pkgs, ... }:
        {
          devShells.default =
            let
              typst-packages = pkgs.symlinkJoin {
                name = "typst-packages";
                paths = [ config.packages.default ];
              };
            in
            pkgs.mkShell {
              TYPST_PACKAGE_PATH = "${typst-packages}/share/typst/packages";
            };

          packages.default = pkgs.stdenv.mkDerivation {
            pname = "typst-aalto-logo";
            version = "0.1.0";

            src = ./.;

            dontBuild = true;

            installPhase = ''
              local dest="$out/share/typst/packages/local/aalto-logo/0.1.0"
              mkdir -p "$dest"
              cp typst.toml lib.typ "$dest"
              cp -r logos "$dest"
            '';
          };
        };
    };
}
