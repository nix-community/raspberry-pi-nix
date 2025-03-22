{ rpicam-apps-src
, libcamera-src
, libpisp-src
, lock
, ...
}:
final: prev: {
  # A recent known working version of rpicam-apps
  libcamera-apps =
    final.callPackage ./rpicam-apps.nix { inherit rpicam-apps-src; };

  libpisp = final.stdenv.mkDerivation {
    name = "libpisp";
    version = lock.nodes.libpisp-src.original.ref;
    src = libpisp-src;
    nativeBuildInputs = with final; [ pkg-config meson ninja ];
    buildInputs = with final; [ nlohmann_json boost ];
    # Meson is no longer able to pick up Boost automatically.
    # https://github.com/NixOS/nixpkgs/issues/86131
    BOOST_INCLUDEDIR = "${prev.lib.getDev final.boost}/include";
    BOOST_LIBRARYDIR = "${prev.lib.getLib final.boost}/lib";
    # Copy image filters into lib
    postInstall = ''
      mkdir -p $out/lib/libpisp/backend
      cp src/libpisp/backend/*.json $out/lib/libpisp/backend
    '';
  };

  libcamera = prev.libcamera.overrideAttrs (old: {
    version = lock.nodes.libcamera-src.original.ref;
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
      "-Ddocumentation=disabled"
      "-Dpycamera=enabled"
    ];

    # Issue introduced recently
    # https://github.com/raspberrypi/libcamera/issues/226
    CXXFLAGS = "-Wno-sign-compare -Wno-stringop-truncation";
  });
}
