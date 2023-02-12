{ lib, stdenvNoCC, fetchFromGitHub }:

stdenvNoCC.mkDerivation {
  pname = "raspberrypi-wireless-firmware";
  version = "2023-01-19";

  srcs = [
    (fetchFromGitHub {
      name = "bluez-firmware";
      owner = "RPi-Distro";
      repo = "bluez-firmware";
      rev = "9556b08ace2a1735127894642cc8ea6529c04c90";
      sha256 = "gKGK0XzNrws5REkKg/JP6SZx3KsJduu53SfH3Dichkc=";
    })
    (fetchFromGitHub {
      name = "firmware-nonfree";
      owner = "RPi-Distro";
      repo = "firmware-nonfree";
      rev = "8e349de20c8cb5d895b3568777ec53cbb333398f";
      sha256 = "45/FnaaZTEG6jLmbaXohpNpS6BEZu3DBDHqquq8ukXc=";
    })
  ];

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
