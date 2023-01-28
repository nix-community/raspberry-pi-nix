rpi:
{ lib, pkgs, config, ... }:

{
  imports = [ rpi ];
  hardware.raspberry-pi.deviceTree.base-dtb = "bcm2710-rpi-zero-2.dtb";
  # u-boot expects bcm2837-rpi-zero-2.dtb for the zero 2 w (this is
  # the device tree name in the upstream kernel), Rename the raspberry
  # pi dtb to the expected name to satisfy u-boot.
  hardware.raspberry-pi.deviceTree.postInstall = ''
    mv $out/broadcom/bcm2710-rpi-zero-2.dtb $out/broadcom/bcm2837-rpi-zero-2.dtb
  '';
}
