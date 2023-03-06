{ overlay }:
{ lib, pkgs, config, ... }:

{
  imports = [ ../sd-image ./config.nix ./i2c.nix ];

  # On activation install u-boot, Raspberry Pi firmware, and our
  # generated config.txt
  system.activationScripts.raspberrypi = {
    text = ''
      cp ${pkgs.uboot_rpi_arm64}/u-boot.bin /boot/firmware/u-boot-rpi-arm64.bin
      cp -r ${pkgs.raspberrypifw}/share/raspberrypi/boot/{start*.elf,*.dtb,bootcode.bin,fixup*.dat,overlays} /boot/firmware
      cp ${config.hardware.raspberry-pi.config-output} /boot/firmware/config.txt
    '';
  };

  # Default config.txt on Raspberry Pi OS:
  # https://github.com/RPi-Distro/pi-gen/blob/master/stage1/00-boot-files/files/config.txt
  hardware.raspberry-pi.config = {
    cm4 = {
      options = {
        otg_mode = {
          enable = lib.mkDefault true;
          value = lib.mkDefault true;
        };
      };
    };
    pi4 = {
      options = {
        arm_boost = {
          enable = lib.mkDefault true;
          value = lib.mkDefault true;
        };
      };
    };
    all = {
      options = {
        # The firmware will start our u-boot binary rather than a
        # linux kernel.
        kernel = {
          enable = true;
          value = "u-boot-rpi-arm64.bin";
        };
        arm_64bit = {
          enable = true;
          value = true;
        };
        enable_uart = {
          enable = true;
          value = true;
        };
        avoid_warnings = {
          enable = lib.mkDefault true;
          value = lib.mkDefault true;
        };
        camera_auto_detect = {
          enable = lib.mkDefault true;
          value = lib.mkDefault true;
        };
        display_auto_detect = {
          enable = lib.mkDefault true;
          value = lib.mkDefault true;
        };
        disable_overscan = {
          enable = lib.mkDefault true;
          value = lib.mkDefault true;
        };
      };
      dt-overlays = {
        vc4-kms-v3d = {
          enable = lib.mkDefault true;
          params = { };
        };
      };
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

  services = {
    udev.extraRules = ''
      SUBSYSTEM=="dma_heap", GROUP="video", MODE="0660"
      KERNEL=="gpiomem", GROUP="gpio", MODE="0660"
      KERNEL=="gpiochip*", GROUP="gpio", MODE="0660"
    '';
  };
}
