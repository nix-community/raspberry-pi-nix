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

  # A recent known working version of libcamera-apps
  libcamera-apps = final.callPackage ./libcamera-apps.nix { };

  # provide generic rpi arm64 u-boot
  uboot_rpi_arm64 = prev.buildUBoot rec {
    defconfig = "rpi_arm64_defconfig";
    extraMeta.platforms = [ "aarch64-linux" ];
    filesToInstall = [ "u-boot.bin" ];
    version = "2023.01";
    src = prev.fetchurl {
      url = "ftp://ftp.denx.de/pub/u-boot/u-boot-${version}.tar.bz2";
      sha256 = "03wm651ix783s4idj223b0nm3r6jrdnrxs1ncs8s128g72nknhk9";
    };
    # In raspberry pi sbcs the firmware manipulates the device tree in
    # a variety of ways before handing it off to the linux kernel. [1]
    # Since we have installed u-boot in place of a linux kernel we may
    # pass the device tree passed by the firmware onto the kernel, or
    # we may provide the kernel with a device tree of our own. This
    # configuration uses the device tree provided by firmware so that
    # we don't have to be aware of all manipulation done by the
    # firmware and attempt to mimic it.
    #
    # 1. https://forums.raspberrypi.com/viewtopic.php?t=329799#p1974233
    extraConfig = ''
      CONFIG_OF_HAS_PRIOR_STAGE=y
      CONFIG_OF_BOARD=y
    '';
  };
  raspberrypiWirelessFirmware = final.rpi-kernels.v5_15_87.wireless-firmware;
  raspberrypifw = final.rpi-kernels.v5_15_87.firmware;

} // {
  # rpi kernels and firmware are available at
  # `pkgs.rpi-kernels.<VERSION>.{kernel,firmware,wireless-firmware}'. 
  #
  # For example: `pkgs.rpi-kernels.v5_15_87.kernel'
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
