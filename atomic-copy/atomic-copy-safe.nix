{ pkgs }:

pkgs.substituteAll {
  src = ./atomic-copy-safe.sh;
  isExecutable = true;
  path = [pkgs.coreutils pkgs.gnused pkgs.gnugrep];
  inherit (pkgs) bash;
}
