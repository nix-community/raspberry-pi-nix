rpi:
{ lib, pkgs, config, ... }:

{
  imports = [ rpi ];
  hardware.raspberry-pi.deviceTree.base-dtb = "bcm2711-rpi-4-b.dtb";
}

