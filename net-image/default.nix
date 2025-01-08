{ config, lib, pkgs, ... }:

{
  imports = [ ./net-image.nix ];

  config = {
    boot.loader.grub.enable = false;

    boot.consoleLogLevel = lib.mkDefault 8;

    boot.kernelParams = [
        # Read-only root filesystem
        "ro"
        # NFS root filesystem location
        "nfsroot=${config.netImage.nfsRoot},v3"
        # Root filesystem device
        "root=/dev/nfs"
        # Wait for root filesystem
        "rootwait"
        # I/O scheduler
        "elevator=deadline"
        # Enable systemd debug shell
        "systemd.debug_shell=1"
        # Set systemd log level to debug
        "systemd.log_level=info"
        # Disable splash screen
        "disable_splash"
        # Early printk to serial console
        "earlyprintk=serial,ttyS0,115200"
        # Enable initcall debugging
        "initcall_debug"
        # Print timestamps in printk messages
        "printk.time=1"
    ];

    netImage =
      let
        kernel-params = pkgs.writeTextFile {
          name = "cmdline.txt";
          text = ''
            ${lib.strings.concatStringsSep " " config.boot.kernelParams}
          '';
        };
        cfg = config.raspberry-pi-nix;
        version = cfg.kernel-version;
        board = cfg.board;
        kernel = "${config.system.build.kernel}/${config.system.boot.loader.kernelFile}";
        initrd = "${config.system.build.initialRamdisk}/${config.system.boot.loader.initrdFile}";
        populate-kernel =
          if cfg.uboot.enable
          then ''
            cp ${cfg.uboot.package}/u-boot.bin ./u-boot-rpi-arm64.bin
          ''
          else ''
            cp "${kernel}" ./kernel.img
            cp "${initrd}" ./initrd
            cp "${kernel-params}" ./cmdline.txt
          '';
      in
      {
        populateFirmwareCommands = ''
          ${populate-kernel}
          cp -r ${pkgs.raspberrypifw}/share/raspberrypi/boot/{start*.elf,*.dtb,bootcode.bin,fixup*.dat,overlays} ./
          cp ${config.hardware.raspberry-pi.config-output} ./config.txt
        '';
        populateRootCommands =
          if cfg.uboot.enable
          then ''
            mkdir -p ./files/boot
            ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d ./files/boot
          ''
          else ''
            mkdir -p ./files/sbin
            content="$(
              echo "#!${pkgs.bash}/bin/bash"
              echo "exec ${config.system.build.toplevel}/init"
            )"
            echo "$content" > ./files/sbin/init
            chmod 744 ./files/sbin/init
          '';
      };
  };
}
