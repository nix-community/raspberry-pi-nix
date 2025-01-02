{ config, lib, pkgs, ... }:

{
  imports = [ ./net-image.nix ];

  config = {
    boot.loader.grub.enable = false;

    boot.consoleLogLevel = lib.mkDefault 7;

    boot.kernelParams = [
      "rw"
      "nfsroot=${config.netImage.nfsRoot}"
      "ip=dhcp"
      "root=/dev/nfs"
      "rootwait"
      "elevator=deadline"
    #   "console=tty1"
    #   "console=serial0,115200n8"
    #   "init=/sbin/init"
    #   "loglevel=7"
      "systemd.debug_shell=1"
      "systemd.log_level=debug"
      "disable_splash"
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
