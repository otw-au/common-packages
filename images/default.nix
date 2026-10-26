# Every attribute here is a container image, exposed as packages.<system>.<name>-image
# and picked up automatically by CI.
{ pkgs }:
{
  cups = pkgs.callPackage ./cups { };
}
