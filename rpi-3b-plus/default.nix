rpi:
{ lib, pkgs, config, ... }:

{
  imports = [ rpi ];
  hardware.raspberry-pi.deviceTree = {
    base-dtb = "bcm2710-rpi-3-b-plus.dtb";
    # u-boot expects bcm2837-rpi-3-b-plus.dtb for the 3b+ Rename the
    # raspberry pi dtb to match mainline linux and satisfy u-boot.
    postInstall = ''
      mv $out/broadcom/bcm2710-rpi-3-b-plus.dtb $out/broadcom/bcm2837-rpi-3-b-plus.dtb
    '';
  };
}
