{
  description = "Common packages and container images";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
      imagesFor = pkgs: import ./images { inherit pkgs; };
    in
    {
      packages = forAllSystems (
        pkgs: nixpkgs.lib.mapAttrs' (name: nixpkgs.lib.nameValuePair "${name}-image") (imagesFor pkgs)
      );

      # Image names, for CI to build a matrix from.
      imageNames = builtins.attrNames (imagesFor nixpkgs.legacyPackages.x86_64-linux);

      # Tools the image workflow uses to push and assemble multi-arch manifests.
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.skopeo
            pkgs.crane
          ];
        };
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt);
    };
}
