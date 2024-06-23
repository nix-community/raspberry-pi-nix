{ libcamera-apps-src, lib, pkgs, stdenv }:
stdenv.mkDerivation rec {
  pname = "libcamera-apps";
  version = "v1.5.0";

  src = libcamera-apps-src;

  nativeBuildInputs = with pkgs; [ meson pkg-config ];
  buildInputs = with pkgs; [ libjpeg libtiff libcamera libepoxy boost libexif libpng ninja ];
  mesonFlags = [
    "-Denable_qt=false"
    "-Denable_opencv=false"
    "-Denable_tflite=false"
    "-Denable_drm=true"
  ];
  # Meson is no longer able to pick up Boost automatically.
  # https://github.com/NixOS/nixpkgs/issues/86131
  BOOST_INCLUDEDIR = "${lib.getDev boost}/include";
  BOOST_LIBRARYDIR = "${lib.getLib boost}/lib";

  meta = with lib; {
    description = "Userland tools interfacing with Raspberry Pi cameras";
    homepage = "https://github.com/raspberrypi/libcamera-apps";
    license = licenses.bsd2;
    platforms = [ "aarch64-linux" ];
  };
}
