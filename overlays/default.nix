{ lock
, rpi-linux-6_6_y-src
, rpi-linux-6_14_y-src
, rpi-firmware-6_6_y-src
, rpi-firmware-6_14_y-src
, rpi-firmware-nonfree-src
, rpi-bluez-firmware-src
, ...
}:
final: prev:
let
  versions = {
    v6_6_78 = {
      src = rpi-linux-6_6_y-src;
      firmware = rpi-firmware-6_6_y-src;
    };
    v6_14_0-rc7 = {
      src = rpi-linux-6_14_y-src;
      firmware = rpi-firmware-6_14_y-src;
    };
 
  };
  boards = [ "bcm2711" "bcm2712" ];

  # Helpers for building the `pkgs.rpi-kernels' map.
  rpi-kernel = { version, board }:
    let
      kernel = builtins.getAttr version versions;
      version-slug = builtins.replaceStrings [ "v" "_" ] [ "" "." ] version;
    in
    {
      "${version}"."${board}" = {
        kernel = (final.buildLinux {
          modDirVersion = version-slug;
          version = version-slug;
          pname = "linux-rpi";
          src = kernel.src;
          defconfig = "${board}_defconfig";
          structuredExtraConfig = with final.lib.kernel; {
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
            HID_LENOVO = no;
          };
          features.efiBootStub = false;
          kernelPatches =
            if kernel ? "patches" then kernel.patches else [ ];
        }).overrideAttrs
          (oldAttrs: {
            postConfigure = ''
              # The v7 defconfig has this set to '-v7' which screws up our modDirVersion.
              sed -i $buildRoot/.config -e 's/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION=""/'
              sed -i $buildRoot/include/config/auto.conf -e 's/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION=""/'
            '';
          });
        firmware = prev.raspberrypifw.overrideAttrs (oldfw: { src = kernel.firmware; });

      };
    };
  rpi-kernels = builtins.foldl'
    (b: a: final.lib.recursiveUpdate b (rpi-kernel a))
    { };
in
{
  # disable firmware compression so that brcm firmware can be found at
  # the path expected by raspberry pi firmware/device tree
  compressFirmwareXz = x: x;
  compressFirmwareZstd = x: x;

  # provide generic rpi arm64 u-boot
  uboot-rpi-arm64 = final.buildUBoot {
    defconfig = "rpi_arm64_defconfig";
    extraMeta.platforms = [ "aarch64-linux" ];
    filesToInstall = [ "u-boot.bin" ];
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
  raspberrypiWirelessFirmware = final.callPackage
    (
      import ./raspberrypi-wireless-firmware.nix {
        bluez-firmware = rpi-bluez-firmware-src;
        firmware-nonfree = rpi-firmware-nonfree-src;
      }
    )
    { };

} // {
  # rpi kernels and firmware are available at
  # `pkgs.rpi-kernels.<VERSION>.<BOARD>'. 
  #
  # Check all available versions/boards with: nix flake show
  rpi-kernels = rpi-kernels (
    final.lib.cartesianProduct
      { board = boards; version = (builtins.attrNames versions); }
  );
}
