{ config, lib, pkgs, ... }:

let cfg = config.hardware.raspberry-pi.i2c;
in {
  options.hardware.raspberry-pi.i2c = {
    enable = lib.mkEnableOption "configuration for i2c";
  };
  config = lib.mkIf cfg.enable {
    hardware = {
      raspberry-pi.config.all.base-dt-params = { i2c = "on"; };
      i2c.enable = true;
    };
  };
}
