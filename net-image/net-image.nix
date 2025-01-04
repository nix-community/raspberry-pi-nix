# This module creates the files necessary containing the given NixOS
# configuration. The generated directories consists of a `boot` directory
# (for TFTP boot) and a `root` directory (for NFS root). The goal is to
# allow the system to boot over the network, using TFTP to retrieve the
# boot files and NFS to mount the root filesystem, enabling fully
# headless deployment of the NixOS system.

# The generated files consists of two directories:
# - `boot`: Contains the necessary bootloader, kernel, and initrd files
#   required for booting the system. These files will be served via TFTP
#   to the target machine.
# - `root`: Contains the root filesystem that will be mounted by the
#   target machine over NFS. This is typically an ext4 root partition
#   populated with the necessary NixOS configuration.

# The image does not include a bootable SD card but instead prepares the
# filesystem and boot files for network-based booting. The NixOS
# configuration will be automatically applied when the system boots.

# Note: This module assumes that you have already set up the TFTP and
# NFS servers on your network, and the target machine is configured
# for network booting.

{ modulesPath, config, lib, pkgs, ... }:

with lib;

let
  rootfsImage = pkgs.callPackage (builtins.path { path = ./make-root-fs.nix; }) ({
    inherit (config.netImage) storePaths;
    populateRootCommands = config.netImage.populateRootCommands;
  });
in
{
  imports = [ ];

  options.netImage = {
    rootDirectoryName = mkOption {
      default =
        "${config.netImage.directoryBaseName}-${config.system.nixos.label}-${pkgs.stdenv.hostPlatform.system}";
      description = ''
        Name of the generated root directory.
      '';
    };

    directoryBaseName = mkOption {
      default = "nixos-net-image";
      description = ''
        Prefix of the name of the generated root directory.
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
      default = "192.168.0.108:/mnt/nfsshare/${config.netImage.directoryBaseName}-${config.system.nixos.label}-${pkgs.stdenv.hostPlatform.system}";
      description = ''
        cmdline.txt nfs parameter for the root filesystem.
      '';
    };

    nfsOptions = mkOption {
      type = with types; listOf str;
      default = [
          # Disable file locking
          "nolock"
          # Mount the filesystem read-write
          "rw"
          # Use NFS version 3
          "vers=3"
          # Set the read buffer size to 131072 bytes
          "rsize=131072"
          # Set the write buffer size to 131072 bytes
          "wsize=131072"
          # Set the maximum filename length to 255 characters
          "namlen=255"
          # Use hard mounts (retry indefinitely on failure)
          "hard"
          # Disable Access Control Lists
          "noacl"
          # Use TCP as the transport protocol
          "proto=tcp"
          # Set the NFS timeout to 11 tenths of a second
          "timeo=11"
          # Set the number of NFS retransmissions to 3
          "retrans=3"
          # Use the 'sys' security flavor
          "sec=sys"
          # Use NFS mount protocol version 3
          "mountvers=3"
          # Use TCP for the mount protocol
          "mountproto=tcp"
          # Enable local locking
          "local_lock=all"
          # Do not update inode access times on reads
          "noatime"
          # Do not update directory inode access times on reads
          "nodiratime"
        ];
      description = ''
        NFS options to use when mounting the root filesystem.
      '';
    };

    populateFirmwareCommands = mkOption {
      example =
        literalExpression "'' cp \${pkgs.myBootLoader}/u-boot.bin ./ ''";
      description = ''
        Shell commands to populate the ./ directory.
        All files in that directory are copied to the
        tftp files on the Netboot image.
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
  };

  config = {
    # net
    networking.useDHCP = lib.mkForce true;
    networking.interfaces.eth0.useDHCP = lib.mkForce true;
    networking.interfaces.wlan0.useDHCP = lib.mkForce false;

    # boot
    boot.initrd.network.enable = lib.mkForce true;
    boot.initrd.network.flushBeforeStage2 = lib.mkForce false;
    boot.initrd.supportedFilesystems = [
        # Network File System (NFS) support for mounting root over the network
        "nfs"
        # Overlay filesystem for layering file systems
        "overlay"
    ];

    boot.initrd.availableKernelModules = [
        # Network File System (NFS) module
        "nfs"
        # Overlay filesystem module
        "overlay"
        # Broadcom PHY library for Ethernet device support
        "bcm_phy_lib"
        # Broadcom-specific driver module
        "broadcom"
        # Broadcom GENET Ethernet controller driver
        "genet"
    ];

    boot.initrd.kernelModules = [
        # Network File System (NFS) module
        "nfs"
        # Overlay filesystem module
        "overlay"
        # Broadcom PHY library for Ethernet device support
        "bcm_phy_lib"
        # Broadcom-specific driver module
        "broadcom"
        # Broadcom GENET Ethernet controller driver
        "genet"
    ];


    # fileSystems
    fileSystems = {
      "/boot/firmware" = {
        device = "${config.netImage.nfsRoot}/boot/firmware";
        fsType = "nfs";
        options = config.netImage.nfsOptions;
        neededForBoot = lib.mkForce true;
      };
      "/" = {
        device = "${config.netImage.nfsRoot}";
        fsType = "nfs";
        options = config.netImage.nfsOptions;
        neededForBoot = lib.mkForce true;
      };
    };

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
            export rootfs=$out/net-image/os/${config.netImage.rootDirectoryName}
            export bootfs=$out/net-image/boot

            echo "${pkgs.stdenv.buildPlatform.system}" > $out/nix-support/system

            # Populate the files intended for NFS
            echo "Exporting rootfs image"
            mkdir -p $rootfs
            cp -r ${rootfsImage}/* $rootfs

            # Populate the files intended for TFTP
            echo "Exporting rootfs image"
            ${config.netImage.populateFirmwareCommands}
            mkdir -p $bootfs
            cp -r . $bootfs
            mkdir -p $rootfs/boot/firmware
            cp -r . $rootfs/boot/firmware
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
