{ u-boot-src
, rpi-linux-6_6-src
, rpi-firmware-src
, rpi-firmware-nonfree-src
, rpi-bluez-firmware-src
, ...
}:
final: prev:
let
  # The version to stick at `pkgs.rpi-kernels.latest'
  latest = "v6_6_28";

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
  # disable firmware compression so that brcm firmware can be found at
  # the path expected by raspberry pi firmware/device tree
  compressFirmwareXz = x: x;

  # provide generic rpi arm64 u-boot
  uboot_rpi_arm64 = prev.buildUBoot rec {
    defconfig = "rpi_arm64_defconfig";
    extraMeta.platforms = [ "aarch64-linux" ];
    filesToInstall = [ "u-boot.bin" ];
    version = "2024.04";
    patches = [ ];
    makeFlags = [ ];
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
    version = "6.6.28";
    kernel = rpi-linux-6_6-src;
    fw = rpi-firmware-src;
    wireless-fw = import ./raspberrypi-wireless-firmware.nix {
      bluez-firmware = rpi-bluez-firmware-src;
      firmware-nonfree = rpi-firmware-nonfree-src;
    };
    argsOverride = {
      structuredExtraConfig = with prev.lib.kernel; {
        # The perl script to generate kernel options sets unspecified
        # parameters to `m` if possible [1]. This results in the
        # unspecified config option KUNIT [2] getting set to `m` which
        # causes DRM_VC4_KUNIT_TEST [3] to get set to `y`.
        #
        # This vc4 unit test fails on boot due to a null pointer
        # exception with the existing config. I'm not sure why, but in
        # any case, the DRM_VC4_KUNIT_TEST config option itself states
        # that it is only useful for kernel developers working on the
        # vc4 driver. So, I feel no need to deviate from the standard
        # rpi kernel and attempt to successfully enable this test and
        # other unit tests because the nixos perl script has this
        # sloppy "default to m" behavior. So, I set KUNIT to `n`.
        #
        # [1] https://github.com/NixOS/nixpkgs/blob/85bcb95aa83be667e562e781e9d186c57a07d757/pkgs/os-specific/linux/kernel/generate-config.pl#L1-L10
        # [2] https://github.com/raspberrypi/linux/blob/1.20230405/lib/kunit/Kconfig#L5-L14
        # [3] https://github.com/raspberrypi/linux/blob/bb63dc31e48948bc2649357758c7a152210109c4/drivers/gpu/drm/vc4/Kconfig#L38-L52
        KUNIT = no;
        GPIO_PWM = no;
      };
    };
  }] // {
    latest = final.rpi-kernels."${latest}";
  };
}
