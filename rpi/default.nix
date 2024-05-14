{ pinned, core-overlay, libcamera-overlay }:
{ lib, pkgs, config, ... }:

let cfg = config.raspberry-pi-nix;
in
{
  imports = [ ../sd-image ./config.nix ./i2c.nix ];

  options = with lib; {
    raspberry-pi-nix = {
      pin-kernel = {
        enable = mkOption {
          default = true;
          type = types.bool;
          description = ''
            Whether to pin the kernel to the latest cachix build.
          '';
        };
      };
      firmware-migration-service = {
        enable = mkOption {
          default = true;
          type = types.bool;
          description = ''
            Whether to run the migration service automatically or not.
          '';
        };
      };
      libcamera-overlay = {
        enable = mkOption {
          default = true;
          type = types.bool;
          description = ''
            If enabled then the libcamera overlay is applied which
            overrides libcamera with the rpi fork.
          '';
        };
      };
      uboot = {
        enable = mkOption {
          default = true;
          type = types.bool;
          description = ''
            If enabled then uboot is used as the bootloader. If disabled
            then the linux kernel is installed directly into the
            firmware directory as expected by the raspberry pi boot
            process.

            This can be useful for newer hardware that doesn't yet have
            uboot compatibility or less common setups, like booting a
            cm4 with an nvme drive.
          '';
        };
      };
    };
  };

  config = {
    boot.kernelParams =
      if cfg.uboot.enable then [ ]
      else [
        # This is ugly and fragile, but the sdImage image has an msdos
        # table, so the partition table id is a 1-indexed hex
        # number. So, we drop the hex prefix and stick on a "02" to
        # refer to the root partition.
        "root=PARTUUID=${lib.strings.removePrefix "0x" config.sdImage.firmwarePartitionID}-02"
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
            value = if cfg.uboot.enable then "u-boot-rpi-arm64.bin" else "kernel.img";
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
      # This pin is not necessary, it would be fine to replace it with
      # `pkgs.rpi-kernels.latest.kernel`. It is helpful to ensure
      # cache hits for kernel builds though.
      kernelPackages =
        if cfg.pin-kernel.enable
        then pinned.linuxPackagesFor (pinned.rpi-kernels.latest.kernel)
        else pkgs.linuxPackagesFor (pkgs.rpi-kernels.latest.kernel);

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
      udev.extraRules =
        let shell = "${pkgs.bash}/bin/bash";
        in ''
          # https://raw.githubusercontent.com/RPi-Distro/raspberrypi-sys-mods/master/etc.armhf/udev/rules.d/99-com.rules
          SUBSYSTEM=="input", GROUP="input", MODE="0660"
          SUBSYSTEM=="i2c-dev", GROUP="i2c", MODE="0660"
          SUBSYSTEM=="spidev", GROUP="spi", MODE="0660"
          SUBSYSTEM=="*gpiomem*", GROUP="gpio", MODE="0660"
          SUBSYSTEM=="rpivid-*", GROUP="video", MODE="0660"

          KERNEL=="vcsm-cma", GROUP="video", MODE="0660"
          SUBSYSTEM=="dma_heap", GROUP="video", MODE="0660"

          SUBSYSTEM=="gpio", GROUP="gpio", MODE="0660"
          SUBSYSTEM=="gpio", KERNEL=="gpiochip*", ACTION=="add", PROGRAM="${shell} -c 'chgrp -R gpio /sys/class/gpio && chmod -R g=u /sys/class/gpio'"
          SUBSYSTEM=="gpio", ACTION=="add", PROGRAM="${shell} -c 'chgrp -R gpio /sys%p && chmod -R g=u /sys%p'"

          # PWM export results in a "change" action on the pwmchip device (not "add" of a new device), so match actions other than "remove".
          SUBSYSTEM=="pwm", ACTION!="remove", PROGRAM="${shell} -c 'chgrp -R gpio /sys%p && chmod -R g=u /sys%p'"

          KERNEL=="ttyAMA[0-9]*|ttyS[0-9]*", PROGRAM="${shell} -c '\
                  ALIASES=/proc/device-tree/aliases; \
                  TTYNODE=$$(readlink /sys/class/tty/%k/device/of_node | sed 's/base/:/' | cut -d: -f2); \
                  if [ -e $$ALIASES/bluetooth ] && [ $$TTYNODE/bluetooth = $$(strings $$ALIASES/bluetooth) ]; then \
                      echo 1; \
                  elif [ -e $$ALIASES/console ]; then \
                      if [ $$TTYNODE = $$(strings $$ALIASES/console) ]; then \
                          echo 0;\
                      else \
                          exit 1; \
                      fi \
                  elif [ $$TTYNODE = $$(strings $$ALIASES/serial0) ]; then \
                      echo 0; \
                  elif [ $$TTYNODE = $$(strings $$ALIASES/serial1) ]; then \
                      echo 1; \
                  else \
                      exit 1; \
                  fi \
          '", SYMLINK+="serial%c"

          ACTION=="add", SUBSYSTEM=="vtconsole", KERNEL=="vtcon1", RUN+="${shell} -c '\
          	if echo RPi-Sense FB | cmp -s /sys/class/graphics/fb0/name; then \
          		echo 0 > /sys$devpath/bind; \
          	fi; \
          '"
        '';
    };
  };

}
