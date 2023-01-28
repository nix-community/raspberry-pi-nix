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
    initrd.availableKernelModules = [ "usbhid" "usb_storage" "vc4" ];
    kernelPackages = pkgs.linuxPackagesFor (pkgs.rpi-kernels.v5_15_87.kernel);

    loader = {
      grub.enable = lib.mkDefault false;
      generic-extlinux-compatible.enable = lib.mkDefault true;
    };
  };
  hardware.enableRedistributableFirmware = true;

}
