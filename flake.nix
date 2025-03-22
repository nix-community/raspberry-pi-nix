{
  description = "raspberry-pi nixos configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    rpi-linux-6_6_y-src = {
      flake = false;
      url = "github:raspberrypi/linux/rpi-6.6.y";
    };
    rpi-linux-6_14_y-src = {
      flake = false;
      url = "github:raspberrypi/linux/rpi-6.14.y";
    };
    rpi-firmware-6_6_y-src = {
      flake = false;
      url = "github:raspberrypi/firmware/stable";
    };
    rpi-firmware-6_14_y-src = {
      flake = false;
      url = "github:raspberrypi/firmware/master";
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
      url = "github:raspberrypi/rpicam-apps/v1.6.0";
    };
    libcamera-src = {
      flake = false;
      url = "github:raspberrypi/libcamera/v0.4.0+rpt20250213";
    };
    libpisp-src = {
      flake = false;
      url = "github:raspberrypi/libpisp/v1.2.0";
    };
  };

  outputs = srcs@{ self, ... }:
    let
      pinned = import srcs.nixpkgs {
        system = "aarch64-linux";
        overlays = with self.overlays; [ core libcamera ];
      };
      lock = builtins.fromJSON (builtins.readFile ./flake.lock);
      lib = srcs.nixpkgs.lib;
      inputs = lib.recursiveUpdate (builtins.removeAttrs srcs [ "self" ]) { inherit lock; };
    in
    {
      overlays = {
        core = import ./overlays inputs;
        libcamera = import ./overlays/libcamera.nix inputs;
      };
      nixosModules = {
        raspberry-pi = import ./rpi {
          inherit pinned inputs;
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
          libcamera = pinned.libcamera;
          wireless-firmware = pinned.raspberrypiWirelessFirmware;
          uboot-rpi-arm64 = pinned.uboot-rpi-arm64;
        } // kernels;
    };
}
