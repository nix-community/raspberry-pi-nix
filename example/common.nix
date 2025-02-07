{ config, inputs, lib, modulesPath, pkgs, ... }: {
  time.timeZone = "America/New_York";
  users.users.root.initialPassword = "root";
  networking = {
    hostName = "example";
    useDHCP = false;
    interfaces = {
      wlan0.useDHCP = true;
      eth0.useDHCP = true;
    };
  };
  raspberry-pi-nix = {
    board = "bcm2711";
  };
  hardware = {
    raspberry-pi = {
      config = {
        all = {
          base-dt-params = {
            BOOT_UART = {
              value = 1;
              enable = true;
            };
            uart_2ndstage = {
              value = 1;
              enable = true;
            };
          };
          dt-overlays = {
            disable-bt = {
              enable = true;
              params = { };
            };
          };
        };
      };
    };
  };
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  fileSystems = {
    "/boot" = {
      device = "/dev/disk/by-label/ESP";
      fsType = "vfat";
    };
    "/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
      autoResize = true;
    };
  };
  boot.growPartition = true;
  system.build.image = (import "${toString modulesPath}/../lib/make-disk-image.nix" {
    inherit lib config pkgs;
    format = "raw";
    partitionTableType = "efi";
    copyChannel = false;
    diskSize = "auto";
    additionalSpace = "64M";
    bootSize = "128M";
    touchEFIVars = false;
    installBootLoader = true;
    label = "nixos";
    deterministic = true;
  });

  nix.settings.substituters = lib.mkForce config.nix.settings.trusted-substituters;
  nix.settings.trusted-substituters = [
    "https://cache.nixos.org/"
    "https://nix-community.cachix.org"
  ];
  nix.settings.trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
  ];
}
