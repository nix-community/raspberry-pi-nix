{
  description = "raspberry-pi nixos configuration";

  inputs = {
    u-boot-src = {
      flake = false;
      url = "https://ftp.denx.de/pub/u-boot/u-boot-2023.01.tar.bz2";
    };
    rpi-linux-5_15-src = {
      flake = false;
      url = "github:raspberrypi/linux/rpi-5.15.y";
    };
    rpi-firmware-stable-src = {
      flake = false;
      url = "github:raspberrypi/firmware/stable";
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
      url = "github:raspberrypi/libcamera-apps/v1.1.1";
    };
  };

  outputs = srcs@{ self, ... }: {
    overlay = import ./overlay (builtins.removeAttrs srcs [ "self" ]);
    rpi = import ./rpi { overlay = self.overlay; };
  };
}
