# This module creates a bootable netboot image containing the given NixOS
# configuration. The generated image consists of a `/boot` partition
# (for TFTP boot) and a `/root` partition (for NFS root). The goal is to
# allow the system to boot over the network, using TFTP to retrieve the
# boot files and NFS to mount the root filesystem, enabling fully
# headless deployment of the NixOS system.

# The generated netboot image consists of two directories:
# - `/boot`: Contains the necessary bootloader, kernel, and initrd files
#   required for booting the system. These files will be served via TFTP
#   to the target machine.
# - `/root`: Contains the root filesystem that will be mounted by the
#   target machine over NFS. This is typically an ext4 root partition
#   populated with the necessary NixOS configuration.

# The image is generated in such a way that it can be used to netboot a
# Raspberry Pi (or any other compatible hardware) directly, as long as
# the appropriate network boot infrastructure (TFTP server for `/boot`
# and NFS server for `/root`) is configured.

# The image does not include a bootable SD card but instead prepares the
# filesystem and boot files for network-based booting. The NixOS
# configuration will be automatically applied when the system boots.

# The generated image will be placed in
# config.system.build.netImage. This image is intended to be deployed
# to a TFTP server (for the boot files) and an NFS server (for the root
# filesystem) for a fully headless, network-booted NixOS system.

# Note: This module assumes that you have already set up the TFTP and
# NFS servers on your network, and the target machine is configured
# for network booting.

{ modulesPath, config, lib, pkgs, ... }:

with lib;

let
  rootfsImage = pkgs.callPackage (builtins.path { path = ./make-root-fs.nix; }) ({
    inherit (config.netImage) storePaths;
    populateImageCommands = config.netImage.populateRootCommands;
  });
in
{
  imports = [ ];

  options.netImage = {
    rootDirectoryName = mkOption {
      default =
        "${config.netImage.imageBaseName}-${config.system.nixos.label}-${pkgs.stdenv.hostPlatform.system}";
      description = ''
        Name of the generated root directory.
      '';
    };

    imageBaseName = mkOption {
      default = "nixos-net-image";
      description = ''
        Prefix of the name of the generated image file.
      '';
    };

    storePaths = mkOption {
      type = with types; listOf package;
      example = literalExpression "[ pkgs.stdenv ]";
      description = ''
        Derivations to be included in the Nix store in the generated Netboot image.
      '';
    };

    nfsRoot = mkOption {
      type = types.str;
      default = "192.168.0.108:/mnt/nfsshare/${config.netImage.imageBaseName}-${config.system.nixos.label}-${pkgs.stdenv.hostPlatform.system},v3";
      description = ''
        cmdline.txt nfs parameter for the root filesystem.
      '';
    };

    populateFirmwareCommands = mkOption {
      example =
        literalExpression "'' cp \${pkgs.myBootLoader}/u-boot.bin firmware/ ''";
      description = ''
        Shell commands to populate the ./firmware directory.
        All files in that directory are copied to the
        /boot/firmware partition on the Netboot image.
      '';
    };

    populateRootCommands = mkOption {
      example = literalExpression
        "''\${config.boot.loader.generic-extlinux-compatible.populateCmd} -c \${config.system.build.toplevel} -d ./files/boot''";
      description = ''
        Shell commands to populate the ./files directory.
        All files in that directory are copied to the
        root (/) partition on the Netboot image. Use this to
        populate the ./files/boot (/boot) directory.
      '';
    };

    postBuildCommands = mkOption {
      example = literalExpression
        "'' dd if=\${pkgs.myBootLoader}/SPL of=$img bs=1024 seek=1 conv=notrunc ''";
      default = "";
      description = ''
        Shell commands to run after the image is built.
        Can be used for boards requiring to dd u-boot SPL before actual partitions.
      '';
    };
  };

  config = {
    netImage.storePaths = [ config.system.build.toplevel ];

    system.build.netImage = pkgs.callPackage
      ({ stdenv, util-linux }:
        stdenv.mkDerivation {
          name = config.netImage.rootDirectoryName;

          nativeBuildInputs = [ util-linux ];

          buildCommand = ''
            set -e
            set -x
            mkdir -p $out/nix-support $out/net-image
            export rootfs=$out/net-image/${config.netImage.rootDirectoryName}
            export bootfs=$out/net-image/boot

            echo "${pkgs.stdenv.buildPlatform.system}" > $out/nix-support/system

            echo "Exporting rootfs image"
            mkdir -p $rootfs
            mv ${rootfsImage} $rootfs

            # Populate the files intended for /boot/firmware
            mkdir -p firmware
            ${config.netImage.populateFirmwareCommands}
            mkdir -p $bootfs
            mv firmware $bootfs

            ${config.netImage.postBuildCommands}
          '';
        })
      { };

    boot.postBootCommands = ''
      # On the first boot do some maintenance tasks
      if [ -f /nix-path-registration ]; then
        set -euo pipefail
        set -x

        # Register the contents of the initial Nix store
        ${config.nix.package.out}/bin/nix-store --load-db < /nix-path-registration

        # nixos-rebuild also requires a "system" profile and an /etc/NIXOS tag.
        touch /etc/NIXOS
        ${config.nix.package.out}/bin/nix-env -p /nix/var/nix/profiles/system --set /run/current-system

        # Prevents this from running on later boots.
        rm -f /nix-path-registration
      fi
    '';
  };
}
