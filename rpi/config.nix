{ lib, config, pkgs, ... }:
let
  cfg = config;
  render-raspberrypi-config = let
    render-options = opts:
      lib.strings.concatStringsSep "\n" (render-dt-kvs opts);
    render-dt-param = x: "dtparam=" + x;
    render-dt-kv = k: v:
      if isNull v then k else let vstr = toString v; in "${k}=${vstr}";
    render-dt-kvs = x: lib.attrsets.mapAttrsToList render-dt-kv x;
    render-dt-overlay = { overlay, args }:
      "dtoverlay=" + overlay + "\n"
      + lib.strings.concatMapStringsSep "\n" render-dt-param args + "\n"
      + "dtoverlay=";
    render-base-dt-params = params:
      lib.strings.concatMapStringsSep "\n" render-dt-param
      (render-dt-kvs params);
    render-dt-overlays = overlays:
      lib.strings.concatMapStringsSep "\n" render-dt-overlay
      (lib.attrsets.mapAttrsToList (k: v: {
        overlay = k;
        args = render-dt-kvs v;
      }) overlays);
    render-config-section = k:
      { options, base-dtb-params, dt-overlays }: ''
        [${k}]
        ${render-options options}
        ${render-base-dt-params base-dtb-params}
        ${render-dt-overlays dt-overlays}
      '';
  in conf:
  lib.strings.concatStringsSep "\n"
  (lib.attrsets.mapAttrsToList render-config-section conf);
in {
  options = {
    raspberrypi-config = let
      raspberrypi-config-options = {
        options = {
          options = lib.mkOption {
            type = with lib.types; attrsOf anything;
            default = { };
            example = {
              enable_gic = true;
              armstub = "armstub8-gic.bin";
              arm_boost = true;
            };
          };
          base-dtb-params = lib.mkOption {
            type = with lib.types; attrsOf anything;
            default = { };
            example = {
              i2c = "on";
              audio = "on";
            };
            description = "parameters to pass to the base dtb";
          };
          dt-overlays = lib.mkOption {
            type = with lib.types; attrsOf (attrsOf (nullOr str));
            default = { };
            example = { vc4-kms-v3d = { cma-256 = null; }; };
            description = "dtb overlays to apply";
          };
        };
      };
    in lib.mkOption {
      type = with lib.types; attrsOf (submodule raspberrypi-config-options);
    };
    raspberrypi-config-output = lib.mkOption {
      type = lib.types.package;
      default = pkgs.writeTextFile {
        name = "config.txt";
        text = ''
          # Auto-generated by nix. Modifications will be overwritten.
          ${render-raspberrypi-config cfg.raspberrypi-config}
        '';
      };
    };
  };

}