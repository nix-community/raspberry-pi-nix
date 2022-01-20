rpi:
{ lib, pkgs, config, ... }:

{
  imports = [ rpi ];
  hardware.raspberry-pi.deviceTree = {
    base-dtb = "bcm2710-rpi-3-b-plus.dtb";
    # u-boot expects bcm2837-rpi-3-b-plus.dtb for the 3b+ (as of
    # 2020.04), although the kernel has 2710. We rename it to satisfy
    # u-boot for now.
    postInstall = ''
      mv $out/broadcom/bcm2710-rpi-3-b-plus.dtb $out/broadcom/bcm2837-rpi-3-b-plus.dtb
    '';
  };
}
