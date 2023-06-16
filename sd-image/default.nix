{ config, lib, pkgs, ... }:

{
  imports = [ ./sd-image.nix ];

  config = {
    boot.loader.grub.enable = false;
    boot.loader.generic-extlinux-compatible.enable = true;

    boot.consoleLogLevel = lib.mkDefault 7;

    # https://github.com/raspberrypi/firmware/issues/1539#issuecomment-784498108
    boot.kernelParams = [ "console=ttyAMA0,115200n8" "console=tty1" ];

    sdImage = {
      populateFirmwareCommands = ''
        cp ${pkgs.uboot_rpi_arm64}/u-boot.bin firmware/u-boot-rpi-arm64.bin
        cp -r ${pkgs.raspberrypifw}/share/raspberrypi/boot/{start*.elf,*.dtb,bootcode.bin,fixup*.dat,overlays} firmware
        cp ${config.hardware.raspberry-pi.config-output} firmware/config.txt
      '';
      populateRootCommands = ''
        mkdir -p ./files/boot
        ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d ./files/boot
      '';
    };
  };
}
