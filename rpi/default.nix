{ overlay }:
{ lib, pkgs, config, ... }:

{
  imports = [ ../sd-image ./config.nix ];

  system.activationScripts.raspberrypi = {
    text = ''
      if ! grep -qs '/boot/firmware ' /proc/mounts; then
         mount /dev/disk/by-label/${config.sdImage.firmwarePartitionName} /boot/firmware
      fi
      cp ${pkgs.uboot_rpi_arm64}/u-boot.bin /boot/firmware/u-boot-rpi-arm64.bin
      cp -r ${pkgs.raspberrypifw}/share/raspberrypi/boot/{start*.elf,*.dtb,bootcode.bin,fixup*.dat,overlays} /boot/firmware
      cp ${config.raspberrypi-config-output} /boot/firmware/config.txt
    '';
  };

  raspberrypi-config = {
    pi4 = {
      options = {
        enable_gic = true;
        armstub = "armstub8-gic.bin";
        arm_boost = true;
        disable_overscan = true;
      };
      dt-overlays = { vc4-kms-v3d-pi4 = { cma-512 = null; }; };
    };
    pi02 = { dt-overlays = { vc4-kms-v3d = { cma-256 = null; }; }; };
    all = {
      options = {
        kernel = "u-boot-rpi-arm64.bin";
        enable_uart = true;
        avoid_warnings = true;
        arm_64bit = true;
      };
      base-dtb-params = { krnbt = "on"; };
    };
  };

  nixpkgs = { overlays = [ overlay ]; };
  boot = {
    initrd.availableKernelModules = [
      "usbhid"
      "usb_storage"
      "vc4"
      "pcie_brcmstb" # required for the pcie bus to work
      "reset-raspberrypi" # required for vl805 firmware to load
    ];
    kernelPackages = pkgs.linuxPackagesFor (pkgs.rpi-kernels.latest.kernel);

    loader = {
      grub.enable = lib.mkDefault false;
      generic-extlinux-compatible = {
        enable = lib.mkDefault true;
        # We want to use the device tree provided by firmware, so don't
        # add FDTDIR to the extlinux conf file.
        useGenerationDeviceTree = false;
      };
    };
  };
  hardware.enableRedistributableFirmware = true;
}
