{ libcamera-apps-src
, libcamera-src
, libpisp-src
, ...
}:
final: prev:
{
  # A recent known working version of libcamera-apps
  libcamera-apps =
    final.callPackage ./libcamera-apps.nix { inherit libcamera-apps-src; };

  libpisp = final.stdenv.mkDerivation {
    name = "libpisp";
    version = "1.0.3";
    src = libpisp-src;
    nativeBuildInputs = with final; [ pkg-config meson ninja ];
    buildInputs = with final; [ nlohmann_json boost ];
    # Meson is no longer able to pick up Boost automatically.
    # https://github.com/NixOS/nixpkgs/issues/86131
    BOOST_INCLUDEDIR = "${prev.lib.getDev final.boost}/include";
    BOOST_LIBRARYDIR = "${prev.lib.getLib final.boost}/lib";
  };

  libcamera = prev.libcamera.overrideAttrs (old: {
    version = "0.1.0";
    src = libcamera-src;
    buildInputs = old.buildInputs ++ (with final; [ libpisp ]);
    patches = [ ];
  });
}
