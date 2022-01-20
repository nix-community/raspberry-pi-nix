final: prev: {
  # newer version of libcamera
  libcamera = prev.libcamera.overrideAttrs (old: {
    src = prev.fetchgit {
      url = "https://git.libcamera.org/libcamera/libcamera.git";
      rev = "44d59841e1ce59042b8069b8078bc9f7b1bfa73b";
      sha256 = "1nzkvy2y772ak9gax456ws2fmjc9ncams0m1w27h1rzpxn5yphqr";
    };
    mesonFlags = [ "-Dv4l2=true" "-Dqcam=disabled" "-Dlc-compliance=disabled" ];
    patches = (old.patches or [ ]) ++ [ ./libcamera.patch ];
  });

  libcamera-apps = final.callPackage ./libcamera-apps.nix { };

  # newer version of rpi firmware
  raspberrypifw = prev.raspberrypifw.overrideAttrs (old: {
    src = prev.fetchFromGitHub {
      owner = "raspberrypi";
      repo = "firmware";
      rev = "2cf8a179b3f2e6e5e5ceba4e8e544def10a49020";
      sha256 = "YG1bryflbV3W62MhZ/XMSgUJXMhCl/fe86x+CT7XZ4U=";
    };
  });

  # provide generic rpi arm64 u-boot
  uboot_rpi_arm64 = prev.buildUBoot rec {
    defconfig = "rpi_arm64_defconfig";
    extraMeta.platforms = [ "aarch64-linux" ];
    filesToInstall = [ "u-boot.bin" ];
    version = "2022.04";
    src = prev.fetchurl {
      url = "ftp://ftp.denx.de/pub/u-boot/u-boot-${version}.tar.bz2";
      sha256 = "1l5w13dznj0z1ibqv2d6ljx2ma1gnf5x5ay3dqkqwxr6750nbq38";
    };
  };

  # use a newer version of the rpi linux kernel fork
  linux_rpi = prev.linux_rpi4.override {
    argsOverride = rec {
      src = prev.fetchFromGitHub {
        owner = "raspberrypi";
        repo = "linux";
        rev = "9af1cc301e4dffb830025207a54d0bc63bec16c7";
        sha256 = "fsMTUdz1XZhPaSXpU1uBV4V4VxoZKi6cwP0QJcrCy1o=";
        fetchSubmodules = true;
      };
      version = "5.15.36";
      modDirVersion = "5.15.36";
    };
  };
}
