{ config, lib, pkgs, ... }:

let cfg = config.hardware.raspberry-pi.deviceTree;
in {
  options.hardware.raspberry-pi.deviceTree = {
    base-dtb = lib.mkOption {
      type = lib.types.str;
      example = "bcm2711-rpi-4-b.dtb";
      description = "base dtb to apply";
    };
    base-dtb-params = lib.mkOption {
      type = lib.types.listOf lib.types.string;
      default = [ ];
      example = [ "i2c1=on" "audio=on" ];
      description = "parameters to pass to the base dtb";
    };
    dt-overlays = lib.mkOption {
      type = with lib.types;
        listOf (submodule {
          options = {
            overlay = lib.mkOption { type = oneOf [ str path ]; };
            args = lib.mkOption {
              type = listOf str;
              default = [ ];
            };
          };
        });
      default = [ ];
      example = [{
        overlay = "vc4-fkms-v3d";
        args = [ "cma-512" ];
      }];
      description = "dtb overlays to apply";
    };
    postInstall = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "bash command to run after building dtb";
    };
  };
  config = {
    hardware = {
      deviceTree = {
        enable = true;
        filter = cfg.base-dtb;
        package = let
          dtbsWithSymbols = pkgs.stdenv.mkDerivation {
            name = "dtbs-with-symbols";
            inherit (config.boot.kernelPackages.kernel)
              src nativeBuildInputs depsBuildBuild;
            patches = map (patch: patch.patch)
              config.boot.kernelPackages.kernel.kernelPatches;
            buildPhase = ''
              patchShebangs scripts/*
              substituteInPlace scripts/Makefile.lib \
                --replace 'DTC_FLAGS += $(DTC_FLAGS_$(basetarget))' 'DTC_FLAGS += $(DTC_FLAGS_$(basetarget)) -@'
              make ${pkgs.stdenv.hostPlatform.linux-kernel.baseConfig} ARCH="${pkgs.stdenv.hostPlatform.linuxArch}"
              make dtbs ARCH="${pkgs.stdenv.hostPlatform.linuxArch}"
            '';
            installPhase = ''
              make dtbs_install INSTALL_DTBS_PATH=$out/dtbs  ARCH="${pkgs.stdenv.hostPlatform.linuxArch}"
            '';
          };
          compiled-overlays = map (x:
            let
              overlay-file = if builtins.isPath x.overlay then
                pkgs.runCommand "overlay.dtbo" {
                  buildInputs = with pkgs; [ dtc ];
                } "dtc -I dts -O dtb -o $out ${x.overlay}"
              else
                "${config.boot.kernelPackages.kernel}/dtbs/overlays/${x.overlay}.dtbo";
            in x // { overlay = overlay-file; }) cfg.dt-overlays;
        in lib.mkForce (pkgs.runCommand "device-tree-overlays" {
          buildInputs = with pkgs; [ findutils libraspberrypi ];
        } ''
          cd ${dtbsWithSymbols}/dtbs
          for dtb in $(find . -type f -name "${config.hardware.deviceTree.filter}")
          do
            install -D $dtb $out/$dtb

            ${
              lib.concatMapStrings (param: ''
                dtmerge -d $out/$dtb{,-merged} - ${param}
                mv $out/$dtb{-merged,}
              '') cfg.base-dtb-params
            }

            ${
              lib.concatMapStrings (x: ''
                dtmerge -d $out/$dtb{,-merged} ${x.overlay} ${
                  builtins.concatStringsSep " " x.args
                }
                mv $out/$dtb{-merged,}
              '') compiled-overlays
            }
          done
          ${cfg.postInstall}
        '');
      };
    };
  };
}
