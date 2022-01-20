{ config, lib, pkgs, ... }:

let cfg = config.hardware.raspberry-pi.i2c;
in {
  options.hardware.raspberry-pi.i2c = {
    enable = lib.mkEnableOption "configuration for i2c";
  };
  config = lib.mkIf cfg.enable {
    hardware = {
      raspberry-pi.deviceTree.base-dtb-params = [ "i2c1=on" ];
      i2c.enable = true;
    };
  };
}
