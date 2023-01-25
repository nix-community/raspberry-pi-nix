rpi:
{ lib, pkgs, config, ... }:

{
  imports = [ rpi ];
  nixpkgs = {
    overlays = [
      (final: prev: {
        raspberrypiWirelessFirmware =
          final.rpi-kernels.v5_15_36.wireless-firmware;
        raspberrypifw = final.rpi-kernels.v5_15_36.firmware;
      })
    ];
  };
  hardware.raspberry-pi.deviceTree.base-dtb = "bcm2710-rpi-zero-2.dtb";
  # u-boot expects bcm2837-rpi-zero-2.dtb for the zero 2 w (as of
  # 2020.04), although the kernel has 2710. We rename it to satisfy
  # u-boot for now.
  hardware.raspberry-pi.deviceTree.postInstall = ''
    mv $out/broadcom/bcm2710-rpi-zero-2.dtb $out/broadcom/bcm2837-rpi-zero-2.dtb
  '';
  boot.kernelPackages =
    pkgs.linuxPackagesFor (pkgs.rpi-kernels.v5_15_36.kernel);
}
