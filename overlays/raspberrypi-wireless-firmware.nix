{ bluez-firmware, firmware-nonfree }:
{ lib, stdenvNoCC }:

stdenvNoCC.mkDerivation {
  pname = "raspberrypi-wireless-firmware";
  version = "2024-02-26";

  srcs = [ ];

  sourceRoot = ".";

  dontUnpack = true;
  dontBuild = true;
  # Firmware blobs do not need fixing and should not be modified
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/firmware/brcm"
    mkdir -p "$out/lib/firmware/cypress"

    # Wifi firmware
    cp -rv "${firmware-nonfree}/debian/config/brcm80211/." "$out/lib/firmware/"

    # Bluetooth firmware
    cp -rv "${bluez-firmware}/debian/firmware/broadcom/." "$out/lib/firmware/brcm"

    # brcmfmac43455-stdio.bin is a symlink to ../cypress/cyfmac43455-stdio.bin that doesn't exist
    # See https://github.com/RPi-Distro/firmware-nonfree/issues/26
    ln -s "./cyfmac43455-sdio-standard.bin" "$out/lib/firmware/cypress/cyfmac43455-sdio.bin"

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
