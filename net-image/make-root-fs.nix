# Builds a directory containing a populated /nix/store with the closure
# of store paths passed in the storePaths parameter, in addition to the
# contents of a directory that can be populated with commands.
{
  pkgs,
  lib,
  # List of derivations to be included
  storePaths,
  # Shell commands to populate the ./files directory.
  # All files in that directory are copied to the root of the FS.
  populateRootCommands ? "",
  perl
}:

let
  netbootClosureInfo = pkgs.buildPackages.closureInfo { rootPaths = storePaths; };
in
pkgs.stdenv.mkDerivation {
  name = "root-fs";

  nativeBuildInputs = [
    perl
  ];

  buildCommand = ''
    echo "Populating image with command: ${populateRootCommands}"
    mkdir -p ./files
    ${populateRootCommands}

    echo "Preparing store paths for image..."
    # Create nix/store before copying path
    mkdir -p ./rootImage/nix/store

    xargs -I % cp -a --reflink=auto % -t ./rootImage/nix/store/ < ${netbootClosureInfo}/store-paths
    (
      GLOBIGNORE=".:.."
      shopt -u dotglob

      for f in ./files/*; do
          cp -a --reflink=auto -t ./rootImage/ "$f"
      done
    )

    # Also include a manifest of the closures in a format suitable for nix-store --load-db
    cp ${netbootClosureInfo}/registration ./rootImage/nix-path-registration

    # done
    echo "Image populated."
    ls -aR ./rootImage
    cp -r ./rootImage/ $out
  '';
}
