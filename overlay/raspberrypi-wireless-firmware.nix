{ bluez-firmware-src, firmware-nonfree-src }:
{ lib, stdenvNoCC, fetchFromGitHub }:

stdenvNoCC.mkDerivation {
  pname = "raspberrypi-wireless-firmware";
  version = "2023-01-19";

  srcs = [ bluez-firmware-src firmware-nonfree-src ];

  sourceRoot = ".";

  dontBuild = true;
  # Firmware blobs do not need fixing and should not be modified
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/firmware/brcm"

    # Wifi firmware
    cp -rv "$NIX_BUILD_TOP/firmware-nonfree/debian/config/brcm80211/." "$out/lib/firmware/"

    # Bluetooth firmware
    cp -rv "$NIX_BUILD_TOP/bluez-firmware/broadcom/." "$out/lib/firmware/brcm"

    # CM4 symlink must be added since it's missing from upstream
    pushd $out/lib/firmware/brcm &>/dev/null
    ln -s "./brcmfmac43455-sdio.txt" "$out/lib/firmware/brcm/brcmfmac43455-sdio.raspberrypi,4-compute-module.txt"

    # There are two options for the brcmfmac43455 binary: minimal or
    # standard. For more info see the readme at:
    # https://github.com/RPi-Distro/firmware-nonfree/blob/bullseye/debian/config/brcm80211/cypress/README.txt

    ln -sf ../cypress/cyfmac43455-sdio-minimal.bin brcmfmac43455-sdio.bin
    popd &>/dev/null

    runHook postInstall
  '';

  meta = with lib; {
    description =
      "Firmware for builtin Wifi/Bluetooth devices in the Raspberry Pi 3+ and Zero W";
    homepage = "https://github.com/RPi-Distro/firmware-nonfree";
    license = licenses.unfreeRedistributableFirmware;
    platforms = platforms.linux;
    maintainers = with maintainers; [ lopsided98 ];
  };
}
