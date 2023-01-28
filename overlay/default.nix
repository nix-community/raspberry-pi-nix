final: prev:
let
  rpi-kernel = { kernel, version, fw, wireless-fw, argsOverride ? null }:
    let
      new-kernel = prev.linux_rpi4.override {
        argsOverride = {
          src = kernel;
          inherit version;
          modDirVersion = version;
        } // (if builtins.isNull argsOverride then { } else argsOverride);
      };
      new-fw = prev.raspberrypifw.overrideAttrs (oldfw: { src = fw; });
      new-wireless-fw = final.callPackage wireless-fw { };
      version-slug = builtins.replaceStrings [ "." ] [ "_" ] version;
    in {
      "v${version-slug}" = {
        kernel = new-kernel;
        firmware = new-fw;
        wireless-firmware = new-wireless-fw;
      };
    };
  rpi-kernels = builtins.foldl' (b: a: b // rpi-kernel a) { };
in {

  # disable firmware compression so that brcm firmware can be found at
  # the path expected by raspberry pi firmware/device tree
  compressFirmwareXz = x: x;
  libcamera-apps = final.callPackage ./libcamera-apps.nix { };

  # provide generic rpi arm64 u-boot
  uboot_rpi_arm64 = prev.buildUBoot rec {
    defconfig = "rpi_arm64_defconfig";
    extraMeta.platforms = [ "aarch64-linux" ];
    filesToInstall = [ "u-boot.bin" ];
    version = "2022.07";
    src = prev.fetchurl {
      url = "ftp://ftp.denx.de/pub/u-boot/u-boot-${version}.tar.bz2";
      sha256 = "0png7p8k6rwbmmcyhc22xczcaz7kx0dafw5zmp0i9ni4kjs8xc4j";
    };
  };
  raspberrypiWirelessFirmware = final.rpi-kernels.v5_15_87.wireless-firmware;
  raspberrypifw = final.rpi-kernels.v5_15_87.firmware;

  # raspberrypiWirelessFirmware = prev.raspberrypiWirelessFirmware.overrideAttrs
  #   (old: {
  #     version = "2023-01-19";
  #     srcs = [
  #       (prev.fetchFromGitHub {
  #         name = "bluez-firmware";
  #         owner = "RPi-Distro";
  #         repo = "bluez-firmware";
  #         rev = "9556b08ace2a1735127894642cc8ea6529c04c90";
  #         sha256 = "gKGK0XzNrws5REkKg/JP6SZx3KsJduu53SfH3Dichkc=";
  #       })
  #       (prev.fetchFromGitHub {
  #         name = "firmware-nonfree";
  #         owner = "RPi-Distro";
  #         repo = "firmware-nonfree";
  #         rev = "8e349de20c8cb5d895b3568777ec53cbb333398f";
  #         sha256 = "45/FnaaZTEG6jLmbaXohpNpS6BEZu3DBDHqquq8ukXc=";
  #       })
  #     ];
  #   });

} // {
  rpi-kernels = rpi-kernels [
    {
      version = "5.15.36";
      kernel = prev.fetchFromGitHub {
        owner = "raspberrypi";
        repo = "linux";
        rev = "9af1cc301e4dffb830025207a54d0bc63bec16c7";
        sha256 = "fsMTUdz1XZhPaSXpU1uBV4V4VxoZKi6cwP0QJcrCy1o=";
        fetchSubmodules = true;
      };
      fw = prev.fetchFromGitHub {
        owner = "raspberrypi";
        repo = "firmware";
        rev = "2cf8a179b3f2e6e5e5ceba4e8e544def10a49020";
        sha256 = "YG1bryflbV3W62MhZ/XMSgUJXMhCl/fe86x+CT7XZ4U=";
      };
      wireless-fw = import ./raspberrypi-wireless-firmware/5.10.36.nix;
    }
    {
      version = "5.15.87";
      kernel = prev.fetchFromGitHub {
        owner = "raspberrypi";
        repo = "linux";
        rev = "da4c8e0ffe7a868b989211045657d600be3046a1";
        sha256 = "hNLVfhalmRhhRfvu2mR/qDmmGl//Ic1eqR7N1HFj2CY=";
        fetchSubmodules = true;
      };
      fw = prev.fetchFromGitHub {
        owner = "raspberrypi";
        repo = "firmware";
        rev = "2e7137e0840f76f056589aba7f82d5b7236d8f1c";
        sha256 = "jIKhQxp9D83OAZ8X2Vra9THHBE0j5Z2gRMDSVqIhopY=";
      };
      wireless-fw = import ./raspberrypi-wireless-firmware/5.10.87.nix;
    }
  ];
}
