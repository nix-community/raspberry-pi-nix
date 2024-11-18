{ pkgs }:

pkgs.substituteAll {
  src = ./atomic-copy-clobber.sh;
  isExecutable = true;
  path = [pkgs.coreutils pkgs.gnused pkgs.gnugrep];
  inherit (pkgs) bash;
}
