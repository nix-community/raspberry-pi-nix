{ core-overlay, libcamera-overlay }:
{ lib, pkgs, config, ... }:

let cfg = config.raspberry-pi-nix;
in
{
  imports = [ ../sd-image ./config.nix ./i2c.nix ];

  options = with lib; {
    raspberry-pi-nix = {
      firmware-migration-service = {
        enable = mkOption {
          default = true;
          type = types.bool;
        };
      };
      libcamera-overlay = {
        enable = mkOption {
          default = true;
          type = types.bool;
        };
      };
      uboot = {
        enable = mkOption {
          default = true;
          type = types.bool;
        };
      };
    };
  };

  config = {
    boot.kernelParams =
      if cfg.uboot.enable then [ ]
      else [
        "root=PARTUUID=2178694e-02" # todo: use option
        "rootfstype=ext4"
        "fsck.repair=yes"
        "rootwait"
        "init=/sbin/init"
      ];
    systemd.services = {
      "raspberry-pi-firmware-migrate" =
        {
          description = "update the firmware partition";
          wantedBy = if cfg.firmware-migration-service.enable then [ "multi-user.target" ] else [ ];
          serviceConfig =
            let
              firmware-path = "/boot/firmware";
              kernel-params = pkgs.writeTextFile {
                name = "cmdline.txt";
                text = ''
                  ${lib.strings.concatStringsSep " " config.boot.kernelParams}
                '';
              };
            in
            {
              Type = "oneshot";
              MountImages =
                "/dev/disk/by-label/${config.sdImage.firmwarePartitionName}:${firmware-path}";
              StateDirectory = "raspberrypi-firmware";
              ExecStart = pkgs.writeShellScript "migrate-rpi-firmware" ''
                shopt -s nullglob

                TARGET_FIRMWARE_DIR="${firmware-path}"
                TARGET_OVERLAYS_DIR="$TARGET_FIRMWARE_DIR/overlays"
                TMPFILE="$TARGET_FIRMWARE_DIR/tmp"
                UBOOT="${pkgs.uboot_rpi_arm64}/u-boot.bin"
                KERNEL="${pkgs.rpi-kernels.latest.kernel}/Image"
                SHOULD_UBOOT=${if cfg.uboot.enable then "1" else "0"}
                SRC_FIRMWARE_DIR="${pkgs.raspberrypifw}/share/raspberrypi/boot"
                STARTFILES=("$SRC_FIRMWARE_DIR"/start*.elf)
                DTBS=("$SRC_FIRMWARE_DIR"/*.dtb)
                BOOTCODE="$SRC_FIRMWARE_DIR/bootcode.bin"
                FIXUPS=("$SRC_FIRMWARE_DIR"/fixup*.dat)
                SRC_OVERLAYS_DIR="$SRC_FIRMWARE_DIR/overlays"
                SRC_OVERLAYS=("$SRC_OVERLAYS_DIR"/*)
                CONFIG="${config.hardware.raspberry-pi.config-output}"

                migrate_uboot() {
                  echo "migrating uboot"
                  touch "$STATE_DIRECTORY/uboot-migration-in-progress"
                  cp "$UBOOT" "$TMPFILE"
                  mv -T "$TMPFILE" "$TARGET_FIRMWARE_DIR/u-boot-rpi-arm64.bin"
                  echo "${
                    builtins.toString pkgs.uboot_rpi_arm64
                  }" > "$STATE_DIRECTORY/uboot-version"
                  rm "$STATE_DIRECTORY/uboot-migration-in-progress"
                }

                migrate_kernel() {
                  echo "migrating kernel"
                  touch "$STATE_DIRECTORY/kernel-migration-in-progress"
                  cp "$KERNEL" "$TMPFILE"
                  mv -T "$TMPFILE" "$TARGET_FIRMWARE_DIR/kernel.img"
                  echo "${
                    builtins.toString pkgs.rpi-kernels.latest.kernel
                  }" > "$STATE_DIRECTORY/kernel-version"
                  rm "$STATE_DIRECTORY/kernel-migration-in-progress"
                }

                migrate_cmdline() {
                  echo "migrating cmdline"
                  touch "$STATE_DIRECTORY/cmdline-migration-in-progress"
                  cp "${kernel-params}" "$TMPFILE"
                  mv -T "$TMPFILE" "$TARGET_FIRMWARE_DIR/cmdline.txt"
                  echo "${
                    builtins.toString kernel-params
                  }" > "$STATE_DIRECTORY/cmdline-version"
                  rm "$STATE_DIRECTORY/cmdline-migration-in-progress"
                }

                migrate_config() {
                  echo "migrating config.txt"
                  touch "$STATE_DIRECTORY/config-migration-in-progress"
                  cp "$CONFIG" "$TMPFILE"
                  mv -T "$TMPFILE" "$TARGET_FIRMWARE_DIR/config.txt"
                  echo "${config.hardware.raspberry-pi.config-output}" > "$STATE_DIRECTORY/config-version"
                  rm "$STATE_DIRECTORY/config-migration-in-progress"
                }

                migrate_firmware() {
                  echo "migrating raspberrypi firmware"
                  touch "$STATE_DIRECTORY/firmware-migration-in-progress"
                  for SRC in "''${STARTFILES[@]}" "''${DTBS[@]}" "$BOOTCODE" "''${FIXUPS[@]}"
                  do
                    cp "$SRC" "$TMPFILE"
                    mv -T "$TMPFILE" "$TARGET_FIRMWARE_DIR/$(basename "$SRC")"
                  done

                  if [[ ! -d "$TARGET_OVERLAYS_DIR" ]]; then
                    mkdir "$TARGET_OVERLAYS_DIR"
                  fi

                  for SRC in "''${SRC_OVERLAYS[@]}"
                  do
                    cp "$SRC" "$TMPFILE"
                    mv -T "$TMPFILE" "$TARGET_OVERLAYS_DIR/$(basename "$SRC")"
                  done
                  echo "${
                    builtins.toString pkgs.raspberrypifw
                  }" > "$STATE_DIRECTORY/firmware-version"
                  rm "$STATE_DIRECTORY/firmware-migration-in-progress"
                }

                if [[ "$SHOULD_UBOOT" -eq 1 ]] && [[ -f "$STATE_DIRECTORY/uboot-migration-in-progress" || ! -f "$STATE_DIRECTORY/uboot-version" || $(< "$STATE_DIRECTORY/uboot-version") != ${
                  builtins.toString pkgs.uboot_rpi_arm64
                } ]]; then
                  migrate_uboot
                fi

                if [[ "$SHOULD_UBOOT" -ne 1 ]] && [[ ! -f "$STATE_DIRECTORY/kernel-version" || $(< "$STATE_DIRECTORY/kernel-version") != ${
                  builtins.toString pkgs.rpi-kernels.latest.kernel
                } ]]; then
                  migrate_kernel
                fi

                if [[ "$SHOULD_UBOOT" -ne 1 ]] && [[ ! -f "$STATE_DIRECTORY/cmdline-version" || $(< "$STATE_DIRECTORY/cmdline-version") != ${
                  builtins.toString kernel-params
                } ]]; then
                  migrate_cmdline
                fi

                if [[ -f "$STATE_DIRECTORY/config-migration-in-progress" || ! -f "$STATE_DIRECTORY/config-version" || $(< "$STATE_DIRECTORY/config-version") != ${
                  builtins.toString config.hardware.raspberry-pi.config-output
                } ]]; then
                  migrate_config
                fi

                if [[ -f "$STATE_DIRECTORY/firmware-migration-in-progress" || ! -f "$STATE_DIRECTORY/firmware-version" || $(< "$STATE_DIRECTORY/firmware-version") != ${
                  builtins.toString pkgs.raspberrypifw
                } ]]; then
                  migrate_firmware
                fi
              '';
            };
        };
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

    nixpkgs = {
      overlays = [ core-overlay ]
        ++ (if config.raspberry-pi-nix.libcamera-overlay.enable
      then [ libcamera-overlay ] else [ ]);
    };
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
        initScript.enable = !cfg.uboot.enable;
        generic-extlinux-compatible = {
          enable = lib.mkDefault cfg.uboot.enable;
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
  };

}
