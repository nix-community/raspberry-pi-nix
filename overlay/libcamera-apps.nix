{ libcamera-apps-src, lib, stdenv, fetchFromGitHub, fetchpatch, cmake
, pkg-config, libjpeg, libtiff, libpng, libcamera, libepoxy, boost, libexif }:

stdenv.mkDerivation rec {
  pname = "libcamera-apps";
  version = "v1.1.2";

  src = libcamera-apps-src;

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
