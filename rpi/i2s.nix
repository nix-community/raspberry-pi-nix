{ config, lib, pkgs, ... }:

let cfg = config.hardware.raspberry-pi.i2s;
in {
  options.hardware.raspberry-pi.i2s = {
    enable = lib.mkEnableOption "configuration for i2s";
  };
  config = lib.mkIf cfg.enable {
    hardware = {
      raspberry-pi.deviceTree.base-dtb-params = [ "i2s=on" ];
    };
  };
}
