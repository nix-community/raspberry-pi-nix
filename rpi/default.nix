{ pinned, core-overlay, libcamera-overlay }:
{ lib, pkgs, config, ... }:
with lib;
let
  cfg = config.raspberry-pi-nix;
  version = cfg.kernel-version;
  board = cfg.board;
  atomicCopySafe = import ../atomic-copy/atomic-copy-safe.nix { inherit pkgs; };
  atomicCopyClobber = import ../atomic-copy/atomic-copy-clobber.nix { inherit pkgs; };

  # used for direct-to-kernel boot only: emulate cleanName()
  # https://github.com/NixOS/nixpkgs/blob/904ecf0b4e055dc465f5ae6574be2af8cc25dec3/nixos/modules/system/boot/loader/generic-extlinux-compatible/extlinux-conf-builder.sh#L47
  kernelStorePath = "${config.system.build.kernel}/${config.system.boot.loader.kernelFile}";
  kernelBootPath = "nixos/${builtins.replaceStrings [ "/nix/store/" "/" ] [ "" "-" ] kernelStorePath}";
in
{
  imports = [ ../generic-extlinux-compatible ./config.nix ./i2c.nix ];

  options = with lib; {
    raspberry-pi-nix = {
      kernel-version = mkOption {
        default = "v6_6_51";
        type = types.str;
        description = "Kernel version to build.";
      };
      board = mkOption {
        type = types.enum [ "bcm2711" "bcm2712" ];
        description = ''
          The kernel board version to build.
          Examples at: https://www.raspberrypi.com/documentation/computers/linux_kernel.html#native-build-configuration
          without the _defconfig part.
        '';
      };
      firmware-partition-label = mkOption {
        default = "FIRMWARE";
        type = types.str;
        description = "label of rpi firmware partition";
      };
      pin-inputs = {
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
          default = false;
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

        package = mkPackageOption pkgs "uboot-rpi-arm64" { };
      };
      rootGPUID = mkOption {
        description = "The UID of the root partition";
        type = types.str;
        # https://github.com/NixOS/nixpkgs/blob/23e89b7da85c3640bbc2173fe04f4bd114342367/nixos/lib/make-disk-image.nix#L177
        default = "F222513B-DED1-49FA-B591-20CE86A2FE7F";
      };
    };
  };

  config = {
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
          kernel = {
            enable = true;
            value = if cfg.uboot.enable then "u-boot-rpi-arm64.bin" else kernelBootPath;
          };
          ramfsfile = {
            enable = !cfg.uboot.enable;
            value = "initrd";
          };
          ramfsaddr = {
            enable = !cfg.uboot.enable;
            value = -1;
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
      overlays =
        let
          rpi-overlays = [ core-overlay ]
            ++ (if config.raspberry-pi-nix.libcamera-overlay.enable
          then [ libcamera-overlay ] else [ ]);
          rpi-overlay = lib.composeManyExtensions rpi-overlays;
          pin-prev-overlay = overlay: pinned-prev: final: prev:
            let
              # apply the overlay to pinned-prev and fix that so no references to the actual final
              # and prev appear in applied-overlay
              applied-overlay =
                lib.fix (final: pinned-prev // overlay final pinned-prev);
              # We only want to set keys that appear in the overlay, so restrict applied-overlay to
              # these keys
              restricted-overlay = lib.getAttrs (builtins.attrNames (overlay { } { })) applied-overlay;
            in
            prev // restricted-overlay;
        in
        if cfg.pin-inputs.enable
        then [ (pin-prev-overlay rpi-overlay pinned) ]
        else [ rpi-overlay ];
    };
    boot = {
      kernelParams =
        [ "console=serial0,115200n8" "console=tty1" ] ++
        (if cfg.uboot.enable then [ ]
        else [
          "root=PARTUUID=${cfg.rootGPUID}"
          "rootfstype=ext4"
          "fsck.repair=yes"
          "rootwait"
          "init=/nix/var/nix/profiles/system/init"
        ]);
      initrd = {
        availableKernelModules = [
          "usbhid"
          "usb_storage"
          "vc4"
          "pcie_brcmstb" # required for the pcie bus to work
          "reset-raspberrypi" # required for vl805 firmware to load
        ];
      };
      kernelPackages = pkgs.linuxPackagesFor pkgs.rpi-kernels."${version}"."${board}";
      loader = {
        grub.enable = lib.mkDefault false;

        generic-extlinux-compatible.enable = false;
        generic-extlinux-compatible-pi-loader = {
          # extlinux-style boot is only used when uboot is enabled
          # when uboot is disabled, use this module to put files into
          # the boot partition as part of installBootloader
          enable = true;
          # We want to use the device tree provided by firmware, so don't
          # add FDTDIR to the extlinux conf file.
          useGenerationDeviceTree = false;
          extraCommandsAfter = let
            configTxt = config.hardware.raspberry-pi.config-output;
            kernelParams = pkgs.writeTextFile {
              name = "cmdline.txt";
              text = ''
                ${lib.strings.concatStringsSep " " config.boot.kernelParams}
              '';
            };
            script = flip concatMapStrings config.boot.loader.generic-extlinux-compatible-pi-loader.mirroredBoots (args: ''
              # Add raspi files
              cd ${pkgs.raspberrypifw}/share/raspberrypi/boot
              ${atomicCopySafe} bootcode.bin ${args.path}/bootcode.bin
              ${atomicCopySafe} overlays     ${args.path}/overlays
              ${pkgs.findutils}/bin/find . -type f -name 'fixup*.dat' -exec ${atomicCopySafe} {} ${args.path}/{} \;
              ${pkgs.findutils}/bin/find . -type f -name 'start*.elf' -exec ${atomicCopySafe} {} ${args.path}/{} \;
              ${pkgs.findutils}/bin/find . -type f -name '*.dtb'      -exec ${atomicCopySafe} {} ${args.path}/{} \;

              # Add config.txt
              ${atomicCopyClobber} ${configTxt} ${args.path}/config.txt
            '' + (if cfg.uboot.enable then ''
              # Add u-boot files
              ${atomicCopySafe} ${cfg.uboot.package}/u-boot.bin ${args.path}/u-boot-rpi-arm64.bin
            '' else ''
              # Add kernel params
              ${atomicCopyClobber} ${kernelParams} ${args.path}/cmdline.txt
            ''));
          in [ (toString (pkgs.writeShellScript "cp-pi-loaders.sh" script)) ];
        };
      };
    };
    hardware.enableRedistributableFirmware = true;

    users.groups = builtins.listToAttrs (map (k: { name = k; value = { }; })
      [ "input" "sudo" "plugdev" "games" "netdev" "gpio" "i2c" "spi" ]);
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
