{ lib, stdenv, fetchFromGitHub, fetchpatch, cmake, pkg-config, libjpeg, libtiff
, libpng, libcamera, libepoxy, boost, libexif }:

stdenv.mkDerivation rec {
  pname = "libcamera-apps";
  version = "unstable-2022-05-12";

  src = fetchFromGitHub {
    owner = "raspberrypi";
    repo = "libcamera-apps";
    rev = "f5a2f1d86b440ebc064d4369421348d858ef31f3";
    sha256 = "Et8enICYct/AvWstY/id6BD/NB9+La9pNrtAsdwv+Tg=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [ cmake pkg-config ];
  buildInputs = [ libjpeg libtiff libcamera libepoxy boost libexif libpng ];
  cmakeFlags = [
    "-DENABLE_QT=0"
    "-DENABLE_OPENCV=0"
    "-DENABLE_TFLITE=0"
    "-DENABLE_X11=1"
    "-DENABLE_DRM=1"
    (if (stdenv.hostPlatform.isAarch64) then "-DARM64=ON" else "-DARM64=OFF")
  ];

  meta = with lib; {
    description = "Userland tools interfacing with Raspberry Pi cameras";
    homepage = "https://github.com/raspberrypi/libcamera-apps";
    license = licenses.bsd2;
    platforms = [ "aarch64-linux" ];
  };
}
