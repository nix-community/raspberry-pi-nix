{ rpicam-apps-src
, libcamera-src
, libpisp-src
, ...
}:
final: prev: {
  # A recent known working version of rpicam-apps
  libcamera-apps =
    final.callPackage ./rpicam-apps.nix { inherit rpicam-apps-src; };

  libpisp = final.stdenv.mkDerivation {
    name = "libpisp";
    version = "1.0.7";
    src = libpisp-src;
    nativeBuildInputs = with final; [ pkg-config meson ninja ];
    buildInputs = with final; [ nlohmann_json boost ];
    # Meson is no longer able to pick up Boost automatically.
    # https://github.com/NixOS/nixpkgs/issues/86131
    BOOST_INCLUDEDIR = "${prev.lib.getDev final.boost}/include";
    BOOST_LIBRARYDIR = "${prev.lib.getLib final.boost}/lib";
  };

  libcamera = prev.libcamera.overrideAttrs (old: {
    version = "0.3.1";
    src = libcamera-src;
    buildInputs = old.buildInputs ++ (with final; [
      libpisp
      openssl
      libtiff
      (python3.withPackages (ps: with ps; [
        python3-gnutls
        pybind11
        pyyaml
        ply
      ]))
      libglibutil
      gst_all_1.gst-plugins-base
    ]);
    patches = [ ];
    postPatch = ''
      patchShebangs src/py/ utils/
    '';
    mesonFlags = [
      "--buildtype=release"
      "-Dpipelines=rpi/vc4,rpi/pisp"
      "-Dipas=rpi/vc4,rpi/pisp"
      "-Dv4l2=true"
      "-Dgstreamer=enabled"
      "-Dtest=false"
      "-Dlc-compliance=disabled"
      "-Dcam=disabled"
      "-Dqcam=disabled"
      "-Ddocumentation=enabled"
      "-Dpycamera=enabled"
    ];
  });
}
