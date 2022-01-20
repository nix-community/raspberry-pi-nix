{ config, lib, pkgs, ... }:

let cfg = config.hardware.raspberry-pi.audio;
in {
  options.hardware.raspberry-pi.audio = {
    enable = lib.mkEnableOption "configuration for audio";
  };
  config = lib.mkIf cfg.enable {
    hardware = {
      raspberry-pi.deviceTree.base-dtb-params = [ "audio=on" ];
      pulseaudio.configFile = lib.mkOverride 990
        (pkgs.runCommand "default.pa" { } ''
          sed 's/module-udev-detect$/module-udev-detect tsched=0/' ${config.hardware.pulseaudio.package}/etc/pulse/default.pa > $out
        '');
    };
  };
}
