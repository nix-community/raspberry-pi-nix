{ config, lib, pkgs, ... }:

{
  imports = [ ./sd-image.nix ];

  config = {
    boot.loader.grub.enable = false;

    boot.consoleLogLevel = lib.mkDefault 7;

    # https://github.com/raspberrypi/firmware/issues/1539#issuecomment-784498108
    boot.kernelParams = [ "console=serial0,115200n8" "console=tty1" ];

    sdImage =
      let
        kernel-params = pkgs.writeTextFile {
          name = "cmdline.txt";
          text = ''
            ${lib.strings.concatStringsSep " " config.boot.kernelParams}
          '';
        };
        cfg = config.raspberry-pi-nix;
        version = cfg.kernel-version;
        board = cfg.board;
        kernel = pkgs.rpi-kernels."${version}"."${board}";
        populate-kernel =
          if cfg.uboot.enable
          then ''
            cp ${pkgs.uboot-rpi-arm64}/u-boot.bin firmware/u-boot-rpi-arm64.bin
          ''
          else ''
            cp "${kernel}/Image" firmware/kernel.img
            cp "${kernel-params}" firmware/cmdline.txt
          '';
      in
      {
        populateFirmwareCommands = ''
          ${populate-kernel}
          cp -r ${pkgs.raspberrypifw}/share/raspberrypi/boot/{start*.elf,*.dtb,bootcode.bin,fixup*.dat,overlays} firmware
          cp ${config.hardware.raspberry-pi.config-output} firmware/config.txt
        '';
        populateRootCommands =
          if cfg.uboot.enable
          then ''
            mkdir -p ./files/boot
            ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d ./files/boot
          ''
          else ''
            mkdir -p ./files/sbin
            content="$(
              echo "#!${pkgs.bash}/bin/bash"
              echo "exec ${config.system.build.toplevel}/init"
            )"
            echo "$content" > ./files/sbin/init
            chmod 744 ./files/sbin/init
          '';
      };
  };
}
