{ config, inputs, lib, modulesPath, pkgs, ... }: {
  imports = [
    ./common.nix
  ];
  raspberry-pi-nix.uboot.enable = false;
}
