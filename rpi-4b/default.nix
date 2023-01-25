rpi:
{ lib, pkgs, config, ... }:

{
  nixpkgs = {
    overlays = [
      (final: prev: {
        raspberrypiWirelessFirmware =
          final.rpi-kernels.v5_15_87.wireless-firmware;
        raspberrypifw = final.rpi-kernels.v5_15_87.firmware;
      })
    ];
  };
  imports = [ rpi ];
  hardware.raspberry-pi.deviceTree.base-dtb = "bcm2711-rpi-4-b.dtb";
  boot.kernelPackages =
    pkgs.linuxPackagesFor (pkgs.rpi-kernels.v5_15_87.kernel);
}

