{
  description = "raspberry-pi nixos configuration";

  inputs = {
    u-boot-src = {
      flake = false;
      url = "https://ftp.denx.de/pub/u-boot/u-boot-2023.04.tar.bz2";
    };
    rpi-linux-6_1-src = {
      flake = false;
      url = "github:raspberrypi/linux/1.20230405";
    };
    rpi-firmware-src = {
      flake = false;
      url = "github:raspberrypi/firmware/1.20230405";
    };
    rpi-firmware-nonfree-src = {
      flake = false;
      url = "github:RPi-Distro/firmware-nonfree";
    };
    rpi-bluez-firmware-src = {
      flake = false;
      url = "github:RPi-Distro/bluez-firmware";
    };
    libcamera-apps-src = {
      flake = false;
      url = "github:raspberrypi/libcamera-apps/v1.1.2";
    };
  };

  outputs = srcs@{ self, ... }: {
    overlay = import ./overlay (builtins.removeAttrs srcs [ "self" ]);
    nixosModules.raspberry-pi = import ./rpi { overlay = self.overlay; };
  };
}
