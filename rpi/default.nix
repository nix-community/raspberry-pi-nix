{ overlay }:
{ lib, pkgs, config, ... }:

{
  imports = [
    ../sd-image
    ./device-tree.nix
    ./audio.nix
    ./i2c.nix
    ./i2s.nix
    ./modesetting.nix
  ];

  nixpkgs = { overlays = [ overlay ]; };
  boot = {
    kernelPackages = pkgs.linuxPackagesFor (pkgs.linux_rpi-5_15_61);
    initrd.availableKernelModules = [ "usbhid" "usb_storage" "vc4" ];

    loader = {
      grub.enable = lib.mkDefault false;
      generic-extlinux-compatible.enable = lib.mkDefault true;
    };
  };
  hardware.enableRedistributableFirmware = true;

}
