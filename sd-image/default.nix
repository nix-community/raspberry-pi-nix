stable:
{ config, lib, pkgs, ... }:

{
  imports = [ (import ./sd-image.nix stable) ];

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  boot.consoleLogLevel = lib.mkDefault 7;

  # The serial ports listed here are:
  # - ttyS0: for Tegra (Jetson TX1)
  # - ttyAMA0: for QEMU's -machine virt
  boot.kernelParams =
    [ "console=ttyS0,115200n8" "console=ttyAMA0,115200n8" "console=tty0" ];

  sdImage = {
    populateFirmwareCommands = let
      raspberrypifw = pkgs.raspberrypifw-5_15_56;
      configTxt = pkgs.writeText "config.txt" ''
        [pi02]
        kernel=u-boot-rpi_arm64.bin

        [pi3+]
        kernel=u-boot-rpi_arm64.bin

        [pi4]
        kernel=u-boot-rpi4.bin
        enable_gic=1
        armstub=armstub8-gic.bin
        arm_boost=1

        # Otherwise the resolution will be weird in most cases, compared to
        # what the pi3 firmware does by default.
        disable_overscan=1

        [all]
        # Boot in 64-bit mode.
        arm_64bit=1

        # U-Boot needs this to work, regardless of whether UART is actually used or not.
        # Look in arch/arm/mach-bcm283x/Kconfig in the U-Boot tree to see if this is still
        # a requirement in the future.
        enable_uart=1

        # Prevent the firmware from smashing the framebuffer setup done by the mainline kernel
        # when attempting to show low-voltage or overtemperature warnings.
        avoid_warnings=1
      '';
    in ''
      (cd ${raspberrypifw}/share/raspberrypi/boot && cp bootcode.bin fixup*.dat start*.elf $NIX_BUILD_TOP/firmware/)

      # Add the config
      cp ${configTxt} firmware/config.txt

      # Add rpi generic u-boot
      cp ${pkgs.uboot_rpi_arm64}/u-boot.bin firmware/u-boot-rpi_arm64.bin

      # Add pi3 specific files
      cp ${raspberrypifw}/share/raspberrypi/boot/bcm2710-rpi-3-b-plus.dtb firmware/

      # Add pi4 specific files
      cp ${pkgs.ubootRaspberryPi4_64bit}/u-boot.bin firmware/u-boot-rpi4.bin
      cp ${pkgs.raspberrypi-armstubs}/armstub8-gic.bin firmware/armstub8-gic.bin
      cp ${raspberrypifw}/share/raspberrypi/boot/bcm2711-rpi-4-b.dtb firmware/

      # Add pi-zero-2 specific files
      cp ${raspberrypifw}/share/raspberrypi/boot/bcm2710-rpi-zero-2.dtb firmware/
      cp ${raspberrypifw}/share/raspberrypi/boot/bcm2710-rpi-zero-2-w.dtb firmware/
    '';
    populateRootCommands = ''
      mkdir -p ./files/boot
      ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d ./files/boot
    '';
  };
}
