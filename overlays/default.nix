{ u-boot-src
, rpi-linux-6_6-src
, rpi-firmware-src
, rpi-firmware-nonfree-src
, rpi-bluez-firmware-src
, ...
}:
final: prev:
let
  versions = {
    v6_6_31 = rpi-linux-6_6-src;
  };
  boards = [ "bcmrpi" "bcm2709" "bcmrpi3" "bcm2711" "bcm2712" ];

  # Helpers for building the `pkgs.rpi-kernels' map.
  rpi-kernel = { version, board }: {
    "${version}"."${board}" = prev.lib.overrideDerivation (prev.buildLinux {
        modDirVersion = version;
        inherit version;
        pname = "linux-rpi";
        src = versions[version];
        defconfig = "${board}_defconfig";
        structuredExtraConfig = with lib.kernel; {
          # Workaround https://github.com/raspberrypi/linux/issues/6198
          # Needed because NixOS 24.05+ sets DRM_SIMPLEDRM=y which pulls in
          # DRM_KMS_HELPER=y.
          BACKLIGHT_CLASS_DEVICE = yes;
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
        };
        features.efiBootStub = false;
        postConfigure = ''
          # The v7 defconfig has this set to '-v7' which screws up our modDirVersion.
          sed -i $buildRoot/.config -e 's/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION=""/'
          sed -i $buildRoot/include/config/auto.conf -e 's/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION=""/'
        '';
        postFixup = "";
        kernelPatches = [
          # Fix compilation errors due to incomplete patch backport.
          # https://github.com/raspberrypi/linux/pull/6223
          {
            name = "gpio-pwm_-_pwm_apply_might_sleep.patch";
            patch = fetchpatch {
              url = "https://github.com/peat-psuwit/rpi-linux/commit/879f34b88c60dd59765caa30576cb5bfb8e73c56.patch";
              hash = "sha256-HlOkM9EFmlzOebCGoj7lNV5hc0wMjhaBFFZvaRCI0lI=";
            };
          }
          {
            name = "ir-rx51_-_pwm_apply_might_sleep.patch";
            patch = fetchpatch {
              url = "https://github.com/peat-psuwit/rpi-linux/commit/23431052d2dce8084b72e399fce82b05d86b847f.patch";
              hash = "sha256-UDX/BJCJG0WVndP/6PbPK+AZsfU3vVxDCrpn1kb1kqE=";
            };
          }
        ];
    });
  };
  rpi-kernels = builtins.foldl' (b: a: b // rpi-kernel a) { };
in
{
  # disable firmware compression so that brcm firmware can be found at
  # the path expected by raspberry pi firmware/device tree
  compressFirmwareXz = x: x;
  compressFirmwareZstd = x: x;

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
  raspberrypiWirelessFirmware = final.callPackage (
    import ./raspberrypi-wireless-firmware.nix {
      bluez-firmware = rpi-bluez-firmware-src;
      firmware-nonfree = rpi-firmware-nonfree-src;
    }
  ) { };
  raspberrypifw = prev.raspberrypifw.overrideAttrs (oldfw: { src = rpi-firmware-src; });

} // {
  # rpi kernels and firmware are available at
  # `pkgs.rpi-kernels.<VERSION>.<BOARD>'. 
  #
  # For example: `pkgs.rpi-kernels.v6_6_31.bcm2712'
  rpi-kernels = rpi-kernels (
    prev.lib.lists.crossLists 
      (board: version: { inherit board version; })
      [boards (builtins.attrNames versions)]
  );
}
