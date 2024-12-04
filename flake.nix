{
  description = "raspberry-pi nixos configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    u-boot-src = {
      flake = false;
      url = "https://ftp.denx.de/pub/u-boot/u-boot-2024.07.tar.bz2";
    };
    rpi-linux-6_6_54-src = {
      flake = false;
      url = "github:raspberrypi/linux/rpi-6.6.y";
    };
    rpi-linux-6_12_1-src = {
      flake = false;
      url = "github:raspberrypi/linux/rpi-6.12.y";
    };
    rpi-firmware-src = {
      flake = false;
      url = "github:raspberrypi/firmware/1.20241126";
    };
    rpi-firmware-nonfree-src = {
      flake = false;
      url = "github:RPi-Distro/firmware-nonfree/bookworm";
    };
    rpi-bluez-firmware-src = {
      flake = false;
      url = "github:RPi-Distro/bluez-firmware/bookworm";
    };
    rpicam-apps-src = {
      flake = false;
      url = "github:raspberrypi/rpicam-apps/v1.5.2";
    };
    libcamera-src = {
      flake = false;
      url = "github:raspberrypi/libcamera/1230f78d2f6d38d812568fd27f7b985b9ff19e39"; # v0.3.2+rpt20241119
    };
    libpisp-src = {
      flake = false;
      url = "github:raspberrypi/libpisp/v1.0.7";
    };
  };

  outputs = srcs@{ self, ... }:
    let
      pinned = import srcs.nixpkgs {
        system = "aarch64-linux";
        overlays = with self.overlays; [ core libcamera ];
      };
    in
    {
      overlays = {
        core = import ./overlays (builtins.removeAttrs srcs [ "self" ]);
        libcamera = import ./overlays/libcamera.nix (builtins.removeAttrs srcs [ "self" ]);
      };
      nixosModules = {
        raspberry-pi = import ./rpi {
          inherit pinned;
          core-overlay = self.overlays.core;
          libcamera-overlay = self.overlays.libcamera;
        };
        sd-image = import ./sd-image;
      };
      nixosConfigurations = {
        rpi-example = srcs.nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [ self.nixosModules.raspberry-pi self.nixosModules.sd-image ./example ];
        };
      };
      checks.aarch64-linux = self.packages.aarch64-linux;
      packages.aarch64-linux = with pinned.lib;
        let
          kernels =
            foldlAttrs f { } pinned.rpi-kernels;
          f = acc: kernel-version: board-attr-set:
            foldlAttrs
              (acc: board-version: drv: acc // {
                "linux-${kernel-version}-${board-version}" = drv;
              })
              acc
              board-attr-set;
        in
        {
          example-sd-image = self.nixosConfigurations.rpi-example.config.system.build.sdImage;
          firmware = pinned.raspberrypifw;
          libcamera = pinned.libcamera;
          wireless-firmware = pinned.raspberrypiWirelessFirmware;
          uboot-rpi-arm64 = pinned.uboot-rpi-arm64;
        } // kernels;
    };
}
