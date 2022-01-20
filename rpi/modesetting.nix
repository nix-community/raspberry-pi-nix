{ config, lib, pkgs, ... }:

let cfg = config.hardware.raspberry-pi.fkms-3d;
in {
  options.hardware.raspberry-pi.fkms-3d = {
    enable = lib.mkEnableOption "Enable modesetting through fkms-3d";
  };
  config = lib.mkIf cfg.enable {
    hardware = {
      raspberry-pi.deviceTree.dt-overlays = [
        {
          overlay = "cma";
          args = [ ];
        }
        {
          overlay = "vc4-fkms-v3d";
          args = [ ];
        }
      ];
    };
    services.xserver.videoDrivers = lib.mkBefore [ "modesetting" "fbdev" ];
  };
}
