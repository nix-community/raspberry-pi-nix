{ overlay }:
{ lib, pkgs, config, ... }:

{
  imports = [ ../sd-image ./config.nix ./i2c.nix ];

  # On activation install u-boot, Raspberry Pi firmware, and our
  # generated config.txt
  system.activationScripts.raspberrypi = {
    text = ''
      shopt -s nullglob

      TARGET_FIRMWARE_DIR="/boot/firmware"
      TARGET_OVERLAYS_DIR="$TARGET_FIRMWARE_DIR/overlays"
      TMPFILE="$TARGET_FIRMWARE_DIR/tmp"
      UBOOT="${pkgs.uboot_rpi_arm64}/u-boot.bin"
      SRC_FIRMWARE_DIR="${pkgs.raspberrypifw}/share/raspberrypi/boot"
      STARTFILES=("$SRC_FIRMWARE_DIR"/start*.elf)
      DTBS=("$SRC_FIRMWARE_DIR"/*.dtb)
      BOOTCODE="$SRC_FIRMWARE_DIR/bootcode.bin"
      FIXUPS=("$SRC_FIRMWARE_DIR"/fixup*.dat)
      SRC_OVERLAYS_DIR="$SRC_FIRMWARE_DIR/overlays"
      SRC_OVERLAYS=("$SRC_OVERLAYS_DIR"/*)
      CONFIG="${config.hardware.raspberry-pi.config-output}"

      cp "$UBOOT" "$TMPFILE"
      mv -T "$TMPFILE" "$TARGET_FIRMWARE_DIR/u-boot-rpi-arm64.bin"

      cp "$CONFIG" "$TMPFILE"
      mv -T "$TMPFILE" "$TARGET_FIRMWARE_DIR/config.txt"

      for SRC in "''${STARTFILES[@]}" "''${DTBS[@]}" "$BOOTCODE" "''${FIXUPS[@]}"
      do
        cp "$SRC" "$TMPFILE"
        mv -T "$TMPFILE" "$TARGET_FIRMWARE_DIR/$(basename "$SRC")"
      done

      for SRC in "''${SRC_OVERLAYS[@]}"
      do
        cp "$SRC" "$TMPFILE"
        mv -T "$TMPFILE" "$TARGET_OVERLAYS_DIR/$(basename "$SRC")"
      done
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
