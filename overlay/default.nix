{ u-boot-src
, rpi-linux-6_1-src
, rpi-firmware-src
, rpi-firmware-nonfree-src
, rpi-bluez-firmware-src
, libcamera-apps-src
}:
final: prev:
let
  # The version to stick at `pkgs.rpi-kernels.latest'
  latest = "v6_1_21";

  # Helpers for building the `pkgs.rpi-kernels' map.
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
    in
    {
      "v${version-slug}" = {
        kernel = new-kernel;
        firmware = new-fw;
        wireless-firmware = new-wireless-fw;
      };
    };
  rpi-kernels = builtins.foldl' (b: a: b // rpi-kernel a) { };
in
{

  # A recent known working version of libcamera-apps
  libcamera-apps =
    final.callPackage ./libcamera-apps.nix { inherit libcamera-apps-src; };

  # provide generic rpi arm64 u-boot
  uboot_rpi_arm64 = prev.buildUBoot rec {
    defconfig = "rpi_arm64_defconfig";
    extraMeta.platforms = [ "aarch64-linux" ];
    filesToInstall = [ "u-boot.bin" ];
    version = "2023.01";
    src = u-boot-src;
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

  # default to latest firmware
  raspberrypiWirelessFirmware = final.rpi-kernels.latest.wireless-firmware;
  raspberrypifw = final.rpi-kernels.latest.firmware;

} // {
  # rpi kernels and firmware are available at
  # `pkgs.rpi-kernels.<VERSION>.{kernel,firmware,wireless-firmware}'. 
  #
  # For example: `pkgs.rpi-kernels.v5_15_87.kernel'
  rpi-kernels = rpi-kernels [{
    version = "6.1.21";
    kernel = rpi-linux-6_1-src;
    fw = rpi-firmware-src;
    wireless-fw = import ./raspberrypi-wireless-firmware.nix {
      bluez-firmware = rpi-bluez-firmware-src;
      firmware-nonfree = rpi-firmware-nonfree-src;
    };
    argsOverride = {
      structuredExtraConfig = with prev.lib.kernel; {
        KUNIT = no;
      };
    };
  }] // {
    latest = final.rpi-kernels."${latest}";
  };
}
