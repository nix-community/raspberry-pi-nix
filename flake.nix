{
  description = "raspberry-pi nixos configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/9a9960b98418f8c385f52de3b09a63f9c561427a";
    u-boot-src = {
      flake = false;
      url = "https://ftp.denx.de/pub/u-boot/u-boot-2024.01.tar.bz2";
    };
    rpi-linux-6_1-src = {
      flake = false;
      url = "github:raspberrypi/linux/stable_20231123";
    };
    rpi-firmware-src = {
      flake = false;
      url = "github:raspberrypi/firmware/7e6decce72fdff51923e9203db46716835ae889a";
    };
    rpi-firmware-nonfree-src = {
      flake = false;
      url = "github:RPi-Distro/firmware-nonfree/88aa085bfa1a4650e1ccd88896f8343c22a24055";
    };
    rpi-bluez-firmware-src = {
      flake = false;
      url = "github:RPi-Distro/bluez-firmware/d9d4741caba7314d6500f588b1eaa5ab387a4ff5";
    };
    libcamera-apps-src = {
      flake = false;
      url = "github:raspberrypi/libcamera-apps/v1.4.1";
    };
    libcamera-src = {
      flake = false;
      url = "github:raspberrypi/libcamera/563cd78e1c9858769f7e4cc2628e2515836fd6e7"; # v0.1.0+rpt20231122
    };
    libpisp-src = {
      flake = false;
      url = "github:raspberrypi/libpisp/v1.0.3";
    };
  };

  outputs = srcs@{ self, ... }:
    let
      pinned = import nixpkgs {
        system = "aarch64-linux";
        overlays = with self.overlays; [ core libcamera ];
      };
    in
    {
      overlays = {
        core = import ./overlays (builtins.removeAttrs srcs [ "self" ]);
        libcamera = import ./overlays/libcamera.nix (builtins.removeAttrs srcs [ "self" ]);
      };
      nixosModules.raspberry-pi = import ./rpi {
        inherit pinned;
        core-overlay = self.overlays.core;
        libcamera-overlay = self.overlays.libcamera;
      };
      packages.aarch64-linux = {
        linux = pinned.rpi-kernels.latest.kernel;
      };
    };
}
